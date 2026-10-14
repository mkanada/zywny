# E10 — Responder tocando na nota da partitura (`answer: note`)

**Repo:** zywny · **Depende de:** E07 (e E08, para o item 5) · **Decisão
necessária:** não (D-LEI-NOTA no [E00](E00-exercicios-de-ouvido.md))

## Objetivo

O aluno responde "onde mudou?" tocando **na nota** da partitura, não no
número do compasso. É mais preciso e mais difícil: não basta achar o
compasso, é preciso achar a nota.

- No curso: `answer: note` no `listen-score`.
- No treino "só ouvido" (E08): do **nível 7** em diante, a resposta passa a
  ser pela nota. Depois de cada leitura, continua o compasso.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md) (D-LEI-NOTA), [E06](E06-listen-score-formato.md),
  [E07](E07-listen-score-tela.md) e, para o item 5, [E08](E08-ouvido-no-treino.md).
- `score_bridge/lib/src/score_view.dart`: `onElementTap` (L306, L362,
  L913) e `score_bridge/lib/src/score_page_view.dart`: L95–L105 e
  L310–L335 (o toque vira id).
- `lib/course/ui/exercise_screen.dart`, L334–L341: o id do MusicXML e o
  `document.sceneIdOf(id)`.
- `lib/course/exercise/question_session.dart`: todo.

## Contexto que você precisa

- `ScoreView(onElementTap: (id) { … })` entrega o id do elemento tocado. As
  classes aceitas são `{'note'}` por padrão.
- O id que o `.vsb` usa pode ser o do MusicXML (`s1-m2-n3`) ou um id de
  cena. A tela de exercício compara os dois (`runner.document.sceneIdOf(id)
  ?? id`). **Escreva primeiro um teste** que toca numa nota de uma
  partitura do `sightScoreXml` (com o renderizador de teste) e veja qual id
  chega. Compare com `changedIds` e também com
  `changedIds.map(document.sceneIdOf)`.
- Na mudança de ritmo "juntar", `changedIds` tem duas notas: tocar em
  qualquer uma vale. Na "dividir", tem uma.
- Com `answer: note` sempre há mudança (como `measure`).

## O que fazer

### 1. Formato

- `ScoreAnswer` ganha `note`.
- `formato-v1.md`, seção `### listen-score`: `note` na tabela, com
  "toque na nota que soou diferente".

### 2. A pergunta — `sight_listen.dart`

`SightAnswer` ganha `note`. Com ela, `sightListenQuestion` devolve
`answers` vazio e `correct` nulo (a resposta é pela `compare.changedIds`).
`ListenScoreKind` traduz `ScoreAnswer.note`.

### 3. A sessão — `question_session.dart`

```dart
  /// Resposta tocando numa nota da partitura (`listen-score` com `answer:
  /// note`). Mesma convenção de retorno de [answerChoice].
  bool? answerNote(String id) {
    if (done || revealing) return null;
    final ids = questions[index].compare?.changedIds;
    if (ids == null || ids.isEmpty) return null;
    if (ids.contains(id)) { … avança como answerChoice … }
    _markWrong();
    return false;
  }
```

O aluno simulado (`test/support/simulated_student.dart`, `answerQuestions`)
passa a responder perguntas sem `correct` e sem `expectedPitch` com
`answerNote(compare.changedIds.first)`; com `wrongEvery`, toque antes num
id que não está em `changedIds`.

### 4. A tela — `question_body.dart`

- `_answersByNote`: `listen-score` com `answer: note`.
- `_scoreView` ganha o parâmetro `onNoteTap`; com ele, passa
  `onElementTap` ao `ScoreView`. Só durante a pergunta (na revelação, não).
- O toque: traduza o id (veja o "Contexto"), chame `answerNote`. Errado:
  pinte a nota tocada de `practiceWrongColor` por 500 ms, como o botão
  errado pisca. Certo: `_afterAnswer()` (a revelação do E07 segue igual).
- O prompt: **"Toque na nota que soou diferente"**. Sem botões de resposta.
- A nota tocada precisa de alvo de dedo: confira no celular se as
  semínimas de quatro compassos são tocáveis. Se não forem, registre nas
  notas (a partitura pode precisar de mais largura por compasso).

### 5. No treino "só ouvido" — `sight_listen_source.dart` (E08)

- `nextRound`: com `progress.level >= 7`, use `answer: SightAnswer.note`.
- `questionSpec`: o `answer` do `ListenScoreSpec` acompanha.
- A pergunta depois de cada leitura (`SightReadingSource`) **não** muda:
  continua `measure`.

### 6. Curso inicial

`10-juntando-tudo.md`, o exercício `l10-onde-mudou` (E06): troque
`answer: measure` por `answer: note` e o texto "em que compasso?" por "toque
na nota que soou diferente". O `measure` continua no curso (lições 6, 7 e
9). `test/course_coverage_test.dart`: `answer` passa a exigir `note`.

## Testes

1. `course_reader_test.dart`: `answer: note` lido.
2. `question_session_test` (ou onde a sessão é testada): `answerNote`
   certo avança; errado marca e fica; id qualquer numa pergunta sem
   `compare` devolve `null`.
3. `exercise_question_screens_test.dart`: um `listen-score` com `answer:
   note`; tocar (com `tester.tapAt`, na posição da nota pelo `.vsb`, ou
   chamando o `onElementTap` do `ScoreView` encontrado) numa nota fora de
   `changedIds` e depois numa de dentro leva à revelação.
4. `sight_listen_source_test.dart`: nível 6, perguntas com botões; nível 7,
   sem botões e com `changedIds`.

## Fora de escopo

- Arrastar ou ampliar a partitura para tocar com precisão.
- Responder pela nota depois de cada leitura no treino.

## Critérios de aceite

1. `cd packages/zywny_course_format && dart test` passa.
2. `flutter analyze` sem avisos novos; `flutter test` inteiro passa.
3. Manual (celular): lição 10, "Onde mudou, nas duas mãos": dá para tocar
   em cada nota das duas pautas sem errar o alvo.
4. Manual (celular, só ouvido, nível 7): a pergunta pede a nota.

## Notas de execução

(Preencha ao executar.)
