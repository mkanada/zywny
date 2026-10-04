# B01 — Formato `.zywny` e leitor (Dart puro)

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** não (todas no B00)

## Objetivo

Um leitor que recebe os bytes de um `.zywny`, valida tudo e devolve o
manifesto, o índice e um jeito de descompactar uma partitura — sem tocar em
disco, preferências ou widgets.

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md) seção "O formato `.zywny`".
- `lib/library/hymn.dart` (`Hymn.fromJson`, `HymnCatalog.loadScore`: o
  gzip é o do `archive`, porque o de `dart:io` não existe na Web).

## O que fazer

1. `lib/library/library_package.dart`:
   - `LibraryManifest` (campos do B00, `fromJson` com validação).
   - `LibraryPackage.parse(Uint8List bytes)` → manifesto + `List<Hymn>`
     (o `Hymn` ganha `id` agora; a troca de nome para `Piece` é do B04) +
     `Future<Uint8List> loadScore(String id)`.
   - `LibraryFormatException` com mensagem em português pronta para mostrar.
2. Validações: é zip; tem `manifest.json` e `indice.json`; `formato` ≤ 1;
   `id` no padrão; `numerada` ⇒ todo item tem `n`, sem `n` repetido; `id`
   de peça único e com arquivo em `partituras/`; o JSON tem os campos
   obrigatórios.
3. Testes em `test/library_package_test.dart` montando zips em memória
   (sem partituras reais — `assets/hinos/` não é versionado). Uma
   partitura mínima de fixture serve.

## Fora de escopo

Gravar, listar, preferências (B03); trocar o catálogo do app (B04).

## Critérios de aceite

1. Pacote válido lido; um teste para cada erro da lista do passo 2, cada um
   com a mensagem esperada.
2. Um pacote de 600 peças / 4 MB lê em < 300 ms no Linux (medir com o
   pacote do B02 se já existir; registrar).
3. `just analyze` e `just test` limpos.

## Notas de execução

**Concluído (2026-10-04).** `lib/library/library_package.dart`
(`LibraryManifest`, `LibraryTerm`, `LibraryPackage.parse`, `loadScore`,
`LibraryFormatException`) e `test/library_package_test.dart` (23 testes: o
pacote válido, zip em `store`, biblioteca não numerada, campos opcionais e
um teste por erro). `just analyze` e a suíte inteira limpos.

- **Aceite 2 (600 peças < 300 ms):** 36 ms com o pacote real do B02 (3,1 MB).
- `Hymn` ganhou `id`. Sem o campo (índice embutido de hoje) vale o número
  com três dígitos; `Hymn.fromJson` aceita os dois índices.
- `Hymn.number` ainda é `int` obrigatório (a troca por `Piece` com número
  opcional é do B04). Enquanto isso, uma biblioteca **não numerada** devolve
  a posição no índice (1, 2, …) em `number` — provisório, o B04 remove.
- O `ZipDecoder` do `archive` aceita lixo e devolve um zip vazio, então o
  leitor confere a assinatura `PK` antes; sem isso "não é zip" virava
  "falta manifest.json".
- Além do B00, o leitor exige `nome` e `versao` não vazios no manifesto e
  `termo` completo; `creditos` e `idioma` são opcionais.

**Reaberto (2026-10-04) — D-BIB-CIFRA.** O `.zywny` passou a ser um envelope
cifrado e assinado (ver B00). `LibraryPackage.parse` continua lendo o **zip de
dentro**; `lib/library/library_envelope.dart` abre o envelope
(`LibraryEnvelope.open`, `openLibraryPackage(bytes, chavePublica)`) e
`test/library_envelope_test.dart` cobre: ida e volta, conteúdo não aparece
no envelope, sal/nonce aleatórios, chave errada, forjado com outra privada,
byte alterado (cifra e cabeçalho), truncado, zip sem cifra, versão nova e o
pacote real do gerador Python. Dependência nova: `cryptography` (Dart puro).
**Medido:** abrir o pacote real (assinatura + decifrar + parse, 3,1 MB)
leva **~460 ms** no Linux em Dart puro — o AES-GCM é o grosso. O parse sozinho
continua em ~35 ms. Fica para o B03/B04 decidir se isso a cada abertura do app
incomoda (no celular será mais lento; `cryptography_flutter` usaria o nativo).
