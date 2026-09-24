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
- Linux: ALSA sequencer. **Sem teclado físico**, teste com teclado virtual:
  `sudo apt install vmpk` (Virtual MIDI Piano Keyboard) ou
  `sudo modprobe snd-virmidi` + `aconnect`/`amidi`. `aconnect -l` lista as
  portas (hoje só `System`).
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

1. **(manual, Linux)** Com VMPK (ou teclado real), notas aparecem no monitor
   e as teclas acendem; desplugar/replugar reconecta sozinho.
2. **(manual, Android)** Com teclado USB via OTG (se houver) idem; sem
   teclado, registre o que foi possível testar.
3. Unidade de `event.timestamp` por plataforma e jitter vs. carimbo de
   chegada registrados (100 notas).
4. Testes unitários verdes; `just analyze` e `just test` limpos.

## Notas de execução

(preencher)
