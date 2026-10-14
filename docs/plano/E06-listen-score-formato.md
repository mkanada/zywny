# E06 — `listen-score`: formato, rodada e curso inicial

**Repo:** zywny · **Depende de:** E05 · **Decisão necessária:** não (D-LEI
no [E00](E00-exercicios-de-ouvido.md))

## Objetivo

O curso aceita o tipo `listen-score`: o zywny mostra uma partitura gerada
por um passo do treino de leitura (`step: 4c`), toca uma versão dela com uma
diferença, e o aluno diz em que compasso (ou se é igual ou diferente). A
rodada sai pronta, com as perguntas do `sightListenQuestion` (E05). O curso
inicial ganha cinco exercícios do tipo novo, e o `formato-v1.md` ganha a
seção do tipo.

A tela ainda **não** mostra a partitura de cada pergunta nem toca a frase:
isso é o E07. Entre o E06 e o E07, os exercícios novos abrem só com os
botões. Não publique o app nesse meio.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md) (segunda parte e D-LEI) e
  [E05](E05-mudanca-e-frase.md) (`SightChange`, `SightAnswer`,
  `sightListenQuestion`).
- [E04](E04-intervalos.md), itens 1 a 8: **este passo repete o caminho
  dele.** Faça cada item no mesmo lugar em que o E04 fez o do
  `listen-interval`.
- `packages/zywny_course_format/lib/course_model.dart`: L1–L160 (os enums e
  `ExerciseType`) e `ListenIntervalSpec` (L577).
- `packages/zywny_course_format/lib/vocabulary.dart`: `kPassKeys`
  (L213–L237) e `_typeKeys` (o caso `listenInterval`, L335).
- `packages/zywny_course_format/lib/mark_parser.dart`: o caso
  `listenInterval` de `_buildExercise` (L544).
- `lib/course/exercise/question_kinds.dart`: `ListenIntervalKind` (L196).
- `test/course_coverage_test.dart`: L28–L60 e L270–L310.

## O formato

````markdown
```zywny-exercise
id: l6-onde-mudou-ritmo
type: listen-score
title: Onde o ritmo mudou
step: 4c
change: rhythm
answer: measure
count: 5
pass: {accuracy: 60}
```
````

| Chave | Valor | Padrão |
| --- | --- | --- |
| `step` | um passo do treino de leitura, de `1a` a `20d` | — (obrigatória) |
| `change` | `pitch` (uma nota em outra altura), `rhythm` (uma nota dividida ou duas juntas) ou `accidental` (o acidente da armadura esquecido) | `pitch` |
| `answer` | `measure` (botões com o número do compasso) ou `same-different` (Igual / Diferente) | `measure` |
| `count` | quantas perguntas, de 1 a 10; cada uma é uma partitura nova | `5` |
| `bpm` | andamento da frase, de 40 a 200 | o do passo, nunca abaixo de 72 |

`change: accidental` só vale com um passo que tenha armadura, do `11a` em
diante.

## O que fazer

### 1. O passo pelo nome — `lib/sight_reading/sight_steps.dart`

```dart
/// O passo de nome [name] (`1a` a `20d`), ou `null` se não existe.
SightStep? sightStepNamed(String name);
```

Aceite `^([1-9]|1[0-9]|20)([a-d])$`. Teste: `1a`, `11c` e `20d` existem e
têm esse `name`; `0a`, `21a`, `1e` e `abc` dão `null`.

### 2. Modelo — `course_model.dart`

Depois de `IntervalPlay`:

```dart
/// `listen-score`: o que muda entre o escrito e o que soa.
enum ScoreChange implements WireEnum {
  pitch,
  rhythm,
  accidental;

  @override
  String get wire => name;
}

/// `listen-score`: como o aluno responde.
enum ScoreAnswer implements WireEnum {
  measure('measure'),
  sameDifferent('same-different');

  const ScoreAnswer(this.wire);

  @override
  final String wire;
}
```

`ExerciseType` ganha `listenScore('listen-score')` **no fim**. Depois de
`ListenIntervalSpec`, crie `ListenScoreSpec` com `step` (`String`, o nome
do passo), `change` (`ScoreChange`), `answer` (`ScoreAnswer`), `count`
(`int`) e `bpm` (`int?`).

O pacote `zywny_course_format` **não** conhece os passos (eles moram no
app). Ele só confere o nome pelo padrão do item 1.

### 3. Vocabulário — `vocabulary.dart`

- `kPassKeys['time-limit']`: acrescente `ExerciseType.listenScore`.
- `_typeKeys`:

