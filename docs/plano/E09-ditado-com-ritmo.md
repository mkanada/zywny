# E09 — Ditado com o ritmo dado (`answer: dictation`)

**Repo:** zywny · **Depende de:** E07 · **Decisão necessária:** não
(D-LEI-DITADO no [E00](E00-exercicios-de-ouvido.md): executar depois do
E08; o usuário pode adiar para depois da 1.0. **Confirme com o usuário
antes de começar.**)

## Objetivo

Um terceiro jeito de responder o `listen-score`: o **ditado**. O zywny
mostra só o **ritmo** da frase (as figuras numa linha só, sem altura), com
a primeira nota escrita de verdade. Toca o acorde e a frase. O aluno toca,
no teclado MIDI, as notas que ouviu, uma a uma; a figura da vez fica acesa.
No fim da frase, a partitura de verdade aparece na revelação.

````markdown
```zywny-exercise
id: l3-ditado
type: listen-score
title: Ditado de ouvido
step: 1c
answer: dictation
count: 2
pass: {accuracy: 60}
```
````

Com `dictation`, `count` é o número de **frases**; cada frase tem uma
pergunta por nota (menos a primeira, que vem escrita). `change` não vale:
a frase soa como está escrita.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md) (segunda parte), [E05](E05-mudanca-e-frase.md),
  [E06](E06-listen-score-formato.md) e [E07](E07-listen-score-tela.md).
- `lib/sight_reading/sight_score.dart` (com os ids do E05).
- `lib/course/ui/question_body.dart`: `_onMidi`, `_afterAnswer`,
  `_applyHighlight`, `_usesKeyboard` e o que o E07 acrescentou.
- `lib/course/ui/exercise_card.dart`, `exerciseNeedsMidi`.

## Contexto que você precisa

- As perguntas respondidas no teclado já existem: `Question.expectedPitch`
  e `anyOctave` (o `find-key` e o `listen-note`). `QuestionSession.answerPitch`
  confere e avança; tecla errada conta como erro e a pergunta continua.
- `_applyHighlight` pinta a nota da vez (`highlightId`) de
  `practicePendingColor` e as já respondidas de verde ou vermelho. Num
  ditado, a partitura com o ritmo tem um id por figura, e isso já basta.
- No E07, cada pergunta do `listen-score` tem a sua `ScoreComparison`. No
  ditado, **todas as perguntas da mesma frase compartilham a mesma
  instância**. A tela usa isso para saber quando a frase mudou.
- O aluno não sabe a oitava pelo ritmo: o ditado vale em qualquer oitava
  (`anyOctave: true`).

## O que fazer

### 1. Formato

- `ScoreAnswer` ganha `dictation`.
- No leitor: com `answer: dictation`, `change` presente dá erro
  ``'`change` não vale com `answer: dictation`: a frase soa como está escrita.'``.
- `exerciseNeedsMidi`: `listen-score` com `answer: dictation` precisa do
  teclado.
- `exerciseSummary`: com `dictation`, `'Ditado · ${spec.count}
  ${spec.count == 1 ? 'frase' : 'frases'}'`.

### 2. A partitura só com o ritmo — `sight_score.dart`

```dart
/// A pauta [staff] de [ex] só com o ritmo: cada nota na linha do meio
/// (Si4 na clave de sol, Ré3 na de fá), com cabeça em barra
/// (`<notehead>slash</notehead>`), menos a primeira nota, escrita na altura
/// de verdade. Os ids são os de `sightNoteId`. Uma pauta só, com a clave
/// dela, a armadura e a fórmula de compasso do passo.
String sightRhythmXml(SightExercise ex, {required int staff});
```

Se o Verovio não desenhar a cabeça em barra, use a cabeça normal na linha
do meio e registre nas notas de execução.

### 3. As perguntas — `sight_listen.dart`

```dart
/// As perguntas de um ditado de [step] com [seed]: uma por nota da pauta
/// ditada, menos a primeira. Todas levam a mesma [ScoreComparison], com
/// `promptBytes` (o ritmo) e `scoreBytes` (a partitura de verdade).
List<Question> sightDictationQuestions(SightStep step, int seed, {int? bpm});
```

- A pauta ditada é a de sol, ou a de fá num passo `SightHands.left`. Num
  passo de duas mãos, dita-se a de sol, e a de fá soa junto.
