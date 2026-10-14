# E05 — Ouvido na leitura: a frase que soa e a mudança sorteada

**Repo:** zywny · **Depende de:** E04 · **Decisão necessária:** não (D-LEI
no [E00](E00-exercicios-de-ouvido.md))

## Objetivo

Tudo o que a pergunta "Onde mudou?" precisa, em **Dart puro**, sem tela:

1. a partitura gerada passa a ter um id em cada nota;
2. a frase vira notas com hora marcada (as duas mãos juntas, no ritmo
   escrito), precedida do acorde da tônica;
3. uma mudança sorteada (altura, ritmo ou acidente esquecido) sai dessa
   frase, dizendo em que compasso caiu e que notas escritas ela tocou;
4. uma função monta a `Question` pronta: partitura, o que soa, o que está
   escrito, os botões e a resposta certa;
5. o `cue_player` toca notas com hora marcada.

Nada aparece na tela neste passo. O E06 liga isto ao curso e o E07 à tela.

## Ler antes (só isto)

- [E00](E00-exercicios-de-ouvido.md), seção "Segunda parte" e as decisões
  D-LEI.
- `lib/sight_reading/sight_steps.dart`: `SightStep` (L16–L72) e
  `sightStep` (L549).
- `lib/sight_reading/sight_generator.dart`: L1–L110 (`SightNote`,
  `SightExercise`, `generateSight`).
- `lib/sight_reading/sight_score.dart`: todo (177 linhas).
- `lib/course/exercise/exercise_round.dart`: L75–L140 (`QuestionRound`,
  `SoundCue`, `Question`).
- `lib/course/exercise/cue_player.dart`: todo (31 linhas).
- `lib/course/score/round_score.dart`: L20–L25 (`roundNoteId`) e L330–L345
  (o `<note id=…>`).
- `test/sight_score_test.dart` e `test/cue_player_test.dart`, como molde.

## Contexto que você precisa

- `SightNote.degree` é o grau da escala (1 = tônica, 8 = oitava), ou `null`
  numa pausa. `units` está em dezesseis avos (4 = semínima, 16 =
  semibreve). Cada exercício tem `sightMeasures` (4) compassos por pauta.
- A pauta de sol começa na oitava 4 e a de fá na oitava 3
  (`_rightOctave`, `_leftOctave` em `sight_score.dart:13`). A conta de grau
  para letra e oitava está em `_writeStaff` (L84–L95): `n = índice da letra
  da tônica + grau - 1`, letra `n % 7`, oitava `base + n ~/ 7`, e a
  alteração vem de `KeySignature.parse(step.tonic).alterOf(letra)`.
- O Verovio **preserva** o atributo `id` de `<note>` no `.vsb` (é assim que
  o `name-note` destaca a nota da vez). Use o mesmo mecanismo.
- Num passo de uma mão (`SightHands.right`/`left`), a outra pauta só tem
  pausas. Pausa não soa e não muda.
- `playCues` (E02) põe 0,3 s de silêncio entre um `SoundCue` e o seguinte:
  não serve para melodia no ritmo nem para duas mãos com figuras
  diferentes. Por isso este passo cria `TimedNote` e `playTimed`.
- Comentários: os arquivos de `lib/sight_reading/` comentam em português.
  Siga-os.

## O que fazer

### 1. Ids e altura MIDI — `lib/sight_reading/sight_score.dart`

a. Crie e exporte:

```dart
/// O id (`id` do `<note>`) da nota [index] (base 0, contando pausas) do
/// compasso [measure] (base 0) na pauta [staff] (1 = sol, 2 = fá). O Verovio
/// o preserva, e a tela destaca a nota por ele.
String sightNoteId(int staff, int measure, int index) =>
    's$staff-m${measure + 1}-n${index + 1}';

/// A altura MIDI do [degree] na pauta [staff] do [step], com a armadura.
int sightMidi(SightStep step, int degree, {required int staff});
```

Implemente `sightMidi` com a mesma conta do `_writeStaff` (letra, oitava e
`alterOf`), e use `Pitch` de `package:zywny_music/note_name.dart` ou a
conta direta (`12 * (oitava + 1) + semitom da letra + alter`). Escreva um
teste que compara as duas para os graus 1 a 8 nas duas pautas, em `C`, `G`
e `Bb`.

