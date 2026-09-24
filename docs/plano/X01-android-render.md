# X01 — Android: `.vsb` e partitura rodando (sem som)

**Depende de:** — · **Decisão necessária:** não

## Objetivo

O zywny abre uma partitura, gera o `.vsb` via FFI e desenha no Android
(emulador x86_64 e aparelho arm64), exatamente como no Linux. Sem som. É
pré-requisito de K05 (motor de áudio no Android).

## Ler antes (só isto)

- `lib/native_paths.dart` (inteiro, ~30 linhas).
- `lib/verovio_render.dart` L75-L124 (`renderScoreToVsb`, `_renderInIsolate`).
- `lib/verovio_resources.dart` (extração do zip de dados).
- `lib/main.dart` L181-L198 (`_abrirPartitura`, usa `file_selector`).
- `android/app/build.gradle.kts`.
- `/home/mauricio/rust_projects/verovio_flutter_bridge/verovio/bindings/dart/build_android_so.sh`
  (cabeçalho de uso, ~40 linhas).

## Contexto que você precisa

- `build_android_so.sh [abi...]` gera `android-libs/<abi>/libverovio.so` no
  pacote Dart do bridge (`verovio/bindings/dart/android-libs/`). Hoje só
  existe `arm64-v8a`. ABIs padrão do script: `armeabi-v7a arm64-v8a x86
  x86_64`. Plataforma padrão `android-21` (variável `ANDROID_PLATFORM`).
  Já liga com a flag de página de 16 KB.
- NDKs instalados em `~/Android/Sdk/ndk/` (23.1 … 29.0). O script acha o mais
  novo sozinho.
- O `tool/build_verovio_linux.sh` do zywny faz `strip --strip-unneeded`
  depois do build ("unstripped Android .so files were ~10x bigger"). Faça o
  mesmo com o `llvm-strip` do NDK
  (`$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip`).
- No Android, `DynamicLibrary.open('libverovio.so')` (só o nome) acha a lib
  se ela estiver em `jniLibs/<abi>/` do APK. O caminho mais simples é
  apontar o `sourceSets` do Gradle para uma pasta do zywny
  (`android/app/src/main/jniLibs/`), populada por um script novo
  `tool/build_verovio_android.sh`, e **não** versionar os `.so` (acrescente
  ao `.gitignore`).
- `findVerovioLibrary()` hoje devolve um **caminho de arquivo** e lança
  `StateError` fora do Linux. O isolate (`_renderInIsolate`) recebe
  `libraryPath` no `VsbRenderRequest` e abre a lib nele. No Android passe
  `'libverovio.so'` (nome puro).
- Os dados do Verovio (`assets/verovio_data.zip`) são extraídos por
  `verovio_resources.dart` para um diretório do `path_provider` — funciona
  no Android sem mudança, mas confira o tempo da primeira extração.
- `file_selector` no Android usa o Storage Access Framework e devolve um
  `XFile` cujo `path` pode ser um caminho de cache — o FFI precisa de um
  arquivo real. Se `path` não for legível por `File`, copie os bytes
  (`xfile.readAsBytes()`) para um temporário e passe esse caminho.
  Os `typeGroups` com extensões (`mei`, `musicxml`, `mxl`, `xml`) podem não
  filtrar no Android (MIME desconhecido) — use `XTypeGroup` sem filtro no
  Android se o seletor vier vazio.
- Sem Impeller no Linux por um bug do Linux; **no Android use o padrão
  (Impeller)** e só troque se o antialiasing ficar ruim.

## O que fazer

1. `tool/build_verovio_android.sh`: chama `build_android_so.sh arm64-v8a
   x86_64`, faz `llvm-strip` e copia para `android/app/src/main/jniLibs/<abi>/`.
   Receita `just native-android` no `justfile`.
2. `findVerovioLibrary()` por plataforma (`Platform.isAndroid` → nome puro;
   Linux inalterado; outras plataformas continuam lançando com mensagem clara).
3. Ajuste de `_abrirPartitura` para o caso Android (cópia para temporário se
   preciso).
4. Rodar no emulador x86_64 (`flutter emulators --launch <id>` ou criar um AVD
   com API 34) e, se houver, num aparelho arm64.

## Fora de escopo

- Som, MIDI (K05, M01).
- Windows (X02). Ajustes de layout para tela pequena (só registrar nas notas).

## Critérios de aceite

1. `just native-android` gera os dois `.so` com strip; tamanho registrado.
2. **(manual)** No emulador: abrir `corpus/musicxml/Erik_Satie_-_Gymnopedie_No.1.mxl`
   (copie para o emulador com `adb push`) mostra a partitura; Play acende as
   notas e vira a página.
3. Tempo de geração do `.vsb` da Gymnopédie no emulador registrado nas notas
   (e no aparelho, se houver).
4. `just run` no Linux continua funcionando; `just analyze` e `just test`
   limpos.

## Notas de execução

(preencher)
