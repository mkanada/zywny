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

(preencher)
