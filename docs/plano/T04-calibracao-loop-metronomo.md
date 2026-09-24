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
3. **(manual)** Calibração no Linux com VMPK/teclado dá número estável
   (3 execuções com diferença < 15 ms); registrar.
4. **(manual)** Treino em loop nos piores compassos a partir do resumo.
5. `just analyze` e `just test` limpos.

## Notas de execução

(preencher)
