# J05 — Tela: executar uma etapa (faixa, resumo, avançar)

**Repo:** zywny · **Depende de:** J03, J04 · **Decisão necessária:** nenhuma

## Objetivo

O aluno abre um hino e **joga a trilha**: a tela mostra a etapa atual, um
toque começa, a passagem termina sozinha, aparece o resumo e ele segue para
a próxima. É o primeiro passo em que a trilha é utilizável de ponta a
ponta (sem a lista completa de etapas — J06 — e sem a fase final — J07).

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Etapas de um trecho", "Interface".
- `lib/main.dart`: estado da tela L113-L300, `_togglePractice` L679-L728,
  `_endPractice` L732-L755, `_setLoop` L896, `_setSpeed` L806,
  `_buildPhoneBody` L1450, `_buildOptionsDrawer` L1503-L1617,
  `_buildScoreArea` L1619.
- `lib/ui/phone_chrome.dart` (`PhoneRail`, `PhoneStatusPill`,
  `PhoneCountersPill`, `PhoneOptionsDrawer`).
- `lib/practice/practice_tools.dart` L256-L343 (`showPracticeSummary`).
- `lib/trail/` (J01–J03) e o intervalo de passagem única do J04.

## Contexto que você precisa

- **Alvo: celular em paisagem** (a partitura ocupa quase tudo; a
  biblioteca é que fica em retrato). A faixa da trilha tem de ser fina e
  não pode encolher a área da partitura a ponto de disparar re-render
  (ver o comentário sobre `_onBoxSize` em `build`, `lib/main.dart` ~L1870).
  Largura ≥ `kPhoneLayoutMaxWidth` usa o layout largo: a mesma faixa vale
  lá.
- `lib/main.dart` tem 2092 linhas. **Não** engorde `_ScoreHomePageState`:
  o estado da trilha vai num controlador próprio
  (`lib/trail/trail_controller.dart`, `ChangeNotifier`) que recebe o plano,
  o progresso e callbacks para "iniciar etapa"/"parar"; os widgets novos
  vão em `lib/trail/trail_widgets.dart`. Em `main.dart` fica só a cola.
- A etapa **manda** nos controles enquanto roda: modo, mão, andamento,
  intervalo, contagem inicial e metrônomo (ligados nas etapas com tempo).
  Nada disso é gravado em `HymnSettings`/`AppSettings` — ao sair da trilha
  ou entrar no modo livre, valem de novo os valores do aluno.
- O treino exige o motor de som (`_ensureEngine`) e um teclado MIDI. Sem
  teclado conectado, a faixa avisa em vez de começar.
- **Trilha indisponível**: caminho com saltos (até o J08) ou partitura sem
  número de hino → sem faixa, a tela abre direto no modo livre de hoje,
  com uma linha explicando.
- **Modo livre**: a trilha é o padrão; uma entrada "Treino livre" na gaveta
  de opções troca para os controles de hoje (e "Voltar à trilha" desfaz).
  No modo livre nada toca no progresso da trilha; o
  `widget.opened?.onPracticeScore` de hoje continua valendo só lá.
- **Resumo da etapa** (folha/diálogo novo, não o `showPracticeSummary`):
  porcentagem grande, "aprovado"/"faltou X%", compassos com erro (números
  de compasso lógico), e os botões do J00. "Pular" pede uma confirmação
  curta. Parar a etapa no meio não registra nada e não abre resumo.
- A partitura deve mostrar o trecho: ao armar a etapa, vá para o início do
  intervalo (`player.seek`), como `_setLoop` faz.

## O que fazer

1. `TrailController`: plano + progresso + etapa selecionada (a atual por
   padrão); `startSelected()`, `onStageDone(StageResult)` → grava via
   `TrailProgressStore`, expõe o resultado para o resumo; `next()`,
   `skipSelected()`.
2. Cola em `lib/main.dart`: montar caminho/plano depois do render
   (`_renderAndShow`), carregar o progresso do hino, iniciar etapa (criar
   o `PracticeController` com modo/mão/andamento/intervalo da etapa, forçar
   contagem e metrônomo), e encaminhar `onRangeDone`.
