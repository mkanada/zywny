# B08 — O app sem hinos embutidos

**Repo:** zywny · **Depende de:** B05, B06, B07 · **Decisão necessária:** não

## Objetivo

`assets/hinos/` sai do app; tudo funciona só com bibliotecas instaladas
(D-BIB-VAZIO).

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md).
- `pubspec.yaml` (seção `assets`), `justfile`, `tool/web_smoke/`, os testes
  que dependem de `assets/hinos/`.

## O que fazer

1. Tirar `assets/hinos/` do `pubspec.yaml`, o atalho de depuração do B04 e
   a opção `--assets` do `build_hymn_assets.py`.
2. `just web-smoke` e os testes de integração passam a instalar um pacote
   de teste antes (um `.zywny` pequeno com peças em domínio público,
   versionado em `test/fixtures/` — pode sair do B10).
3. Conferir o tamanho do app (Linux, APK, Web) antes/depois; registrar.

## Critérios de aceite

1. `just test`, `just analyze`, `just web-smoke` limpos sem `assets/hinos/`
   no disco.
2. **(manual)** instalação limpa no Linux, Android e Chrome: cartão do B05 →
   instalar hinos → treinar um hino → instalar clássicos → trocar.
3. README do plano: Mapa do código e Fatos atualizados.

## Notas de execução

**Concluído (2026-10-04); falta o aceite manual 2.** `just analyze`, `just
test` (400 testes) e `just web-smoke` limpos **com `assets/hinos/` fora do
repositório** (movido para o scratchpad; o `.gitignore` continua barrando a
pasta caso sobre cópia antiga).

- **Removido:** `assets/hinos/` do `pubspec.yaml`; `PieceCatalog.fromAssets`,
  `Piece.legacyAssetPath`, `LibraryScreen.legacyHymnAssets` (o atalho de
  depuração do B04); a opção `--assets` e o `write_assets` do
  `build_hymn_assets.py`; a receita `just hinos` (agora `just pacote-hinos`) e
  o `hinos` de `just setup` (o pacote é privado e precisa das chaves). Nova
  receita `just chaves`.
- **Tamanho do app (antes → depois, release):** APK arm64 74.238.467 →
  71.183.847 B (−3.054.620); bundle Linux 59.683.240 → 56.595.310 B
  (−3.087.930); Web (`build/web`) 72.319.773 → 69.174.996 B (−3.144.777).
  Os hinos embutidos pesavam 3.045.265 B.
- **`just web-smoke`** agora parte do app vazio: confere o cartão "Instale uma
  biblioteca", instala `dist/hinos.zywny` **pelo seletor de arquivos de
  verdade** (o diálogo é interceptado pelo CDP e o arquivo entregue com
  `DOM.setFileInputFiles`), vê os 600 hinos e **recarrega a página** para
  provar o IndexedDB; o resto do roteiro (MIDI, som, monitor) segue igual e
  passa. Isto cumpre também o aceite manual "Chrome" dos B03 e B05 (instalar do
  zero e persistir). Precisa de `dist/hinos.zywny` (`just pacote-hinos`) e de
  `keys/`.
- **Pacote de teste:** em vez de um `.zywny` versionado em `test/fixtures/`, os
  testes de widget montam pacotes em memória (`test/support/library_fixtures.dart`,
  com um par de chaves gerado na hora), e o smoke e os testes manuais usam o
  pacote local `dist/hinos.zywny` (`test/support/hymn_package.dart`). Motivo: um
  `.zywny` versionado teria de ser assinado com a chave privada de verdade, e
  os testes não devem depender dela nem versionar nada assinado por ela.
- **`integration_test/telas_celular_test.dart`** (`just telas`, aparelho) agora
  semeia o histórico nas chaves novas (`lib_progress_hinos`,
  `trail_hinos_005`…) e instala a biblioteca antes do roteiro: precisa de
  `dist/hinos.zywny` no aparelho (`adb push`, de preferência em
  `/sdcard/Android/data/com.example.zywny/files/`) e do caminho em
  `--dart-define=ZYWNY_TEST_LIBRARY=…`. **Não rodei** (nenhum aparelho
  visível): o fluxo de empurrar o arquivo e a permissão de leitura são
  suposições a conferir.
- Testes manuais que liam `assets/hinos/` (`layout_phone`, `hino559_espera`,
  `trail_stats`) leem `dist/hinos.zywny` pelo helper e se pulam sem ele/sem
  chaves.
- **Pendente (manual):** instalação limpa no **Linux e Android** (Chrome já
  coberto pelo smoke): cartão → instalar hinos → treinar → instalar clássicos
  (B10) → trocar. README do plano e README do repo atualizados.
