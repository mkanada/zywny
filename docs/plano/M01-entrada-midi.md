# M01 — Dispositivos MIDI e entrada (monitor de notas)

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** **D-MIDI**
(recomendação: `flutter_midi_command`)

## Objetivo

O app lista os dispositivos MIDI, conecta num teclado e recebe as notas que o
usuário toca, com **carimbo de tempo confiável**, expostas num serviço Dart
único. Uma tela/painel de monitor mostra as notas chegando (e um teclado
desenhado acendendo as teclas). Linux e Android nesta etapa; Windows entra
junto se X02 estiver pronto; Web é W03.

## Ler antes (só isto)

- Este README (Fatos: MIDI I/O, Windows, Web).
- `lib/main.dart` `build` (L550-L638) — onde botões/painéis ficam hoje (o
  painel "Opções" em `layout_panel.dart` é o modelo de painel lateral).
- Página do pacote: `pub.dev/packages/flutter_midi_command` (README e
  exemplo) — só para confirmar nomes; os principais estão abaixo.

## Contexto que você precisa

- `flutter_midi_command` 1.3.0: `final midi = MidiCommand();`
  `await midi.devices` → `List<MidiDevice>` (`id`, `name`, `type`,
  `inputPorts`, `onConnectionStateChanged`); `await
  midi.connectToDevice(d)` (lança `MidiConnectionException` e subtipos;
  timeout padrão 30 s); `midi.onMidiDataReceived` → `MidiDataReceivedEvent
  {device, transport, timestamp, message}` com `message` tipada
  (`NoteOnMessage`, `NoteOffMessage`, `CCMessage`, …); `midi.onMidiSetupChanged`
  para hot-plug; `midi.sendData(bytes, deviceId:)`; `MidiMessageParser`
  para bytes crus. BLE é o pacote `flutter_midi_command_ble` (fora deste
  passo).
- **Note-on com velocity 0 = note-off** (running status de muitos teclados).
  Normalize no serviço.
- **Carimbo de tempo**: a unidade de `event.timestamp` varia por plataforma
  (documentação não diz) — **meça e registre**. Independentemente disso,
  carimbe cada evento na chegada com o relógio do app (o mesmo
  `SoundEngine.nowSeconds` de K03 se já existir, senão um `Stopwatch`
  global do app) — é esse que o treino usa. Registre o jitter entre
  timestamp do plugin e carimbo de chegada.
- Linux: ALSA sequencer. O `flutter_midi_command_linux`
  (`alsa_seq_linux_device.dart`, master do GitHub) **só lista portas com
  `SND_SEQ_PORT_TYPE_HARDWARE`** e pula os clientes 0 (System) e 14 (Midi
  Through). Por isso VMPK (porta APPLICATION) e `snd-virmidi` (SOFTWARE)
  **não aparecem** — confira se a 1.3.0 tem o mesmo filtro. O timestamp do
  evento é `DateTime.now().millisecondsSinceEpoch`, gerado no plugin.
  **Sem teclado físico**, use `just fake-midi` (`tool/fake_midi_keyboard.py`):
  um cliente seq que se declara HARDWARE e toca notas. Para tocar ao vivo,
  use `just fake-midi --relay` + `aconnect <VMPK> <porta falsa>`: a porta
  falsa repassa o que o VMPK mandar. `just fake-midi --list` mostra quais
  portas o plugin enxergaria. Para monitorar, use
  `aseqdump -p <cliente>:0`, `aconnect -l` e `cat /proc/asound/seq/clients`
  (mostra se o app assinou a porta).
- Android: USB MIDI class-compliant via OTG funciona sem permissão especial;
  adicionar ao manifest `<uses-feature android:name="android.software.midi"
  android:required="false"/>`. `minSdk` ≥ 23 para `android.media.midi` (o
  plugin exige 21, o recurso MIDI é 23; K05 já pode ter subido para 26).
