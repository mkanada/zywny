# T02 — Modo espera + escolha de mão + app toca a outra

**Repo:** zywny · **Depende de:** T01, K04, M01 · **Decisão necessária:** não

## Objetivo

A primeira experiência de treino completa: o aluno escolhe a mão (direita,
esquerda, ambas), o app toca a outra mão, a partitura **para** em cada acorde
da mão do aluno até ele acertar, e as notas mudam de cor (certa/errada).

## Ler antes (só isto)

- `lib/practice/practice_session.dart` (T01).
- `lib/audio/score_audio_scheduler.dart` e `AudioPlaybackClock` (K04).
- `score_bridge/lib/src/score_controller.dart`: API de cor por id (procure
  `setColor`/`highlight`/`clearHighlights` — confira os nomes reais com
  `grep -n "void " score_bridge/lib/src/score_controller.dart`).
- `lib/main.dart` `build` e a barra do Play.

## Contexto que você precisa

- **Relógio no modo espera**: o `AudioPlaybackClock` ganha um "freio": antes
  de cruzar o `onMs` do próximo passo pendente, a posição **para** ali (o
  clock devolve `min(posição, onMs do passo pendente)`) e o agendador **não
  agenda** além desse ponto (os eventos da outra mão também esperam). Quando
  o passo conclui, nova âncora a partir daquele `onMs` e segue. Isso é o
  C01 critério 3 (posição parada) usado de verdade.
- Eventos da mão do app que começam **no mesmo instante** do passo do aluno
  tocam quando o aluno acerta (juntos), não antes.
- Filtro de mão no agendador: `track.startingIn(..., staves: appStaves)`.
  Com "ambas as mãos" o app não toca nada (só metrônomo, T04).
- Cores (defina constantes num lugar só): esperado agora = cor de destaque
  atual (amarelo do player); certo = verde; errado = vermelho **piscando** na
  nota esperada mais próxima (a nota errada não existe na partitura);
  concluído = volta à cor normal com fade. Use as animações do
  `ScoreController` (release com duração) — não crie outro motor.
- Nota errada também pode ser mostrada no teclado desenhado de M01 (vermelho
  na tecla tocada), o que é mais claro que na partitura.
- Passo com mais de uma pauta ("ambas"): todas as notas das duas mãos no
  mesmo onset formam um passo (T01).
- Piano digital: o aluno ouve o próprio teclado; o app só toca a outra mão.
  Controlador sem som: M02 (monitor) ligado.
- Botões: Play vira "Praticar" quando um dispositivo MIDI está conectado
  e o modo treino está ativo; seletor de mão ao lado.

## O que fazer

1. Modo treino na UI (mão, iniciar/parar), `PracticeController` que liga
   `MidiInputService` → `WaitModeSession` → cores + freio do relógio +
   agendador filtrado.
2. Teste de widget com `FakeMidiInput` e `FakeSoundEngine`: tocar as notas
   certas avança a posição do player; errada não avança.

## Fora de escopo

- Tempo real e pontuação (T03). Loop/metrônomo (T04).

## Critérios de aceite

1. Teste de widget do item 2 verde.
2. **(manual, Linux, VMPK via `just fake-midi --relay` ou teclado)**
   Gymnopédie mão direita: o app toca a esquerda, espera cada nota da direita, cores corretas; nota errada
   aparece em vermelho e não avança.
3. **(manual)** Virada de página acontece normalmente no modo espera
   (inclusive nas repetições).
4. `just analyze` e `just test` limpos.

## Notas de execução

- `lib/practice/hand.dart`: enum `Hand` (extraído de `lib/mockup/
  practice_state.dart`, que agora só reexporta — `lib/main.dart`, app real,
  não deve depender do diretório de mockup) com `studentStaves`/`appStaves`
  (convenção N03: pauta 1 = direita, pauta 2 = esquerda; "ambas" tem
  `appStaves` vazio, o app não toca nada).
