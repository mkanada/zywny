# E04 — `listen-interval`: ouvir e nomear intervalos

**Repo:** zywny · **Depende de:** E03 · **Decisão necessária:** não
(D-OUV-INTERVALO no [E00](E00-exercicios-de-ouvido.md))

## Objetivo

Um tipo novo, `listen-interval`. O zywny toca duas notas, uma depois da
outra (melódico) ou juntas (harmônico), e o aluno escolhe o nome do
intervalo num botão ("2ª menor", "5ª justa"…). Funciona sem teclado.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md), [E01](E01-formato-e-rodada.md) e
  [E02](E02-som-e-tela.md): este passo repete o caminho deles. **Faça cada
  item no mesmo lugar em que o E01/E02 fez o do `listen-note`.**
- `docs/licoes/formato-v1.md`, seção `### listen-note` (escrita no E03).

## O formato

````markdown
```zywny-exercise
id: l8-ouvir-tom
type: listen-interval
title: Meio tom ou tom?
notes: {random: C4-G4, count: 10}
intervals: [m2, M2]
direction: up
play: melodic
pass: {accuracy: 70}
```
````

| Chave | Valor | Padrão |
| --- | --- | --- |
| `notes` | as notas de partida (lista ou sorteio; `count` = quantas perguntas) | — (obrigatória) |
| `intervals` | 2 ou mais nomes da tabela abaixo; os botões seguem esta ordem | — (obrigatória) |
| `direction` | `up` (a 2ª nota acima), `down` (abaixo) ou `both` (sorteado) | `up` |
| `play` | `melodic` (uma depois da outra) ou `harmonic` (juntas) | `melodic` |

| Nome no arquivo | Semitons | Botão |
| --- | --- | --- |
| `m2` | 1 | 2ª menor |
| `M2` | 2 | 2ª maior |
| `m3` | 3 | 3ª menor |
| `M3` | 4 | 3ª maior |
| `P4` | 5 | 4ª justa |
| `TT` | 6 | trítono |
| `P5` | 7 | 5ª justa |
| `m6` | 8 | 6ª menor |
| `M6` | 9 | 6ª maior |
| `m7` | 10 | 7ª menor |
| `M7` | 11 | 7ª maior |
| `P8` | 12 | oitava |

## O que fazer

### 1. Modelo — `course_model.dart`

- `enum IntervalName implements WireEnum` com os 12 valores da tabela, cada
  um com `wire` (`'m2'`…) e `semitones` (o nome **não** pode ser
  `Interval`, porque colide com o `Interval` do Flutter):
  ```dart
  enum IntervalName implements WireEnum {
    m2('m2', 1),
    M2('M2', 2),
    // … os 12, na ordem da tabela
    P8('P8', 12);

    const IntervalName(this.wire, this.semitones);

    @override
    final String wire;
    final int semitones;
  }
  ```
  Se o `flutter analyze` reclamar do nome em maiúscula (`M2`, `P5`), use
  `// ignore: constant_identifier_names` na linha, como no resto do
  projeto (procure por `constant_identifier_names`; se não houver,
  acrescente o `ignore`).
- `enum IntervalDirection implements WireEnum { up, down, both; … wire =>
  name }` e `enum IntervalPlay implements WireEnum { melodic, harmonic; … }`,
  no molde do `AnswerInput` do E01.
- `ExerciseType.listenInterval('listen-interval')`, no fim.
- `class ListenIntervalSpec extends ExerciseSpec` com `notes`
  (`NotesSpec`), `intervals` (`List<IntervalName>`), `direction`, `play`.

### 2. Vocabulário — `vocabulary.dart`

- `time-limit` em `kPassKeys`: acrescente `ExerciseType.listenInterval`.
- Em `_typeKeys`:
  ```dart
  ExerciseType.listenInterval: {
    'notes': _notes,
    'intervals': const KeyDef(ValueType.stringList, required: true, minItems: 2),
    'direction': KeyDef(ValueType.option, values: _wires(IntervalDirection.values), fallback: 'up'),
    'play': KeyDef(ValueType.option, values: _wires(IntervalPlay.values), fallback: 'melodic'),
  },
  ```

### 3. Leitura — `mark_parser.dart`, caso novo em `_buildExercise`

- `notes` com `_notes(f, issues, defaultCount: 10)`.
- `intervals`: para cada texto da lista, procure em `IntervalName.values`
  pelo `wire`. Se não achar, dê
  `issues.error(f.lineOf('intervals'), '`$texto` não é um intervalo; use: ${IntervalName.values.map((i) => i.wire).join(', ')}.')`.
  Se houver repetido, dê `'`intervals` repete um intervalo.'`. Em qualquer
  erro, `return null`.
- `direction` e `play` com `_enumOf`, padrões `up` e `melodic`.

### 4. A rodada — `question_kinds.dart`, `ListenIntervalKind`

