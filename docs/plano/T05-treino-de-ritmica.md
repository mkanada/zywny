# T05 — Treino de rítmica (qualquer tecla, no ritmo da partitura)

**Repo:** zywny · **Depende de:** T01 (casador), T03 (tempo real na UI),
T04 (metrônomo, contagem, calibração) · **Decisão necessária:** **D-RITMO**
(janelas, cobrar duração, som do toque)

## Objetivo

Um quarto modo de treino, "Ritmo": a música anda no andamento escolhido e
o aluno aperta **qualquer tecla** no instante de cada ataque da mão dele. O
pitch não importa, só o tempo. Cada ataque recebe veredito na hora (cor no
acorde inteiro na partitura) e, ao fim, um resumo com tendência de
correr/arrastar e regularidade.

A parte 1 (`RhythmSession`, Dart puro) não depende de T03/T04 e pode ser
feita já; as partes 2-3 (UI, som, resumo) entram depois do T03, e o modo só
fica usável de verdade com o metrônomo e a contagem inicial do T04.

## Ler antes (só isto)

- `lib/practice/practice_session.dart`: `WaitModeSession.forStaves` (fusão
  de acordes por `onMs`), `RealtimeSession` (janelas × `speed`, `tick`,
  `resetTo`) e `NoteVerdict`.
- `lib/practice/practice_controller.dart` (ligação sessão ↔ MIDI ↔
  agendador ↔ cores).
- `lib/midi/midi_monitor.dart` (o monitor que toca a tecla apertada).
- `docs/plano/T03-modo-tempo-real-e-nota.md` (conversão para ms musicais,
  `PracticeReport`) e `docs/plano/T04-calibracao-loop-metronomo.md`.

## Contexto que você precisa

- **Unidade de avaliação = onset (ataque), não nota.** Os alvos são os
  `onMs` distintos dos acordes das pautas do aluno — a mesma fusão de
  `WaitModeSession.forStaves` (acordes de pautas diferentes no mesmo `onMs`
  viram um alvo só). Um acorde de 3 notas pede **um** toque.
  - Nota ligada não gera onset novo (N03 já trata). Ornamentos
    (`SoundEvent.ornament`) não viram alvo (D-TREINO); se um onset só tem
    ornamento, ele some.
- **Debounce de acorde**: toques a menos de `chordDebounceMs` (padrão 45 ms
  de parede) do toque anterior que casou são o **mesmo** toque — quem
  aperta o acorde inteiro, ou "arpejado" de leve, não leva `extra`. O
  debounce vale só depois de um toque que casou; toques soltos sem alvo são
  `extra` cada um.
- **Casamento**: para cada toque (já em ms musicais), candidato = alvo
  pendente mais próximo com `|delta| ≤ janelaMax`. `≤ janelaOk` →
  `correct`; senão `early`/`late`. Sem candidato → `extra` (ex.: bater
  durante uma pausa). Alvo cujo `onMs + janelaMax` passou sem toque →
  `missed`, via `tick(musicalNowMs)`. Janelas em ms **de parede**,
  convertidas para musicais multiplicando por `speed`, como no
  `RealtimeSession`.
- **Veredito**: `RhythmVerdict {onsetIndex, onMs, eventIds (todas as notas
  do onset, para pintar o acorde inteiro), kind: correct|early|late|missed|extra,
  deltaMs, velocity}`. `extra` não tem `onsetIndex`/`eventIds`. Não reusar
  `NoteVerdict` (tem um `eventId` e um `pitch` só — semântica errada aqui).
- **Relógio**: a conversão tocada → musical é a mesma fórmula do T03
  (`musicalT0 + (atSeconds - inputLatency - deviceT0) * 1000 * speed`), na
  camada de cima. A calibração do T04 já é "qualquer tecla junto com o
  clique" — mesma mecânica deste modo, então aqui a latência pesa mais que
  no treino de notas: sem calibração, avise na UI.
- **Mãos**:
  - Uma mão: alvos = onsets da pauta do aluno; o app toca a outra
    (`scheduler.setStaves(hand.appStaves)`), como hoje.
  - Ambas, ritmo composto: alvos = união dos onsets das duas pautas.
  - Ambas, **teclado dividido** (opcional nesta etapa, recomendado): teclas
    abaixo do Dó central (pitch < 60) respondem pela pauta de baixo e as
    demais pela de cima — duas `RhythmSession`, uma por zona. Treina a
    independência das mãos. Ponto de divisão configurável é fora de escopo.
- **Som do toque** (D-RITMO; padrão recomendado: a):
  - (a) "piano mágico": o toque que casa soa as **notas esperadas** do
    onset (canal do monitor), soltas no note-off da tecla; `extra` soa
    nada (ou um clique abafado).
  - (b) percussão fixa no canal 9 (ex.: nota 37, side stick).
  - (c) a tecla real, como o `MidiMonitor` faz hoje.

  Em (a)/(b) o `MidiMonitor` fica desviado neste modo. Com saída MIDI para
  piano digital (M03), o piano soa a tecla real de qualquer jeito, a menos
  que o usuário ligue o *Local Off* — registre e mostre uma dica.
