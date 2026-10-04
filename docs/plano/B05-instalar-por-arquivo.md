# B05 — Tela sem biblioteca e instalar por arquivo

**Repo:** zywny · **Depende de:** B04 · **Decisão necessária:** não

## Objetivo

Sem biblioteca, o app mostra como instalar uma; o seletor de arquivo
instala, pergunta antes de substituir e passa a nova para "em uso".

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md) "Telas".
- `lib/library/library_screen.dart` (estado vazio/erro de hoje: "Os hinos
  não vieram com esta compilação"), o cartão de primeiro uso do U16.
- `lib/settings/general_settings_panel.dart` (o `openFile` do soundfont).

## Contexto que você precisa

- `file_selector` 1.0.3 já é dependência. **No Android**, filtro por
  extensão vira filtro por MIME, e `.zywny` não tem MIME conhecido — o
  arquivo pode simplesmente não aparecer. Verifique; se for o caso, no
  Android abra sem filtro e confie na validação do B01. Na Web o seletor
  aceita `accept=".zywny"`.
- Pacote de ~4 MB: mostrar um indicador enquanto lê e valida.

## O que fazer

1. Estado "sem biblioteca" na tela da biblioteca (cartão, botão **Abrir
   arquivo…**). O cartão do U16 só aparece depois de haver biblioteca.
2. Fluxo `installFromFile()` reaproveitável pelo B06: escolher → validar →
   se `id` existe, diálogo com as duas versões (D-BIB-ATUALIZAR) → gravar
   → em uso (D-BIB-NOVA) → aviso com nome e quantidade, no termo do
   pacote → recarregar o catálogo.
3. Erro: diálogo com a mensagem do `LibraryFormatException`; nada gravado.

## Critérios de aceite

1. Teste de widget: sem biblioteca mostra o cartão; instalar (store em
   memória, seletor falso) troca para a lista; substituição pergunta e
   "Cancelar" não muda nada.
2. **(manual)** Linux, Android (aparelho, ver memória "Instalar no celular
   pelo Wi-Fi") e Chrome: instalar `hinos.zywny` a partir do zero.
3. **(manual)** Abrir um `.zip` qualquer: mensagem clara.
4. Atualizar as fotos das telas (`just telas`) do estado vazio.

## Notas de execução

**Concluído em código (2026-10-04); falta o aceite manual 2–4.** `just
analyze` e `just test` limpos (12 testes novos em
`test/library_install_test.dart`).

- `lib/library/library_installer.dart`: `pickLibraryBytes()` (no Android sem
  filtro por extensão — o MIME de `.zywny` não existe; lá a validação
  recusa o que não serve) e `installLibraryFromFile(context, store, {pick})`,
  o fluxo reaproveitável pelo B06: escolher → "Lendo a biblioteca…" →
  validar (assinatura, cifra e conteúdo, sem gravar) → se o `id` existe,
  diálogo "Substituir *Hinário*?" com as duas versões e quantidades, também
  quando a nova é mais antiga, e "Seu progresso e seus ajustes ficam" →
  "Instalando…" → vira a em uso → SnackBar "*Nome* instalada (N hinos)" no
  singular/plural do termo do pacote. Erro: diálogo "Não deu para instalar"
  com a mensagem; nada é gravado. `LibraryStore` ganhou `inspect(bytes)` e
  `install(..., inspected:)` para não abrir o pacote duas vezes.
- `LibraryScreen`: sem biblioteca, cartão "Instale uma biblioteca de músicas"
  com **Abrir arquivo…** e a explicação do `.zywny`; sem busca, ordenação nem
  cartão do U16 (que só aparece depois de haver biblioteca) e sem nenhuma
  menção a onde baixar (D-BIB-DIST; o teste confere "http" e "baixar").
  Título do cabeçalho vira "Músicas" no estado vazio (o "Hinário" fixo do resto
  da tela é do B07). Depois de instalar o catálogo e o progresso são relidos.
  O seletor é injetável (`pickLibraryFile`) — usado nos testes.
- **Pendente (manual, precisa de aparelho/janela):** (2) instalar
  `dist/hinos.zywny` do zero no Linux, no Android (nenhum aparelho visível pelo
  `adb` nesta sessão) e no Chrome; conferir também no Android se o arquivo
  `.zywny` aparece no seletor sem filtro; (3) abrir um `.zip` qualquer e ver a
  mensagem; (4) `just telas` para a foto do estado vazio. No Linux em
  depuração o app ainda cai nos `assets/hinos/` e **não mostra** o estado
  vazio: para vê-lo, apague `assets/hinos/` ou rode um build `--release`.
  Para rodar com a chave, use `just run` (as receitas leem `keys/`).
