# I07 — Tipos por pergunta: `find-key`, `name-note`, `count-beats`, `choice`

**Repo:** zywny · **Status:** concluído · **Depende de:** I03, I09 · **Decisão necessária:** não
(D-LIC-SEM-TECLADO: `find-key` exige MIDI; os outros três respondem por
botões e funcionam sem teclado)

## Objetivo

Os quatro tipos "pergunta a pergunta" rodando na `ExerciseScreen` do I09,
com a mesma contagem de **acerto de primeira** do modo espera e o
`time-limit` do `pass`. Fecha os exercícios das lições 1 (`find-key`) e 8
(`choice`), e os `name-note`/`count-beats` das lições 2, 3 e 6.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): a tabela de tipos e `pass`.
- `lib/course/exercise/exercise_round.dart`, `exercise_kind.dart`,
  `pass_check.dart` (I03) e o ponto de extensão da `ExerciseScreen` (I09).
- `lib/course/score/round_score.dart` (I02: `notesScore`, `rhythmScore`,
  `pickNotes`, `pickFigures`, e o que as notas de execução do I02 dizem
  sobre **ids estáveis** das notas geradas).
- `lib/course/note_names.dart` (I05).
- `score_bridge/lib/src/score_controller.dart` (`highlightAll`,
  `setColors`, `clearHighlights`).

## Contexto que você precisa

- **Regra comum das perguntas**: a pergunta fica na tela até a resposta
  certa. Errou: o botão (ou a tecla) pisca na cor de erro e a pergunta
  **não** conta como de primeira; segue esperando. `time-limit` estourou:
  conta como erro, a resposta certa aparece por 1,5 s e passa para a
  próxima. `RoundResult(hits: de primeira, total: perguntas)`.
- Sem `speed` aqui: a pergunta não tem andamento (o validador do I01 já
  recusa).
- `find-key` ouve `MidiInputService.notes` (só `on`); `octave: any` aceita
  a classe de altura (`pitch % 12`), `exact` exige a altura. Teclas
  apertadas durante o pisca da resposta certa são ignoradas.
- Botões: grandes (≥ 56 dp de altura), numa fileira que cabe no celular
  deitado; teclado do computador também responde no desktop/Web (1–7 e as
  letras C–B), útil para o aluno simulado e para quem testa.

## O que fazer

1. **`QuestionRound`** (I03 deixou o lugar): lista de `Question` com
   `prompt` (texto ou partitura + id destacado), `answers` (para botões) ou
   `expectedPitch` (MIDI), `correct`. Uma `QuestionSession` Dart pura:
   `answer(x)`, `tick(now)` para o `time-limit`, `current`, `result()`,
   com relógio injetável (teste sem espera real).
2. **`find-key`** — sorteia `count` (padrão 10) nomes de `notes`; a tela
   mostra o nome bem grande ("Ré", ou "Ré 4" e o dó central marcado num
   `zywny-keyboard` pequeno quando `octave: exact`). Exige teclado (tela
   "Conecte o teclado" do I09).
3. **`name-note`** — uma partitura com as `count` notas da rodada (I02
   `notesScore`), a nota da vez destacada (cor de "esperada"), as anteriores
   na cor de certo/errado; botões com os nomes de `choices` (padrão os
   sete naturais, na grafia das configurações). Sem MIDI.
4. **`count-beats`** — uma partitura de ritmo (`rhythmScore`) com
   `count` figuras (padrão 8) sorteadas de `figures`, a figura da vez
   destacada; botões com os valores possíveis **das figuras pedidas** em
   tempos do `time` ("½", "1", "1½", "2", "3", "4"; em 6/8, a colcheia vale
   1). Pausas contam igual ("quantos tempos dura este silêncio"). Sem MIDI.
5. **`choice`** — a `question` (markdown em linha pelo `MarkdownView`), a
   figura opcional (`image` da pasta ou `abc` pela partitura pequena do I05)
   e os botões das `options` **na ordem do autor** (não embaralhe: o autor
   pode querer "Nenhuma das anteriores" por último). Uma pergunta por
   exercício; `rounds` e `accuracy` valem igual (100% ou 0%).