- **Duração** (note-off vs `offMs`): **não** cobrada nesta etapa. Exponha
  `release(musicalMs)` na sessão já como no-op documentado, para a opção
  "articulação" futura não mudar a API.
- **UI**: `PracticeMode.ritmo` no enum (`ouvir | espera | tempoReal |
  ritmo`), rótulo "Ritmo", selo "Ritmo · mão dir.". Por dentro, é o fluxo do
  tempo real com a `RhythmSession`. Não existe "espera + só ritmo" (qualquer
  tecla avançaria — sem sentido). Cores: as mesmas do T03 (certo / laranja
  para adiantado-atrasado / perdido); `extra` não pinta a partitura, só
  conta no contador e pisca o indicador de toque.
- **Resumo**: o `PracticeReport` do T03 ganha, para este modo: precisão,
  **delta médio** (tendência: "você corre ~25 ms"), **desvio-padrão**
  (regularidade), contagens por tipo, piores compassos (mesma agregação por
  ocorrência do T03). Botão "repetir os piores compassos" usa o loop do
  T04.
- Loop (T04): `resetTo(musicalMs)` como nas outras sessões.

## O que fazer

1. `lib/practice/rhythm_session.dart`: `RhythmSession` (`forStaves`,
   `hit`, `release` no-op, `tick`, `resetTo`, `dispose`, stream
   `broadcast(sync: true)` como as outras), `RhythmVerdict`,
   `RhythmVerdictKind`. Testes em `test/practice_session_rhythm_test.dart`.
2. Controlador: `RhythmPracticeController` (ou o `PracticeController` com
   uma estratégia — decidir ao ver o T03 pronto), ligando MIDI → conversão
   de relógio → sessão → cores + som do toque; desvio do monitor.
3. `PracticeMode.ritmo` na UI (seletor, selo, contadores) e as métricas de
   ritmo no `PracticeReport`.
4. (opcional) Teclado dividido para "ambas".

## Fora de escopo

- Cobrar duração/articulação (fica o `release` no-op).
- **Entrada sem teclado MIDI** (toque na tela, barra de espaço, palmas pelo
  microfone) — como o pitch não importa, abre o modo para quem só tem o
  celular; pós-1.0, exige calibração por tipo de entrada.
- **Modo eco**: o app toca um compasso, o aluno repete no seguinte;
  avaliação por intervalos entre ataques normalizados (perdoa andamento,
  cobra proporções). Pós-1.0.
- Visão rítmica em linha única (pauta de percussão).

## Critérios de aceite

1. Teste: Gymnopédie (pauta 1) "perfeita", toques gerados dos onsets com
   ruído gaussiano σ=20 ms e **pitches aleatórios** → ≥ 99% `correct`,
   0 `extra`.
2. Teste: acorde de 3 notas tocado como 3 teclas em 30 ms → 1 veredito
   `correct` com os 3 `eventIds`, 0 `extra`; as mesmas 3 teclas espalhadas
   em 200 ms → 1 casamento + `extra`s.
3. Teste: pular um compasso → exatamente os onsets desse compasso como
   `missed`; toque no meio de uma pausa longa → 1 `extra`.
4. Teste: `speed` 0.5 com deltas na fronteira das janelas (como o critério
   5 do T01).
5. Teste: onset só de ornamento não vira alvo; ligadura não gera onset.
6. Teste: métricas de ritmo do `PracticeReport` (delta médio, desvio,
   piores compassos) com vereditos sintéticos.
7. **(manual)** Gymnopédie mão direita a 0,75×, com contagem e metrônomo:
   batendo sempre a mesma tecla, no tempo → precisão alta e acordes
   pintados inteiros; correndo de propósito → o resumo mostra delta médio
   negativo.
8. `just analyze` e `just test` limpos.

## Notas de execução

- `RhythmSession` (`lib/practice/rhythm_session.dart`): janelas 60/130 ms de
  parede (padrão recomendado da D-RITMO), debounce de acorde 45 ms só após
  toque que casou; `release` é no-op. Critérios 1-6 cobertos em
  `test/practice_session_rhythm_test.dart`; ligação de ponta a ponta em
  `test/practice_controller_test.dart`.
- Controlador: `PracticeController` com `PracticeMode.rhythm` (estratégia
  dentro do mesmo controlador, reaproveitando tick/loop). Piano mágico via
  `magicEngine` (canal do monitor); `MidiMonitor.muted` desvia a tecla real
  durante o treino. `extra` conta em `wrongCount` e sobe `extraBlink`.
- `PracticeReport.rhythm`: `extra`, `stdDevMs`, delta médio; o resumo mostra
  "toques extras" e a regularidade. UI: o botão de modo cicla
  espera → tempo real → ritmo; a gaveta do celular ganhou "Ritmo"; selo
  "Ritmo · mão dir.".
- Pendente: critério 7 (manual, no aparelho); teclado dividido (item 4,
  opcional) não feito; aviso de "sem calibração" e dica de *Local Off* na UI
  não feitos; o `PracticeMode` do mockup (`lib/mockup/practice_state.dart`)
  não ganhou "Ritmo".
