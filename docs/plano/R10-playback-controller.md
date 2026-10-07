# R10 — `PlaybackController`

**Repo:** zywny · **Depende de:** R09 · **Decisão necessária:** não

## Objetivo

Terceiro passo do achado 5 da revisão. Tocar a partitura — player,
agendador, relógio do áudio, contagem, loop, metrônomo, andamento, seek —
sai da tela para um `ChangeNotifier`. É o controller que liga a gravura
(R09) ao som (R08).

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 5.
- [R08](R08-sound-output-controller.md) e [R09](R09-score-render-session.md):
  as notas de execução.
- `lib/main.dart` nos trechos abaixo (linhas do commit `fac579c`; confira
  com `graft skeleton lib/main.dart` antes).

## Contexto que você precisa

- Estado (L240–L355): `_controller` (`ScoreController`), `_ghosts`,
  `_player`, `_playing`, `_track`, `_scheduler`, `_audioClock`, `_loop`,
  `_silentCountInTimer`, `_silentCountIn`, `_silentCountInEngine`,
  `_inputLatencyMs`, `_speed`, `_metronomeOn` (getter sobre `_settings`).
- Métodos: `_setPlaying` L1551, `_togglePlay` L1556, `_startSilentCountIn`
  L1597, `_playPlayerAfterCount` L1652, `_cancelSilentCountIn` L1675,
  `_stop` L1689, `_restart` L1711, `_seekTo` L1738, `_onEntry` L1924,
  `_setSpeed` L1946, `_attachAudio` L1969, `_toggleMetronome` L1988,
  `_applyLoop` L2007, `_setLoop` L2039, `_loadInputLatency` L2051; e a parte
  de `_toggleSound` (agora no R08) que pausa o agendador e troca o relógio.
- O player é recriado a cada gravura nova (vem da sessão do R09); o
  agendador também, um por `.vsb`. O motor sobrevive (é do R08).
- O modo treino (`_togglePractice` L1762 … `_stopPractice` L1916) usa o
  player e o agendador, mas **fica na tela** neste passo.

## O que fazer

1. `lib/app/playback_controller.dart` (`ChangeNotifier`): recebe a
   `SoundOutputController`, as `AppSettings` e um relógio (para o teste,
   como o `PlaybackClock` do C01); `attach(document, track)` a cada
   gravura; expõe `player`, `playing`, `speed`, `loop`, `countIn` e as
   ações acima.
2. A tela deixa de criar `ScorePlayer`/`ScoreAudioScheduler`; o modo treino
   pega o player e o agendador do controller.
3. `test/playback_controller_test.dart` com relógio simulado e
   `FakeSoundEngine`: play/stop, contagem muda sem som, loop A-B volta ao
   início, trocar o motor durante o play não perde a posição.

## Fora de escopo

Treino e trilha (R11). Mudar o tempo da contagem ou do loop.

## Critérios de aceite

1. Nenhum `ScorePlayer(` nem `ScoreAudioScheduler(` em `main.dart`.
2. `just analyze` e `just test` limpos, com o teste novo.
3. No app, com som e sem som: play, pausa, loop, metrônomo, contagem,
   mudar o andamento tocando **(manual)**.

## Notas de execução

