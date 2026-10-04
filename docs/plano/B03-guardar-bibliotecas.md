# B03 — Guardar bibliotecas (nativo e Web)

**Repo:** zywny · **Depende de:** B01 · **Decisão necessária:** não

## Objetivo

`LibraryStore`: instalar, listar, ler, remover pacotes e lembrar qual está
em uso — com a mesma interface no Linux/Android e na Web.

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md) "Onde o app guarda".
- `lib/audio/soundfont_store.dart` (precedente nativo: `path_provider`,
  falha silenciosa nos testes).
- Como a fase W separa nativo e Web: `lib/midi/web_midi_access*.dart`
  (import condicional `_stub`/`_web`).

## O que fazer

1. `lib/library/library_store.dart` (interface) com:
   `installed()`, `read(id) → Uint8List`, `install(bytes) → LibraryManifest`
   (valida pelo B01 **antes** de gravar), `remove(id)`, `active`/`setActive`.
   A lista e o `id` em uso ficam no `shared_preferences`
   (`library_installed`, `library_active`).
2. Nativo: um arquivo por pacote em
   `getApplicationSupportDirectory()/bibliotecas/<id>.zywny`, gravado num
   temporário e renomeado (não deixar pacote pela metade).
3. Web: IndexedDB pelo `package:web` + `js_interop` (sem pacote novo, a não
   ser que o IndexedDB à mão fique feio — então registre a escolha). Banco
   `zywny`, store `bibliotecas`, chave `id`, valor o `Uint8List`.
4. Uma implementação em memória para os testes.
5. `remove` apaga só o pacote e tira da lista; se era a em uso, a em uso
   vira a primeira restante (ou nenhuma). Progresso fica (D-BIB-REMOVER).

## Fora de escopo

Telas (B05/B06), migração de chaves (B04).

## Critérios de aceite

1. Testes da implementação em memória e da lógica de em uso/remover.
2. **(manual, Linux)** instalar `dist/hinos.zywny` por um teste de
   integração ou botão de depuração, reiniciar o app, continua lá.
3. **(manual, Chrome)** idem na Web; recarregar a página mantém o pacote.
   Registrar o limite de cota do navegador se aparecer.
4. `flutter build web --release` e `just analyze` limpos.

## Notas de execução

**Concluído (2026-10-04).** Arquivos: `lib/library/library_store.dart`
(`LibraryStore`, `InstalledLibrary`), `library_blob_store.dart` (interface
`LibraryBlobStore` + `MemoryLibraryBlobStore`), `library_blob_store_native.dart`
(`FileLibraryBlobStore`, temporário + rename), `library_blob_store_web.dart`
(`IndexedDbLibraryBlobStore`, `package:web` sem pacote novo — ficou
legível). Import condicional `createLibraryBlobStore()` como a fase W faz.

- **Desvios do passo:** (1) `install` devolve `InstalledLibrary` (manifesto +
  nº de peças, que o aviso "instalada (48 peças)" do B05 precisa), não só o
  `LibraryManifest`; (2) `install(bytes, {activate = true})` já aplica
  D-BIB-NOVA; (3) o store ganhou `open(id)` (devolve o `LibraryPackage`
  aberto) e `read(id)` (bytes do envelope); (4) por D-BIB-CIFRA o store
  valida **assinatura + cifra + conteúdo** com a chave pública (injetável;
  padrão: `--dart-define=ZYWNY_LIBRARY_KEY`) antes de gravar, e grava o
  **envelope como veio** — cifrado também em disco/IndexedDB. App sem chave:
  recusa instalar com mensagem.
- `load()` tira da lista o que não tem pacote (arquivo sumido, dados do site
  limpos) e, se a em uso sumiu, usa a primeira restante.
- **Testes:** `test/library_store_test.dart` (memória, arquivo, pacote real
  instalado e relido por um store novo — o **aceite 2** automatizado, sem
  botão de depuração); `test/library_blob_store_web_test.dart` roda em
  Chromium: `CHROME_EXECUTABLE=/usr/bin/chromium-browser flutter test
  --platform chrome test/library_blob_store_web_test.dart` (IndexedDB: gravar,
  ler, apagar, 4 MB relidos por outra conexão = o "recarregar a página"; e o
  envelope no navegador).
- **Aceite 3 (Chrome):** feito pelo teste acima, não pela página (a tela de
  instalar é do B05) — refazer na página quando o B05 existir. Nenhum erro de
  cota com 4 MB; o limite do navegador não apareceu.
- **Desempenho do envelope na Web:** seal+open de 3 MB levou ~1,8 s no
  Chromium em `flutter test` (modo debug); abrir sozinho deve ser menos da
  metade. Se a abertura a cada visita pesar, medir no build release e
  considerar guardar o zip já verificado (perdendo a cifra em repouso).
- `flutter build web --release`, `just analyze` e `just test` limpos.
