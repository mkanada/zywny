# B07 — Vocabulário e ordenação vindos do manifesto

**Repo:** zywny · **Depende de:** B04 · **Decisão necessária:** não

## Objetivo

Os textos dizem "hino" nos hinos e "peça" nos clássicos, com a concordância
certa; o que só faz sentido com numeração some quando o pacote não é
numerado.

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md) (`termo`, `numerada`).
- `lib/library/library_sort.dart` (`SortKey.number`), U17.
- `graft grep "hino"` — a lista exaustiva dos textos (hoje: "Hino 12",
  "ESTE HINO", "Nenhum hino encontrado", "600 hinos", "valem para todos os
  hinos", "Isto reinicia a trilha deste hino"…).

## O que fazer

1. Um `LibraryTerms` (singular, plural, gênero) com helpers: `este`
   (este/esta), `nenhum` (nenhum/nenhuma), `count(n)` ("1 hino", "48
   peças"), maiúsculas.
2. Trocar todos os textos fixos com "hino" pelos helpers.
3. `numerada == false`: sem `SortKey.number` (ordem padrão passa a título),
   linha da lista sem o número; o subtítulo mostra compositor e `o` (o
   número de catálogo).
4. Ordem salva que não existe mais na biblioteca nova cai na padrão.

## Critérios de aceite

1. Testes dos helpers e de que nenhum texto da UI tem "hino" fixo (um
   teste que roda as telas com termo "peça"/f e procura "hino").
2. **(manual)** As telas da biblioteca, da partitura e da trilha com os
   clássicos.

## Notas de execução

**Concluído em código (2026-10-04); falta o aceite manual 2.** `just analyze`
e `just test` limpos (11 testes novos em `test/library_vocabulary_test.dart`).

- **Helpers:** em vez de uma classe nova `LibraryTerms`, o `LibraryTerm` do
  B01 ganhou a concordância: `este/neste/deste/nenhum/nenhumCapitalized/um/o/
  os/todos/encontrado`, `singularCapitalized` e `count(n)` ("1 hino", "48
  peças", "0 peças"). `LibraryTermScope` (InheritedWidget, em
  `library_term_scope.dart`) leva o termo até quem não recebe o catálogo;
  sem escopo vale o hinário. `OpenedPiece` carrega `term` e `numbered`; o
  `MyApp` embrulha a partitura no escopo, e as configurações abertas pela
  biblioteca também.
- **Textos trocados** (levantamento por `grep` em `lib/`): cabeçalho da
  biblioteca (nome da biblioteca + `count`), "Hino N" do cartão Continuar e do
  título da partitura, "Escolha um/uma … fácil", "Nenhum/Nenhuma … encontrado/
  encontrada" e "… com “x”.", "Não deu para abrir o/a …", "ESTE/ESTA …"
  (gaveta), "Isto reinicia a trilha deste/desta …", "Trilha indisponível
  neste/nesta … — treino livre", "Reiniciar trilha" (deste/este),
  "Restaurar o layout padrão neste/nesta …", "valem para todos os hinos/todas
  as peças" e "Os/As … que usam o padrão recomeçam a trilha". O teste roda a
  biblioteca e as configurações com termo "peça"/feminino e procura "hino" em
  `Text`, dicas e `hint`s: não há.
- **Não numerada:** sem a pastilha "Número" (a ordem padrão cai em "Nome" ao
  carregar; vale também ao trocar de biblioteca), sem a coluna do número,
  hint de busca sem "número", segunda linha = compositor · `o` (catálogo) e a
  armadura passa para o resto da linha. Como antes (B04), o `id` em ordem
  natural desempata.
- "Ordem salva": a ordem não é persistida entre aberturas do app, só vive
  na tela; o caso real é a troca de biblioteca, coberto acima.
- **Não coberto por teste automatizado:** a tela de partitura (precisa do
  Verovio nativo): título, gaveta "ESTA PEÇA", dica do layout e diálogos da
  trilha foram trocados e conferidos só por análise. **Pendente (manual,
  aceite 2):** abrir os clássicos (B10) e olhar a biblioteca, a partitura e a
  trilha.
- **Achado pelo teste de 360 dp (B06):** com o nome da biblioteca no lugar do
  "Hinário" fixo, o cabeçalho ("Clássicos" + "48 peças" + engrenagem + selo
  MIDI) estourava 46 px. Nome e contagem viraram **um `Text.rich` de uma
  linha** (a contagem cede primeiro, depois o nome, com reticências). Efeito
  em testes: quem procurava `find.text('Hinário')`/`'4 hinos'` na biblioteca
  usa `find.textContaining(…, findRichText: true)`.