```dart
const kIntervalLabels = {
  IntervalName.m2: '2ª menor',
  IntervalName.M2: '2ª maior',
  // … a coluna "Botão" da tabela
  IntervalName.P8: 'oitava',
};

class ListenIntervalKind extends ExerciseKind<ListenIntervalSpec> {
  const ListenIntervalKind();

  @override
  Future<QuestionRound> generate(
    ListenIntervalSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final roots = notesOf(spec.notes, rng);
    final labels = [for (final i in spec.intervals) kIntervalLabels[i]!];
    return QuestionRound([
      for (final root in roots)
        () {
          final index = rng.nextInt(spec.intervals.length);
          final down = switch (spec.direction) {
            IntervalDirection.up => false,
            IntervalDirection.down => true,
            IntervalDirection.both => rng.nextBool(),
          };
          final semitones = spec.intervals[index].semitones;
          final other = (root.midi + (down ? -semitones : semitones))
              .clamp(kLowestPianoMidi, kHighestPianoMidi);
          return Question(
            answers: labels,
            correct: index,
            sound: spec.play == IntervalPlay.harmonic
                ? [SoundCue([root.midi, other], seconds: 1.5)]
                : [SoundCue([root.midi]), SoundCue([other])],
          );
        }(),
    ]);
  }
}
```

(`kLowestPianoMidi`/`kHighestPianoMidi` vêm de
`package:zywny_music/note_name.dart`.) Registre em `exerciseKinds`.

### 5. Os outros lugares (os mesmos do E01, item 5)

- `exerciseSummary`: `case ListenIntervalSpec():` →
  `'Ouça o intervalo · ${countOf(spec.notes, fallback: 10)}'`.
- `course_render_check.dart`: `case ListenIntervalSpec():` devolve `null`.
- `exercise_source.dart`, `isQuestion`: acrescente
  `ExerciseType.listenInterval`.
- `exerciseNeedsMidi`: **não** muda (só botões).

### 6. A tela — `question_body.dart`

- `_isListen` passa a ser
  `widget.spec is ListenNoteSpec || widget.spec is ListenIntervalSpec`.
- `_usesKeyboard` não muda: o `listen-interval` usa botões.
- `_listenPrompt`: no começo, se `widget.spec is ListenIntervalSpec`,
  devolva uma versão curta: o ícone, o título **"Que intervalo é este?"**,
  o botão "Ouvir de novo", o texto "Escolha o intervalo." e o aviso
  `_noSound`. Extraia as partes repetidas para métodos pequenos, se ajudar;
  o `ListenNoteSpec` continua igual.
- `_buttonLabel` não muda: as respostas já são os rótulos.

### 7. Curso inicial e cobertura

a. Em `assets/cursos/iniciacao/lessons/08-acidentes.md`, na seção `## Tom e
meio tom` (L7), logo depois do bloco `zywny-keyboard` dela e antes de `##
Sustenido e bemol`, acrescente:

````markdown
Agora de ouvido: o zywny toca duas notas, uma depois da outra. A distância
entre elas é meio tom ou um tom?

```zywny-exercise
id: l8-ouvir-tom
type: listen-interval
title: Meio tom ou tom, subindo
notes: {random: C4-G4, count: 10}
intervals: [m2, M2]
direction: up
play: melodic
pass: {accuracy: 70}
```

```zywny-exercise
id: l8-ouvir-tom-descendo
type: listen-interval
title: Meio tom ou tom, descendo
notes: {random: D4-A4, count: 10}
intervals: [m2, M2]
direction: down
pass: {accuracy: 70}
```
````

b. Em `10-juntando-tudo.md`, no fim da lição:

````markdown
## Ouvir as notas juntas

Duas notas ao mesmo tempo. Quanto mais longe uma da outra, mais "aberto"
soa. Qual é a distância?

```zywny-exercise
id: l10-ouvir-juntas
type: listen-interval
title: Terça, quinta ou oitava
notes: {random: C4-C5, count: 10}
intervals: [M3, P5, P8]
direction: both
play: harmonic
pass: {accuracy: 70, time-limit: 20}
```
````

Os botões são rótulos fixos ("2ª menor"), e o texto da lição fala em
"meio tom" e "tom". A lição 08 não liga um ao outro. Por isso, acrescente
esta frase logo antes do primeiro exercício: "Nos botões, meio tom aparece
como **2ª menor** e um tom como **2ª maior**."

c. `test/course_coverage_test.dart`: colete e confira `direction` (`up`,
`down`, `both`) e `play` (`melodic`, `harmonic`) no molde do `input` do
E01. Confira também `intervals`: o curso precisa usar **pelo menos**
`m2`, `M2`, `M3`, `P5` e `P8`. Os outros sete ficam como exceção
explícita, com um comentário no molde do comentário dos tons (L284):
"intervalos menos comuns não cabem num curso para iniciantes".

### 8. Especificação — `docs/licoes/formato-v1.md`