3. Faixa da trilha: "Trecho 2/6 · Notas juntas" (+ "75%" nos degraus),
   botão começar/parar, estado da etapa (pendente, aprovada com a melhor
   %, pulada).
4. Resumo da etapa com os botões.
5. Entrada "Treino livre" / "Voltar à trilha" na gaveta e no layout largo.
6. Testes de widget com motor e MIDI falsos (os de
   `test/widget_test.dart`/`test/practice_controller_test.dart` servem de
   base): fluxo aprovar → próxima; reprovar → tentar de novo; pular.

## Fora de escopo

- Lista completa de etapas, escolher uma etapa antiga, configurar N (J06).
- Fase final e reforço (J07): neste passo, ao acabar o último trecho a
  faixa mostra "fase final em breve" e nada mais.
- Progresso na biblioteca (J09).

## Critérios de aceite

1. Teste de widget: hino com caminho contíguo abre com a faixa na etapa
   `t0.notasD`; passagem aprovada → resumo com "próxima etapa" → faixa em
   `t0.notasE`; o progresso foi gravado.
2. Teste de widget: passagem reprovada → resumo com "tentar de novo" e
   "pular"; "pular" → etapa `pulada`, próxima aberta.
3. Teste de widget: "Treino livre" mostra os controles de hoje e um treino
   ali não altera a trilha; andamento e mão do modo livre voltam como
   estavam.
4. Teste: partitura com salto no caminho → sem faixa, mensagem, modo livre.
5. **(manual, celular em paisagem)** Hino 1, trecho 1: as 12 etapas em
   sequência com teclado MIDI — a outra mão soa nas etapas de uma mão, a
   contagem e o metrônomo entram sozinhos nas etapas com tempo, e o
   andamento muda a cada degrau. Anote quanto tempo levou um trecho
   inteiro (dado para o alerta de "48 etapas" do J00).
6. **(manual)** A faixa não provoca re-render da partitura nem corta a
   pauta em 360×780 dp em paisagem.
7. `just analyze` e `just test` limpos.

## Notas de execução (J05, 2026-10-01)

Implementado: `lib/trail/trail_controller.dart` (`TrailController`: plano,
progresso, selecionada/atual, `recordDone`/`skipSelected`/`next`,
`freeMode`, `running`, `lastResult/lastStage`), `lib/trail/trail_widgets.dart`
(`TrailStrip` fixa de 34 px, `showStageSummary` com `StageSummaryAction`,
textos testáveis) e a cola em `lib/main.dart` (`_setupTrail` pós-gravura,
`_startTrailStage`, `_onTrailStageDone`, `_abandonTrailStage`,
`_endTrailRun`). Plano sem fase final (`includeFinal: false` novo em
`TrailPlan.build`); ao concluir o último trecho a faixa diz "Fase final em
breve". Testes: `test/trail_controller_test.dart` (6) e
`test/trail_widgets_test.dart` (5) — fluxos aprovar→próxima, reprovar→tentar
de novo, pular com confirmação.

- A etapa manda nos controles sem gravar: modo/mão da fase, andamento no
  agendador (restaurado a `_speed`), contagem+metrônomo forçados nas etapas
  com tempo, resto do aluno intacto. Sem teclado MIDI, a faixa avisa em vez
  de começar.
- Faixa em sobreposição (fora da caixa de layout): não muda a área gravada
  e não dispara re-render — vale no celular e no layout largo.
- Sem trilha (saltos, sem número de hino): linha explicando + modo livre
  direto. "Treino livre"/"Voltar à trilha" na gaveta e no layout largo; o
  livre não toca na trilha e só ele alimenta `onPracticeScore`.
- Parar no meio não registra e não abre resumo (só o fim por conta própria
  chama `onRangeDone`).
- Critérios 1–3 cobertos nos testes de controlador+widgets (com motor e
  MIDI falsos no controlador J04); o fluxo E2E na `ScoreHomePage` (que pede
  Verovio nativo, sem implementação em `flutter test`) fica nos manuais
  5–6, pendentes no aparelho: hino 1 com teclado, contagem/metrônomo e a
  outra mão nas etapas de uma mão; faixa sem re-render nem corte em
  360×780 em paisagem.
- `just analyze` e `just test` limpos.
