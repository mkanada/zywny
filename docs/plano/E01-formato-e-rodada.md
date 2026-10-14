# E01 — `listen-note`: formato, rodada e curso inicial

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** não (D-OUV
no [E00](E00-exercicios-de-ouvido.md))

## Objetivo

O curso aceita o tipo `listen-note`. A rodada sai pronta: cada pergunta
traz a resposta certa e **o que deve soar** (`Question.sound`). O curso
inicial ganha três exercícios do tipo novo. A tela ainda não toca nada,
porque o som entra no E02.

Ao fim deste passo, `flutter test` e `dart test` passam inteiros.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md): todo.
- `packages/zywny_course_format/lib/course_model.dart`: `OctaveRule` (L38),
  `ExerciseType` (L85), `FindKeySpec` e `NameNoteSpec` (L320–L375).
- `packages/zywny_course_format/lib/mark_parser.dart`: `_buildExercise`
  (L364–L502). Copie os casos `findKey` e `nameNote`.
- `packages/zywny_course_format/lib/vocabulary.dart`: `kPassKeys` (L213–L235)
  e `_typeKeys` (L248–L313).
- `lib/course/exercise/exercise_round.dart`: L70–L130.
- `lib/course/exercise/question_kinds.dart`: `FindKeyKind` e `NameNoteKind`
  (L21–L68).
- `lib/course/exercise/exercise_kind.dart`: `exerciseKinds` (L27–L35).

## O que fazer

### 1. Modelo — `packages/zywny_course_format/lib/course_model.dart`

a. Logo depois de `enum OctaveRule`, crie:

```dart
/// `listen-note`: como o aluno responde.
enum AnswerInput implements WireEnum {
  keyboard,
  buttons;

  @override
  String get wire => name;
}
```

b. Em `ExerciseType`, acrescente **no fim** (depois de `choice`):
`listenNote('listen-note');` (troque o `;` do `choice` por `,`).

c. Depois de `ChoiceSpec`, crie:

```dart
class ListenNoteSpec extends ExerciseSpec {
  const ListenNoteSpec({
    required super.id,
    required super.title,
    required super.pass,
    required super.line,
    required this.notes,
    required this.input,
    required this.octave,
    required this.choices,
    this.reference,
    this.key,
  });

  @override
  ExerciseType get type => ExerciseType.listenNote;

  final NotesSpec notes;

  /// Nota tocada antes de cada pergunta (`null` = sem referência).
  final Pitch? reference;

  final AnswerInput input;

  /// Só vale com [AnswerInput.keyboard].
  final OctaveRule octave;

  /// Letras dos botões (`C`…`B`); só vale com [AnswerInput.buttons].
  final List<String> choices;

  /// Tom do sorteio; só vale com [AnswerInput.keyboard].
  final String? key;
}
```

### 2. Vocabulário — `packages/zywny_course_format/lib/vocabulary.dart`

a. Em `kPassKeys['time-limit']`, acrescente `ExerciseType.listenNote` ao
conjunto.

b. Em `_typeKeys`, acrescente:

```dart
  ExerciseType.listenNote: {
    'notes': _notes,
    'reference': const KeyDef(ValueType.note),
    'input': KeyDef(
      ValueType.option,
      values: _wires(AnswerInput.values),
      fallback: 'keyboard',
    ),
    'octave': KeyDef(
      ValueType.option,
      values: _wires(OctaveRule.values),
      fallback: 'any',
    ),
    'key': _key,
    'choices': const KeyDef(
      ValueType.letterList,
      minItems: 2,
      fallback: '[C, D, E, F, G, A, B]',
    ),
  },
```

### 3. Leitura — `packages/zywny_course_format/lib/mark_parser.dart`

Em `_buildExercise`, acrescente o caso abaixo depois de `case
ExerciseType.choice:`. As três mensagens de erro são **novas** e **não**
entram na seção "11. Erros comuns" do `docs/licoes/formato-v1.md`, porque
um teste confere aquela lista.

```dart
    case ExerciseType.listenNote:
      final input =
          _enumOf(AnswerInput.values, f.get<String>('input')) ??
          AnswerInput.keyboard;
      final buttons = input == AnswerInput.buttons;
      var ok = true;
      for (final k in buttons ? ['octave', 'key'] : ['choices']) {
        if (f.has(k)) {
          issues.error(
            f.lineOf(k),
            '`$k` só vale com `input: ${buttons ? 'keyboard' : 'buttons'}`.',
          );
          ok = false;
        }
      }
      if (!ok) return null;
      final choices =
          f.get<List<Object>>('choices')?.cast<String>() ??
          const ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
      final notes = buttons
          ? _notes(
              f,
              issues,
              defaultCount: 10,
              naturalsOnly: true,
              letters: choices,
            )
          : _notes(f, issues, defaultCount: 10);
      if (notes == null) return null;
      return ListenNoteSpec(
        id: id,
        title: title,
        pass: _pass(pass),
        line: line,
        notes: notes,
        reference: f.get<Pitch>('reference'),
        input: input,
        octave:
            _enumOf(OctaveRule.values, f.get<String>('octave')) ??
            OctaveRule.any,
        choices: choices,
        key: f.get<String>('key'),
      );
```

