# U05 — O selo e o resumo na mesma régua

**Repo:** zywny · **Depende de:** U01 · **Decisão necessária:** D-SELO

## Objetivo

O número que o aluno vê durante a etapa é o número que o resumo vai dar, e a
meta de 90% está escrita. Achados A5 e B1; sugestões A5 e B1.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e as sugestões **A5** e **B1**.
- Telas `38`→`39` (selo ✓ 10 ✗ 8, resumo 10% "Faltou 80%") e `41`→`42`
  (selo ✓ 10 ✗ 10, "Precisão 7%").
- `lib/practice/practice_controller.dart`: contadores L194-L201,
  `stageResult` L401-L417, `_onRhythmVerdict` L523-L558, `_onVerdict`
  L588-L638, `_onStepChanged` L678-L714.
- `lib/trail/stage_result.dart` (93 linhas, inteiro): `StageResult`,
  `StageResult.fromReport`, `WaitTally`, `kTrailPassAccuracy`.
- `lib/practice/practice_report.dart` L72-L130 (`PracticeReport`:
  `correct`, `early`, `late`, `wrong`, `missed`, `extra`, `accuracy`).
- `lib/ui/phone_chrome.dart`: `PhoneCountersPill` L322-L371.
- `lib/main.dart`: `_buildPhoneTitleBar` L1966-L1987.
- `lib/trail/trail_widgets.dart`: `showStageSummary` L130-L247 (o texto
  "Faltou" em L163-L164).
- `test/stage_result_test.dart`, `test/trail_widgets_test.dart` L69-L160.

## Contexto que você precisa

- O selo de hoje tem dois contadores:
  - `correctCount` sobe em `correct`, **`early` e `late`** (L593, L619,
    L539);
  - `wrongCount` sobe em `wrong` e em toque `extra` (L602, L555);
  - nota `missed` não entra em nenhum.
- O resultado da etapa conta só `correct` como acerto; `early`, `late`,
  `wrong` e `missed` são erro (J00, "Aprovação"), e no ritmo o `extra` entra
  no denominador. Por isso ✓ 10 ✗ 8 virou 10%.
- No modo espera a conta é outra (`WaitTally`): passos concluídos de
  primeira / passos concluídos.
- **D-SELO, recomendação:** o selo mostra a porcentagem corrente, na conta
  do `StageResult`, e a meta: "72% · meta 90%". Alternativa: os quatro
  contadores do resumo.
- "Faltou $missing%" (`missing = 90 − percent`) mistura ponto percentual com
  porcentagem; a meta não aparece em lugar nenhum do app.
- Treino livre: tempo real e ritmo têm `PracticeReport.accuracy` (a mesma
  conta `correct/total`); o modo espera livre não tem resultado.
- Cuidado com custo: `stageResult` no tempo real reconstrói o
  `PracticeReport` a partir de todas as entradas. Chamar a cada veredito é
  O(n²) no pior caso; some contadores incrementais em vez disso.

## O que fazer

1. `PracticeController`: um `ValueListenable<({int hits, int total})>`
   (`liveScore`), atualizado a cada veredito e a cada passo do modo espera,
   com a **mesma** conta de `stageResult`:
   - espera com intervalo: `WaitTally` (exponha `_firstTry`/`_done`);
   - tempo real: `correct` / avaliadas;
   - ritmo: `correct` / (avaliadas + `extra`).
   Teste que trava a igualdade: ao fim de uma passagem,
   `liveScore` == `stageResult` (hits e total), nos três modos.
2. `PhoneScorePill` em `lib/ui/phone_chrome.dart`: "72%" + " · meta 90%"
   quando há meta; verde (`kGoodColor`) a partir da meta, âmbar (`kOkColor`)
   abaixo, neutro com `total == 0` (mostra "—"). Algarismos tabulares, para
   a largura não dançar.
3. `_buildPhoneTitleBar`: na trilha, `PhoneScorePill` com meta
   `kTrailPassAccuracy`; no treino livre em tempo real e ritmo, sem meta; no
   modo espera livre, o `PhoneCountersPill` de hoje.
4. `showStageSummary`: reprovado → "Precisa de 90% para passar"; aprovado →
   "Aprovado · meta 90%". O número grande continua sendo `result.percent`.
   O 90 vem de `kTrailPassAccuracy`, não escrito à mão.
5. Atualizar `test/trail_widgets_test.dart` (os textos) e o roteiro das
   telas (`_summaryOpen` procura "Aprovado" ou "Faltou": passa a procurar
   "Aprovado" ou "Precisa de").

## Fora de escopo

- Mudar o que conta como acerto, as janelas ou os 90%.
- Marcar os compassos com erro na pauta e o resumo do treino livre (U12).
- O layout largo.

## Critérios de aceite

1. Teste: para uma sequência de vereditos com `correct`, `late`, `wrong` e
   `missed`, `liveScore` final == `stageResult` (tempo real).
2. Teste: idem no ritmo com toques `extra`, e no modo espera com um passo
   errado.
3. Teste de widget: `PhoneScorePill` com 0/0 ("—"), 72% âmbar e 93% verde.
4. Teste de widget: resumo reprovado mostra "Precisa de 90% para passar";
   não existe mais "Faltou".
5. `just telas`: o número do selo na última foto antes do resumo de uma
   etapa (38) é coerente com o do resumo (39) — a etapa pode ter andado
   entre as duas fotos, mas não pode haver ✓ maior que ✗ com resultado de
   10%.
6. `just analyze` e `just test` limpos; o roteiro das telas passa.