- `ScoreComparison` ganha `final Uint8List? promptBytes;` (a partitura
  mostrada enquanto o aluno responde; `null` nas perguntas de "onde
  mudou?").
- Cada pergunta: `expectedPitch` = o `midi` da nota, `anyOctave: true`,
  `highlightId` = o id dela, `compare` = a instância da frase (`played` =
  `written`, `changedIds` vazio).
- `ListenScoreKind`: com `dictation`, junte as perguntas de `count` frases
  (sementes de `rng.nextInt(1 << 31)`).

### 4. A tela — `question_body.dart`

- `_isDictation`: `listen-score` com `answer: dictation`. `_usesKeyboard`
  passa a incluí-lo (assina o MIDI e esconde os botões).
- **Partitura mostrada**: durante as perguntas, `compare.promptBytes`; na
  revelação, `compare.scoreBytes`. O `_scoreSourceOf` do E07 escolhe por
  isso.
- **Som**: a frase toca sozinha só quando a `compare` da pergunta atual não
  é a mesma (`identical`) da anterior. Nas outras perguntas da mesma frase
  não toca de novo (o aluno usa "Ouvir de novo").
- **Revelação**: só no fim da frase. No `_afterAnswer`, entre na revelação
  quando a pergunta que acabou de ser respondida é a última da sua frase
  (a próxima tem outra `compare`, ou a sessão terminou). A revelação mostra
  "A frase era esta:", a partitura de verdade e "Ouvir de novo", sem
  "Ouvir o escrito" (é igual). As notas erradas, as que não foram de
  primeira, ficam pintadas de `practiceWrongColor` (pelos ids).
- **Prompt**: título **"Toque as notas que ouviu"**, a linha "A primeira já
  está escrita. Vale qualquer oitava.", "Ouvir de novo" e a partitura.
- Tecla errada: mostre "Você tocou Fá — tente de novo.", como o `find-key`
  (`_wrongMessage`).

### 5. Curso inicial

`03-clave-de-sol.md`, logo depois do exercício `l3-brilha-brilha`:

````markdown
## Ditado de ouvido

Agora o contrário: o zywny toca e você escreve, tocando. A partitura mostra
só o ritmo e a primeira nota. Ouça a frase, ponha a mão na posição de Dó e
toque as notas que ouviu, uma de cada vez. Se precisar, ouça de novo.

```zywny-exercise
id: l3-ditado
type: listen-score
title: Ditado de ouvido
step: 1c
answer: dictation
count: 2
pass: {accuracy: 60}
```
````

`test/course_coverage_test.dart`: `answer` passa a exigir `dictation`.

### 6. Especificação — `formato-v1.md`

Na seção `### listen-score`: `dictation` na tabela (`answer`), o parágrafo
do ditado (o ritmo, a primeira nota escrita, qualquer oitava, `count` =
frases, sem `change`) e "precisa de teclado MIDI" na tabela de tipos.

## Testes

1. `course_reader_test.dart`: `answer: dictation` lido; `dictation` com
   `change` dá o erro do item 1.
2. `sight_listen_test.dart`: `sightDictationQuestions` do 1c tem 3
   perguntas (4 semibreves menos a primeira), todas com a mesma
   `compare` (`identical`), `anyOctave` verdadeiro e `expectedPitch` igual
   às notas da partitura; num passo `left`, os ids começam com `s2-`.
3. `sight_score_test.dart`: `sightRhythmXml` tem uma pauta só, a primeira
   nota na altura de verdade e as outras com `slash`.
4. `exercise_question_screens_test.dart`, `group('listen-score ditado')`:
   com o `FakeMidiInput`, tocar as três notas certas (em outra oitava)
   leva à revelação "A frase era esta:"; numa rodada de 2 frases, a frase
   toca duas vezes (uma por frase), não uma por nota.

## Fora de escopo

- Ditado sem o ritmo dado.
- Ditado no treino de leitura (o aluno acabou de ler a partitura; não há o
  que ditar).
- Ditar as duas mãos.

## Critérios de aceite

1. `cd packages/zywny_course_format && dart test` passa.
2. `flutter analyze` sem avisos novos; `flutter test` inteiro passa.
3. `dart run tool/zywny_course.dart validate --render assets/cursos/iniciacao`
   sem erros.
4. Manual (Linux, teclado MIDI): lição 3, "Ditado de ouvido"; o ritmo
   aparece sem altura, a primeira nota está escrita, a figura da vez acende
   e a partitura de verdade aparece no fim da frase.

## Notas de execução

(Preencha ao executar.)
