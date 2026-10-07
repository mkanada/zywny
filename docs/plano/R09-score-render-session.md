# R09 — `ScoreRenderSession`

**Repo:** zywny · **Depende de:** R08 · **Decisão necessária:** não

## Objetivo

Segundo passo do achado 5 da revisão. A gravura — pedir o render, a fila
de renders, a transposição com que foi gravada, o tamanho da caixa — sai
da tela para um `ChangeNotifier` que entrega o `VsbDocument` e a
`PerformanceTrack` prontos.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 5.
- [R08](R08-sound-output-controller.md): as notas de execução (como a tela
  passou a ouvir o primeiro controller).
- `lib/main.dart` nos trechos abaixo (linhas do commit `fac579c`; confira
  com `graft skeleton lib/main.dart` antes).

## Contexto que você precisa

- Estado (L183–L240): `_renderer`, `_document`, `_pageIndex`, `_status`,
  `_renderError`, `_busy`, `_renderQueued`, `_renderedTransposition`,
  `_originalRange`, `_boxDevicePx`, `_resizeDebounce`, `_layout`,
  `_pageFitsBox`, `_transposeChoice`.
- Métodos: `_onBoxSize` L643; `_transpositionFor` L693,
  `_chooseTranspose` L721, `_pickTone` L756; `_effectiveOptions` L925;
  `_renderAndShow` L936–L1059 (com a recusa de gravura sem páginas do
  achado 1, já corrigido — os testes estão em `test/transpor_tela_test.dart`);
  `_setLayoutValue` L2543, `_commitLayout` L2548, `_resetLayout` L2554,
  `_copyOptions` L2562.
- `_renderAndShow` hoje também recria o `ScorePlayer`, a `PerformanceTrack`
  e o agendador, e chama `_attachAudio`. A criação do player **fica na tela**
  até o R10: a sessão avisa "documento novo" e a tela monta o player.
- Os widgets de transposição (`_transposeSection` L777, `_transposeSeal`
  L819, `_openTransposeDialog` L804) são tela e ficam.

## O que fazer

1. `lib/app/score_render_session.dart` (`ChangeNotifier`): recebe o
   `ScoreRenderer`, o `scoreXml`, as `PieceSettings` guardadas e o
   `debugMode`; expõe `document`, `track`, `status`, `error`, `busy`,
   `transposition`, `originalRange`, `layout`, `pageFitsBox`,
   `effectiveOptions` e as ações `setBox`, `setLayoutValue`,
   `commitLayout`, `resetLayout`, `chooseTranspose`, `render()`.
2. A fila (`_renderQueued`) e o debounce do redimensionamento vão junto e
   ganham teste sem widget: dois pedidos durante um render dão um render
   só depois, com as opções da hora.
3. A tela ouve a sessão e, a cada documento novo, monta player/agendador
   como antes.
4. Os testes de `transpor_tela_test.dart` sobre a gravura vazia continuam
   passando sem mudança de expectativa.

## Fora de escopo

O player e o agendador (R10). A trilha que é montada depois do render
(`_setupTrail`, R11).

## Critérios de aceite

1. `_renderAndShow`, `_effectiveOptions` e `_onBoxSize` não existem mais em
   `main.dart`.
2. `just analyze` e `just test` limpos; teste novo da fila de render.
3. `just telas` sem diferença nas fotos.

## Notas de execução

