# R11 — `TrailRunner`

**Repo:** zywny · **Depende de:** R10 · **Decisão necessária:** não

## Objetivo

Último passo do achado 5 da revisão. O andamento da trilha de estudo —
montar a trilha, armar a etapa, contar, ouvir, avaliar, avançar, encerrar
— sai da tela para um `ChangeNotifier`. Depois dele, `_ScoreHomePageState`
é composição: monta os controllers e desenha.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 5.
- [R10](R10-playback-controller.md): as notas de execução.
- `lib/main.dart` nos trechos abaixo (linhas do commit `fac579c`; confira
  com `graft skeleton lib/main.dart` antes).

## Contexto que você precisa

- Estado (L300–L330): `_trail` (`TrailController`), `_trailUnavailable`,
  `_trailPieceN`, `_alsoStudied`; o `_trailStore` vem do `OpenedPiece`
  desde o R07.
- Métodos: `_setPieceTrailN` L573, `_refreshAlsoStudied` L855,
  `_setupTrail` L1060, `_onTrailChanged` L1142, `_markErrors` L1157,
  `_clearErrorMarks` L1167, `_armTrailStage` L1179, `_trailMarkedIds`
  L1200, `_startTrailStage` L1244, `_listenTrailStage` L1333,
  `_stopListening` L1378, `_onTrailStageDone` L1405, `_onTrailBlockDone`
  L1479, `_trailBadLogical` L1513, `_abandonTrailStage` L1523,
  `_endTrailRun` L1530.
- `TrailController` (`lib/trail/trail_controller.dart`) já é a lógica pura
  da trilha; o que mora na tela é a **cola** entre ela, o player (R10), a
  prática (`PracticeController`) e as marcas de erro na partitura.
- O progresso é separado por tom (Q04): o id vem de
  `progressIdFor(piece.id, transposition)` (L1073–L1075), com a
  transposição da sessão do R09.
- Widgets da trilha (`_trailChip` L2843, `_trailStrip` L2878,
  `_buildTrailDrawer` L2920, `_trailMessage` L2962) ficam na tela.

## O que fazer

1. `lib/app/trail_runner.dart` (`ChangeNotifier`): recebe o
   `TrailProgressStore`, o `PlaybackController`, a `ScoreRenderSession` e
   a peça; expõe `trail`, `unavailable`, `alsoStudied`, `markedIds` e as
   ações acima.
2. A tela só chama o runner e desenha o que ele expõe.
3. `test/trail_runner_test.dart` com `FakeMidiInput` e relógio simulado:
   uma etapa passada avança, uma etapa com erro marca os compassos, o
   bloco final grava o progresso no tom certo. Os testes de
   `test/trail_*_test.dart` existentes continuam passando.
4. Se o modo treino livre (`_togglePractice` … `_stopPractice`) ficar
   claramente melhor junto do runner, pode ir; senão fica na tela e é
   anotado aqui.

## Fora de escopo

Mudar regras da trilha (J00) ou o que a gaveta mostra.

## Critérios de aceite

1. `wc -l lib/main.dart` abaixo de 2500 linhas (era 3823); nenhum dos
   métodos listados existe mais lá.
2. `just analyze`, `just test` e `just telas` limpos.
3. No app, com o teclado: uma etapa da trilha do começo ao fim, uma com
   erro de propósito, e trocar de tom no meio **(manual)**.

## Notas de execução


Feito em 2026-10-07.

- `lib/app/trail_runner.dart`: `TrailRunner` (`ChangeNotifier`) com `trail`,
  `unavailable`, `alsoStudied`, `pieceN`, `trailMode`, `practice`,
  `listening`, `inputLatencyMs`, `errorMeasureIds`, `markedIds()`/`isMarked`
  e as ações `attachDocument`, `setup`, `restartTrail`, `setPieceN`,
  `markErrors`/`clearErrorMarks`, `startStage`, `listenStage`,
  `stopListening`, `abandonStage`, `loadInputLatency`/`setInputLatency`,
  `togglePractice`, `endPractice`, `stopPractice`. Recebe o
  `TrailProgressStore`, o `PlaybackController`, a `ScoreRenderSession`, a
  `SoundOutputController`, as configurações, o MIDI (gerenciador e
  entrada), a peça e o termo da biblioteca, os controllers de destaque e
  fantasma, o detector de deslocamento (Q07) com o `onShift` da tela e a
  conversão de alturas da entrada (fase Q).
- Os diálogos ficam na tela, por `TrailRunnerHost`: `stageSummary`,
  `conclusion`, `backToLibrary`, `practiceReport` (pontuação na biblioteca
  e resumo do T03) e `pieceNChanged` (guardar o N do hino). A confirmação de
  trocar o corte vai como `confirm:` de `setPieceN`.
- **O treino livre foi junto** (item 4): ele e a etapa dividem o mesmo
  `PracticeController`, a pintura das mãos, o "devolver o player" e a
  latência calibrada — separados, o runner teria de expor o treino da tela
  e vice-versa. A tela passa a mão e o modo (`togglePractice(hand:,
  mode:)`); `_trainingMode` e `_hand` continuam dela (são escolhas da
  barra/gaveta).
- O runner ouve as configurações (remontar a trilha quando o corte ou as
  etapas mudam; cores do treino); o `_onSettingsChanged` da tela só
  redesenha. A tela não tem mais `_trail`, `_practice`, `_listening`,
  `_inputLatencyMs` nem os campos das marcas; `_markMeasure` (desenho)
  ficou e lê do runner.
- `test/trail_runner_test.dart`, 3 testes (`testWidgets`, Gymnopédie pronta,
  `FakeSoundEngine` com relógio andado pelo teste e `FakeMidiInput` tocando
  a etapa "notas da direita" no modo espera): uma etapa passada fica
  aprovada e a trilha avança; com teclas erradas, o resumo traz os
  compassos e eles ficam marcados na pauta (dentro do trecho); com a
  partitura transposta, o progresso vai para o id do tom
  (`progressIdFor`) e o do tom original fica intocado. Os `trail_*_test`
  existentes passam sem mudança.
- Aceite: `wc -l lib/main.dart` 2318 (era 3823 no `fac579c`; 2948 depois do
  R10); nenhum dos métodos listados existe lá; `just analyze` limpo;
  `just test` 897 passaram, 10 pulados. **`just telas` (precisa do celular
  no `adb`) e o critério 3 (manual, teclado) pendentes.**
