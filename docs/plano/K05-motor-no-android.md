# K05 — Motor de áudio no Android (cargo-ndk, AAudio) e latência

**Repo:** zywny · **Depende de:** K04, X01 · **Decisão necessária:** não

## Objetivo

O mesmo `zywny_audio` compilado para Android, empacotado no APK, tocando a
partitura com a latência medida. Soundfont empacotado com tamanho aceitável.

## Ler antes (só isto)

- Notas de execução de X01 (como a `libverovio.so` foi empacotada — repita o
  padrão), K01, K02, K04.
- `native/zywny_audio/Cargo.toml`, `tool/build_audio_linux.sh`.

## Contexto que você precisa

- Alvos Rust a instalar: `rustup target add aarch64-linux-android
  x86_64-linux-android`. Ferramenta: `cargo install cargo-ndk`; build:
  `cargo ndk -t arm64-v8a -t x86_64 -o <jniLibs> build --release`
  (gera `jniLibs/<abi>/libzywny_audio.so`). NDKs em `~/Android/Sdk/ndk/`
  (use o mesmo da X01; `ANDROID_NDK_HOME`).
- `cpal` no Android usa **AAudio** (API 26+). Se o `minSdk` do app for menor
  que 26, suba para 26 no `android/app/build.gradle.kts` (hoje é
  `flutter.minSdkVersion`) e registre.
- Página de 16 KB (exigência do Play para apps novos desde 2025): passe
  `-C link-arg=-Wl,-z,max-page-size=16384` (via `.cargo/config.toml` ou
  `RUSTFLAGS`) — o build da `libverovio.so` já faz o equivalente.
- `libc++_shared.so`: o cpal/oboe não é usado (AAudio direto via `ndk`), então
  normalmente não precisa; se o link pedir, registre.
- Latência Android: AAudio em modo `LowLatency`/`Exclusive` depende do
  aparelho. O cpal expõe pouco disso; meça com `zy_output_latency_frames` e
  com o teste de ouvido (bater na tela e ouvir). Aparelhos baratos: 40-100
  ms são comuns; bons: 10-20 ms. **Fone Bluetooth: 150-250 ms.**
- Dispositivo de saída muda (fone plugado, BT conectado): o stream do cpal
  pode morrer (`err_cb`). Trate reabrindo o stream no próximo comando ou por
  um evento — registre como foi feito.
- Tamanho: meça o APK (`flutter build apk --release --split-per-abi`) antes e
  depois; o `.sf2` provavelmente domina. Se passar de ~60 MB, avise o usuário
  (pode reabrir D-SF).
- Emulador tem áudio (sai no PC), mas a latência dele não vale nada: só
  aparelho real conta para o critério 3.

## O que fazer

1. `tool/build_audio_android.sh` + receita `just native-audio-android`.
2. `findAudioLibrary()` no Android = nome puro `libzywny_audio.so`.
3. Tratar perda do dispositivo de saída.
4. Medir.

## Fora de escopo

- MIDI no Android (vem com M01, que é multiplataforma pelo plugin).

## Critérios de aceite

1. **(manual)** Emulador: Play toca a Gymnopédie com destaque sincronizado.
2. **(manual)** Aparelho real (se houver): idem; latência reportada e a
   percebida registradas (modelo do aparelho).
3. Tamanho do APK por ABI registrado, antes/depois.
4. Plugar/desplugar fone durante a execução não derruba o app (manual).
5. Linux inalterado; `just analyze`, `just test` limpos.

## Notas de execução

(preencher)
