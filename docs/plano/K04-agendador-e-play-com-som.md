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

- `lib/audio/score_audio_scheduler.dart` (`ScoreAudioScheduler`) e
  `lib/audio/audio_playback_clock.dart` (`AudioPlaybackClock`), como
  planejado. `ScoreAudioScheduler` expõe `pump()` público em vez de manter o
  tick só interno: com `autoTick: false` (usado pelos testes) nenhum
  `Timer.periodic` de verdade é criado — os testes chamam `pump()` direto,
  avançando `FakeSoundEngine.now` manualmente, sem depender de tempo real
  nem de `fake_async` (não é dependência do projeto).
- Note-off pendente além da janela: em vez do mapa `(ch,pitch) → at`
  sugerido como alternativa, cada evento agenda seu par on/off **junto**,
  no mesmo `pump()` em que `onMs` entra na janela — mesmo que `offMs` caia
  bem além do `lookahead`. Já temos os dois instantes prontos no
  `SoundEvent` (`PerformanceTrack` já funde ligadura), e K02 documenta que o
  motor aceita agendamento bem no futuro; o mapa só adicionaria estado sem
  ganhar nada.
- Program Change (`0xC0 | canal`) só é reenviado em `play()`, não em
  `seek()`/`setSpeed()`: `Command::AllNotesOff` no motor nativo
  (`native/zywny_audio/src/engine.rs`) manda `0xB0,123,0`/`0xB0,64,0` por
  canal, mas não mexe no patch do canal — reenviar a cada seek seria
  redundante.
- **Limitação encontrada no motor nativo (K01-K03), fora do escopo Dart
  deste passo**: `render_block` (`native/zywny_audio/src/engine.rs:118`)
  chama `synth.process_midi_message(0, e.msg[0], ...)` com o canal
  **fixo em 0**, e `rustysynth::Synthesizer::process_midi_message` espera
  o parâmetro `command` **sem** o nibble de canal (`0x90`, não `0x90|ch`) —
  hoje só o canal 0 realmente soa; qualquer nota com canal ≠ 0 não bate em
  nenhum case do `match` e é silenciosamente ignorada. Não afeta os
  critérios manuais (Gymnopédie e Maple Leaf Rag só usam o canal 0 —
  conferido lendo os dois `.vsb` de teste), então não bloqueia K04, mas
  bloqueia qualquer peça futura com canais diferentes de 0 e deveria virar
  um item separado (arrumar `render_block` para separar canal de comando,
  ou o Dart parar de OR'ar o canal no status byte).
- Sobreposição real de mesma tecla no próprio corpus: `maple-leaf-rag.vsb`
  tem 2 pares de eventos (pitch 65 e 73, por volta de 133,35–133,65 s) cuja
  janela `[onMs, offMs)` já se sobrepõe na fonte (resolução de ornamento
  antes do fim da nota anterior) — o agendador não tem como evitar um 2º
  note-on antes do note-off do 1º nesses casos pontuais (é uma limitação de
  representar duas vozes na mesma tecla/canal MIDI, não um bug do
  agendador). O teste de seek (critério 3) contabiliza isso a partir do
  próprio `PerformanceTrack`, não com um número fixo.
- UI (`lib/main.dart`): interruptor "som" (`_soundOn`, ícone
  volume_up/volume_off) e um `Slider` de velocidade (0,5×–1,5×) ao lado do
  Play/Stop, como pedido. O motor (`createSoundEngine`, K03) só é aberto na
  primeira vez que o som é ligado, e como não há soundfont embutida (D-SF
  segue em aberto — o próprio `SoundEngineDebugPanel` já tinha essa
  decisão pendente), ligar o som pede um `.sf2` por `file_selector`,
  reaproveitando o motor já aberto nas vezes seguintes. Toque numa nota
  (`onElementTap`, ainda não ligado antes de K04) chama
  `player.seekToElement` e replica a posição resultante no agendador.
- `just analyze` e `just test` limpos (critério 6). Critérios 4 e 5
  (manual: ouvir a Gymnopédie/Maple Leaf Rag no Linux e medir a deriva) não
  foram executados nesta sessão — pendente de verificação manual com um
  dispositivo de áudio e um `.sf2` à mão.
