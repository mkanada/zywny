# L01 — Colunas e sorteio do sumiço (Dart puro)

**Repo:** zywny · **Depende de:** J01 · **Decisão necessária:** nenhuma
(regras em [L00](L00-trilha-do-decorar.md))

## Objetivo

Dado o caminho de uma música e a sua `PerformanceTrack`, dizer **quais
colunas estão escondidas** em cada sumiço (25, 50, 75, 100%). Dart puro,
sem UI, sem desenho.

## Ler antes (só isto)

- [L00](L00-trilha-do-decorar.md): "O que some".
- [J00](J00-trilha-de-estudo.md): "Caminho".
- `lib/trail/trail_path.dart` (J01: `TrailPath`, `LogicalMeasure`).
- `lib/music/` — a `PerformanceTrack` (N03): eventos `{id, pitch, onMs,
  offMs, staff, …}`, a marca de ornamento e os ids ligados (`tied`).
- `test/practice_report_test.dart` (estilo dos testes com dados sintéticos).

## Contexto que você precisa

- **Coluna** = os eventos não-ornamento de **uma pauta** com o mesmo `onMs`,
  dentro do caminho. Nos hinos são quase sempre duas notas (as duas vozes
  da mão, em camadas diferentes; 598 de 600 hinos, nenhum usa `<chord/>`).
- A nota ligada é **um** evento na `PerformanceTrack` (a cabeça, com a
  duração somada). A coluna guarda também os ids das continuações, para o
  desenho escondê-las junto (L02).
- A ordem do sorteio **não** pode depender de `xml:id` (o Verovio gera
  parte dos ids ao acaso a cada render) nem de `dart:math` `Random(seed)`
  (a sequência não é garantida entre versões do SDK). Use uma função de
  mistura própria, pequena e fixa (ex.: `mulberry32` ou um `xorshift` de 32
  bits), sobre a chave `(número do compasso lógico, pauta, índice da coluna
  no compasso)`.
- Aninhamento: ordene as colunas do compasso lógico pela mistura; no sumiço
  `p` estão escondidas as primeiras `⌈p × n⌉`. Com `n = 1` a coluna some já
  a 25%.
- O sorteio é da **música**, não do trecho: `hiddenAt` de um trecho é só o
  filtro por intervalo do conjunto da música.

## O que fazer

1. `lib/memo/memo_columns.dart`:
   - `MemoColumn {measure (número do compasso lógico), staff, onMs,
     eventIds, tiedIds, shortestOffMs}`.
   - `List<MemoColumn> columnsOf(TrailPath, PerformanceTrack)`, em ordem de
     tempo e depois de pauta.
2. `lib/memo/memo_hiding.dart`:
   - `const kMemoHideLevels = [25, 50, 75, 100]`.
   - `MemoHiding.build(columns)` → `Set<MemoColumn> hiddenAt(int level,
     {double? startMs, double? endMs})` e `int rankOf(MemoColumn)`.
3. Medição: acrescente à ferramenta do J01 (`tool/trail_stats.dart`) o
   número de colunas por compasso lógico (mín., mediana, máx.) nos 600
   hinos, e ponha os totais nas notas — diz se 25% de um compasso é "uma
   coluna" ou "quase nada".

## Fora de escopo

- Desenho (L02, L03), etapas e progresso (L04).
- Esconder vozes separadas dentro de uma pauta.

## Critérios de aceite

1. Teste: compasso com 8 colunas numa pauta → 2, 4, 6 e 8 escondidas; cada
   conjunto contém o anterior.
2. Teste: compasso com 1 coluna → escondida já a 25%; com 3 → 1, 2, 3, 3.
3. Teste: a mesma música montada duas vezes, com `xml:id` diferentes nos
   eventos → os mesmos `(compasso, pauta, índice)` escondidos.
4. Teste: `hiddenAt(50, startMs:, endMs:)` de dois trechos vizinhos
   concorda no compasso compartilhado.
5. Teste: ornamento não vira coluna; nota ligada entra uma vez, com a
   continuação em `tiedIds`.
6. Teste: a tabela de saída da mistura para uma chave fixa está
   congelada no teste (trocar a função quebra o teste de propósito — muda
   o que cada aluno já decorou).
7. **(manual)** A medição de colunas por compasso está nas notas.
8. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