b. Em `_writeStaff`, receba o índice do compasso e escreva
`<note id="${sightNoteId(staff, measure, i)}">` **só nas notas** (pausa
continua `<note>` sem id). `sightScoreXml` passa `m` adiante.

c. `test/sight_score_test.dart` continua passando; acrescente um teste: o
XML do 1a tem `id="s1-m1-n1"` e nenhum id começando por `s2-` (a pauta de
fá só tem pausas).

### 2. A frase como eventos — `lib/sight_reading/sight_phrase.dart` (novo)

```dart
/// Uma nota escrita ou tocada da frase. [start] e [units] em dezesseis avos
/// desde o começo do exercício; [ids] são as notas escritas que ela
/// representa (uma, ou duas quando a mudança juntou figuras).
class SightEvent {
  const SightEvent({
    required this.staff,
    required this.measure,
    required this.start,
    required this.units,
    required this.midi,
    required this.ids,
  });

  final int staff;
  final int measure; // base 0
  final int start;
  final int units;
  final int midi;
  final List<String> ids;
}

/// As notas de [ex], das duas pautas, em ordem de [SightEvent.start] (a pauta
/// de sol antes da de fá no mesmo instante). Pausas não entram.
List<SightEvent> sightEvents(SightExercise ex);
```

`start` acumula `units` de todas as figuras anteriores da pauta, inclusive
pausas, e soma `measure * step.unitsPerMeasure`. `ids` é
`[sightNoteId(staff, measure, índice da figura no compasso)]`.

### 3. Notas com hora marcada — `exercise_round.dart` e `cue_player.dart`

a. Em `lib/course/exercise/exercise_round.dart`, ao lado de `SoundCue`:

```dart
/// Uma nota com hora marcada: soa em [start] segundos desde o começo, por
/// [seconds] segundos.
@immutable
class TimedNote {
  const TimedNote(this.pitch, this.start, this.seconds);

  final int pitch;
  final double start;
  final double seconds;
}
```

b. Em `cue_player.dart`, acrescente:

```dart
/// Cala o que estiver soando e agenda [notes] a partir de
/// `engine.earliestScheduleSeconds`. Devolve quanto tudo dura (0 sem notas).
double playTimed(SoundEngine engine, List<TimedNote> notes, {int velocity = 90});
```

Uma nota ligada (`0x90`) em `início + start` e desligada (`0x80`) em
`início + start + seconds`, tudo num `engine.schedule` só, como o
`playCues`.

c. Em `sight_phrase.dart`:

```dart
/// Andamento em que a frase soa (D-LEI-ANDAMENTO): o do passo, nunca
/// abaixo de 72.
int sightListenBpm(SightStep step) => max(step.bpm, 72);

/// Segundos em que o acorde da tônica soa antes da frase, e a pausa depois.
const kSightChordSeconds = 1.2;
const kSightChordGap = 0.6;

/// [events] como notas com hora marcada, em [bpm] semínimas por minuto.
/// Com [withTonic], o acorde da tônica (graus 1, 3 e 5 na pauta de sol e o
/// grau 1 na de fá) soa antes, por [kSightChordSeconds].
List<TimedNote> sightTimedNotes(
  SightStep step,
  List<SightEvent> events, {
  required int bpm,
  bool withTonic = true,
});
```

Um dezesseis avos dura `60 / bpm / 4` segundos. Cada nota soa por **95%**
do seu valor (as notas repetidas se separam). Com o acorde, a frase começa
em `kSightChordSeconds + kSightChordGap`.

### 4. A mudança — `lib/sight_reading/sight_change.dart` (novo)

```dart
/// O que muda entre o escrito e o que soa.
enum SightChange { pitch, rhythm, accidental }

/// As mudanças que cabem no [step]: `pitch` sempre; `rhythm` sempre (uma
/// figura de 2 dezesseis avos ou mais pode ser dividida); `accidental` só
/// com armadura (`step.tonic != 'C'`).
List<SightChange> sightChangesFor(SightStep step);

/// O que soa depois da mudança.
class SightChanged {
  const SightChanged({
    required this.played,
    required this.measure,
    required this.changedIds,
    required this.description,
  });

  /// Os eventos que soam.
  final List<SightEvent> played;

  /// O compasso (base 0) onde a mudança caiu.
  final int measure;

  /// As notas escritas que soam diferente (para destacar na revelação).
  final Set<String> changedIds;

  /// O que mudou, para a revelação: "uma nota soou mais aguda", "uma nota
  /// soou mais grave", "uma nota soou dividida em duas", "duas notas soaram
  /// como uma só", "a nota soou sem o acidente da armadura".
  final String description;
}

/// Aplica uma mudança de [change] a [written]. `null` quando não há nota
/// onde aplicá-la (por exemplo, `accidental` sem nenhuma nota alterada pela
/// armadura).
SightChanged? changeSight(
  SightStep step,
  List<SightEvent> written,
  SightChange change,
  Random rng,
);
```

