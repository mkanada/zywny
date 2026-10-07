// I02 — Tempo de render de uma partitura pequena de lição **no aparelho**
// (risco 2 do I00: ~300 ms). O mesmo roteiro de
// `test/lesson_score_timing_manual_test.dart`, mas pelo `ScoreRenderer` do app
// (nativo no Android, wasm na Web) em vez do helper de teste.
//
//   flutter test integration_test/lesson_score_timing_test.dart -d <aparelho>
//
// Imprime `RENDER <caso>: mediana N ms (…)` — copie para as notas de
// execução do I02. Em debug o número é pessimista na parte Dart (o Verovio é
// C++ nativo e pesa igual).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zywny_course_format/course_model.dart';
import 'package:zywny_music/note_name.dart';
import 'package:zywny/course/score/lesson_score.dart';
import 'package:zywny/course/score/round_score.dart';
import 'package:zywny/render/score_renderer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mediana de render: 12 notas, 4 compassos de ritmo, duas pautas',
    (tester) async {
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
      // A largura de um celular em paisagem, em pixels do dispositivo.
      final layout = lessonScoreLayout(2054);
      final renderer = createScoreRenderer();
      for (final entry in cases.entries) {
        final source = fromMusicXml(entry.value);
        final times = <int>[];
        for (var i = 0; i < 11; i++) {
          final watch = Stopwatch()..start();
          await renderer.render(
            ScoreRenderRequest(
              source: source.bytes,
              fileName: source.fileName,
              pageWidth: layout.pageWidth,
              pageHeight: layout.pageHeight,
              options: layout.options,
            ),
          );
          times.add(watch.elapsedMilliseconds);
        }
        final first = times.removeAt(0);
        times.sort();
        // ignore: avoid_print
        print(
          'RENDER ${entry.key}: mediana ${times[times.length ~/ 2]} ms '
          '(min ${times.first}, máx ${times.last}, primeira $first)',
        );
      }
    },
  );
}