Uma linha na tabela de tipos, `listen-interval` no `time-limit` da seção 7
e uma seção `### listen-interval` depois da `### listen-note`, com o
exemplo e as duas tabelas deste arquivo (chaves e nomes). Nada na seção 11.

## Testes

1. `course_reader_test.dart`: o exemplo do topo vira `ListenIntervalSpec`
   com `intervals == [IntervalName.m2, IntervalName.M2]`; os padrões
   (`up`, `melodic`); `intervals: [m2, X9]` dá erro que contém
   ``"`X9` não é um intervalo"``; `intervals: [m2, m2]` dá erro que contém
   `'repete'`; `intervals: [m2]` dá erro (mínimo 2, pelo `KeyDef`).
2. `exercise_questions_test.dart`, `group('listen-interval')`:
   - `notes: [C4]`, `intervals: [M3, P5]`, `direction: up`, `play:
     melodic`, semente fixa: a pergunta tem `answers == ['3ª maior', '5ª
     justa']`; o `sound` tem duas `SoundCue`, a 1ª `[60]` e a 2ª `[64]` ou
     `[67]`, e o `correct` aponta para o rótulo que corresponde;
   - `direction: down`: a segunda altura é **menor** que 60;
   - `play: harmonic`: uma `SoundCue` só, com duas alturas e `seconds ==
     1.5`;
   - `direction: both` com `count: 40`: aparecem as duas direções;
   - aluno simulado tudo certo → aprova.
3. `exercise_question_screens_test.dart`: um `testWidgets` sem teclado,
   `notes: [C4]`, `intervals: [M3, P5]`: aparece `'Que intervalo é
   este?'`; o `FakeSoundEngine` recebeu notas ligadas `[60, x]` com `x` em
   `{64, 67}`; tocar no botão certo (`x == 64` → `'3ª maior'`, senão `'5ª
   justa'`) leva a `'Exercício aprovado!'`.

## Fora de escopo

- Acordes (`listen-chord`).
- Responder o intervalo tocando as duas teclas.
- Rótulos em outra língua.

## Critérios de aceite

1. `cd packages/zywny_course_format && dart test` passa.
2. `flutter analyze` sem avisos novos; `flutter test` inteiro passa.
3. `just curso-validar validate assets/cursos/iniciacao` sem erros.
4. Manual (Linux): lição 8, "Meio tom ou tom, subindo", toca e aprova;
   lição 10, "Terça, quinta ou oitava", toca as duas notas juntas.

## Notas de execução

Feito em 2026-10-13, sem commit. Critérios 1–3 passam; o 4 (manual, com
ouvido e teclado) fica com o usuário.

**Resultados dos critérios de aceite:**

1. `cd packages/zywny_course_format && dart test`: "All tests passed!" (24
   testes; 4 deles novos em `course_reader_test.dart`).
2. `flutter analyze`: "No issues found!". `flutter test` inteiro: "All
   tests passed!" (+1023 ~11).
3. `dart run tool/zywny_course.dart validate assets/cursos/iniciacao`: saiu
   com 0 e sem erros (`just curso-validar` roda este comando).
4. Manual (Linux, lições 8 e 10): **pendente com o usuário**. Daqui não dá
   para ouvir o som nem tocar o teclado.

**Desvios do texto:**

- Os oito nomes em maiúscula (`M2`, `M3`, `P4`, `TT`, `P5`, `M6`, `M7`,
  `P8`) pediram `// ignore: constant_identifier_names` na linha de cada um,
  como o item 1 manda. Nenhum outro lugar do projeto usava o lint.
- `test/fixtures/cursos/erro-exercicios/esperado.txt`: a lista de tipos da
  mensagem "tipo de exercício desconhecido" ganhou `listen-interval` (o
  plano não listava este arquivo; o `course_validator_test` quebrava sem ele).
- `docs/licoes/formato-v1.md`: o padrão de `count` (10) ganhou
  `listen-interval` na mesma linha em que estava `listen-note`.
- Lição 10: a seção nova ficou **no fim**, como o plano pede, mas a frase
  "Quando passar no último exercício, o curso está completo. Parabéns!"
  vem antes dela e agora não aponta mais para o último exercício. Ficou
  como está; quem decide o texto é o autor do curso.

**Limite conhecido (sem correção neste passo):**

- `ListenIntervalKind` usa `clamp` na segunda nota. Se a nota de partida
  estiver tão alta (ou tão baixa) que o intervalo passe de A0 ou C8, o som
  sai mais curto que o intervalo da resposta, sem aviso. O curso inicial
  fica em C4–C5 e não chega perto. Corrigir pede uma decisão: recusar a
  faixa no leitor, ou sortear outra direção só nesses casos.

**Para quem for aceitar à mão:** a lição 8 tem dois exercícios
(`l8-ouvir-tom` e `l8-ouvir-tom-descendo`, botões "2ª menor" e "2ª maior");
a lição 10 tem `l10-ouvir-juntas`, com as duas notas soando juntas por 1,5 s
em cada pergunta. Os três são de botões: não precisam de teclado MIDI.
