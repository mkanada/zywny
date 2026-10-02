# U02 — A pauta mostra o trecho da etapa

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** nenhuma

## Objetivo

Com a etapa parada, a partitura já está no primeiro compasso do trecho e os
compassos do trecho estão marcados. O aluno olha o que vai tocar antes de
tocar. Achado A4; sugestão A4.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A4**.
- Telas `30` (a faixa diz "Trecho 2/6", a pauta mostra os compassos 1–4) e
  `32` (só depois do play a página certa aparece).
- `lib/main.dart`: `_setupTrail` L730-L778, `_onTrailChanged` L780-L782,
  `_startTrailStage` L788-L865 (o `player.seek` de L818), `_setLoop`
  L1411-L1419 (já faz "ir para o início do intervalo"), `_buildScoreArea`
  L2294-L2340 (onde a `ScoreView` é criada).
- `lib/trail/trail_controller.dart` (306 linhas): `selected`, `select` L71,
  `next` L79, `setRunning` L162.
- `lib/trail/trail_path.dart` L19-L61 (`PathMeasure.occurrence`,
  `LogicalMeasure.measures`) e `lib/trail/trail_stage.dart` (`TrailStage.first`
  /`last`: índices de compasso lógico; `segment == null` é a fase final).
- `score_bridge/lib/src/score_page_view.dart` L70-L90 e L273-L300 (overlays
  por id) e `score_bridge/test/overlay_test.dart`.

## Contexto que você precisa

- O J05 pedia "ao armar a etapa, vá para o início do intervalo", mas o
  `seek` só acontece dentro de `_startTrailStage`. Ao abrir o hino
  (`_setupTrail`) e ao trocar de etapa (`select`, `next`, pular) nada move a
  partitura.
- `player.seek` com a música parada mostra a página do instante pedido
  (`ScorePlayer._publish` → `view.showPage`). Se o som estiver ligado,
  `_scheduler?.seek(ms)` acompanha (ver `_openMeasureJump` L1936-L1939).
- **Marcar compassos**: `ScoreView.overlayIds` + `overlayBuilder(context,
  id, rect)` desenha um widget sobre o retângulo de cada id, **acima** da
  página; ids que não estão na página exibida são ignorados. O id de um
  compasso é `player.measures[occurrence].id` (`MeasureInfo.id`,
  `score_bridge/lib/src/score_timeline.dart` L85-L100). Os compassos de uma
  etapa são `trail.path.logical[stage.first..stage.last]`, cada um com uma
  ou mais `PathMeasure.occurrence`.
- O retângulo do compasso na cena pode cobrir as duas pautas ou só uma —
  **meça** antes de desenhar (um overlay de cor chapada num teste manual
  resolve). Se cobrir só uma pauta, una os retângulos do sistema.
- O seek ao **armar** não pode acontecer com a etapa rodando (`trail.running`)
  nem no meio de um render (`_busy`).

## O que fazer

1. `_armTrailStage()` em `lib/main.dart`: se há trilha, não está no modo
   livre, nada toca e há etapa selecionada, `player.seek(stage.startMs)` (e
   o agendador, se houver). Chamar no fim de `_setupTrail` e em
   `_onTrailChanged` quando a etapa selecionada mudou (guarde o id
   anterior para não repetir o seek a cada `notifyListeners`).
2. `trailStageMeasureIds(path, stage, measures)` em `lib/trail/` (Dart
   puro, testável): os ids dos compassos da etapa, na ordem.
3. Passar `overlayIds`/`overlayBuilder` à `ScoreView` na trilha (não no
   modo livre, não na fase final):
   - compassos do trecho: um traço de 3 dp em `kAccent` na borda inferior
     do retângulo;
   - compassos da página que **não** são do trecho: véu branco a 55%.
   Os ids de todos os compassos da página saem de `player.measures`.
4. Com a etapa rodando, o véu continua e o traço some (a nota destacada já
   diz onde se está) — ou fica, se ler melhor: decida pela foto e anote.
5. Testes: `trailStageMeasureIds` com caminho contíguo, com anacruse
   grudada e com salto (fixtures de `test/trail_path_test.dart`).

## Fora de escopo

- Marcar os compassos com erro depois do resumo (U12 reusa o mecanismo).
- Rolagem ou zoom até o trecho (a tela do celular é paginada e fixa).
- O layout largo pode ganhar a marca de carona se sair de graça; não é
  critério.

## Critérios de aceite

1. Teste: `trailStageMeasureIds` devolve os ids certos para o trecho 1 e o
   trecho 2 do fixture, e lista vazia para a fase final.
2. `just telas`: a tela 30 mostra a página com os compassos 5–9, marcados,
   **antes** de qualquer play; a tela 35 (etapa seguinte selecionada) idem.
3. `just telas`: na tela 11 (trecho 1) os compassos de fora do trecho, se
   houver na página, aparecem esmaecidos.
4. Trocar de etapa pela gaveta com a música parada muda a página; com a
   etapa rodando, não.
5. A marca não aparece no treino livre (tela 21).
6. `just analyze`, `just test` e `cd score_bridge && flutter test` limpos.

## Notas de execução

- `trailStageMeasureIds` em `lib/trail/trail_plan.dart`; `_armTrailStage`,
  `_trailMarkedIds` e `_markMeasure` em `lib/main.dart`. O overlay vale
  também no layout largo (a `ScoreView` é a mesma).
- Trechos vizinhos compartilham um compasso (J00), então o último compasso
  do trecho 1 é também o primeiro do 2 e aparece nos dois.
- Com a etapa rodando o véu fica e o traço some (decisão do passo, sem foto
  para confirmar).
- Critério 1 e 6 passam (`just test`, `just analyze`, `score_bridge`).
  Critérios 2–5 pedem `just telas` / aparelho e **não foram rodados**. A
  geometria do retângulo do compasso (uma pauta ou as duas) também não foi
  medida.
