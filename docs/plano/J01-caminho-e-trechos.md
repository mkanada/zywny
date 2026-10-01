# J01 — Caminho sem repetições e corte em trechos (Dart puro)

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** nenhuma
(regras em [J00](J00-trilha-de-estudo.md))

## Objetivo

Dada a linha do tempo de uma partitura, produzir (1) o **caminho** — a
música sem repetições, em compassos lógicos — e (2) o **corte** desse
caminho em trechos de N compassos com 1 de intersecção. Tudo Dart puro, sem
UI, sem áudio.

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Corte em trechos" e "Caminho".
- `score_bridge/lib/src/score_timeline.dart` L85-L140 (`MeasureInfo`: `id`,
  `pass`, `isJump`, `startMs`, `endMs`) e `measureIndexAt`.
- `lib/audio/metronome.dart` (como o comprimento do compasso sai do
  `qstamp` do timemap — é a fonte para saber se um compasso é incompleto).
- `test/practice_report_test.dart` (estilo dos testes com dados sintéticos).

## Contexto que você precisa

- `ScoreTimeline.measures` é a música expandida, em ordem de execução. O
  mesmo compasso aparece uma vez por passagem, com o mesmo `id` e `pass`
  1, 2, 3… `isJump` é `true` quando a ocorrência não continua a anterior em
  ordem de documento.
- O timemap **não** traz fórmula de compasso nem a marca `implicit` do
  MusicXML. Compasso incompleto se reconhece pela duração em semínimas
  (`qstamp`) menor que a do compasso cheio vizinho. `metronome.dart` já faz
  essa conta por compasso; extraia ou reuse, não duplique.
- O caminho é contíguo quando os índices das ocorrências escolhidas são
  consecutivos. Só nesse caso `[startMs do primeiro, endMs do último)` é um
  intervalo que o agendador toca direto.
- As duas partes do hino (P1, P2) chegam ao `PerformanceTrack` como pautas
  1 e 2 (convenção do N03). **Confirme** abrindo um hino: se P2 não for a
  pauta 2, registre nas notas — afeta J03 e J04.

## O que fazer

1. `lib/trail/trail_path.dart`:
   - `PathMeasure {occurrence (índice em measures), startMs, endMs}`.
   - `LogicalMeasure {measures: List<PathMeasure>, startMs, endMs, number}`
     — um ou mais `PathMeasure` grudados (anacruse, compasso partido).
     `number` é o que a tela mostra (1-based, contando compassos lógicos).
   - `TrailPath {logical: List<LogicalMeasure>, jumps: List<int>}` —
     `jumps` são os índices de compasso lógico **antes** dos quais há um
     salto. `isContiguous => jumps.isEmpty`.
   - `TrailPath.fromTimeline(ScoreTimeline)` com as regras do J00:
     primeira ocorrência de cada `id`; descartar casas não finais; grudar
     incompletos.
2. `lib/trail/trail_segments.dart`:
   - `TrailSegment {index, first, last}` (índices de compasso lógico,
     inclusivos), com `startMs`/`endMs` tirados do caminho.
   - `List<TrailSegment> cutSegments(TrailPath path, int n)` com a fórmula
     do J00. `n < 3` é erro de programação (`assert`); a UI nunca manda.
   - Enquanto o J08 não existir, um trecho **não** atravessa um salto: se o
     caminho não é contíguo, `cutSegments` devolve lista vazia e a trilha
     fica indisponível (o J08 remove essa regra).
3. Ferramenta de medição, fora do app: `tool/trail_stats.dart` (ou um teste
   marcado `@Tags(['manual'])`) que gera o `.vsb` de cada hino e imprime,
   por hino: compassos, compassos lógicos, `isContiguous`, número de
   saltos, quantos compassos incompletos e onde. Rode nos 600 e ponha os
   totais nas notas de execução.

## Fora de escopo

- Tocar um caminho com saltos (J08).
- Persistência, etapas, UI.
- Tocar as repetições.

## Critérios de aceite

1. Teste: caminho sintético `X |: A B :|` ×3 (ocorrências
   `X A1 B1 A2 B2 A3 B3`) → caminho `X A B`, contíguo, 3 compassos lógicos.
2. Teste: `|: A B [1 C] :| [2 D] E` (ocorrências `A1 B1 C A2 B2 D E`) →
   caminho `A B D E`, um salto antes de `D`, `C` fora.
3. Teste: `|: A :| |: B :|` → caminho `A B` com um salto antes de `B`.
4. Teste: anacruse (primeiro compasso com metade da duração) → gruda no
   seguinte; `number` 1 cobre os dois.
5. Teste de corte, tabela: (M=8,N=3) → `[0-2][2-4][4-6][6-7]`; (M=7,N=3) →
   `[0-2][2-4][4-6]`; (M=16,N=5) → `[0-4][4-8][8-12][12-15]`; (M=4,N=5) →
   `[0-3]`; (M=20,N=20) → `[0-19]`; (M=21,N=20) → `[0-19][19-20]`.
6. Teste: `erik-satie.vsb` e `maple-leaf-rag.vsb` (fixtures) → caminho sem
   exceção; registre nas notas se são contíguos.
7. **(manual)** A medição dos 600 hinos está nas notas: quantos têm caminho
   contíguo, quantos têm salto, e os casos de compasso incompleto que não
   são anacruse.
8. `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
