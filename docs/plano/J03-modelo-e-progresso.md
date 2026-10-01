# J03 — Modelo da trilha, desbloqueio e progresso persistente

**Repo:** zywny · **Depende de:** J01 · **Decisão necessária:** nenhuma
(regras em [J00](J00-trilha-de-estudo.md))

## Objetivo

O modelo que diz **quais etapas existem** para uma música, **qual está
aberta**, e guarda o que o aluno já fez. Mais a configuração de N (geral e
por música). Sem tela.

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Etapas de um trecho", "Fase final",
  "Pular e refazer", "Dados".
- `lib/trail/trail_segments.dart` (do J01).
- `lib/library/hymn_progress.dart` inteiro (o padrão de store: um JSON em
  `SharedPreferencesAsync`, `ChangeNotifier`, JSON estragado recomeça).
- `lib/settings/hymn_settings.dart` L1-L110 e `lib/settings/app_settings.dart`
  L24-L135 (como se acrescenta um campo).
- `lib/practice/hand.dart`, e `PracticeMode` em
  `lib/practice/practice_controller.dart`.
- `test/settings_test.dart`, `test/library_test.dart` (prefs falsas).

## Contexto que você precisa

- Uma etapa precisa de um **id estável** para ser guardada:
  `t<trecho>.<fase>[.<degrau>]` — `t0.notasD`, `t0.notasE`, `t0.notasJ`,
  `t0.ritmoD.50`, `t0.ritmoE.75`, `t0.junto.100`; fase final `final.50`,
  `final.75`, `final.100`.
- Os ids dependem do corte. Por isso o progresso guarda o **N usado**: se o
  N efetivo da música mudar, o progresso guardado é de outro corte e é
  descartado (a tela pede confirmação antes — J06).
- "Mão sem notas no trecho": pergunte ao `PerformanceTrack` se há evento
  não-ornamento da pauta em `[startMs, endMs)`. Com uma mão só, o trecho
  tem 4 etapas: notas + ritmo 50/75/100 daquela mão.
- Estados: `pendente` (nunca aprovada nem pulada), `aprovada`, `pulada`.
  Guarda-se também a melhor porcentagem (0–100) de qualquer tentativa.
- Desbloqueio: as etapas têm uma ordem linear (trecho 0 inteiro, trecho 1…,
  fase final). A **atual** é a primeira `pendente`. Estão abertas a atual e
  todas as anteriores. Trilha concluída = nenhuma `pendente`.
- N: `AppSettings.trailMeasures` (padrão 5, mínimo 3) e
  `HymnSettings.trailMeasures` (`int?`, `null` = usa o geral). Efetivo =
  o da música, senão o geral.

## O que fazer

1. `lib/trail/trail_stage.dart`: `TrailPhase` (enum com `mode`, `hand`,
   rótulo), `TrailStage {id, segment (null na fase final), phase, speed
   (null no modo espera), startMs, endMs, label}`.
2. `lib/trail/trail_plan.dart`: `TrailPlan.build(TrailPath, PerformanceTrack,
   {required int n})` → lista ordenada de `TrailStage` (trechos + fase
   final), pulando as fases de mão vazia.
3. `lib/trail/trail_progress.dart`:
   - `StageRecord {state, best}`.
   - `TrailProgress {n, records}` com `stateOf(id)`, `current(plan)`,
     `isOpen(plan, id)`, `doneCount(plan)`, `isComplete(plan)`,
     `finalApproved` (a `final.100` aprovada).
   - Mutações que devolvem novo valor: `recordResult(id, StageResult)`
     (aprova se `passed`; sempre atualiza `best`; nunca rebaixa `aprovada`),
     `skip(id)` (só `pendente` vira `pulada`).
   - `TrailProgressStore extends ChangeNotifier`: `load()`, `operator
     [](hymnNumber)`, `save(hymnNumber, progress)`, `reset(hymnNumber)`.
     Um JSON por hino (`trail_<número>`), com `'v': 1`. Guarde também
     `doneCount`/`total` no próprio JSON: a biblioteca (J09) mostra o
     resumo sem montar o plano de 600 hinos.
4. `trailMeasures` em `AppSettings` (chave `trail_measures`) e em
   `HymnSettings` (campo no JSON, entra em `isDefault`).

## Fora de escopo

- Tela, gaveta, confirmação de reinício (J05, J06).
- Blocos do reforço (não são guardados — J07).
- Partitura aberta fora da biblioteca (sem número de hino: a trilha não
  persiste; a tela trata disso no J05).

## Critérios de aceite

1. Teste: plano de 2 trechos com as duas mãos → 12 + 12 + 3 = 27 etapas,
   na ordem do J00, ids como descrito.
2. Teste: trecho em que a pauta 2 não tem notas → 4 etapas naquele trecho,
   nenhuma de mão esquerda nem "juntas".
3. Teste de desbloqueio: tudo `pendente` → atual é `t0.notasD`, só ela
   aberta; aprovar → atual `t0.notasE`; pular → a pulada fica `pulada` e a
   seguinte abre; refazer a pulada com 95% → `aprovada`.
4. Teste: aprovada com 92%, nova tentativa com 70% → continua `aprovada`,
   `best == 92`; tentativa com 97% → `best == 97`.
5. Teste: grava, cria outro store com as mesmas prefs, carrega → igual.
   JSON estragado → trilha vazia, sem exceção.
6. Teste: progresso guardado com `n = 5`, plano montado com `n = 4` → o
   store entrega trilha vazia para esse plano (e não mistura ids).
7. Teste: `trailMeasures` geral e por hino persistem; valor fora da faixa
   lido do JSON é trazido para ≥ 3.
8. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
