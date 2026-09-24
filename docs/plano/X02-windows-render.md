# X02 — Windows: `verovio.dll` e partitura rodando (sem som)

**Depende de:** — · **Decisão necessária:** **D-WIN** (onde compilar/testar)

## Objetivo

O zywny roda no Windows 10/11 x64 gerando o `.vsb` via FFI e desenhando a
partitura, como no Linux. Sem som. Pré-requisito de K06.

## Ler antes (só isto)

- `lib/native_paths.dart`, `lib/verovio_render.dart` L75-L124.
- `linux/CMakeLists.txt` L100-L120 (como a `libverovio.so` é instalada no
  bundle — replique a ideia em `windows/CMakeLists.txt`).
- `windows/CMakeLists.txt` (seção `install`).
- `/home/mauricio/rust_projects/verovio_flutter_bridge/verovio/bindings/dart/build_linux_so.sh`
  (quais alvos/flags do CMake do Verovio ele usa).
- `docs/plano/windows-a-partir-do-linux.md` — build mingw já testado, os
  dois ajustes que o fork precisa e as opções de VM/CI.

## Contexto que você precisa

- **Não existe build Windows do fork ainda.** O Verovio upstream compila no
  MSVC com CMake (`verovio/cmake/CMakeLists.txt`); a opção de biblioteca
  compartilhada é a mesma usada por `build_linux_so.sh` (leia o script para
  ver as flags `-D...`). O wrapper C é `verovio/tools/c_wrapper.cpp`; no MSVC
  as funções precisam ser exportadas (`__declspec(dllexport)` ou
  `WINDOWS_EXPORT_ALL_SYMBOLS ON` no CMake — o mais simples).
- A máquina de desenvolvimento é Linux, sem Windows. Pela decisão D-WIN:
  - (a) máquina/VM Windows 11 com Visual Studio Build Tools 2022 + CMake +
    Flutter: compile e rode lá (recomendado);
  - (b) cross-compile com `mingw-w64` a partir do Linux: gera a DLL, mas o
    app Flutter para Windows só compila no Windows de qualquer jeito.
  Se a decisão não estiver registrada no README, **pare e pergunte**.
- No Windows, `DynamicLibrary.open` aceita o caminho completo; a DLL
  instalada fica ao lado do `.exe` (`<bundle>/verovio.dll`), então
  `File(Platform.resolvedExecutable).parent.path + '\\verovio.dll'`.
- Os dados do Verovio vêm do mesmo zip de assets; `path_provider` funciona
  no Windows.
- Crie `tool/build_verovio_windows.ps1` (ou `.bat`) documentado no README do
  zywny; não versione a DLL.

## O que fazer

1. Script de build da `verovio.dll` (Release, x64), com símbolos exportados.
2. `windows/CMakeLists.txt`: `install(FILES .../verovio.dll DESTINATION
   "${INSTALL_BUNDLE_LIB_DIR}"...)` — no Windows `INSTALL_BUNDLE_LIB_DIR` é a
   raiz do bundle; confira e registre.
3. `findVerovioLibrary()` com ramo `Platform.isWindows` + variável
   `VEROVIO_LIBRARY_PATH` continuando a valer.
4. `flutter run -d windows` e `flutter build windows --release`.

## Fora de escopo

- Som e MIDI (K06, M01). Instalador (MSIX) — registrar como pendência.

## Critérios de aceite

1. **(manual, Windows)** `flutter build windows --release` gera um bundle que,
   copiado para outra pasta, abre a Gymnopédie, toca o destaque e vira página.
2. Tamanho da `verovio.dll` e tempo de geração do `.vsb` registrados.
3. Linux inalterado: `just analyze`, `just test`, `just run`.

## Notas de execução

(preencher)