```dart
  ExerciseType.listenScore: {
    'step': const KeyDef(ValueType.scalarText, required: true),
    'change': KeyDef(
      ValueType.option,
      values: _wires(ScoreChange.values),
      fallback: 'pitch',
    ),
    'answer': KeyDef(
      ValueType.option,
      values: _wires(ScoreAnswer.values),
      fallback: 'measure',
    ),
    'count': const KeyDef(ValueType.integer, min: 1, max: 10, fallback: '5'),
    'bpm': const KeyDef(ValueType.integer, min: 40, max: 200),
  },
```

### 4. Leitura — `mark_parser.dart`, caso novo em `_buildExercise`

- `step`: se não casar com `^([1-9]|1[0-9]|20)([a-d])$`, dê
  `issues.error(f.lineOf('step'), '`$step` não é um passo do treino de leitura: use de `1a` a `20d`.')`
  e `return null`.
- `change: accidental` com nível menor que 11: dê
  `issues.error(f.lineOf('change'), '`change: accidental` pede um passo com armadura, do `11a` em diante.')`
  e `return null`.
- `change`, `answer` com `_enumOf` e os padrões da tabela; `count` com
  padrão 5; `bpm` pode faltar.

As duas mensagens são novas e **não** entram na seção 11 do
`formato-v1.md` (um teste confere aquela lista).

### 5. A rodada — `question_kinds.dart`, `ListenScoreKind`

```dart
class ListenScoreKind extends ExerciseKind<ListenScoreSpec> {
  const ListenScoreKind();

  @override
  Future<QuestionRound> generate(
    ListenScoreSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final step = sightStepNamed(spec.step)!; // o leitor já conferiu o nome
    return QuestionRound([
      for (var i = 0; i < spec.count; i++)
        sightListenQuestion(
          step,
          rng.nextInt(1 << 31),
          change: _changeOf(spec.change),
          answer: _answerOf(spec.answer),
          bpm: spec.bpm,
        ),
    ]);
  }
}
```

`_changeOf` e `_answerOf` traduzem `ScoreChange` → `SightChange` e
`ScoreAnswer` → `SightAnswer` com `switch`. Registre em `exerciseKinds`.

`question_kinds.dart` passa a importar `../../sight_reading/sight_listen.dart`
e `../../sight_reading/sight_steps.dart`. O `test/camadas_test.dart` não
proíbe isso (só `practice/ → trail/`, `settings/app_settings.dart` e
`app/`). Rode-o mesmo assim.

### 6. Os outros lugares (os mesmos do E04, item 5)

- `exerciseSummary` (`lib/course/ui/exercise_card.dart`):
  `case ListenScoreSpec():` →
  `'Ouça a partitura · ${spec.count}'`.
- `course_render_check.dart`: `case ListenScoreSpec():` devolve `null`
  (a partitura é gerada).
- `exercise_source.dart`, `isQuestion`: acrescente
  `ExerciseType.listenScore`.
- `exerciseNeedsMidi`: **não** muda (só botões).
- `test/fixtures/cursos/erro-exercicios/esperado.txt`: a lista de tipos da
  mensagem "tipo de exercício desconhecido" ganha `listen-score` no fim.

### 7. Curso inicial (`assets/cursos/iniciacao/lessons/`)

Cinco exercícios. Os passos foram escolhidos pelo que a lição já ensinou:
`1c` (Dó a Sol, semibreves, mão direita), `4c` (semibreves e mínimas), `8c`
(colcheias e semínimas), `11c` (Sol maior, semínimas e mínimas) e `5d`
(semínimas e mínimas, as duas mãos).

a. `02-pauta-e-clave-de-sol.md`, no fim da lição (depois de
`l2-ouvir-posicao`):

````markdown
## Leia e ouça

Agora leia sem tocar. O zywny mostra quatro notas, toca o acorde de Dó e
depois as quatro. Às vezes uma delas soa diferente do que está escrito.
Siga a partitura com os olhos enquanto ouve: igual ou diferente?

```zywny-exercise
id: l2-igual-ou-diferente
type: listen-score
title: Igual ou diferente
step: 1c
change: pitch
answer: same-different
count: 6
pass: {accuracy: 80}
```
````

(Com dois botões, o chute acerta metade: por isso 80.)

b. `06-figuras-e-pausas.md`, no fim da lição (depois de `l6-ritmo-basico`):

````markdown
## Ouça o ritmo

O zywny toca uma partitura de semibreves e mínimas, mas num compasso o
ritmo soa diferente do escrito: uma nota se divide em duas, ou duas viram
uma só. Conte os tempos enquanto ouve. Em que compasso?

```zywny-exercise
id: l6-onde-mudou-ritmo
type: listen-score
title: Onde o ritmo mudou
step: 4c
change: rhythm
count: 5
pass: {accuracy: 60}
```
````

