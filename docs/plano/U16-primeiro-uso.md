# U16 — Primeiro uso: cartão de começo

**Repo:** zywny · **Depende de:** U13, U15 · **Decisão necessária:** nenhuma

## Objetivo

Na primeira abertura, a biblioteca diz por onde começar: um hino fácil e o
teclado ligado. Achado C6; sugestão C6.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **C6**.
- Telas `01` (abertura) e `02` (biblioteca sem histórico: uma lista de 600
  hinos e nada mais).
- `lib/library/library_screen.dart`: `_content` L230-L262, `_continuing`
  L264-L271, `_continueCard` L340-L412, `_sortChips` L414-L446, o subtítulo
  do `_HymnRow` (L503-L510, "nível N").
- `lib/library/hymn_progress.dart`: `lastOpenedNumber`.
- `lib/library/library_sort.dart`: `SortKey.difficulty`, `SortState`.
- `lib/midi/midi_device_picker.dart`: `showMidiDevicePicker`.
- `test/library_test.dart`: grupo `tela` L224-L317.

## Contexto que você precisa

- O cartão "Continuar" só existe quando algum hino já foi aberto
  (`_continuing` devolve `null` no primeiro uso). O cartão de começo ocupa
  o **mesmo lugar**, com o mesmo molde visual — não é um diálogo, não é um
  tutorial, não bloqueia nada.
- Some sozinho no primeiro hino aberto (`lastOpenedNumber != null`). Não
  precisa de preferência nova nem de botão "não mostrar de novo".
- O nível de dificuldade vai de 1 a 5 (`Hymn.level`); a linha diz só
  "nível 1". Hino sem nível não mostra nada.
- "Ver os mais fáceis" = `setState(() => _sort = const
  SortState(key: SortKey.difficulty))` (crescente é o padrão da chave) e
  rolar a lista para o topo.
- Com o teclado já conectado (ele conecta sozinho ao plugar), o segundo
  botão não faz sentido: mostre "Teclado conectado ✓" como texto.
- Em 360 dp de largura, dois botões lado a lado com esses rótulos não
  cabem: empilhe (`Wrap`).

## O que fazer

1. `_startCard()` em `library_screen.dart`, no molde de `_continueCard`:
   - rótulo "COMECE POR AQUI";
   - "Escolha um hino fácil e ligue o teclado ao celular.";
   - botões "Ver os mais fáceis" e "Conectar teclado" (ou o texto de
     teclado conectado).
2. `_content`: sem `_continuing`, mostra o `_startCard`.
3. `_HymnRow`: "nível 1 de 5".
4. A lista precisa de um `ScrollController` para voltar ao topo ao trocar a
   ordenação pelo cartão.
5. Testes de widget: primeiro uso mostra o cartão; "Ver os mais fáceis"
   ordena por dificuldade (o primeiro hino da lista de teste muda); depois
   de abrir um hino e voltar, o cartão de começo deu lugar ao "Continuar".

## Fora de escopo

- Tutorial passo a passo, dicas sobre a tela da partitura.
- Recomendar hinos pelo histórico.
- Texto de boas-vindas na tela de abertura.

## Critérios de aceite

1. Teste de widget: sem progresso gravado, a biblioteca mostra "COMECE POR
   AQUI" e não mostra "CONTINUAR".
2. Teste de widget: "Ver os mais fáceis" deixa a pastilha "Dificuldade"
   selecionada e o hino mais fácil no topo.
3. Teste de widget: com um hino aberto no progresso, o cartão de começo não
   existe.
4. Teste de widget (360 dp): o cartão não estoura.
5. `just telas`: a tela 02 mostra o cartão; a 26 e a 27, o "Continuar". O
   roteiro abre o hino por `find.text('Jubilosos Te Adoramos')`, que com o
   cartão no topo continua visível sem rolar — confira.
6. `just analyze` e `just test` limpos.
