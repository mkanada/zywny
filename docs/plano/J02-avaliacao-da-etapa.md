# J02 — Avaliação da etapa e blocos de reforço (Dart puro)

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** nenhuma
(regras em [J00](J00-trilha-de-estudo.md))

## Objetivo

Transformar o que as sessões de treino já emitem num **resultado de etapa**
(porcentagem, aprovado ou não, compassos com erro) e, a partir dos
compassos com erro, montar os **blocos de reforço**. Dart puro.

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Aprovação" e "Fase final".
- `lib/practice/practice_report.dart` inteiro (`PracticeReport`,
  `MeasureStats`, `PracticeReport.rhythm`).
- `lib/practice/practice_session.dart` L44-L200 (`PracticeStep`,
  `WaitModeSession.noteOn`: quando sai `wrong`, quando o passo avança,
  `_restartChord`).
- `test/practice_report_test.dart`.

## Contexto que você precisa

- Tempo real e ritmo já têm `PracticeReport` com `accuracy = correct /
  total` e `measures` (por ocorrência). No ritmo, `extra` fica **fora** de
  `total` — para a trilha ele entra no denominador (J00).
- O modo espera não tem resumo hoje (`_endPractice` em `lib/main.dart` só
  monta resumo quando `mode != wait`). Os vereditos existem: `correct` por
  nota certa e `wrong` por tecla errada, este sem `eventId`. O passo
  pendente é `WaitModeSession.current` (`PracticeStep.index`, `onMs`).
- "De primeira" = nenhum `wrong` chegou enquanto aquele passo estava
  pendente. Um acorde de 3 notas é **um** passo.
- Os índices de compasso em `MeasureStats.index` são ocorrências de
  `ScoreTimeline.measures`. O reforço trabalha em compassos **lógicos** do
  caminho (J01). Este passo recebe a conversão pronta como função
  (`int? Function(int occurrence)`), para não depender do J01.

## O que fazer

1. `lib/trail/stage_result.dart`:
   - `const double kTrailPassAccuracy = 0.90;`
   - `StageResult {hits, total, badMeasures: Set<int> (ocorrências)}`, com
     `accuracy`, `percent` (inteiro, arredondado para **baixo** — 89,9% não
     vira 90) e `passed => total > 0 && hits / total >= kTrailPassAccuracy`.
   - `StageResult.fromReport(PracticeReport r, {required bool rhythm})`:
     `hits = r.correct`; `total = r.total + (rhythm ? r.extra : 0)`;
     `badMeasures` = compassos com `errors + imprecise > 0`.
2. `WaitTally` (mesmo arquivo ou `lib/trail/wait_tally.dart`): contador
   alimentado pelo controlador —
   `stepStarted(int stepIndex, int measure)`, `wrong()`, `stepDone()` —
   que devolve um `StageResult` (passos de primeira / passos concluídos;
   `badMeasures` = compassos de passos que tiveram `wrong`). Um `wrong`
   antes do primeiro `stepStarted` ou depois do último `stepDone` é
   ignorado.
3. `lib/trail/reinforcement.dart`:
   `List<({int first, int last})> reinforcementBlocks(Set<int> badLogical,
   int measureCount)` com as 4 regras do J00 (agrupar vizinhos, um bom de
   cada lado, mínimo 3, fundir).

## Fora de escopo

- Ligar o `WaitTally` ao `PracticeController` (J04).
- Mudar janelas de tolerância ou o `PracticeReport` do modo livre.

## Critérios de aceite

1. Teste: `fromReport` tempo real, 18 `correct` + 1 `late` + 1 `missed` →
   90%, aprovado; 17 + 3 → 85%, reprovado.
2. Teste: `fromReport` ritmo, 10 `correct`, 0 erros, 2 `extra` → 83%,
   reprovado.
3. Teste: 899 acertos em 1000 → `percent == 89`, reprovado.
4. Teste: `total == 0` → reprovado (etapa sem nada avaliado não aprova).
5. Teste `WaitTally`: 10 passos, `wrong` em um deles (duas vezes) → 9/10,
   aprovado, um compasso ruim; `wrong` em dois passos → 8/10, reprovado.
6. Teste `reinforcementBlocks`, com 20 compassos: `{7}` → `[6-8]`; `{7,8}`
   → `[6-9]`; `{0}` → `[0-2]`; `{19}` → `[17-19]`; `{5,7}` → `[4-8]`
   (fundidos); `{3,12}` → `[2-4]` e `[11-13]`; vazio → lista vazia.
7. `just analyze` e `just test` limpos.

## Notas de execução (J02, 2026-10-01)

Implementado: `lib/trail/stage_result.dart` (`kTrailPassAccuracy`,
`StageResult`, `StageResult.fromReport`, `WaitTally`) e
`lib/trail/reinforcement.dart` (`reinforcementBlocks`).
Testes: `test/stage_result_test.dart` (6 testes, todos os critérios 1–6).

- `percent` usa conta inteira (`hits * 100 ~/ total`): 90% crava 90 sem
  erro de binário; 899/1000 dá 89.
- `WaitTally` ignora `wrong` sem passo pendente (antes do primeiro
  `stepStarted`, depois do último `stepDone`); o recomeço de acorde por
  falta de simultaneidade (`kWaitChordWindowMs`) não passa por aqui —
  é `correct`/`_restartChord` na sessão, nunca `wrong` (J00).
- `reinforcementBlocks` recebe lógicos (a conversão
  ocorrência→lógico é `TrailPath.logicalOf`, do J01) e aplica as 4
  regras; blocos que se tocam (`next.first <= cur.last + 1`) fundem.
- `just analyze` e `just test` limpos.