Regras, em todas as mudanças:

- A **primeira nota** da frase (o primeiro evento da lista) nunca muda.
- Sorteie primeiro o **compasso**, entre os que têm alguma nota elegível;
  depois a nota, dentro dele. Assim os quatro compassos saem com chance
  parecida, mesmo quando um tem muitas notas.

**`pitch`:** troque o `midi` do evento pelo de outro grau na mesma pauta.
O deslocamento, em graus, é ±2 ou ±3 até o nível 6 e ±1 ou ±2 do 7 em
diante (D-LEI-MUDANCA). O grau novo fica entre 1 e `max(step.high, 5)` na
pauta de sol e entre 1 e 8 na de fá; se sair da faixa, use o sinal
contrário. Guarde o grau escrito de cada evento (acrescente um campo
`degree` ao `SightEvent`, se ajudar) para fazer a conta com `sightMidi`.
`changedIds` = os `ids` do evento.

**`rhythm`:** escolha, com chance igual, entre:

- **dividir**: um evento com `units >= 2` vira dois, com a mesma altura;
  as metades são `units ~/ 2` e o resto, e para figuras pontuadas (3, 6,
  12) a divisão é `2+1`, `4+2`, `8+4`. Os dois eventos novos levam os
  mesmos `ids`.
- **juntar**: dois eventos **seguidos na mesma pauta e no mesmo compasso**,
  sem pausa entre eles, viram um só, com a altura do primeiro e a soma dos
  `units`. Só quando a soma é uma figura (2, 3, 4, 6, 8, 12 ou 16) e, em
  4/4, os dois ficam na mesma metade do compasso. `ids` = os dos dois.

Se não houver par para juntar, divida. `changedIds` = os `ids` envolvidos.

**`accidental`:** só notas cuja letra a armadura altera
(`alterOf(letra) != 0`). O `midi` perde a alteração (`midi - alter`): em
Sol, soa Fá natural onde está escrito Fá♯. Sem nenhuma nota assim,
devolva `null`.

### 5. A pergunta pronta — `lib/sight_reading/sight_listen.dart` (novo)

a. Em `exercise_round.dart`, um campo novo e opcional em `Question`:

```dart
  /// `listen-score` (E05): a partitura desta pergunta e as duas versões da
  /// frase. `null` nos outros tipos.
  final ScoreComparison? compare;
```

e a classe:

```dart
/// Uma pergunta de "onde mudou?": a partitura escrita, o que soa, o que
/// está escrito e o que mudou.
@immutable
class ScoreComparison {
  const ScoreComparison({
    required this.scoreBytes,
    required this.fileName,
    required this.played,
    required this.written,
    required this.changedIds,
    this.measure,
    this.description,
  });

  final Uint8List scoreBytes;
  final String fileName;

  /// O que o zywny toca na pergunta (com a mudança, se houver).
  final List<TimedNote> played;

  /// A frase como está escrita (o botão "Ouvir o escrito" da revelação).
  final List<TimedNote> written;

  /// As notas escritas que soam diferente; vazio quando nada mudou.
  final Set<String> changedIds;

  /// O compasso da mudança (base 0); `null` quando nada mudou.
  final int? measure;

  /// `SightChanged.description`; `null` quando nada mudou.
  final String? description;
}
```

b. Em `sight_listen.dart`:

```dart
/// Como o aluno responde a pergunta de ouvido.
enum SightAnswer { measure, sameDifferent }

/// A pergunta de ouvido sobre a partitura de [step] sorteada com [seed].
/// [change] `null` sorteia entre `sightChangesFor(step)`. Com
/// [SightAnswer.sameDifferent], metade das vezes nada muda.
Question sightListenQuestion(
  SightStep step,
  int seed, {
  SightChange? change,
  SightAnswer answer = SightAnswer.measure,
  int? bpm,
});
```

