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


Feito em 2026-10-07.

- `lib/app/score_render_session.dart`: `ScoreRenderSession` (`ChangeNotifier`)
  com `document`, `track`, `pageIndex`/`pageCount`, `status`, `error`, `busy`,
  `transposition` (a pedida) e `renderedTransposition` (a da gravura na tela),
  `transpositionFor`, `noAccidentals`, `originalRange`, `transposeChoice`,
  `layout`/`layoutDefaults`, `pageFitsBox`, `fittedPage`, `effectiveOptions`
  e as ações `setBox`, `setPage`, `setLayoutValue`, `setPageFitsBox`,
  `resetLayout`, `chooseTranspose` e `render()`. Recebe o `ScoreRenderer`, o
  `scoreXml`, a peça, as `AppSettings`, as `PieceSettings` guardadas, o nome
  do status, `phone` e `debugMode`.
- "Documento novo" é o callback `onDocument(document, track)`, chamado com o
  estado da sessão já trocado e antes do aviso aos ouvintes. Na tela,
  `_onDocument` desmonta o treino/player/agendador da gravura anterior e
  monta os novos, como o `_renderAndShow` fazia, e segue com a trilha,
  `restoreSound` e a conferência do TRANSPOSE.
- A sessão ouve as configurações ela mesma: a regravação quando a chave
  "sem acidentes" muda o tom saiu do `_onSettingsChanged` da tela.
- `setBox` é chamado do `build` e nunca avisa na hora; devolve `true` na
  primeira caixa, e a tela redesenha num `addPostFrameCallback` (como antes).
- Ficaram na tela, por serem tela ou gravação das preferências do hino:
  `_commitLayout` (guarda e chama `render()`), `_resetLayout`,
  `_copyOptions`, a parte de `_chooseTranspose` que pergunta (Q04) e os
  widgets de transposição. O status deixou de passar por "gerando .vsb…"
  (era trocado no mesmo quadro por "renderizando…").
- `test/score_render_session_test.dart`, 6 testes: a primeira caixa grava;
  dois pedidos durante um render dão um só depois, com o `unit` da hora; a
  caixa tremida (1%) não grava e duas mudanças seguidas dão uma gravura
  depois do respiro; página fixa não regrava; gravura sem páginas é erro e
  mantém a de antes; descartada, não grava.
- Aceite: os três métodos não existem mais em `main.dart` (3476 → 3240
  linhas); `just analyze` limpo; `just test` 889 passaram, 10 pulados (os
  testes de `transpor_tela_test.dart` sem mudança). **Critério 3 (`just
  telas`) pendente**: precisa do celular ligado pelo `adb`, que não estava.