- **Freio em `ScoreAudioScheduler`** (`setBrake`/`setStaves`), não no
  `AudioPlaybackClock` (que continua um passthrough puro): `positionMs` e o
  horizonte de `pump()` capam em `_brakeMs` quando armado, e `pump()` só
  agenda as pautas em `_staves`. `setBrake` reancora a posição atual, mas
  **nunca deixa `_scheduledUpToMs` regredir** — descobri isso com um teste
  que dava 2 note-on a mais do que devia: o aluno pode completar um passo
  antes do próximo tick do `pump()` (que agenda com até 250 ms de
  antecedência), e um reancoragem ingênua reagendava em duplicata o que já
  tinha ido para o motor.
- Cor de "esperado agora" no treino: **azul** (`kPracticePendingColor`,
  `lib/practice/practice_colors.dart`) — o vermelho padrão do `ScorePlayer`
  (`kDefaultHighlightColor`, configurável em Opções) confundia pendente com
  errada. `lib/main.dart` troca o `highlightColor` do player ao iniciar a
  prática (`_togglePractice`) e devolve ao sair (`_endPractice`); fora do
  treino continua o vermelho configurável. Paleta do treino: pendente azul,
  certa verde, errada vermelha (+ fantasma laranja), adiantado/atrasado
  âmbar escuro (tom do `kOkColor` do resumo).
- `lib/practice/practice_controller.dart`: `PracticeController` (Flutter-
  aware, ao contrário do T01 Dart-puro) liga `MidiInputService.notes` →
  `WaitModeSession` → freio (via `session.current`) → cores (via
  `session.verdicts`). Nota errada: acha a nota esperada mais próxima em
  pitch (`step.notes` filtrado por `step.remaining`) e pisca nela; o pitch
  errado em si vai para um `ValueNotifier<Set<int>>` exposto (`wrongPitches`)
  para o teclado desenhado.
- `PianoKeyboardPainter` ganhou `wrong`/`wrongColor` (tecla errada em
  vermelho, por cima de `held`) e `MidiMonitorPanel` um `wrong:` opcional —
  `lib/main.dart` passa `_practice?.wrongPitches` só quando uma sessão está
  ativa.
- UI em `lib/main.dart`: `_trainingMode` (armado por um botão dedicado,
  independente do Play) + seletor de mão (`PopupMenuButton<Hand>`, some
  durante a sessão) + `_canTrain` (`_canPlay && _trainingMode && `
  dispositivo MIDI conectado`) decide se o Play vira "Praticar"
  (`_togglePractice`/`_stopPractice`). `_practice` é desmontado em todo
  lugar que já derrubava `_scheduler`/`_player` (`_stop`, `_toggleSound`
  desligando, `_onEntry` no fim da peça, `_renderAndShow` numa gravura
  nova) — sem isso o freio/filtro de pauta ficaria armado por engano na
  próxima reprodução normal.
- Testes: `test/score_audio_scheduler_test.dart` ganhou o grupo "freio do
  modo espera (T02)" (posição estaciona; freio + filtro de pauta juntos;
  avançar o freio não perde nem duplica evento — via `maple-leaf-rag.vsb`
  real, mesmo `FakeSoundEngine`/`_advanceUntil` de K04).
  `test/practice_controller_test.dart` (novo): `FakeMidiInput` (não existia
  dublê, só a interface — escrito no estilo do `FakeMidiSender` de M03) +
  `FakeSoundEngine` + `ScoreController` real sobre o corpus, cobrindo nota
  certa (avança passo, pinta verde), nota errada (não avança, pisca a mais
  próxima, marca a tecla) e `stop()`. `test()` puro, não `testWidgets`: sem
  árvore de widget para montar, só `TestWidgetsFlutterBinding.
  ensureInitialized()` (o `Ticker` do `ScoreController` precisa) +
  `pumpEventQueue()` para o stream de notas (broadcast comum, entrega por
  microtask, igual ao `FlutterMidiInputService` de verdade).
- Critério 1 (teste automatizado) fechado; 2 e 3 são manuais (precisam de
  teclado MIDI/VMPK de verdade) e ficam para o usuário verificar. `just
  analyze`/`just test` limpos (64 testes) fecha o 4.
