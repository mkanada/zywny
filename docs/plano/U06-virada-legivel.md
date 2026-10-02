# U06 — Virada de página que deixa ler adiante

**Repo:** zywny (`score_bridge/` + `lib/main.dart`) · **Depende de:** — ·
**Decisão necessária:** D-VIRADA

## Objetivo

Na virada de página, a página nova fica legível **antes** do instante em que
a primeira nota dela é tocada, e nunca fica borrada com a música parada.
Achado A6; sugestão A6.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A6**.
- Telas `23` e `41` (página nova desfocada à esquerda da haste), `25`
  (pausado, dois terços borrados) e `24` (gaveta sobre o borrão).
- `score_bridge/lib/src/score_timeline.dart`: `_dOf` L527-L528, `curtainAt`
  L534-L577, `_multiMeasureEdge` L614-L633, `_singleMeasureEdge` L635 em
  diante.
- `score_bridge/lib/src/score_view.dart`: `kRevealBlurClearAt` e
  `revealBlurAt` L66-L71, `SweepCurtain.blur` L74-L90, `_buildSweep`
  L959-L1006 (o `ImageFiltered`).
- `score_bridge/lib/src/score_player.dart`: cabeçalho L26-L50 (virada no
  modo espera), `play`/`pause` L303-L330, `_publish` L524-L585 (o
  `blur: revealBlurAt(ahead.progress)` de L567).
- `score_bridge/test/score_view_blur_test.dart` (os dois testes) e
  `score_bridge/test/score_timeline_jump_curtain_test.dart`.
- `lib/main.dart`: `revealBlurSigma` em `_buildScoreArea` (L2328).

## Contexto que você precisa

- A haste de virada, numa página com mais de um compasso
  (`_multiMeasureEdge`), tem três fases em torno do **último compasso** `m`
  da página, com `d = min(maxSweep, duração de m / 4)`:
  1. **entra** (`s ≤ ms < s + d`): vai da borda esquerda até o começo de
     `m`; `blur = 1`;
  2. **espera** (`s + d ≤ ms < e`): parada no começo de `m`; `blur = 1`;
  3. **sai** (`e ≤ ms < e + d`): varre `m` até o fim; `blur =
     revealBlurAt(out)`, que cai a zero em `out = 0,3`.
  À esquerda da haste já se vê a página nova. Ou seja: ela fica desfocada
  durante **todo** o último compasso e só fica nítida depois de `e`, que é
  o instante da primeira nota da página nova.
- A intenção original do desfoque: enquanto o último compasso toca, o olho
  fica no fim da página velha. A proposta mantém isso na primeira metade do
  compasso.
- **D-VIRADA, recomendação (a):** na fase de espera, o desfoque cai de 1 a
  0 entre **50% e 75%** da duração de `m`; na saída é 0. Pausado, 0.
  **(b):** sem desfoque nenhum (`revealBlurSigma: 0` em `main.dart`).
  **(c):** como está.
- A página de **um** compasso só (`_singleMeasureEdge`) e a virada adiantada
  do modo espera (`_resolveAhead`, `waitTarget`) têm regra própria de
  tempo; nas duas o desfoque também passa por `revealBlurAt`. No modo
  espera a virada acontece em tempo de parede depois que o aluno acerta —
  ali a página nova deve ficar nítida logo que a haste começa a sair (o
  aluno está parado, lendo).
- "Pausado": o `ScorePlayer` sabe se está tocando. Com a música parada, a
  cortina publicada deve sair com `blur = 0` (a posição da haste não muda).
- `SweepCurtain` é imutável e comparada por valor; `blur` entra no `==`.

## O que fazer (via a)

1. `score_timeline.dart`: em `_multiMeasureEdge`, o `blur` da fase de
   espera vira função da fração `(ms − s) / (e − s)` — 1 até 0,5, linear
   até 0 em 0,75 —; na saída, 0. Constantes nomeadas
   (`kRevealBlurHoldUntil`, `kRevealBlurClearBy`) ao lado de
   `kRevealBlurClearAt`, com o comentário do porquê.
2. `_singleMeasureEdge`: aplique a mesma ideia ao intervalo que ele já
   calcula (nítida antes do fim do compasso); leia a função inteira antes.
3. `score_player.dart`: com a música parada, publicar a cortina com
   `blur: 0`. Ao dar play de novo, o desfoque volta pela regra.
4. Virada adiantada do modo espera (L567): a página nova nítida desde o
   começo da saída (`blur: 0`), ou caindo em 10% do percurso — decida pelo
   teste manual e anote.
5. Atualizar `score_view_blur_test.dart` (o teste "desfoque inteiro até a
   haste sair" descreve a regra antiga) e acrescentar: desfoque 1 em 40% do
   compasso, 0 em 80% e na saída; 0 com o player pausado.
6. `lib/main.dart`: nada, salvo se a decisão for (b).

## Fora de escopo

- Posição e velocidade da haste (`curtainAt` continua igual em `x`).
- Dois sistemas por página (U10), que reduz o número de viradas.
- Modo de rolagem contínua.

## Critérios de aceite

1. Teste (timeline): numa página de vários compassos, `curtainAt(...).blur`
   é 1 no início da espera, 1 a 40% do último compasso, 0 a 80% e 0 durante
   toda a saída.
2. Teste (player): `pause()` com a haste em espera → `curtain.value!.blur
   == 0`; `play()` → volta ao valor da regra.
3. Os testes existentes de `score_bridge` continuam passando (ajustados só
   onde descrevem a regra antiga do desfoque).
4. `just telas`: a tela 25 (pausado na virada) mostra a página nova nítida;
   a 24 não tem borrão atrás da gaveta.
5. **(manual, com teclado)** Tempo real a 100%, hino 5: tocar três viradas
   de página seguidas lendo a página nova antes de ela "chegar". Anote se a
   primeira nota de cada página saiu no tempo.
6. `cd score_bridge && flutter test`, `just analyze` e `just test` limpos.

## Notas de execução

- **Dispensado.** D-VIRADA decidida pelo usuário: **(c) como está**. Nenhum
  código mudou; o desfoque da página revelada segue a regra antiga (A6
  fica sem tratamento na fase U).