c. `07-mais-tempos.md`, logo antes de `## Para revisar`:

````markdown
## Ouça as colcheias

Agora com colcheias. Siga a partitura contando "um e, dois e": em que
compasso o ritmo soa diferente?

```zywny-exercise
id: l7-onde-mudou-colcheias
type: listen-score
title: Colcheias, de ouvido
step: 8c
change: rhythm
answer: measure
count: 5
pass: {accuracy: 60}
```
````

d. `09-armadura.md`, logo depois do exercício `l9-ouvir-sol` (antes de
`## Armaduras com mais acidentes`):

````markdown
## A armadura esquecida

Quem lê em Sol maior às vezes esquece a armadura e toca Fá natural. O zywny
faz isso de propósito, uma vez em cada partitura. Ouça e diga em que
compasso o Fá soou sem o sustenido.

```zywny-exercise
id: l9-armadura-esquecida
type: listen-score
title: A armadura esquecida
step: 11c
change: accidental
answer: measure
count: 5
pass: {accuracy: 60}
```
````

e. `10-juntando-tudo.md`, numa seção nova logo **antes** de `## As duas
mãos`:

````markdown
## Ouça as duas mãos

Agora uma partitura nas duas pautas, como a Ode. Uma nota, numa das mãos,
soa diferente do escrito. Leia as duas pautas enquanto ouve: em que
compasso?

```zywny-exercise
id: l10-onde-mudou
type: listen-score
title: Onde mudou, nas duas mãos
step: 5d
change: pitch
answer: measure
count: 5
bpm: 80
pass: {accuracy: 60}
```
````

f. `test/course_coverage_test.dart`: colete e confira `change` (`pitch`,
`rhythm`, `accidental`) e `answer` (`measure`, `same-different`) no molde
do `direction` do E04. O teste também exige que **toda chave** de cada tipo
apareça no curso: `step`, `change`, `answer`, `count` e `bpm` aparecem nos
exercícios acima.

### 8. Especificação — `docs/licoes/formato-v1.md`

- Na tabela de tipos (seção 6): `listen-score` | "vê uma partitura gerada,
  ouve uma versão com uma diferença e diz onde" | só a tela.
- Na tabela do `pass` (seção 7): `listen-score` no `time-limit`.
- Uma seção `### listen-score` depois da `### listen-interval`, com o
  exemplo e a tabela de chaves deste arquivo, mais estes parágrafos:
  - o `step` é um passo do treino de leitura à primeira vista. Inclua uma
    tabela com os 20 níveis e o que cada um traz, tirada dos comentários
    `// Nível N: …` de `sight_steps.dart` (L82–L503) e de `_newKey`
    (níveis 11 a 20, um tom novo por nível, na ordem de `_newKeys`), e
    diga que os subníveis `a` a `d` vão da mão direita às duas mãos (os
    rótulos exatos estão em `sightSteps`);
  - antes da frase soa o acorde da tônica;
  - a primeira nota nunca muda;
  - com `same-different`, metade das partituras soa igual ao escrito.

Nada na seção 11.

## Testes

1. `course_reader_test.dart`: o exemplo do topo vira `ListenScoreSpec` com
   `step == '4c'`, `change == ScoreChange.rhythm`, `answer ==
   ScoreAnswer.measure`, `count == 5`, `bpm == null`; os padrões
   (`pitch`, `measure`, 5); `step: 21a` dá erro que contém
   `'não é um passo'`; `step: 4c` com `change: accidental` dá erro que
   contém `'do `11a` em diante'`; `answer: same-different` vira
   `ScoreAnswer.sameDifferent`.
2. `exercise_questions_test.dart`, `group('listen-score')`:
   - `step: 4c`, `count: 3`, semente fixa: 3 perguntas, cada uma com
     `compare` não nulo, `answers == ['1', '2', '3', '4']` e `correct ==
     compare.measure`;
   - `answer: same-different`, `count: 10`: `answers == ['Igual',
     'Diferente']`, e `correct == 0` exatamente quando `changedIds` está
     vazio;
   - o aluno simulado acertando tudo aprova.
3. `course_coverage_test.dart` passa com as listas novas.

## Fora de escopo

- A tela (E07): partitura por pergunta, a frase tocando e a revelação.
- `abc` ou `file` no lugar de `step`.
- O treino de leitura (E08).

## Critérios de aceite

1. `cd packages/zywny_course_format && dart test` passa.
2. `flutter analyze` sem avisos novos; `flutter test` inteiro passa.
3. `dart run tool/zywny_course.dart validate --render assets/cursos/iniciacao`
   sai com 0 e sem erros.

## Notas de execução

(Preencha ao executar.)
