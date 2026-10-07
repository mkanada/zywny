import 'dart:math';

import '../../practice/hand.dart';
import '../format/course_files.dart';
import '../format/course_model.dart';
import '../../music/note_name.dart';
import '../score/lesson_score.dart';
import '../score/round_score.dart';
import 'exercise_round.dart';
import 'question_kinds.dart';
import 'timed_kinds.dart';

/// O que um `type` de exercício sabe fazer: sortear uma rodada do [spec].
/// Roda sem tela e sem relógio; [rng] com semente dá a mesma rodada.
abstract class ExerciseKind<T extends ExerciseSpec> {
  const ExerciseKind();

  /// Assíncrono porque alguns tipos leem um `file:` da pasta do curso.
  Future<ExerciseRound> generate(T spec, CourseFiles files, Random rng);
}

/// Os tipos que já têm implementação. O I07 acrescenta `find-key`,
/// `name-note`, `count-beats` e `choice`; o I08, `rhythm` e `play-score`.
final Map<ExerciseType, ExerciseKind> exerciseKinds = {
  ExerciseType.playNotes: const PlayNotesKind(),
  ExerciseType.findKey: const FindKeyKind(),
  ExerciseType.nameNote: const NameNoteKind(),
  ExerciseType.countBeats: const CountBeatsKind(),
  ExerciseType.choice: const ChoiceKind(),
  ExerciseType.rhythm: const RhythmKind(),
  ExerciseType.playScore: const PlayScoreKind(),
};

/// A rodada de [spec], pelo tipo certo; tipo sem implementação ainda lança
/// [UnimplementedError].
Future<ExerciseRound> generateRound(
  ExerciseSpec spec,
  CourseFiles files,
  Random rng,
) {
  final kind = exerciseKinds[spec.type];
  if (kind == null) {
    throw UnimplementedError(
      'o tipo de exercício `${spec.type.wire}` ainda não roda',
    );
  }
  return kind.generate(spec, files, rng);
}

/// As notas de [spec]: a lista fixa do autor ou o sorteio.
List<Pitch> notesOf(
  NotesSpec spec,
  Random rng, {
  Accidentals accidentals = Accidentals.none,
  String? key,
}) => switch (spec) {
  FixedNotes() => spec.notes,
  RandomNotes() => pickNotes(
    spec.range,
    count: spec.count,
    only: spec.only,
    accidentals: accidentals,
    key: key,
    rng: rng,
  ),
};

/// `play-notes`: lê cada nota na pauta e toca, no modo espera. Duas pautas
/// (`clef: grand`) pedem as duas mãos; com uma pauta só, a pauta 1 (o `Hand`
/// só escolhe pautas). O app **não** toca a outra mão.
class PlayNotesKind extends ExerciseKind<PlayNotesSpec> {
  const PlayNotesKind();

  @override
  Future<ScoreRound> generate(
    PlayNotesSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final notes = notesOf(
      spec.notes,
      rng,
      accidentals: spec.accidentals,
      key: spec.key,
    );
    final source = fromMusicXml(
      notesScore(notes, clef: spec.clef, key: spec.key),
    );
    return ScoreRound(
      bytes: source.bytes,
      fileName: source.fileName,
      mode: PlayMode.wait,
      hand: spec.clef == Clef.grand ? Hand.ambas : Hand.direita,
      pitches: [for (final p in notes) p.midi],
      noteIds: [for (var i = 0; i < notes.length; i++) roundNoteId(i)],
    );
  }
}
