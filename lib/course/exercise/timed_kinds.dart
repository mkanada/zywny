// I08 — tipos com tempo: `rhythm` e `play-score`.
//
// `rhythm` toca uma altura só no tempo real, com contagem e metrônomo;
// `play-score` toca a partitura do autor em espera ou tempo real, com
// `hand`, `measures` e `bpm`.

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
import 'question_kinds.dart' show handForPlayScore;

/// `rhythm`: uma altura só (`note`) no ritmo sorteado ou escrito.
class RhythmKind extends ExerciseKind<RhythmSpec> {
  const RhythmKind();

  @override
  Future<ScoreRound> generate(
    RhythmSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    if (spec.abc != null) {
      final body = spec.abc!;
      final Uint8List bytes;
      final String fileName;
      if (abcIsComplete(body)) {
        bytes = utf8Bytes(body);
        fileName = 'lesson.abc';
      } else {
        // Corpo sem `X:`: cabeçalho com o `time` do exercício.
        bytes = utf8Bytes(abcSource(body, time: spec.time));
        fileName = 'lesson.abc';
      }
      return ScoreRound(
        bytes: bytes,
        fileName: fileName,
        mode: PlayMode.realtime,
        hand: Hand.direita,
      );
    }
    final figures = pickFigures(
      spec.figures!,
      measures: spec.measures!,
      time: spec.time,
      rng: rng,
    );
    final source = fromMusicXml(
      rhythmScore(figures, time: spec.time, pitch: spec.note, bpm: spec.bpm),
    );
    final pitches = [
      for (final figure in figures)
        if (!figure.rest) spec.note.midi,
    ];
    var noteIndex = 0;
    final noteIds = [
      for (final figure in figures)
        if (!figure.rest) roundNoteId(noteIndex++),
    ];
    return ScoreRound(
      bytes: source.bytes,
      fileName: source.fileName,
      mode: PlayMode.realtime,
      hand: Hand.direita,
      pitches: pitches,
      noteIds: noteIds,
    );
  }
}

/// `play-score`: a partitura do autor, em espera ou tempo real.
class PlayScoreKind extends ExerciseKind<PlayScoreSpec> {
  const PlayScoreKind();

  @override
  Future<ScoreRound> generate(
    PlayScoreSpec spec,
    CourseFiles files,
    Random rng,
  ) async {
    final Uint8List bytes;
    final String fileName;
    switch (spec.source) {
      case AbcSource(:final abc):
        if (abcIsComplete(abc)) {
          bytes = utf8Bytes(abc);
        } else {
          bytes = utf8Bytes(abcSource(abc));
        }
        fileName = 'lesson.abc';
      case FileSource(:final path):
        bytes = await files.read(path);
        fileName = path.split('/').last;
    }
    return ScoreRound(
      bytes: bytes,
      fileName: fileName,
      mode: spec.mode,
      hand: handForPlayScore(spec.hand),
      measures: spec.measures,
      bpm: spec.bpm,
    );
  }
}
