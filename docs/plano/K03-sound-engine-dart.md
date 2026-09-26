# K03 — `SoundEngine` (Dart) + `NativeSoundEngine` via FFI no Linux

**Repo:** zywny · **Depende de:** K02 · **Decisão necessária:** não

## Objetivo

Uma interface Dart única para "algo que faz som a partir de MIDI", com a
primeira implementação sobre o motor Rust. Todas as outras saídas (teclado
externo em M03, Web em W04) implementam a mesma interface.

## Ler antes (só isto)

- `native/zywny_audio/include/zywny_audio.h` e as notas de K02.
- `lib/native_paths.dart` (padrão de achar a lib nativa).
- `pubspec.yaml` (seção `assets`).

## Contexto que você precisa

- Interface proposta (`lib/audio/sound_engine.dart`):

  ```dart
  abstract class SoundEngine {
    /// Relógio do dispositivo, em segundos desde um zero arbitrário e
    /// monotônico. É o que se OUVE agora (já descontada a latência).
    double get nowSeconds;
    /// Menor instante que ainda dá para agendar com precisão.
    double get earliestScheduleSeconds;
    double get outputLatencySeconds;
    Future<void> start();                       // abre o dispositivo
    Future<void> loadSoundFont(Uint8List bytes);
    void send(List<int> midi);                  // imediato (monitor, M02)
    void schedule(List<ScheduledMidi> events);  // at = segundos do relógio acima
    void clearScheduled();
    void allNotesOff();                         // + limpa a agenda
    Future<void> dispose();
  }
  class ScheduledMidi { final double at; final int status, d1, d2; }
  ```
  Segundos (double) na interface, quadros só dentro da implementação nativa
  (`frame = (at * sampleRate).round()`), para a Web (AudioContext.currentTime
  em segundos) caber sem conversão.
- `NativeSoundEngine` (`lib/audio/native_sound_engine.dart`) usa `dart:ffi`
  com `DynamicLibrary.open`, `lookupFunction` e um `Pointer<ZyEvent>`
  alocado com `malloc` e reusado (cresça quando precisar) para `schedule` em
  lote. Localização da lib: siga `findVerovioLibrary()` — um
  `findAudioLibrary()` em `native_paths.dart` com o mesmo esquema
  (`ZYWNY_AUDIO_LIBRARY_PATH`, bundle `lib/`, árvore do projeto).
- Imports de `dart:ffi` não compilam na Web: deixe a criação do motor atrás
  de uma função fábrica num arquivo com import condicional
  (`sound_engine_factory.dart` → `_native.dart` / `_stub.dart`), já
  preparando W04. Por enquanto o stub lança `UnsupportedError`.
- Soundfont: conforme D-SF. Se for asset, arquivo grande no bundle aumenta o
  APK (K05 mede). Carregue com `rootBundle.load` e passe os bytes.
- O motor é criado **uma vez** (no `initState` da tela ou num serviço
  singleton) e sobrevive a novos `.vsb`; `dispose` no `dispose` da tela.

## O que fazer

1. `SoundEngine`, `ScheduledMidi`, fábrica com import condicional.
2. `NativeSoundEngine` + `findAudioLibrary`.
3. Um painel de debug (só com `--debug`, como o modo debug existente em
   `main.dart`): botão "tocar escala de teste" e texto com sample rate,
   latência e estatísticas (`zy_stat`).
4. Teste Dart (`test/native_sound_engine_test.dart`) marcado para rodar só
   quando a lib existir (`skip:` se não achar), que cria o motor, agenda 10
   notas e confere que `nowSeconds` anda (tolerância folgada; roda no CI sem
   áudio? — registre; se o cpal falhar sem dispositivo, pule com motivo).

## Fora de escopo

- Tocar a partitura (K04). Entrada MIDI (M01).

## Critérios de aceite

1. **(manual)** `just run -- --debug` (ou o modo debug do app), botão de
   escala toca; números aparecem.
2. `nowSeconds` monotônico em 1 000 leituras seguidas (teste).
3. `allNotesOff` corta uma nota longa agendada (manual).
4. Nenhum arquivo alcançável a partir de `sound_engine.dart` e do ramo stub
   da fábrica importa `dart:ffi` ou `dart:io` (confira com `grep`; o resto
   do app ainda não compila na Web, então `flutter build web` não serve de
   prova aqui).
5. `just analyze` e `just test` limpos.

## Notas de execução

**Implementado em 2026-09-26.** `lib/audio/`:

