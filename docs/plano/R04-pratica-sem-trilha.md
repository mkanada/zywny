# R04 — Prática sem trilha

**Repo:** zywny · **Depende de:** R01 · **Decisão necessária:** não

## Objetivo

`lib/practice/` deixa de importar `lib/trail/` (primeira parte do achado 8
da revisão). A trilha depende da prática, nunca o contrário.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 8.
- `lib/trail/stage_result.dart` inteiro (~140 linhas).

## Contexto que você precisa

- O único import é `practice/practice_controller.dart` L16 →
  `trail/stage_result.dart`, e `stage_result.dart` importa de volta
  `practice/practice_report.dart`.
- `stage_result.dart` tem duas coisas que **são da prática**, não da
  trilha:
  - `StageResult` (acertos, total, compassos com erro, `nothingToPlay`,
    `accuracy`, `percent`, `fromReport`): o resultado de uma passagem.
    Também é usado pelo curso (`course/exercise/score_round_runner.dart`
    L259, `course/ui/exercise_screen.dart` L406) — não é só da trilha;
  - `WaitTally`: a contagem "de primeira" do modo espera, alimentada por
    dentro do `PracticeController` (L87, L200, L242, L452, L572, L710–L723).
- Só uma coisa é da trilha: `kTrailPassAccuracy` (0,90, J00) e o getter
  `passed`, usados em `main.dart` L1421/L1440/L2805,
  `trail/trail_widgets.dart` L202–L203 e `trail/trail_controller.dart` L293.
- A revisão sugeria que o controller emitisse só `PracticeReport` e a
  trilha convertesse. Não basta: o `WaitTally` é estado que o controller
  atualiza nota a nota, e o curso também lê o `StageResult`. Por isso este
  passo **muda o arquivo de lugar** e deixa na trilha só a regra dos 90%.

## O que fazer

1. `lib/practice/stage_result.dart` com `StageResult` (sem `passed`) e
   `WaitTally`, e os mesmos comentários. Nome do tipo não muda.
2. `lib/trail/stage_result.dart` fica com `kTrailPassAccuracy` e
   `extension StagePass on StageResult { bool get passed => … }`, mais
   `export '../practice/stage_result.dart';` para os 13 usuários de hoje
   (ver `grep -rln stage_result.dart lib test`) continuarem compilando.
3. `practice_controller.dart` importa `stage_result.dart` da própria pasta.
4. Mover os testes de `StageResult`/`WaitTally` que não falam de 90% de
   `test/stage_result_test.dart` só se o arquivo ficar confuso; senão,
   deixar.
5. Apagar da lista de desvios do R01 a linha `// R04`.

## Fora de escopo

Mudar a regra da etapa, o texto da tela, o cálculo de `percent`.

## Critérios de aceite

1. `grep -rn "trail/" lib/practice` não acha nada.
2. `just analyze` e `just test` limpos; o teste de camadas passa sem a
   linha `// R04`.

## Notas de execução

2026-10-06:

- `lib/practice/stage_result.dart` novo, com `StageResult` (sem `passed`)
  e `WaitTally`, comentários iguais. `practice_controller.dart` importa da
  própria pasta.
- `lib/trail/stage_result.dart` ficou com `kTrailPassAccuracy`,
  `extension StagePass on StageResult { bool get passed }` e
  `export '../practice/stage_result.dart'`.
- `main.dart` e `trail/trail_widgets.dart` importavam com
  `show StageResult, kTrailPassAccuracy`; passaram a mostrar também
  `StagePass`, senão o `.passed` some.
- O curso não importa `StageResult` hoje (só cita no comentário de
  `exercise_round.dart` L144); o contexto acima estava desatualizado.
- `test/stage_result_test.dart` ficou onde estava: os testes de
  `StageResult`/`WaitTally` conferem `passed` junto, separar só espalharia.
- A linha `// R04` saiu de `_desviosConhecidos`. Sobram 5 (todos R06).
- Aceite: `grep -rn "trail/" lib/practice` vazio; `just analyze` sem
  avisos; `just test` 878 passaram, 10 pulados.