- A partitura é `generateSight(step, Random(seed))`, a **mesma** que o
  treino de leitura monta com essa semente
  (`SightReadingSource._round`). O XML vem de `sightScoreXml` e os bytes de
  `utf8Bytes` (`lib/course/score/abc_source.dart:64`); `fileName`
  `'ouvido-${step.name}.musicxml'`.
- Os sorteios da mudança usam `Random(seed ^ 0x5eed)`, para não mexer na
  sequência que gera a partitura.
- Se `changeSight` devolver `null`, tente de novo com `seed + 1`, `seed +
  2`… (a partitura muda junto), até 50 vezes; depois, lance `StateError`.
  Um passo com armadura sem nenhuma nota alterada em 50 partituras não
  deve existir (há teste).
- `measure`: `answers` = `['1', '2', '3', '4']` (`sightMeasures`) e
  `correct` = o compasso da mudança.
- `sameDifferent`: `answers` = `['Igual', 'Diferente']`; com
  `Random(seed ^ 0x5eed).nextBool()` verdadeiro, nada muda (`played` =
  `written`, `changedIds` vazio, `measure` nulo) e `correct` = 0.
- `played` e `written` vêm de `sightTimedNotes` com
  `bpm ?? sightListenBpm(step)` e o acorde da tônica.

## Testes

1. `test/sight_score_test.dart`: os ids (item 1c) e `sightMidi` igual à
   conta do XML (item 1a).
2. `test/cue_player_test.dart`: `playTimed` agenda liga e desliga nas horas
   certas, a partir de `earliestScheduleSeconds`, e devolve a duração.
3. `test/sight_listen_test.dart` (novo):
   - `sightEvents` do 1a (semibreves, mão direita): 4 eventos, `start` 0,
     16, 32 e 48, todos na pauta 1;
   - `sightTimedNotes` a 60 bpm: a semibreve dura 4 s × 0,95; com o acorde,
     a primeira nota da frase começa em 1,8 s e o acorde tem as alturas da
     tônica (60, 64, 67 e 48 em Dó);
   - para cada um dos 80 passos e 20 sementes: `pitch` muda exatamente um
     evento, nunca o primeiro, e o `midi` novo é diferente do escrito;
   - `rhythm`: a soma dos `units` de cada pauta não muda, e o número de
     eventos muda em exatamente 1 (mais 1 ao dividir, menos 1 ao juntar);
   - `accidental` no 11c (Sol): a nota mudada é um Fá e soa um semitom
     abaixo; no 1a (Dó), `sightChangesFor` não tem `accidental`;
   - `sightListenQuestion` com a mesma semente devolve a mesma pergunta;
     com `measure`, `correct` está entre 0 e 3 e é o compasso de um dos
     `changedIds`; com `sameDifferent` e 40 sementes, aparecem as duas
     respostas;
   - os quatro compassos aparecem como resposta em 40 sementes do 5c.

## Fora de escopo

- O tipo `listen-score` no curso (E06) e a tela (E07).
- Mudar mais de uma nota por pergunta.
- Mudança na fórmula de compasso ou no andamento.

## Critérios de aceite

1. `flutter analyze` sem avisos novos; `flutter test` inteiro passa.
2. Os testes novos do item "Testes" existem e passam.
3. O treino de leitura continua igual para o aluno: os testes `sight_*`
   passam sem mudar o que conferem (só o teste novo dos ids é novo).

## Notas de execução

Feito em 2026-10-13, sem commit. Só Dart puro: nada aparece na tela.

**Arquivos:** `lib/sight_reading/sight_score.dart` (ids, `sightAlter`,
`sightMidi`), `lib/sight_reading/sight_phrase.dart` (novo: `SightEvent`,
`sightEvents`, `sightTimedNotes`), `lib/sight_reading/sight_change.dart`
(novo: `SightChange`, `changeSight`), `lib/sight_reading/sight_listen.dart`
(novo: `sightListenQuestion`), `lib/course/exercise/exercise_round.dart`
(`TimedNote`, `ScoreComparison`, `Question.compare`),
`lib/course/exercise/cue_player.dart` (`playTimed`). Testes: os de
`sight_score_test.dart` e `cue_player_test.dart` ganharam casos, e
`test/sight_listen_test.dart` é novo.

**Desvios do plano:**

