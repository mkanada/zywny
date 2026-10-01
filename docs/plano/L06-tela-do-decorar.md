# L06 — Tela: entrar na trilha do decorar e executar etapas

**Repo:** zywny · **Depende de:** J05, J06, L04, L05 · **Decisão
necessária:** nenhuma

## Objetivo

O aluno abre um hino, escolhe "Trilha do decorar" e joga as etapas dos
trechos e da música inteira: a partitura aparece com as pausas coloridas,
a passagem termina sozinha, vem o resumo, ele segue. É o primeiro passo em
que o decorar é utilizável (sem a prova às cegas — L07).

## Ler antes (só isto)

- [L00](L00-trilha-do-decorar.md): "Onde ela mora", "Etapas",
  "Interface".
- [J05](J05-tela-da-etapa.md) e [J06](J06-gaveta-e-configuracao.md), com
  as notas de execução dos dois.
- `lib/trail/trail_controller.dart`, `lib/trail/trail_widgets.dart`.
- `lib/memo/` (L01, L04) e os parâmetros novos do `PracticeController`
  (L05).
- `lib/main.dart`: a cola da trilha feita no J05 e `_buildScoreArea`.

## Contexto que você precisa

- **Três estados da tela da música**, um de cada vez: trilha de estudo
  (padrão), trilha do decorar, treino livre. A gaveta de opções ganha
  "Trilha do decorar"; dentro dela, "Voltar à trilha de estudo". A escolha
  **não** é guardada: o hino sempre abre na trilha de estudo.
- Não escreva uma segunda faixa, um segundo resumo nem uma segunda gaveta:
  os widgets do J05/J06 recebem um plano e um progresso. Se eles estiverem
  presos a `TrailStage`, a generalização do L04 é o lugar de soltar —
  ajuste lá, não duplique aqui.
- **Não engorde `lib/main.dart`** (regra do J05): o estado do decorar vai
  em `lib/memo/memo_controller.dart`; em `main.dart` fica a cola.
- A etapa manda nos controles: tempo real, as duas mãos, andamento do
  degrau, contagem e metrônomo ligados, intervalo do trecho. Nada disso é
  gravado nas configurações do aluno.
- Rótulo da faixa: "Decorar · Trecho 2/5 · 50% escondido · 75%". Na música
  inteira: "Decorar · Música inteira · 100% escondido · 100%".
- **A partitura mostra o sumiço antes de começar**: ao selecionar a etapa
  (parada), as colunas já estão escondidas e as pausas no lugar, para o
  aluno ver o que o espera. Trocar de etapa ou sair do decorar devolve a
  partitura inteira.
- O `ScoreView` precisa receber o `StandInController` (parâmetro do L03).
  Com ele `null` fora do decorar, o custo é zero.
- Resumo: o do J05, com uma linha a mais — "colunas reveladas: 3".
- Mudança de N (J06): a confirmação passa a dizer que zera **as duas**
  trilhas e chama o `reset` do decorar também.
- Etapas de `cega.*`: aparecem na lista, com "em breve" (L07).

## O que fazer

1. `MemoController` (`ChangeNotifier`): plano + progresso + etapa
   selecionada; `startSelected()`, `onStageDone(StageResult)`, `next()`,
   `skipSelected()`.
2. Cola em `lib/main.dart`: montar `MemoHiding`/`MemoPlan` depois do
   render, carregar o progresso, trocar entre as três telas, criar o
   `PracticeController` com as colunas escondidas da etapa.
3. Pré-visualização do sumiço na etapa parada e limpeza ao sair.
4. Entrada na gaveta (celular) e no layout largo; lista de etapas do J06
   com o plano do decorar.
5. Texto da confirmação de N e `reset` das duas trilhas.
6. Testes de widget com motor e MIDI falsos.

## Fora de escopo

- Prova às cegas (L07), biblioteca (L08).
- Lembrar qual trilha estava aberta.

## Critérios de aceite

1. Teste de widget: "Trilha do decorar" → faixa em `t0.s25.50`, partitura
   com colunas escondidas; "Voltar à trilha de estudo" → nenhuma coluna
   escondida, faixa da trilha de estudo.
2. Teste de widget: passagem aprovada → resumo → "próxima etapa" → faixa
   em `t0.s25.75`; o progresso `memo_<n>` foi gravado e o da trilha de
   estudo não mudou.
3. Teste de widget: reprovar → "tentar de novo" e "pular"; pular marca
   `pulada`.
4. Teste de widget: trocar de `t0.s25.*` para `t0.s50.*` na lista → o
   conjunto escondido na tela é o do sumiço 50, e contém o do 25.
5. Teste: mudar N com progresso nas duas trilhas → uma confirmação, as
   duas zeradas.
6. Teste: hino sem trilha disponível (caminho com salto, até o J08) → sem
   a entrada "Trilha do decorar".
7. **(manual, celular em paisagem)** Hino 1, trecho 1, as 12 etapas com
   teclado MIDI: as pausas aparecem na cor certa, piscam, a coluna errada
   é revelada, e ao sair nada fica escondido. Anote quanto tempo levou o
   trecho (dado para o alerta de "75 etapas" do L00).
8. **(manual)** Virar a página no meio de uma etapa não deixa pausa nem
   nota escondida na página errada.
9. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