6. Tela: o `switch` da `ExerciseScreen` ganha os quatro corpos; o painel
   de fim de rodada é o mesmo do I09.
7. Aluno simulado (estende `test/support/simulated_student.dart`):
   `answerQuestions(session, {wrongEvery, late})` — responde certo, erra
   a cada n, ou deixa estourar o `time-limit`.

## Fora de escopo

`rhythm` e `play-score` (I08); teclado na tela (I06 dispensado); conteúdo
das lições (I10).

## Critérios de aceite

1. `test/question_session_test.dart`: de primeira × depois do erro;
   `time-limit` estourado conta como erro e avança; relógio simulado.
2. `test/exercise_questions_test.dart`: um exercício de cada tipo com
   semente fixa, aluno simulado tudo certo → aprova; acima do limite de
   erros → reprova com `reason`; `find-key` `any` aceita outra oitava e
   `exact` não.
3. Sem teclado conectado, `name-note`, `count-beats` e `choice` abrem e
   rodam; `find-key` pede o teclado (teste de widget).
4. **(manual)** no celular deitado: os botões cabem numa fileira, a nota
   destacada é legível; `find-key` com o teclado MIDI.
5. `just analyze` e `just test` limpos.

## Notas de execução

Concluído. `just analyze` limpo; `just test` limpo (571 passando, 4
pulados/manuais, com a `libverovio.so` real).

**O que existe**

- `lib/course/exercise/question_session.dart` — `QuestionSession` Dart pura:
  `answerChoice`/`answerPitch`, `tick(now)` para o `time-limit` (com
  relógio injetável), `current`, `result()` (`hits` de primeira /
  `total`). Errou: não conta como de primeira e segue esperando;
  estourou: conta como erro, revela a certa por 1,5 s (respostas no pisca
  ignoradas) e avança. `find-key` `any` compara `% 12`, `exact` a altura.
- `lib/course/exercise/question_kinds.dart` — `FindKeyKind`,
  `NameNoteKind`, `CountBeatsKind`, `ChoiceKind` (registro em
  `exerciseKinds`); mesma semente, mesma rodada. `name-note`/`count-beats`
  com partitura (`notesScore`/`rhythmScore` com `withRestIds`) e
  `highlightId` (`zn…`); `choice` com uma pergunta, opções na ordem do
  autor, `image` ou `abc`.
- `lib/course/score/round_score.dart` — `rhythmScore(..., withRestIds)`
  (pausas com `id` para o `count-beats` destacar), `beatsOfFigure`,
  `beatLabel` ("½", "1", "1½", "2", ...; em 6/8 a colcheia vale 1),
  `beatOptions` e `pickCountBeatsFigures` (sorteio exato de `count`
  figuras que preenchem compassos, colcheias em pares).
- `lib/course/ui/question_body.dart` — corpo da `QuestionRound` na
  `ExerciseScreen`: nome grande (`find-key`, com teclado pequeno marcando
  o dó central no `exact`), partitura com a da vez em "esperada" e as
  anteriores em certo/errado, botões ≥ 56 dp em fileira (`Wrap`), teclado
  do computador (1–7 e C–B) no desktop/Web, `time-limit` com revelação em
  verde e "Tente de novo" no erro.
- Aluno simulado (`test/support/simulated_student.dart`):
  `answerQuestions(session, {wrongEvery, late})`.
- Testes: `test/question_session_test.dart` (critério 1),
  `test/exercise_questions_test.dart` (critério 2, 4 tipos + `any`/`exact`
  + `time-limit`),
  `test/exercise_question_screens_test.dart` (critério 3, sem teclado os
  de botão abrem e aprovam, `find-key` pede o teclado).

**Escolhas onde o I00/I07 não diziam**: `QuestionRound` carrega
`scoreBytes`/`fileName` (e `imagePath` na `choice`); `count-beats` conta
o par de colcheias como duas perguntas; botões em `Wrap` (fileira no
celular deitado, quebra se precisar); `anyOctave` no `Question`.

**Manual (critério 4, pendente)**: no celular deitado, botões numa
fileira, nota destacada legível, `find-key` com o teclado MIDI.
