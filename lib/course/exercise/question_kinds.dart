// I07 — tipos por pergunta: `find-key`, `name-note`, `count-beats`, `choice`.
//
// Cada tipo sorteia uma `QuestionRound` (determinística pela semente) com a
// partitura quando há (`name-note`, `count-beats`, `choice` com `abc`) e as
// perguntas com `highlightId` (`zn…` do I02) para a tela destacar.

import 'dart:math';
import 'dart:typed_data';

import '../../practice/hand.dart';
import '../format/course_files.dart';
import '../format/course_model.dart';
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

Hand handForPlayScore(HandChoice choice) => switch (choice) {
  HandChoice.right => Hand.direita,
  HandChoice.left => Hand.esquerda,
  HandChoice.both => Hand.ambas,
};