- Windows 10: porta pode estar **ocupada** por outro programa (DAW) — WinMM
  de cliente único. Mostre erro claro ("feche o outro programa que usa o
  teclado"). Win11 com Windows MIDI Services é multi-cliente.
- Guarde o último dispositivo escolhido (`shared_preferences`, se ainda não
  houver pacote de preferências, adicione) e reconecte ao abrir o app e em
  `onMidiSetupChanged`.
- Serviço sugerido (`lib/midi/midi_input_service.dart`):

  ```dart
  class PlayedNote { final int pitch, velocity, channel; final bool on;
                     final double atSeconds; /* relógio do app */ }
  abstract class MidiInputService {
    Stream<PlayedNote> get notes;
    Stream<int> get sustain;               // CC64 0..127
    ValueListenable<Set<int>> get held;    // teclas apertadas agora
  }
  ```
  A implementação concreta fica atrás de uma fábrica (a Web usará o mesmo
  plugin, mas pode precisar de ajustes em W03).

## O que fazer

1. Dependência, `MidiDeviceManager` (lista, conecta, reconecta, estado) e
   `MidiInputService`.
2. UI: seletor de dispositivo (ícone na AppBar) e painel "Monitor MIDI" com
   as últimas 20 mensagens e um teclado de 88 teclas desenhado com
   `CustomPaint` acendendo `held`.
3. Testes do parsing/normalização com mensagens sintéticas (velocity 0,
   running status via `MidiMessageParser`, CC64).

## Fora de escopo

- Som da entrada (M02). Saída MIDI (M03). BLE (anotar como pendência).

## Critérios de aceite

1. **(manual, Linux)** Com `just fake-midi` (ou VMPK via
   `--relay`, ou teclado real), notas aparecem no monitor
   e as teclas acendem; desplugar/replugar reconecta sozinho.
2. **(manual, Android)** Com teclado USB via OTG (se houver) idem; sem
   teclado, registre o que foi possível testar.
3. Unidade de `event.timestamp` por plataforma e jitter vs. carimbo de
   chegada registrados (100 notas).
4. Testes unitários verdes; `just analyze` e `just test` limpos.

## Notas de execução

- **Dependência**: `flutter_midi_command: ^1.3.0` (D-MIDI resolvida como
  recomendado) + `shared_preferences: ^2.5.5` (último dispositivo). A API
  real da 1.3.0 já resolve sozinha os dois problemas que o passo pedia para
  "normalizar no serviço": `onMidiDataReceived` entrega `MidiPacket`s com
  running status **já expandido** (um `NoteOnMessage`/`CCMessage`/... por
  mensagem completa, nunca bytes crus a montar) e o
  `MidiMessageParser` interno já troca note-on com velocity 0 por
  `NoteOffMessage` antes de chegar no app
  (`flutter_midi_command-1.3.0/lib/src/midi_message_parser.dart:223`).
  Mesmo assim, `FlutterMidiInputService.handleMessage` (abaixo) refaz essa
  troca por conta própria — defesa própria, não uma aposta num detalhe de
  implementação de terceiros.
- **Arquivos** (`lib/midi/`):
  - `midi_input_service.dart` — `PlayedNote`, a interface
    `MidiInputService` e `FlutterMidiInputService` (implementação real,
    com o stream de eventos injetável para teste sem canal de
    plataforma nenhum).
  - `midi_device_manager.dart` — `MidiDeviceManager`: lista, conecta,
    guarda o último dispositivo (`shared_preferences`) e reconecta sozinho
    na abertura e a cada `onMidiSetupChanged` (hot-plug).
  - `piano_keyboard.dart` — `PianoKeyboardPainter`, teclado de 88 teclas
    (A0–C8) em `CustomPaint`, acendendo `held`.
  - `midi_device_picker.dart` — ícone da AppBar + diálogo de escolha de
    dispositivo (`showMidiDevicePicker`).
  - `midi_monitor_panel.dart` — painel "Monitor MIDI" (mesmo padrão visual
    do `LayoutPanel`, ancorado à esquerda em vez da direita): últimas 20
    mensagens e o teclado desenhado.
- **Relógio de carimbo**: `_ScoreHomePageState` mantém um `Stopwatch`
  próprio (`_appClock`, roda desde a abertura do app) e passa para o
  serviço `nowSeconds: () => _engine?.nowSeconds ?? _appClock...`. Como
  `_engine` (K03) só existe depois que o som é ligado, o carimbo migra
  sozinho para o relógio de áudio a partir daí — antes disso usa o
  `Stopwatch`, como o passo pedia.
- **Limitação conhecida, não resolvida nesta sessão**: `held`
  (`FlutterMidiInputService`) é global a todos os dispositivos conectados,
  não por dispositivo — se um teclado desconectar com uma tecla presa, o
  desenho fica com a tecla acesa (sem note-off correspondente). Não é
  coberto pelos critérios de aceite deste passo; anotar se virar
  problema em T02/T03.
- `just analyze` e `just test` limpos (critério 4), incluindo
  `test/midi_input_service_test.dart` (running status e velocity 0 via
  `MidiMessage.parse` de verdade, CC64, held). `test/widget_test.dart`
  precisou de fakes de `MidiCommandPlatform`/`SharedPreferencesAsyncPlatform`
  (`MockPlatformInterfaceMixin`) porque `ScoreHomePage` agora abre os dois
  canais de plataforma assim que a tela existe — sem eles o primeiro
  `pumpWidget(MyApp())` já lançava.
- **2026-09-27, verificação parcial do critério 1**: `just run` no Linux
  sem hardware — o app registrou um cliente ALSA `flutter_midi_command`
  (`aconnect -l`), confirmando que M01 abre e escuta a porta certa. Liguei
  `tool/fake_midi_keyboard.py 60 64 67 --once` nela via `aconnect` e o
  `flutter run` não lançou nenhuma exceção ao receber as notas nem quando o
  cliente falso desapareceu depois (hot-plug de saída). **Não verificado**
  nesta sessão, por falta de captura de tela no ambiente: as notas
  aparecendo no painel "Monitor MIDI" e as teclas acendendo a olho — falta
  um `just run` interativo (clicar no ícone de piano, tocar o teclado
  falso ou um de verdade, olhar o painel) para fechar o critério 1 de
  verdade. Critério 2 (Android/OTG) e a medição de unidade/jitter do
  timestamp (critério 3) também não foram feitos — pedem hardware/aparelho
  à mão.
