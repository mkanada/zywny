# L04 — Plano, desbloqueio e progresso do decorar

**Repo:** zywny · **Depende de:** J03, L01 · **Decisão necessária:**
nenhuma (regras em [L00](L00-trilha-do-decorar.md))

## Objetivo

O modelo que diz quais etapas a trilha do decorar tem para uma música, qual
está aberta, e guarda o que o aluno já fez — reaproveitando o que o J03
construiu. Sem tela.

## Ler antes (só isto)

- [L00](L00-trilha-do-decorar.md): "Onde ela mora", "Etapas", "Dados".
- [J03](J03-modelo-e-progresso.md) e as notas de execução dele.
- `lib/trail/trail_stage.dart`, `trail_plan.dart`, `trail_progress.dart`
  (J03).
- `lib/memo/memo_hiding.dart` (L01).
- `test/` do J03 (prefs falsas, testes de desbloqueio).

## Contexto que você precisa

- As regras de estado (`pendente`, `aprovada`, `pulada`), de melhor
  porcentagem e de desbloqueio linear são **as mesmas** do J03. Não copie
  `TrailProgress`: generalize. O que muda entre as duas trilhas é a lista
  de etapas e a chave de armazenamento.
- A etapa do decorar tem dois campos a mais que a da trilha de estudo:
  o **sumiço** (25/50/75/100, ou `null` na prova às cegas) e a marca de
  **às cegas**. Modo e mão são sempre `realtime` e `ambas`.
- Ids: `t<trecho>.s<sumiço>.<degrau>`, `inteira.s<sumiço>.<degrau>`,
  `cega.<degrau>`. Ordem: trechos em ordem; dentro de cada bloco, sumiço
  por fora e degrau por dentro; depois `inteira`, depois `cega`.
- Chave do store: `memo_<número do hino>`, com `'v': 1`, o N usado e o
  resumo (`feitas`, `total`, `puladas`, `deCor`) para a biblioteca (L08).
  N diferente do efetivo → progresso descartado, como no J03.
- **N compartilhado**: é o `trailMeasures` efetivo. Quem zera a trilha de
  estudo por mudança de N (J06) zera também o decorar — exponha
  `reset(hymnNumber)` e deixe a chamada para o L06.
- Trecho sem coluna nenhuma (só pausas) não gera etapas e não conta como
  pulado. Trecho com uma mão só é normal: as colunas são as da mão que
  existe.

## O que fazer

1. Extrair de `lib/trail/` o que serve às duas trilhas (estado, registro,
   desbloqueio, store com chave parametrizada) sem mudar o comportamento
   nem os testes do J03.
2. `lib/memo/memo_stage.dart`: `MemoStage {id, segment (null em `inteira`
   e `cega`), hideLevel (null em `cega`), blind, speed, startMs, endMs,
   label}`.
3. `lib/memo/memo_plan.dart`: `MemoPlan.build(TrailPath, List<TrailSegment>,
   MemoHiding)`.
4. `lib/memo/memo_progress.dart`: store `memo_<n>`, `deCor` (a `cega.100`
   aprovada), leitura em lote dos resumos.

## Fora de escopo

- Tela (L06), prova às cegas na tela (L07), biblioteca (L08).
- Reforço.

## Critérios de aceite

1. Teste: plano de 2 trechos → 12 + 12 + 12 + 3 = 39 etapas, na ordem do
   L00, com os ids descritos.
2. Teste: a primeira etapa é `t0.s25.50`; depois de `t0.s25.100` vem
   `t0.s50.50`; depois do último trecho vem `inteira.s25.50`; a última é
   `cega.100`.
3. Teste de desbloqueio, pular e refazer: os mesmos cenários do J03,
   rodando no modelo generalizado.
4. Teste: `cega.100` aprovada → `deCor`; `cega.100` pulada → **não**.
5. Teste: progresso do decorar e da trilha de estudo do mesmo hino não se
   misturam (chaves diferentes); `reset` de um não apaga o outro.
6. Teste: N guardado diferente do efetivo → trilha vazia.
7. Os testes do J03 continuam passando sem mudança de expectativa.
8. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_

**Da fase Q (Q04, 2026-10-06):** o progresso é separado por tom da música
transposta. O id do decorar (`memo_<id>`) deve ser montado com
`progressIdFor(pieceId, transposition)` (`lib/library/library_keys.dart`) —
o original mantém `memo_<id>`, um tom transposto vira `memo_<id>@-m3` —, e
quem lê "tons com progresso" (`TrailProgressStore.studiedTones`) deve ter o
equivalente para o decorar. Ninguém concatena o sufixo à mão.
