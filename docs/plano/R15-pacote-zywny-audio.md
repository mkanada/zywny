# R15 — Pacote `zywny_audio`

**Repo:** zywny · **Depende de:** R13 · **Decisão necessária:** sim, item
3 abaixo (onde fica o `diag_log`)

## Objetivo

O motor de som num pacote Flutter, `packages/zywny_audio`: a interface
`SoundEngine`, os motores nativo (FFI, `native/zywny_audio`) e Web
(SpessaSynth, `web_src`), o agendador, o metrônomo, o relógio do áudio e a
`PerformanceTrack`.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): "Divisão em
  pacotes".
- [R13](R13-pacote-zywny-music.md): as notas de execução.

## Contexto que você precisa

- Depois do R03 e do R06, `lib/audio/` só importa `music/` e `core/`.
  Arquivos: `sound_engine`, `sound_engine_factory` (import condicional
  `_native`/`_web`), `native_sound_engine`, `web_sound_engine`,
  `score_audio_scheduler`, `metronome`, `audio_playback_clock`,
  `soundfont_store`, `engine_opener` (só `openAppSoundEngine`),
  `audio_library_path` (R06) e o painel de depuração
  (`sound_engine_debug_panel*`, que é tela e fica no app).
- `music/performance_track.dart` (deixado de fora do R13 por depender do
  `score_bridge`) entra aqui; o pacote depende de `score_bridge` por path.
- O que o build espera, e onde:
  - Linux: `linux/CMakeLists.txt` L129–L137 instala
    `native/zywny_audio/target/release/libzywny_audio.so`;
    `findAudioLibrary` procura o mesmo caminho relativo ao diretório de
    trabalho;
  - Android: `jniLibs` montado por `tool/build_audio_android.sh` (`just`
    L135); `minSdk` 26 em `android/app/build.gradle*` L22;
  - Web: `tool/build_audio_web.sh` empacota `web_src/src/zywny_audio.js`
    em `web/audio/zywny_audio.js`; `tool/publish_web.sh` L21 confere.
  Mover a crate Rust e o `web_src` é opcional: o pacote Dart pode ficar em
  `packages/` e os fontes nativos onde estão. Decida pelo que mexer menos
  no build e anote.
- `soundfont_store.dart` usa `diag_log` (agora em `lib/core/`), assim como
  `midi/` (R16) e `render/`.

## O que fazer

1. `packages/zywny_audio/` (`resolution: workspace`; depende de
   `zywny_music`, `score_bridge`, `ffi`, `path_provider`, `web`…), com os
   arquivos acima e os testes deles (`score_audio_scheduler_test`,
   `native_sound_engine_test`, `metronome`…).
2. Os scripts de build e o `CMakeLists.txt` continuam achando a `.so` e o
   `.js` — conferir os caminhos relativos.
3. **Pergunte ao usuário** onde fica o `diag_log` (84 linhas): num pacote
   próprio mínimo (`packages/zywny_diag`), dentro de `zywny_audio`
   (exportado para o MIDI), ou trocado por um callback de log que o app
   injeta.
4. O grupo "áudio" sai do teste de camadas.

## Fora de escopo

O motor no Windows (K06). Mudar a API do `SoundEngine`.

## Critérios de aceite

1. `just analyze` e `just test` limpos; os testes do pacote rodam com
   `flutter test` dentro dele.
2. `just run` com som (Linux), o APK no celular (`just` alvo de Android) e
   `just web-smoke` tocam como antes **(manual nos dois primeiros)**.

## Notas de execução

