# B04 — Músicas por biblioteca: modelo, chaves e migração

**Repo:** zywny · **Depende de:** B01, B03 · **Decisão necessária:** não

## Objetivo

O app carrega o catálogo do pacote em uso, e tudo o que é guardado por
música passa a ser por biblioteca + peça, com o progresso antigo dos hinos
migrado.

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md) "Chaves do que é guardado por
  música".
- `lib/library/hymn.dart`, `lib/library/hymn_progress.dart` (`_kKey`),
  `lib/settings/hymn_settings.dart` (`_key`), `lib/trail/trail_progress.dart`
  (`key`, `kMaxHymnNumber`, o laço de `1..600`), `lib/main.dart`
  (`MyApp.loadCatalog`).
- `graft callers Hymn --depth 2` antes de renomear.

## O que fazer

1. `Hymn` → `Piece` (e `HymnCatalog` → `PieceCatalog`, `OpenedHymn` →
   `OpenedPiece`), com `libraryId`, `id` e `number` opcional. Renomear em
   todo o código (os textos da tela ficam para o B07).
2. O catálogo vem de `LibraryStore` + `LibraryPackage` (o pacote em uso);
   `loadScore` do pacote. Sem biblioteca, o catálogo é vazio e o app sabe
   distinguir "vazio" de "erro" (o B05 desenha).
3. Chaves novas (`lib_progress_<lib>`, `piece_settings_<lib>_<id>`,
   `trail_<lib>_<id>`). O carregamento da trilha percorre as peças do
   catálogo, não `1..kMaxHymnNumber`.
4. Ver o que hoje depende do número do hino (ex.: "Trilha indisponível sem
   número de hino") e passar a depender do `id`.
5. Migração única (marca `library_migrated_v1`) quando a biblioteca `hinos`
   é instalada; testes com preferências falsas: as três chaves antigas
   viram as novas, as antigas somem, rodar de novo não faz nada.

## Fora de escopo

Telas de instalar/trocar (B05/B06), vocabulário (B07), tirar os assets
(B08) — até lá, se nada estiver instalado, a versão de depuração pode cair
nos `assets/hinos/` antigos para não travar o trabalho de quem roda o app.

## Critérios de aceite

1. Testes de migração e das chaves novas; os testes antigos da biblioteca,
   trilha e ajustes passam com o catálogo injetado.
2. **(manual, Linux)** com progresso antigo gravado, instalar
   `hinos.zywny`: a trilha, a melhor nota e o layout de um hino aparecem
   como antes.
3. `just analyze`, `just test` limpos.

## Notas de execução

**Concluído (2026-10-04).** `just analyze`, `just test` (366 testes) e
`flutter build web --release` limpos.

- **Renomeado em todo o código** (lib, test): `Hymn`→`Piece`,
  `HymnCatalog`→`PieceCatalog`, `OpenedHymn`→`OpenedPiece`,
  `HymnProgress(Store)`→`PieceProgress(Store)`,
  `HymnSettings(Store)`→`PieceSettings(Store)`, `HymnMatch`→`PieceMatch`;
  arquivos `hymn.dart`→`piece.dart`, `hymn_progress.dart`→`piece_progress.dart`,
  `hymn_settings.dart`→`piece_settings.dart`. Os **textos da tela** ("Hino
  N", "hinos") ficam como estavam — são do B07.
- `Piece`: `libraryId`, `id` (String), `number` opcional. Sem `libraryId`/`id`
  (índice embutido de antes, testes) valem `hinos` e o número com três
  dígitos. `PieceCatalog` guarda biblioteca, nome, `term`, `numbered` (para o
  B07) e o leitor de partituras; `PieceCatalog.fromPackage`,
  `PieceCatalog.none()` ("vazio", `hasLibrary == false`) e
  `PieceCatalog.fromAssets()` (o antigo, só para o fallback abaixo). Erro ao
  abrir o pacote **não** vira vazio: sai como exceção e a tela mostra "Não
  consegui abrir a biblioteca".
- **Chaves** em `lib/library/library_keys.dart`. Os stores ficam ligados a
  **uma biblioteca por vez**: `PieceProgressStore.load([libraryId])`,
  `TrailProgressStore.load(ids, [libraryId])` (as músicas do catálogo — o
  laço `1..600` e `kMaxHymnNumber` morreram) e
  `PieceSettingsStore.load/save(libraryId, id)`. Tudo por `id`: `TrailController`
  ganhou `pieceId` (era `pieceNumber`). "Trilha indisponível sem número de
  hino" virou "…sem uma música aberta" (só a partitura avulsa de teste).
  Ordenação sem número: o `id` em ordem natural ("2" antes de "10"); busca só
  por dígitos não acha música sem número.
- **Migração** em `lib/library/legacy_migration.dart`
  (`migrateLegacyHymnKeys`, marca `library_migrated_v1`): chamada por
  `LibraryStore.install` quando entra a biblioteca `hinos` e pelo fallback.
  Valor que já existe na chave nova vence o antigo; JSON antigo ilegível fica
  onde está. Procura as chaves antigas por padrão (`getKeys`), sem limite de
  número. 6 testes em `test/legacy_migration_test.dart`.
- **Tela:** `LibraryScreen` ganhou `libraryStore` e `legacyHymnAssets`
  (padrão `kDebugMode`: sem biblioteca instalada, o app em depuração cai nos
  `assets/hinos/` e roda a migração; **release e Web não caem** — sem
  biblioteca o catálogo é vazio e o cartão "instale uma" é do B05). `loadCatalog`
  /`loadScore` seguem injetáveis. O `integration_test/telas_celular_test.dart`
  continua semeando as chaves **antigas**: o fallback as migra (exercita a
  migração de ponta a ponta). `tool/web_smoke` clica no hino 1 sem biblioteca
  instalada — vai falhar até o B05/B08 darem um jeito de instalar na Web
  (ajustar lá).
- **Aceite 2 (manual, Linux):** feito pelos testes automatizados, não pela
  GUI, porque a tela de instalar é do B05: `library_active_test.dart` instala
  um pacote assinado, abre a tela, abre uma música (partitura do pacote,
  progresso em `lib_progress_<lib>`) e confere a migração disparada pela
  instalação de `hinos`; `library_store_test.dart` instala o `hinos.zywny` real
  e o relê. Refazer na GUI com o B05.
- **Desempenho:** a cada abertura do app o pacote em uso é aberto de novo
  (assinatura + decifrar + parse = ~460 ms no Linux, ~35 ms só o parse; no
  celular mais). Não medi no aparelho. Se incomodar, guardar o zip já
  verificado em memória/disco (perde a cifra em repouso) ou usar o
  `cryptography_flutter` (AES nativo).