### 4. A rodada

a. `lib/course/exercise/exercise_round.dart`: antes de `class Question`,
crie:

```dart
/// Um som da pergunta: as [pitches] (MIDI) soam juntas por [seconds].
@immutable
class SoundCue {
  const SoundCue(this.pitches, {this.seconds = 1.0});

  final List<int> pitches;
  final double seconds;
}
```

Em `Question`, acrescente o parâmetro `this.sound = const []` ao construtor
e o campo:

```dart
  /// O que soa ao mostrar a pergunta, um [SoundCue] depois do outro
  /// (`listen-note`). Vazio nos outros tipos.
  final List<SoundCue> sound;
```

b. `lib/course/exercise/question_kinds.dart`: corrija o comentário da
linha 1 para incluir `listen-note` e acrescente, depois de `ChoiceKind`:

```dart
/// `listen-note`: ouve a nota (depois da referência, se houver) e responde
/// no teclado ou no botão com o nome.
class ListenNoteKind extends ExerciseKind<ListenNoteSpec> {
  const ListenNoteKind();

  @override
  Future<QuestionRound> generate(
    ListenNoteSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final buttons = spec.input == AnswerInput.buttons;
    final notes = notesOf(spec.notes, rng, key: buttons ? null : spec.key);
    final reference = spec.reference;
    List<SoundCue> soundOf(Pitch pitch) => [
      if (reference != null) SoundCue([reference.midi]),
      SoundCue([pitch.midi]),
    ];
    return QuestionRound([
      for (final pitch in notes)
        buttons
            ? Question(
                answers: spec.choices,
                correct: spec.choices.indexOf(pitch.step),
                sound: soundOf(pitch),
              )
            : Question(
                expectedPitch: pitch.midi,
                anyOctave: spec.octave == OctaveRule.any,
                sound: soundOf(pitch),
              ),
    ]);
  }
}
```

c. `lib/course/exercise/exercise_kind.dart`: em `exerciseKinds`, acrescente
`ExerciseType.listenNote: const ListenNoteKind(),`.

### 5. O que mais o compilador pedir

`ExerciseSpec` é `sealed`. Rode `flutter analyze` e, em cada `switch` que
reclamar de caso faltando, acrescente `ListenNoteSpec`. Os conhecidos são:

- `lib/course/ui/exercise_card.dart`, `exerciseSummary`:
  ```dart
    case ListenNoteSpec():
      final how = spec.input == AnswerInput.buttons ? 'pelo nome' : 'no teclado';
      return 'Ouça e responda $how · ${countOf(spec.notes, fallback: 10)}';
  ```
- `lib/course/course_render_check.dart` (L138–L142): acrescente
  `case ListenNoteSpec():` junto dos que devolvem `null`.

E mais dois lugares que **não** são `switch` (o compilador não avisa):

- `lib/course/ui/exercise_card.dart`, `exerciseNeedsMidi`: acrescente
  `|| (spec is ListenNoteSpec && spec.input == AnswerInput.keyboard)`.
- `lib/course/ui/exercise_source.dart`, `isQuestion` (L89–L93): acrescente
  `|| spec.type == ExerciseType.listenNote`.

Se algum teste compara a lista de tipos aceitos numa mensagem (por exemplo,
"type desconhecido… aceitos: …"), atualize o texto esperado com
`listen-note` no fim.

### 6. Curso inicial (`assets/cursos/iniciacao/lessons/`)

O `test/course_coverage_test.dart` exige que **todo tipo e toda chave**
apareçam no curso inicial. Acrescente:

a. Em `01-o-teclado.md`, logo **depois** do exercício `l1-oitava-certa` (o
último `find-key`), esta seção:

````markdown
## Ouvir e achar

Agora o zywny toca e você procura. Primeiro soa o **dó central**, como
referência; depois, outra nota. Ache-a no teclado (vale qualquer oitava).
Se precisar, toque em **Ouvir de novo**.

```zywny-exercise
id: l1-ouvir-achar
type: listen-note
title: Ouça e ache a tecla
notes: {random: C4-B4, count: 8}
reference: C4
input: keyboard
octave: any
pass: {accuracy: 60}
```

Também dá para responder pelo nome, sem teclado:

```zywny-exercise
id: l1-ouvir-nome
type: listen-note
title: Ouça e diga o nome
notes: {random: C4-E4, count: 6}
reference: C4
input: buttons
choices: [C, D, E]
pass: {accuracy: 60, time-limit: 20}
```
````

b. Em `09-armadura.md`, depois do último exercício `play-notes`:

````markdown
## Ouvir em Sol

Agora a referência é o **Sol**, e as notas são as do tom de Sol: o Fá é
sustenido. Toque a tecla na oitava certa.

