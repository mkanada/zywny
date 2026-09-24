# K06 — Motor de áudio no Windows (WASAPI)

**Repo:** zywny · **Depende de:** K04, X02 · **Decisão necessária:** **D-WIN**

## Objetivo

`zywny_audio.dll` compilada e empacotada no bundle Windows, tocando a
partitura como no Linux.

## Ler antes (só isto)

- Notas de execução de X02 (como a `verovio.dll` foi montada e instalada) e
  de K04.
- `native/zywny_audio/Cargo.toml`, `tool/build_audio_linux.sh`,
  `windows/CMakeLists.txt` (seção `install`).

## Contexto que você precisa

- Alvo: `x86_64-pc-windows-msvc` (compilar **no Windows**, com VS Build
  Tools — é o mesmo ambiente de X02). O cpal usa **WASAPI** em modo
  compartilhado por padrão: latência típica 10-30 ms, suficiente. ASIO é
  feature opcional do cpal e exige o SDK da Steinberg — **fora** da 1.0.
- A DLL fica ao lado do `.exe`; `findAudioLibrary()` no Windows =
  `<dir do exe>\zywny_audio.dll`, com `ZYWNY_AUDIO_LIBRARY_PATH` valendo.
- Script: `tool/build_audio_windows.ps1` (cargo build --release e cópia).
- Troca de dispositivo padrão no Windows (fone USB) também derruba o stream;
  reuse o tratamento de K05.

## O que fazer

1. Build e script. 2. `windows/CMakeLists.txt` instala a DLL. 3. Ramo
   Windows em `findAudioLibrary()`. 4. Medir.

## Fora de escopo

- MIDI no Windows (M01). ASIO.

## Critérios de aceite

1. **(manual, Windows)** bundle release toca a Gymnopédie e o Maple Leaf Rag
   com destaque sincronizado; latência reportada registrada.
2. Trocar o dispositivo de saída no meio não derruba o app.
3. Linux inalterado; `just analyze`, `just test` limpos.

## Notas de execução

(preencher)
