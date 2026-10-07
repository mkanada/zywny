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

