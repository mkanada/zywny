// I02 — Tempo de render de uma partitura pequena de lição (risco 2 do I00:
// ~300 ms). Mede, no Linux, o ciclo do app nativo: arquivo temporário →
// libverovio num isolate → `.vsb` → parser. Mediana de 10 repetições.
//
// Roda fora do `just test`:
//
//   LESSON_TIMING=1 flutter test test/lesson_score_timing_manual_test.dart
//
// No celular, o mesmo roteiro está em `integration_test/lesson_score_timing_test.dart`
// (`flutter test integration_test/lesson_score_timing_test.dart -d <aparelho>`).
@Tags(['manual'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny_course_format/course_model.dart';
import 'package:zywny_music/note_name.dart';
import 'package:zywny/course/score/lesson_score.dart';
import 'package:zywny/course/score/round_score.dart';

import 'support/render_helper.dart';

void main() {
  final enabled = Platform.environment['LESSON_TIMING'] == '1';

  test(
    'mediana de render: 12 notas, 4 compassos de ritmo, duas pautas',
    () async {
      final rng = Random(7);
      final cases = {
        '12 notas em 3 compassos': notesScore(
          pickNotes(NoteRange.parse('C4-G5'), count: 12, rng: rng),
        ),
        '4 compassos de ritmo': rhythmScore(
          pickFigures(
            const [
              Figure.half,
              Figure.quarter,
              Figure.eighth,
              Figure.quarterRest,
            ],
            measures: 4,
            rng: rng,
          ),
          bpm: 70,
        ),
        'duas pautas, 12 notas': notesScore(
          pickNotes(NoteRange.parse('C3-C5'), count: 12, rng: rng),
          clef: Clef.grand,
        ),
      };
      final layout = lessonScoreLayout(1800);
      for (final entry in cases.entries) {
        final source = fromMusicXml(entry.value);
        final times = <int>[];
        for (var i = 0; i < 11; i++) {
          final watch = Stopwatch()..start();
          await renderBytes(
            source.bytes,
            source.fileName,
            pageWidth: layout.pageWidth,
            pageHeight: layout.pageHeight,
            options: layout.options,
          );
          times.add(watch.elapsedMilliseconds);
        }
        final first = times.removeAt(0); // a primeira carrega a biblioteca
        times.sort();
        // ignore: avoid_print
        print(
          'RENDER ${entry.key}: mediana ${times[times.length ~/ 2]} ms '
          '(min ${times.first}, máx ${times.last}, primeira $first)',
        );
      }
    },
    skip: enabled ? false : 'LESSON_TIMING=1 para rodar',
  );
}
