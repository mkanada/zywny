# K04 — Agendador da partitura + botão Play com som, relógio do áudio

**Repo:** zywny · **Depende de:** K03, N03, C01 · **Decisão necessária:** não

## Objetivo

Apertar Play toca a partitura pelo sintetizador, com o destaque das notas e a
virada de página **dirigidos pelo relógio do áudio**. Pause, Stop, seek
(tocar numa nota) e `speed` funcionam sem nota presa e sem deriva.

## Ler antes (só isto)

- `lib/main.dart` L212-L339 (`_renderAndShow` cria o `ScorePlayer`;
  `_togglePlay`, `_stop`, `_onEntry`).
- `lib/music/performance_track.dart` (N03), `lib/audio/sound_engine.dart`
  (K03).
- `score_bridge/lib/src/score_player.dart`: a parte de `PlaybackClock` (C01)
  e `seekToElement` (L269).

## Contexto que você precisa

- **Duas escalas de tempo**: musical (ms da partitura, `PerformanceTrack`) e
  do dispositivo (segundos de `SoundEngine.nowSeconds`). A âncora
  `(deviceT0, musicalT0, speed)` converte:
  `musical(t) = musicalT0 + (t - deviceT0) * 1000 * speed` e o inverso. Toda
  mudança (play, seek, troca de speed) cria âncora nova.
- **Agendador (`lib/audio/score_audio_scheduler.dart`)**: um `Timer.periodic`
  de ~25 ms (não precisa de precisão — a precisão é do motor) mantém a agenda
  preenchida até `agora + 250 ms` (constante `lookahead`). A cada tick:
  `track.startingIn(ultimoAgendado, alvo)` → para cada evento, `NoteOn` em
  `at(onMs)` e `NoteOff` em `at(offMs)` (note-off um pouco antes, `-1 ms`,
  para a mesma tecla religada não cortar a nova). Program Change por canal
  no início de cada play (`0xC0 | ch`).
  - Eventos cujo `at` < `earliestScheduleSeconds` (tick atrasado, GC): toque
    no `earliest` — nunca descarte o note-on e **nunca** o note-off.
  - Eventos com `offMs` além do alvo: guarde os note-offs pendentes num mapa
    `(ch, pitch) → at` e agende quando entrarem na janela (ou agende logo —
    o motor aceita futuro distante; escolha e justifique).
- **Pause/stop/seek/speed**: `engine.allNotesOff()` (limpa a agenda), nova
  âncora, recomeça a janela a partir da nova posição. No seek, notas que
  **já estavam soando** no ponto novo **não** são religadas (comportamento
  comum de sequenciador; registre se mudar).
- **Relógio para o `ScorePlayer`**: `AudioPlaybackClock implements
  PlaybackClock` com `positionMs = musical(engine.nowSeconds)` (se tocando),
  ou a posição congelada (se pausado). `player.clock = audioClock`. Como
  `nowSeconds` já desconta a latência de saída, o destaque acende quando o som
  **sai**, não quando é calculado.
- **Fim da peça**: quando `positionMs >= track.durationMs + release`, pare
  tudo (o `_onEntry` atual já para o player — mantenha coerente).
- `speed` na UI: se não existir controle, adicione um simples (0,5×-1,5×)
  perto do Play; o `ScorePlayer.speed` não é usado com relógio externo (C01).
- Repetições: o `PerformanceTrack` já está em ordem de execução (ids
  `-rend<N>`), nada especial.
- Tocar numa nota (`seekToElement`) move o player: o host precisa refletir
  no agendador. Hoje o `ScorePlayer` não avisa o host do seek; o jeito mais
  simples é o host fazer o seek (chamar agendador e player juntos) — veja
  onde `onElementTap` está ligado em `main.dart` (`_buildScoreArea`).

## O que fazer

1. `ScoreAudioScheduler` (Dart puro, recebe `SoundEngine` e
   `PerformanceTrack`; testável com um `FakeSoundEngine` que só registra).
2. `AudioPlaybackClock`.
3. Ligação em `main.dart`: criar motor (K03), passar clock ao player, Play /
   Pause / Stop / seek / speed chamando os dois. Um interruptor "som" (liga/
   desliga o agendador) para manter o modo mudo de hoje.

## Fora de escopo

- MIDI out (M03, usará o mesmo agendador com outro `SoundEngine`).
- Loop A-B e metrônomo (T04).

## Critérios de aceite

1. Testes com `FakeSoundEngine` + relógio falso: a peça inteira da
   Gymnopédie agenda exatamente um note-on e um note-off por evento do track,
   com `at` correto (±1 ms) a `speed` 1.0 e 0.5.
2. Teste: pause no meio → `allNotesOff` chamado; nenhum evento agendado
   depois até o play.
3. Teste: seek para trás e para frente → nenhum note-on duplicado da mesma
   tecla sem note-off entre eles.
4. **(manual)** Linux: tocar a Gymnopédie e o Maple Leaf Rag inteiros: som e
   destaque juntos a olho e ouvido; repetição toca a 2ª passagem; pause/play
   repetidos rapidamente não deixam nota presa.
5. **(manual)** Medida de deriva: ao fim do Maple Leaf Rag, a diferença
   entre a posição do player e o tempo musical do último evento audível é
   < 30 ms (registre como mediu — ex.: log de `positionMs` vs. `onMs` do
   último evento).
6. `just analyze` e `just test` limpos.

## Notas de execução

(preencher)
