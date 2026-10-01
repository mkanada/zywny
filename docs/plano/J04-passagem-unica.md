# J04 — `PracticeController`: passagem única de um intervalo, com resultado

**Repo:** zywny · **Depende de:** J02 · **Decisão necessária:** nenhuma

## Objetivo

Hoje um intervalo de compassos só existe como **loop** que dá voltas até o
aluno parar. A trilha precisa de outra coisa: tocar `[startMs, endMs)`
**uma vez**, parar sozinho no fim e entregar um `StageResult` — nos três
modos, inclusive no modo espera (que hoje não tem resumo).

## Ler antes (só isto)

- [J00](J00-trilha-de-estudo.md): "Etapas de um trecho" e "Aprovação".
- `lib/practice/practice_controller.dart` inteiro (562 linhas): `start`
  L153, `setLoop` L176, `_restartLoop` L196, `_tick` L248, `finish` L272,
  `stop` L282, `_onVerdict` L433, `_onStepChanged` L522.
- `lib/audio/score_audio_scheduler.dart`: `setBrake`, `setLoop`, `play`,
  `pump` (o freio já limita a posição **e** o que é agendado).
- `lib/trail/stage_result.dart` (do J02: `StageResult`, `WaitTally`).
- `test/practice_controller_test.dart` (relógio simulado, como dirigir o
  controlador sem hardware).

## Contexto que você precisa

- O loop e a passagem única são mutuamente exclusivos. Acrescente a
  passagem única sem mudar o comportamento do loop — o modo livre continua
  usando-o.
- **Fim do intervalo**:
  - Espera: o passo pendente passa a ter `onMs >= endMs` (ou a sessão
    acaba). É o mesmo ponto em que `setLoop` hoje chama `_restartLoop`.
  - Tempo real e ritmo: a posição chega a `endMs`. O que faltou vira
    `missed` (como `finish` faz), com a folga `_slackMs` para o último
    toque ainda poder casar.
- **A mão do app não pode passar de `endMs`**: o agendador não deve soar
  nada além do intervalo. O freio (`setBrake`) já capa posição e agenda;
  avalie reusá-lo como teto no modo com tempo, ou um `stopAt` próprio no
  agendador. Nenhuma nota presa: `allNotesOff` no fim (risco 4 do README).
- **Início no meio da música**: `start(fromMs:, countIn:)` já existe e as
  sessões têm `resetTo(ms, untilMs:)`. No modo espera, notas de antes de
  `startMs` não entram.
- **Andamento**: o degrau é o `speed` do agendador (0,5 / 0,75 / 1,0). O
  host ajusta antes de criar o controlador, como já faz com `_speed`.
- **Resultado**:
  - Tempo real / ritmo: `StageResult.fromReport(report, rhythm:)`.
  - Espera: ligue um `WaitTally` a `currentStep` (`stepStarted`/`stepDone`)
    e aos vereditos `wrong`. O compasso do passo sai de
    `measureIndexAt(step.onMs)`.
- O `PracticeController` é descartado e recriado a cada sessão; não precisa
  de "reiniciar" interno.

## O que fazer

1. `PracticeController`: parâmetro opcional de intervalo de passagem única
   (ex.: `range: (startMs, endMs)`) e `onRangeDone` (chamado uma vez,
   quando o intervalo termina por conta própria). `start` começa em
   `startMs`.
2. `StageResult? get stageResult` — válido depois do fim do intervalo ou de
   `finish()`. Parar no meio (`stop` antes do fim) dá resultado com o que
   foi avaliado até ali; a tela decide o que fazer com ele (J05 trata como
   tentativa abandonada, sem registrar).
3. Teto de áudio em `endMs` (ver contexto) e silêncio garantido ao fim.
4. Testes novos em `test/practice_controller_test.dart`.

## Fora de escopo

- Qualquer UI. Quem chama é o J05.
- Intervalo com salto no meio (J08).
- Mudar o loop A-B.

## Critérios de aceite

1. Teste, espera: intervalo de 2 compassos no meio da Gymnopédie, pauta 1,
   tocando tudo certo → `onRangeDone` chamado uma vez, resultado 100%, e o
   passo seguinte ao intervalo **não** é cobrado.
2. Teste, espera: a mesma passagem com uma tecla errada antes de um dos
   passos → esse passo não conta como acerto e o compasso dele está em
   `badMeasures`.
3. Teste, tempo real: intervalo tocado no tempo → 100% e `onRangeDone`
   depois de `endMs` + folga; sem tocar nada → 0%, todos `missed`, e
   **nenhum** `missed` de fora do intervalo.
4. Teste, ritmo: toques no tempo com pitches quaisquer → 100%; com um
   toque extra numa pausa → abaixo de 100% (extra conta).
5. Teste: com a mão do app ativa, nenhum evento com `onMs >= endMs` é
   agendado no motor falso, e há `allNotesOff` no fim.
6. Teste: os testes de loop já existentes continuam passando sem mudança.
7. `just analyze` e `just test` limpos.

## Notas de execução (J04, 2026-10-01)

Implementado em `lib/practice/practice_controller.dart`: `range`
(`startMs`/`endMs`), `onRangeDone` (uma vez), `stageResult`
(J02: `WaitTally` no espera, `fromReport` com tempo/ritmo) e teto de áudio
em `endMs` (`ScoreAudioScheduler.setStopAt/clearStopAt`: nada com
`onMs >= endMs` é agendado e os `offMs` são cortados, mas a posição corre
até `endMs + folga` para o último toque casar). Testes novos em
`test/practice_controller_test.dart` (6, todos os critérios 1–5; os de
loop passam sem mudança — critério 6).

- Espera: `resetTo(startMs)` no `start`; fim quando o pendente tem
  `onMs >= endMs` (ou a sessão acaba). `WaitTally` ligado a `currentStep`
  (`stepStarted`/`stepDone`) e aos `wrong`. Dois bugs achados nos testes:
  tecla repetida entre passos exige soltar (soltar após cada passo) e a
  republicação do passo a cada nota certa não conta como avanço (só a
  troca de índice).
- Tempo real/ritmo: `resetTo(startMs, untilMs: endMs)`; `_tick` fecha em
  `endMs + folga` (o que faltou vira `missed`) e termina sozinho.
- `stop` no meio dá o parcial avaliado; a tela trata como abandono (J05).
- `just analyze` e `just test` limpos.
