# T04 — Calibração de latência, loop A-B, metrônomo

**Repo:** zywny · **Depende de:** T03 · **Decisão necessária:** não

## Objetivo

Os três acessórios que tornam o treino usável: (1) calibrar a latência de
entrada+saída por dispositivo; (2) repetir um trecho (compasso A até B);
(3) metrônomo com contagem inicial.

## Ler antes (só isto)

- `lib/audio/score_audio_scheduler.dart`, `AudioPlaybackClock` (K04),
  `lib/practice/` (T01-T03).
- `score_bridge/lib/src/score_timeline.dart`: `measures` (`MeasureInfo`:
  `id`, `startMs`, `endMs`, `pass`, `page`), `measureIndexAt`.
- `score_bridge/lib/src/score_player.dart`: `seek`, `seekToElement`.

## Contexto que você precisa

- **Calibração**: o app toca 8 cliques num andamento fixo (100 bpm) pelo
  `SoundEngine` ativo; o usuário aperta **qualquer tecla** do teclado MIDI
  junto com cada clique. Latência = mediana de (carimbo da tecla − instante
  agendado do clique), descartando os 2 primeiros. Isso mede
  saída+reação+entrada; como a reação humana sincronizada a um pulso
  regular tende a ser ~0 (antecipação), é o método usado por jogos de ritmo.
  Guarde por par (saída, dispositivo de entrada) e aplique como
  `inputLatency` no T03. Aviso se > 80 ms ("fone Bluetooth?").
- **Loop A-B**: selecionar compasso inicial e final (toque longo em uma nota
  → "início do loop", outro → "fim"; ou dois campos numéricos). Em ordem de
  execução, o trecho é `[measures[a].startMs, measures[b].endMs)`. Com
  repetições, `a`/`b` são **ocorrências** (`MeasureInfo.pass`) — escolha a
  ocorrência da posição atual (mesma regra D-TOQUE do bridge:
  `seekToElement`). Ao chegar em `endMs`: `allNotesOff`, seek para
  `startMs` (agendador + player), e — no treino — `session.resetTo`. Um
  intervalo de 1 compasso de contagem antes de recomeçar é opcional.
- **Metrônomo**: clique no canal 9 (percussão GM; nota 76 "Hi Wood Block"
  para tempo forte, 77 para os outros) agendado pelo mesmo agendador. As
  batidas vêm do compasso: o `.vsb` **não** tem fórmula de compasso
  explícita; derive dos `qstamp` do timemap (semínimas desde o início) e do
  `measureOn` (início de compasso) — batida a cada semínima (ou colcheia
  pontuada em 6/8: aceite semínima na 1.0 e registre). Com MIDI out, o
  canal 9 toca a percussão do piano digital, se ele tiver GM — senão, fica
  mudo (registre).
- **Contagem inicial**: 1 compasso de cliques antes do Play/Praticar, com a
  âncora deslocada (o musical fica parado em `startMs` durante a contagem).
- Mudança de `speed` durante o loop vale a partir da próxima volta
  (mais simples) — ou imediatamente com nova âncora; documente.

## O que fazer

1. Tela de calibração (acessível pelo seletor de dispositivos).
2. Loop A-B (UI + agendador + player + sessão).
3. Metrônomo + contagem inicial (liga/desliga).
4. Habilitar o botão "repetir os piores compassos" do resumo (T03).

## Fora de escopo

- Metrônomo com fórmulas compostas perfeitas; acentos por subdivisão.

## Critérios de aceite

1. Teste: loop de 2 compassos com `FakeSoundEngine` roda 3 voltas sem nota
   presa (todo note-on tem note-off antes do seek) e o player volta ao
   `startMs` a cada volta.
2. Teste: batidas do metrônomo coincidem com `qstamp` inteiros (±1 ms) na
   Gymnopédie (3/4).
3. **(manual)** Calibração no Linux com VMPK (via `just fake-midi
   --relay`) ou teclado dá número estável (3 execuções com diferença < 15 ms); registrar.
4. **(manual)** Treino em loop nos piores compassos a partir do resumo.
5. `just analyze` e `just test` limpos.

## Notas de execução

Feito (código + testes); critérios 3 e 4 (manuais) **pendentes**.

- **Loop A-B** — `ScoreAudioScheduler.setLoop/clearLoop`, `onLoop`. Ao
  horizonte do `pump` alcançar `endMs`, fecha a volta (note-offs cortados em
  `endMs`) e **reancora em `startMs` no instante de dispositivo em que
  `endMs` soa**: sem lacuna entre voltas e sem `allNotesOff` no meio (nada
  fica preso porque nenhum evento atravessa a fronteira). A âncora antiga
  fica em `_segments` até esse instante, para `positionMs` só recuar quando o
  som recua; o `ScorePlayer` percebe o recuo (>20 ms) e faz `seek` sozinho —
  não precisou mexer no bridge. Contagem entre voltas: não feita (opcional).
  Mudança de `speed` no loop vale **na hora** (reancora da posição atual).
  No treino (`PracticeController.setLoop`), passar do último passo do trecho
  repõe o agendador (`seek`) e a sessão (`resetTo`) e chama `onLoopRestart`
  (o host leva o player). UI: folha com dois controles (início/fim, por
  **ocorrência** em ordem de execução, igual ao "ir para o compasso") +
  "Atual". Toque longo em nota para marcar A/B **não** foi feito (o
  `ScoreView` não tem long-press; a alternativa dos campos numéricos vale).
- **Metrônomo** — `lib/audio/metronome.dart`: `metronomeBeats(timeline)`
  interpola o `qstamp` do timemap por compasso (uma batida por semínima, 1ª
  = forte; em 6/8 são semínimas — aceito). Canal 9, notas 76/77. Com saída
  MIDI para o piano, só soa se ele tiver percussão GM (senão mudo).
- **Contagem** — `play(fromMs, countIn: true)`: âncora 1 compasso antes,
  posição parada em `fromMs` (piso) e cliques nas batidas do compasso.
  Metrônomo e contagem só soam com o **som do app ligado** (o agendador é
  quem clica).
  Deixou de ser opção: play, tempo real e ritmo sempre começam com ela (o
  modo espera, em que o tempo espera o aluno, não). Por cima da partitura,
  `lib/practice/count_in_overlay.dart` mostra os tempos que faltam (4, 3,
  2, 1) em azul, esmaecendo a cada tempo; lê `ScoreAudioScheduler.countInTick`
  ou, no play sem som, a contagem muda da tela (só o número, sem cliques).
- **Calibração** — `lib/audio/latency_calibration.dart` (8 cliques a 100
  bpm, mediana sem os 2 primeiros, aviso >80 ms) + diálogo em
  `practice_tools.dart`, aberto por "Calibrar latência" no seletor de
  dispositivos (e na gaveta do celular). Guardada por (dispositivo de
  entrada, saída `app`/`midi`) em `MidiDeviceManager` e descontada dos
  carimbos no `PracticeController` (`inputLatencyMs`). O `RealtimeSession`
  (T03) não tem UI ainda; quando tiver, deve receber o mesmo valor.
- **"Repetir os piores compassos"** (item 4): habilitado no resumo do T03
  (`_repeatWorst` → `_setLoop` em `main.dart`).
- Testes: loop de 2 compassos × 3 voltas sem nota presa; batidas ±1 ms nos
  qstamp da Gymnopédie; contagem; mediana da calibração; reinício do loop no
  `PracticeController`.
