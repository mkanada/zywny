# B02 — Gerador de pacotes e o `hinos.zywny`

**Repo:** zywny · **Depende de:** B01 (o formato) · **Decisão necessária:** não

## Objetivo

Uma ferramenta que monta um `.zywny` a partir de uma pasta de MusicXML e de
um manifesto, e o pacote de hinos gerado por ela.

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md) "O formato `.zywny`".
- `tool/build_hymn_assets.py` (título, autores, `fold`, dificuldade do
  `_dificuldade.csv`, armadura).

## O que fazer

1. `tool/build_library.py`: a parte genérica — recebe o manifesto e uma
   lista de peças (`id`, caminho do MusicXML, campos do índice) e grava o
   zip (`manifest.json`, `indice.json`, `partituras/<id>.musicxml.gz`).
   Calcula `k`/`ck`/`q` com o mesmo `fold` de hoje (tem que bater com
   `foldForSearch` em `lib/library/hymn.dart`).
2. `tool/build_hymn_assets.py` passa a usar o genérico e grava
   `dist/hinos.zywny` (`id: "hinos"`, `numerada: true`, termo "hino"/m,
   `versao` = data). Continua lendo o Hymn_Grabber como hoje. **Não**
   grava mais `assets/hinos/` (quem tira do app é o B08; até lá, uma opção
   `--assets` mantém o comportamento antigo).
3. `dist/` no `.gitignore` (D-BIB-DIST).
4. Uma receita `just pacote-hinos`.

## Fora de escopo

Clássicos (B09/B10). Mudanças no app.

## Critérios de aceite

1. `dist/hinos.zywny` com 600 peças, lido pelo `LibraryPackage` do B01 sem
   erro (um teste/script que leia o arquivo se ele existir).
2. Os `indice.json` antigo e novo têm os mesmos títulos, autores, níveis e
   armaduras (comparar e registrar).
3. Tamanho do pacote registrado.

## Notas de execução

**Concluído (2026-10-04).** `tool/build_library.py` (genérico: módulo
`build_package`/`fold` e CLI `especificacao.json saida.zywny`),
`tool/build_hymn_assets.py` refeito em cima dele, `just pacote-hinos`
(só o pacote) e `just hinos` (continua gerando `assets/hinos/`, agora via
`--assets`, e também o pacote). `/dist/` no `.gitignore`.

- **Tamanho:** `dist/hinos.zywny` = **3,1 MB** (600 hinos), não os ~4,3 MB
  estimados no B00 — corrigido lá. O zip guarda sem comprimir (store) porque
  as partituras já vão em gzip. Os `assets/hinos/` antigos somam 2,9 MB.
- **Índice:** `assets/hinos/indice.json` regenerado é **byte a byte idêntico**
  ao de antes (`cmp`); o do pacote tem os mesmos títulos, autores, níveis,
  notas, armaduras e chaves (teste em `test/library_package_test.dart`,
  que lê `dist/hinos.zywny` se existir e compara campo a campo com o índice
  embutido).
- **Aceite 2 do B01 (velocidade):** `LibraryPackage.parse` de 600 peças /
  3,1 MB = **36 ms** no Linux (limite 300 ms).
- Pacote determinístico: `mtime`/data fixos, então só muda se o conteúdo
  mudar (menos o `versao`, que é a data do dia).
- `q` (busca) do pacote de hinos é calculado pelo script dos hinos, como
  sempre foi (inclui a letra mesmo quando igual ao compositor); o genérico
  calcula o seu padrão (número, título, original, compositor, letra) para os
  clássicos.

**Reaberto (2026-10-04) — D-BIB-CIFRA.** `tool/library_crypto.py` (`gen`,
`seal`, `open_sealed`) e `build_package` agora sempre sela o zip com a
chave privada de `keys/` (`library_crypto.KEYS`); sem ela, o gerador para com
a instrução de gerar o par. O `dist/hinos.zywny` regenerado tem 3,1 MB
(+129 bytes de envelope) e abre no Dart com a chave pública (teste
`library_envelope_test.dart`). O arquivo muda a cada geração (sal/nonce
aleatórios), embora o zip de dentro seja determinístico. `assets/hinos/`
(`--assets`) segue sem cifra: é o embutido que o B08 remove.