```zywny-exercise
id: l9-ouvir-sol
type: listen-note
title: Ouça em Sol maior
notes: {random: G4-G5, count: 8}
reference: G4
input: keyboard
octave: exact
key: G
pass: {accuracy: 60}
```
````

c. Em `test/course_coverage_test.dart`, siga o molde de `octaves`: crie
`final inputs = <String>{};` em `_Seen`, colete com
`if (key == 'input' && value is String) seen.inputs.add(value);` ao lado da
linha 95 e acrescente `checkValues('input', seen.inputs, ['keyboard',
'buttons']);` depois do `checkValues('octave', …)`.

Não mexa no `version` do `course.md`.

## Testes

1. `packages/zywny_course_format/test/course_reader_test.dart`, num
   `test` novo dentro de `group('readCourse')`, usando `_read` e
   `_messages` como os vizinhos:
   - o bloco do `l1-ouvir-achar` acima vira `ListenNoteSpec` com
     `input == AnswerInput.keyboard`, `octave == OctaveRule.any` e
     `reference.toString() == 'C4'`;
   - um bloco só com `id`, `type: listen-note`, `title`, `notes: [C4]`
     tem os padrões: `keyboard`, `any`, `reference == null` e `choices`
     com as sete letras;
   - `input: buttons` + `octave: exact` → uma mensagem que contém
     ``"`octave` só vale com `input: keyboard`"`` e `course == null`;
   - `input: keyboard` + `choices: [C, D]` → ``"`choices` só vale com
     `input: buttons`"``;
   - `input: buttons` + `notes: {random: C4-E4}` + `choices: [C, D]` →
     contém `'E, que não tem botão'` (a mesma regra do `name-note`).
2. `test/exercise_questions_test.dart`, num `group('listen-note')` novo
   (use `specFrom` e `generateRound` como os vizinhos):
   - teclado com `notes: [E4]` e `reference: C4`: uma pergunta com
     `expectedPitch == 64`, `anyOctave == true` e `sound` com duas
     `SoundCue`, de `pitches` `[60]` e `[64]`;
   - sem `reference`: `sound` com uma `SoundCue` só;
   - botões com `notes: [D4]` e `choices: [C, D, E]`: `answers == ['C',
     'D', 'E']`, `correct == 1` e `expectedPitch == null`;
   - teclado com `key: G` e `notes: {random: F4-F5, count: 30}`: nenhuma
     pergunta tem `expectedPitch % 12 == 5` (sem Fá natural em Sol);
   - aluno simulado tudo certo (`answerQuestions`) → aprova
     (`PassCheck`), como os vizinhos fazem com `find-key`.

## Fora de escopo

- Tocar o som e qualquer mudança no `QuestionBody`: é o E02.
- A especificação em `docs/licoes/formato-v1.md`: é o E03.

## Critérios de aceite

1. `cd packages/zywny_course_format && dart test` passa.
2. `flutter analyze` sem avisos novos.
3. `flutter test` passa inteiro, com `course_coverage_test.dart`,
   `course_simulated_student_test.dart` e `exercise_questions_test.dart`.
4. `just curso-validar validate assets/cursos/iniciacao` sem erros.

## Notas de execução

Feito em 2026-10-13, sem commit.

**Resultados dos critérios de aceite:**

1. `packages/zywny_course_format`: `dart test` passou (20 testes em
   `course_reader_test.dart`, 4 deles novos).
2. `flutter analyze`: "No issues found!".
3. `flutter test` inteiro: "All tests passed!" (+1003, ~11 pulados).
   `course_coverage_test.dart`, `course_simulated_student_test.dart` e
   `exercise_questions_test.dart` passaram.
4. `just curso-validar validate assets/cursos/iniciacao`: saiu com 0 e
   sem erros.

**Desvios do texto:**

- `question_kinds.dart` precisou do import `package:zywny_music/note_name.dart`
  (para o tipo `Pitch` em `soundOf`). O plano não o listava.
- `test/fixtures/cursos/erro-exercicios/esperado.txt`: a lista de tipos da
  mensagem "tipo de exercício desconhecido" ganhou `listen-note` no fim
  (item 5 do plano).
- `dart format` quebrou uma linha de `exercise_card.dart`; sem mudança de
  conteúdo.

**Para o E02 (e para a conferência de quem lê o curso agora):**

- O texto das lições já fala em **Ouvir de novo** e em "o zywny toca", mas
  nada toca ainda: o som e o botão entram no E02. Até lá, os dois exercícios
  `l1-ouvir-achar` e `l9-ouvir-sol` mostram só a resposta (teclado ou
  botões), sem som. Não é bug do E01, mas não publique o curso antes do E02.
- `Question.sound` já sai preenchido: a `SoundCue` da referência vem antes
  da nota quando há `reference`. O E02 só precisa consumir esse campo.
- A regra de `pickNotes` com `key: G` ficou coberta por teste (sem Fá natural
  nas 30 perguntas de um sorteio com semente 3).