- `sound_engine.dart`: `SoundEngine` (igual ao proposto) + `ScheduledMidi`.
  Só importa `dart:typed_data` — compila na Web sem alteração nenhuma
  (critério 4).
- `native_sound_engine.dart`: `NativeSoundEngine` — bindings 1:1 às 13
  funções de `zy_*` (`_ZyBindings`, mesmo estilo do `VerovioBindings`),
  `_ZyEvent` (`Struct` espelhando o `ZyEvent` do header C), buffer de
  `malloc<_ZyEvent>` reusado em `schedule` (só realoca quando o lote cresce
  além da capacidade atual, nunca encolhe). `size_t`/`uint64_t` do header
  mapeados para `Uint64` — os alvos do plano (Linux, Android arm64,
  Windows x64) são todos de 64 bits; registrado no código, não é o caminho
  genérico certo se um alvo de 32 bits entrar depois. Getters extras fora
  da interface (`sampleRate`, `stat`) só para o painel de debug.
- `sound_engine_factory.dart` → `_native.dart`/`_stub.dart` (nomes exatos
  sugeridos), import condicional em `dart.library.io`. O stub lança
  `UnsupportedError` (W04 substitui).
- `lib/native_paths.dart`: `findAudioLibrary()` ao lado de
  `findVerovioLibrary()`, mesmo esquema
  (`ZYWNY_AUDIO_LIBRARY_PATH`/bundle/árvore do projeto) — mas o fallback de
  desenvolvimento é um caminho relativo
  (`native/zywny_audio/target/release/libzywny_audio.so`), porque
  `zywny_audio` mora *neste* repo, não num externo como o Verovio.
- `sound_engine_debug_panel.dart` + `pubspec.yaml` (`ffi` passou de
  transitivo a `dependencies` direto): painel condicionado a
  `widget.debugMode` em `main.dart`, um botão só ("Tocar escala de
  teste (.sf2)") que abre um `.sf2` por `file_selector` (D-SF continua
  aberta — sem asset embutido ainda), carrega, agenda a escala de dó maior
  a 120 bpm com `earliestScheduleSeconds + 200 ms` de margem, e mostra
  sample rate/latência/`underruns`/`descartados` (`Timer.periodic` de
  500 ms enquanto o motor está de pé).
- **Teste** (`test/native_sound_engine_test.dart`, critério 2): usa
  `skip:` (não "print e retorna", que é o jeito do lado Rust — o Dart tem
  suporte de verdade a pular um teste) quando `findAudioLibrary()` não acha
  a lib; dentro do teste, se `zy_engine_new` falhar em tempo de execução
  (sem dispositivo de áudio — CI, por exemplo), `markTestSkipped` com o
  motivo em vez de falhar, como pedido. Quando um `.sf2` de teste existe
  (`ZYWNY_TEST_SF2` ou `/usr/share/sounds/sf2/TimGM6mb.sf2`), carrega e
  agenda 10 notas de verdade antes de conferir `nowSeconds` monotônico em
  1000 leituras; sem nenhum dos dois, só confere o relógio (ainda
  significativo: `ZyEngine::new` já teria aberto o dispositivo e o relógio
  anda por extrapolação de tempo mesmo sem `load_sf2`). Rodou de ponta a
  ponta nesta máquina (dispositivo real, `.sf2` real, 10 notas agendadas de
  verdade) — verde.
- **Critério 4** (grep manual): `grep -rn "dart:ffi\|dart:io"
  lib/audio/sound_engine.dart lib/audio/sound_engine_factory.dart
  lib/audio/_stub.dart` só acha a menção em texto de um doc-comment, nenhum
  `import` de verdade.
- **`flutter build linux --release`**: `libzywny_audio.so` (K02) e
  `libverovio.so` lado a lado em `build/linux/x64/release/bundle/lib/`; o
  app sobe com `--debug` sem exceção (processo vivo, log limpo — só o aviso
  de sempre do Impeller/tema de cursor, nada do motor de áudio). **Não
  consegui** clicar no botão/escolher um `.sf2`/ouvir a escala neste
  ambiente (sandbox sem captura de tela/clique em janela) — critérios 1 e 3
  ficam para checagem manual do usuário, como as partes manuais de K01/K02.
- **`just analyze`/`just test`**: limpos (24 testes Dart, incluindo o
  novo).

**Fora de escopo, como previsto**: tocar a partitura de verdade é K04;
entrada MIDI é M01.
