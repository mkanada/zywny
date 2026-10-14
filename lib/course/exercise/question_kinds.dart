// I07 — tipos por pergunta: `find-key`, `name-note`, `count-beats`, `choice`,
// `listen-note` (E01: o som vai no E02), `listen-interval` (E04) e
// `listen-score` (E06).
//
// Cada tipo sorteia uma `QuestionRound` (determinística pela semente) com a
// partitura quando há (`name-note`, `count-beats`, `choice` com `abc`) e as
// perguntas com `highlightId` (`zn…` do I02) para a tela destacar.

import 'dart:math';
import 'dart:typed_data';

import '../../practice/hand.dart';
import '../../sight_reading/sight_change.dart';
import '../../sight_reading/sight_listen.dart';
import '../../sight_reading/sight_steps.dart';

import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/course_model.dart';

import 'package:zywny_music/note_name.dart';

import '../score/abc_source.dart';
import '../score/lesson_score.dart';
import '../score/round_score.dart';
import 'exercise_kind.dart';
import 'exercise_round.dart';

/// `find-key`: vê um nome e toca a tecla. `count` padrão 10.
class FindKeyKind extends ExerciseKind<FindKeySpec> {
  const FindKeyKind();

  @override
  Future<QuestionRound> generate(
    FindKeySpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final notes = notesOf(spec.notes, rng);
    final any = spec.octave == OctaveRule.any;
    return QuestionRound([
      for (final pitch in notes)
        Question(expectedPitch: pitch.midi, anyOctave: any),
    ]);
  }
}

/// `name-note`: lê a nota destacada e toca o botão com o nome.
class NameNoteKind extends ExerciseKind<NameNoteSpec> {
  const NameNoteKind();

  @override
  Future<QuestionRound> generate(
    NameNoteSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final notes = notesOf(spec.notes, rng, key: spec.key);
    final source = fromMusicXml(
      notesScore(notes, clef: spec.clef, key: spec.key),
    );
    final choices = spec.choices;
    return QuestionRound(
      [
        for (var i = 0; i < notes.length; i++)
          Question(
            answers: choices,
            correct: choices.indexOf(notes[i].step),
            highlightId: roundNoteId(i),
          ),
      ],
      scoreBytes: source.bytes,
      fileName: source.fileName,
    );
  }
}

/// `count-beats`: toca o botão com quantos tempos vale a figura destacada.
class CountBeatsKind extends ExerciseKind<CountBeatsSpec> {
  const CountBeatsKind();

  @override
  Future<QuestionRound> generate(
    CountBeatsSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final figures = pickCountBeatsFigures(
      spec.figures,
      count: spec.count,
      time: spec.time,
      rng: rng,
    );
    final source = fromMusicXml(
      rhythmScore(figures, time: spec.time, withRestIds: true),
    );
    final options = beatOptions(spec.figures, spec.time);
    final labels = [for (final o in options) o.$2];
    return QuestionRound(
      [
        for (var i = 0; i < figures.length; i++)
          Question(
            answers: labels,
            correct: labels.indexOf(
              beatLabel(beatsOfFigure(figures[i], spec.time)),
            ),
            highlightId: roundNoteId(i),
          ),
      ],
      scoreBytes: source.bytes,
      fileName: source.fileName,
    );
  }
}

/// `choice`: uma pergunta de múltipla escolha (uma por exercício).
class ChoiceKind extends ExerciseKind<ChoiceSpec> {
  const ChoiceKind();

  @override
  Future<QuestionRound> generate(
    ChoiceSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    Uint8List? scoreBytes;
    String? fileName;
    if (spec.abc != null) {
      final abc = abcSource(spec.abc!);
      scoreBytes = utf8Bytes(abc);
      fileName = 'lesson.abc';
    }
    return QuestionRound(
      [
        Question(
          prompt: spec.question,
          answers: spec.options,
          correct: spec.answer,
        ),
      ],
      scoreBytes: scoreBytes,
      fileName: fileName,
      imagePath: spec.image,
    );
  }
}

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

/// Rótulo de cada intervalo nos botões (a coluna "Botão" do E04).
const kIntervalLabels = {
  IntervalName.m2: '2ª menor',
  IntervalName.M2: '2ª maior',
  IntervalName.m3: '3ª menor',
  IntervalName.M3: '3ª maior',
  IntervalName.P4: '4ª justa',
  IntervalName.TT: 'trítono',
  IntervalName.P5: '5ª justa',
  IntervalName.m6: '6ª menor',
  IntervalName.M6: '6ª maior',
  IntervalName.m7: '7ª menor',
  IntervalName.M7: '7ª maior',
  IntervalName.P8: 'oitava',
};

/// `listen-interval`: toca duas notas (uma depois da outra ou juntas) e o
/// aluno escolhe o nome do intervalo num botão.
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
          final other = (root.midi + (down ? -semitones : semitones)).clamp(
            kLowestPianoMidi,
            kHighestPianoMidi,
          );
          return Question(
            answers: labels,
            correct: index,
            sound: spec.play == IntervalPlay.harmonic
                ? [
                    SoundCue([root.midi, other], seconds: 1.5),
                  ]
                : [
                    SoundCue([root.midi]),
                    SoundCue([other]),
                  ],
          );
        }(),
    ]);
  }
}

/// `listen-score`: uma partitura do treino de leitura por pergunta, com uma
/// diferença (ou nenhuma) que o aluno acha ouvindo a frase.
class ListenScoreKind extends ExerciseKind<ListenScoreSpec> {
  const ListenScoreKind();

  @override
  Future<QuestionRound> generate(
    ListenScoreSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final step = sightStepNamed(spec.step)!; // o leitor já conferiu o nome
    if (spec.answer == ScoreAnswer.dictation) {
      // Cada frase do ditado dá uma pergunta por nota (E09).
      return QuestionRound([
        for (var i = 0; i < spec.count; i++)
          ...sightDictationQuestions(step, rng.nextInt(1 << 31), bpm: spec.bpm),
      ]);
    }
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

SightChange _changeOf(ScoreChange change) => switch (change) {
  ScoreChange.pitch => SightChange.pitch,
  ScoreChange.rhythm => SightChange.rhythm,
  ScoreChange.accidental => SightChange.accidental,
};

SightAnswer _answerOf(ScoreAnswer answer) => switch (answer) {
  ScoreAnswer.measure => SightAnswer.measure,
  ScoreAnswer.sameDifferent => SightAnswer.sameDifferent,
  ScoreAnswer.note => SightAnswer.note,
  ScoreAnswer.dictation => throw ArgumentError.value(
    answer,
    'answer',
    'o ditado não passa por sightListenQuestion',
  ),
};

Hand handForPlayScore(HandChoice choice) => switch (choice) {
  HandChoice.right => Hand.direita,
  HandChoice.left => Hand.esquerda,
  HandChoice.both => Hand.ambas,
};
