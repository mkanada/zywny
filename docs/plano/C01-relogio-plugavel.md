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

(preencher)
