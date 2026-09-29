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

**Sem emulador nesta máquina** — todos os critérios foram verificados num
aparelho real (Samsung Galaxy M14, `SM-M146B`, Android 15/API 35,
arm64-v8a), plugado via USB/ADB.

**Critério 1**: `just native-android` gera `libverovio.so` stripado —
arm64-v8a 19M, x86_64 20M (`android/app/src/main/jniLibs/<abi>/`).
`flutter build apk --debug` empacota os dois `.so` corretamente
(confirmado por `unzip -l` do APK: `lib/arm64-v8a/libverovio.so`,
`lib/x86_64/libverovio.so`).

**Critério 2 — bug real encontrado e corrigido**: a primeira tentativa no
aparelho entrou num **loop de re-render infinito** assim que a partitura
abria (centenas de renders seguidos, ~400-600ms cada, sem nenhum toque do
usuário). Causa: `Text('status: $_status')` (`lib/main.dart` ~L1152) é
filho direto do `Column` da tela, não envolvido em `Expanded` como a área
da partitura (que é `Expanded`, L1140) — como a altura do `Column` é fixa,
a altura do texto de status (1 ou 2 linhas, dependendo do tamanho da
mensagem) rouba/devolve espaço da área da partitura. A mensagem
"renderizando NOME (LxA)…" é longa o bastante pra quebrar em 2 linhas numa
tela de celular (nunca quebrava numa janela de desktop); isso encolhe a
área da partitura o suficiente pra passar do limiar de 2% do `_onBoxSize`,
disparando outro render — cujo status muda de novo, alternando 1/2 linhas
pra sempre. Corrigido fixando `maxLines: 1` no `Text` do status (mesmo
commit). Depois da correção: abrir a Gymnopédie mostra a partitura
(5 páginas nessa tela, contra 1 no desktop), Play destaca as notas
(confirmado visualmente, nota em vermelho) e a virada de página acontece
sozinha — confirmado pelo usuário interagindo direto no aparelho.

**Critério 3 — tempo de geração no aparelho**: primeira abertura depois de
reinstalar o app (extrai `verovio_data.zip` pela primeira vez) — **8703ms**.
Reaberturas subsequentes, com os dados já extraídos: **319-630ms**
(variação por causa do redimensionamento/rotação da tela, cada um
disparando um re-render pro novo tamanho).

**Critério 4**: `just run` (Linux), `just analyze` e `just test` seguem
limpos depois da mudança (64/64 testes, sem avisos do analyzer).

**Segundo bug real encontrado e corrigido — tela apagava durante o Play**:
não é específico do Android (o app não travava nenhum wakelock em nenhuma
plataforma), só ficou óbvio testando num aparelho de verdade. `_playing`
era escrito direto em 7 lugares (`_togglePlay`, `_stop`,
`_togglePractice`/`_stopPractice`, `_onEntry`, o reset em
`_renderAndShow`); centralizado num setter `_setPlaying(bool)`
(`lib/main.dart` perto de `_togglePlay`) que também chama
`WakelockPlus.enable()`/`.disable()` (pacote `wakelock_plus`
adicionado ao `pubspec.yaml`), e `dispose()` solta o wakelock se o widget
for descartado tocando. Confirmado no `logcat` do aparelho: o Android
registrou `PowerManagerService: acquire WakeLock SCREEN_BRIGHT_WAKE_LOCK
... ws=WorkSource{... com.example.zywny}` ao apertar Play, segurou por
**3m04s contínuos** (a duração da Gymnopédie) sem nenhum evento de
"goToSleep" no meio, e foi liberado (`release WakeLock`) exatamente
quando a peça terminou.

**Achado à parte (não é bug, registro pra depois)**: o `file.name` que o
`file_selector`/SAF devolve pra esse arquivo aparece como
`Erik_Satie_-_Gymnopedie_No.1.bin` em vez de `.mxl` no aparelho testado —
a extensão certa não afeta o carregamento (o app não filtra por extensão
no Android, carrega o conteúdo real), só o texto mostrado. Não
investigado a fundo.