1. **11a e 11b não têm acidente.** O plano diz que um passo com armadura
   sempre tem nota alterada em 50 partituras. Não é verdade para 11a e 11b
   (sol): os padrões desses passos não chegam ao grau 7 (o Fá♯) em 50
   sementes. `changeSight(..., accidental)` devolve `null` neles, e
   `sightListenQuestion(..., change: accidental)` lança `StateError`. O
   sorteio aleatório de `change` não sofre com isso: tenta outra mudança na
   próxima semente. Não mexi no gerador, porque o treino de leitura tem de
   continuar igual. O teste confere exatamente `['11a', '11b']` como os
   únicos passos sem acidente. **Para o E06:** o formato do `listen-score`
   deve recusar `change: accidental` nesses dois passos, em vez de deixar
   chegar à tela.
2. **`SightEvent.degree` e `copyWith`** foram acrescentados. O plano previa
   o campo de grau como opcional; sem ele a mudança de altura não tem como
   fazer a conta com `sightMidi`.
3. **`sightMidi` não foi refatorado dentro de `_writeStaff`.** A conta fica
   duplicada, como o plano pediu ("a mesma conta"). O teste compara as duas
   com o XML real (graus 1 a 8, nas duas pautas, em C, G e Bb).
4. **`Question.prompt` fica `null`.** O texto da pergunta ("Em que compasso?",
   "Igual ou diferente?") é do E07, que é quem mostra a tela.
5. **`playTimed` devolve o fim da última nota** (o maior `start + seconds`),
   não a soma. Sem notas, devolve 0 e ainda cala o que soava.
6. **`sameDifferent`:** o primeiro sorteio de `Random(seed ^ 0x5eed)` decide
   "igual" (`nextBool()` verdadeiro). Se a semente não cabe, a pergunta
   passa à próxima semente, como no caso de `measure`.

**Medidas do acidente por passo** (50 sementes, passos com armadura; o
número é em quantas partituras aparece uma nota alterada pela armadura):
11c 2/50, 11d 23/50, 12a e 12b 13/50, 12c 14/50, 12d 36/50, 13a e 13b
42/50, 15a e 15b 45/50; os demais de 13c a 20d ficam entre 49 e 50/50. Os
passos 11a e 11b estão em 0/50.

**Testes novos (E05):**

- `sightEvents` do 1a: 4 semibreves, `start` 0, 16, 32, 48, todas na pauta
  de sol, com o id `s1-m1-n1` na primeira.
- `sightTimedNotes` a 60 bpm: a semibreve dura 3,8 s (4 s × 0,95); com o
  acorde, a frase começa em 1,8 s e o acorde é 60, 64, 67 e 48 em Dó.
- `pitch`, 80 passos × 20 sementes: uma nota muda, nunca a primeira, o
  `midi` novo é o de `sightMidi` para o grau novo.
- `rhythm`, 80 × 20: a soma de cada pauta por compasso não muda; o número
  de eventos muda em 1 (divide: +1, uma nota no `changedIds`; junta: −1,
  duas notas).
- `accidental` no 11c: a nota mudada é o grau 7 (Fá) e soa um semitom
  abaixo do escrito. No 1a, `sightChangesFor` não tem `accidental` e
  `changeSight` devolve `null`.
- `sightListenQuestion`: a mesma semente dá a mesma pergunta; no 5c, em 40
  sementes, as quatro respostas de compasso aparecem e o certo é o de uma
  das notas em `changedIds`; `sameDifferent` dá as duas respostas (0 e 1)
  e, quando "igual", `changedIds` e `measure` vêm vazios.
- `playTimed`: liga e desliga na hora certa a partir de
  `earliestScheduleSeconds`, devolve o fim (2,0 s no exemplo), notas
  sobrepostas soam cada uma na sua hora, e sem notas não agenda nada.

**Aceite:**

1. `dart format` nos arquivos tocados: sem diferenças. `flutter analyze`:
   "No issues found!" (o import sobrando de `sight_listen_test.dart` foi
   removido).
2. Os arquivos de teste dos casos novos: 29 testes passam (sight_listen,
   sight_score e cue_player).
3. Treino de leitura: `sight_generator_test`, `sight_steps_test` e os demais
   `sight_*` passam sem mudar o que conferem. A única mudança visível é o
   `id` nas notas do XML.
4. `flutter test` inteiro: RESULTADO_SUITE_AQUI.
