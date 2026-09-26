# C01 — `ScorePlayer` com relógio plugável

**Repo:** verovio_flutter_bridge (`score_bridge/`) · **Depende de:** — ·
**Decisão necessária:** não

## Objetivo

Hoje o `ScorePlayer` avança sozinho somando `delta × speed` a cada frame do
`Ticker`. Com som, **quem manda é o relógio do áudio** (senão destaque e som
se afastam). Este passo deixa o relógio **plugável** sem mudar o
comportamento padrão: o player pode ler a posição de uma fonte externa a cada
frame, e ainda pode ficar **parado esperando** (modo espera do treino, T02).

## Ler antes (só isto)

- `score_bridge/lib/src/score_player.dart` (inteiro — ~360 linhas; o
  cabeçalho L1-L28 explica o desenho).
- `score_bridge/test/score_player_test.dart` (como os testes usam
  `advance` e `tester.pump`).

## Contexto que você precisa

- Estado atual: `_positionMs`, `_playing`, `_ticker`, `_lastElapsed`,
  `speed`. `play()` inicia o `Ticker`; `_onTick(elapsed)` →
  `advance(delta*speed)` → `_advanceToMs(ms)` aplica **todas** as entradas
  ultrapassadas (`_apply`: off → `controller.release`, on →
  `controller.highlightAll(..., hold: _kForever)`), depois `_publish()`
  (compasso, haste, página). No fim da peça, `pause()`.
- `seek(position)` recalcula do zero. `seekToElement(id, {pass})` existe.
- Regra do projeto: **nunca `DateTime.now()`**; testes usam tempo simulado.
- Desenho sugerido (mínimo e compatível):

  ```dart
  /// Fonte de posição musical, em ms. O player lê a cada frame.
  abstract class PlaybackClock {
    double get positionMs;             // posição musical atual
    bool get isRunning;
  }
  // ScorePlayer:
  PlaybackClock? clock;                // null = comportamento de hoje
  ```
  Com `clock != null`, `_onTick` ignora `delta` e chama
  `_advanceToMs(clock.positionMs)` quando a posição andou para frente; se a
  posição **voltou** (o host fez seek no áudio), chama o caminho do `seek`.
  `play()`/`pause()` do player continuam ligando/desligando o `Ticker` (o
  host coordena os dois). `speed` do player não é usado com relógio externo
  (a fonte já dá posição musical) — documente.
- Posição que anda para trás por jitter de poucos ms (relógio de áudio
  interpolado) **não** deve disparar seek: tolerância de 20 ms; abaixo disso,
  ignore.
- Um `ManualClock` (posição setável) nos testes serve de prova e de exemplo.

## O que fazer

1. `PlaybackClock`, `ScorePlayer.clock`, lógica acima; exportar em
   `score_bridge.dart`.
2. Comentário de cabeçalho do arquivo atualizado (seção RELÓGIO).
3. Testes com `ManualClock`.

## Fora de escopo

- Relógio de áudio de verdade (K04). Loop A-B (T04).

## Critérios de aceite

1. Todos os testes existentes do `score_bridge` passam **sem alteração**
   (comportamento padrão intacto).
2. Com `ManualClock`: avançar a posição em saltos irregulares acende o mesmo
   conjunto de ids que o caminho `advance` (reuse a comparação do critério 4
   de A05a).
3. Posição parada (clock não anda) por 100 frames: nada muda, sem exceção —
   é o modo espera.
4. Posição voltando 5 s: estado igual a `seek` para aquele instante.
   Voltando 10 ms: ignorado.
5. `flutter analyze` limpo.

## Notas de execução

**Implementado em 2026-09-25** (`verovio_flutter_bridge/score_bridge/`).
`PlaybackClock` (abstract, `positionMs`/`isRunning`) e `ScorePlayer.clock`
(nullable) em `score_player.dart`, exportado via `score_bridge.dart` (o
export em bloco já cobria, sem precisar listar o nome). `_onTick`: com
`clock` definido, ignora `elapsed`/`speed` e lê `clock.positionMs` a cada
tick — adiantou → `_advanceToMs` (mesmo caminho do `advance` de sempre);
recuou mais que 20 ms (tolerância) → `seek`; recuou até 20 ms (jitter do
relógio de áudio interpolado) ou ficou parado → nada, é o modo espera (T02).
`play`/`pause` continuam só ligando/desligando o `Ticker`, sem mudança —
desenho igual ao proposto.

**`ManualClock`** (`test/score_player_test.dart`): implementação mínima com
`positionMs`/`isRunning` mutáveis — prova do contrato e exemplo de uso, como
sugerido.

**Testes novos** (grupo "relógio plugável (C01)", 3 testes): (1) saltos
irregulares via `ManualClock` acendem o mesmo conjunto de ids que `advance`
direto na mesma peça — reusa o padrão de comparação de conjuntos do
critério 4 de A05a (`onEntry` coletando `e.on`), em vez de comparar
`highlightedIds` passo a passo; (2) posição parada por 100 frames não muda
destaque, compasso corrente nem posição — sem exceção; (3) recuo de 10 ms é
ignorado (< tolerância de 20 ms), recuo de 5 s refaz como `seek` — destaques
comparados com um segundo player que faz `seek` direto pro mesmo instante.

**`flutter test` (score_bridge)**: 325/325 verdes (era 322 antes: 3 testes
novos, nenhuma quebra nos existentes — critério 1). `flutter analyze` limpo
(critério 5).

**Fora de escopo, como previsto**: relógio de áudio de verdade fica para K04;
loop A-B fica para T04.
