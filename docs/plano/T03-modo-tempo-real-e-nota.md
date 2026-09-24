# T03 — Modo tempo real com avaliação e resumo

**Repo:** zywny · **Depende de:** T02 · **Decisão necessária:** **D-TREINO**
(tolerâncias e o que conta como erro)

## Objetivo

O modo "tocar junto": a música anda no andamento escolhido, o aluno toca a
mão dele, cada nota recebe um veredito na hora (cor na partitura) e, ao fim,
um resumo (precisão, notas certas/erradas/perdidas, adiantado/atrasado médio,
compassos com mais erros).

## Ler antes (só isto)

- `lib/practice/practice_session.dart` (`RealtimeSession`, T01).
- `lib/practice/` do T02 (`PracticeController`, cores).
- `AudioPlaybackClock` e a âncora do agendador (K04).

## Contexto que você precisa

- Conversão da nota tocada para tempo musical (é aqui, não no T01):
  `musicalMs = musicalT0 + (played.atSeconds - inputLatency - deviceT0) *
  1000 * speed`. `played.atSeconds` é o carimbo de chegada no relógio do
  motor (M01). `inputLatency` vem da calibração (T04); até lá, 0.
- Com saída por MIDI (M03), o relógio é o `Stopwatch` do
  `MidiOutSoundEngine`; a fórmula é a mesma.
- `RealtimeSession.tick(musicalNowMs)` a cada frame (ex.: num listener do
  relógio) dispara os `missed`.
- Tolerâncias de D-TREINO (padrão: `correct` ±75 ms, `early/late` até
  ±150 ms, em ms de parede). Mostre adiantado/atrasado com cor diferente de
  errado (ex.: laranja).
- Resumo: `PracticeReport` (Dart puro, testável) agregando os vereditos por
  compasso (`ScoreTimeline.measures` / `measureIndexAt`, lembrando que um
  compasso repetido tem várias ocorrências — agregue por ocorrência e mostre
  pelo número do compasso). Mostre ao fim numa folha (`showModalBottomSheet`)
  com botão "repetir os compassos com mais erros" (que usa o loop de T04 —
  deixe o botão desabilitado até T04).
- Persistência de histórico por música: **fora** da 1.0, salvo se trivial
  (registre).

## O que fazer

1. Modo tempo real na UI (alternar espera/tempo real), vereditos → cores.
2. `PracticeReport` + folha de resumo.
3. Testes do relatório com vereditos sintéticos.

## Fora de escopo

- Calibração, loop, metrônomo (T04). Histórico.

## Critérios de aceite

1. Testes do `PracticeReport` verdes (contagens, médias, piores compassos,
   compasso repetido).
2. **(manual)** Gymnopédie mão direita a 0,75×: tocar bem → resumo com
   precisão alta; tocar errado de propósito um compasso → ele aparece como
   pior compasso.
3. `just analyze` e `just test` limpos.

## Notas de execução

(preencher)
