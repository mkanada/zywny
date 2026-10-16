import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny/course/score/abc_source.dart';
import 'package:zywny/practice/hand.dart';
import 'package:zywny/sight_reading/sight_generator.dart';
import 'package:zywny/sight_reading/sight_score.dart';
import 'package:zywny/sight_reading/sight_steps.dart';
import 'package:zywny_course_format/course_model.dart';

import 'support/practice_fakes.dart';
import 'support/render_helper.dart';
import 'support/simulated_student.dart';

const _noLib = 'libverovio.so ausente';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Leitura à vista da mão esquerda: a pauta 1 sai só de pausas, então a
  // partitura tem uma pauta com notas — a 2. O aluno tem de tocar essa pauta;
  // a regra "pauta só = mão direita" fazia o app esperar a pauta 1 e ignorar
  // as teclas da esquerda.
  test('leitura da mão esquerda: a pauta 2 é a do aluno', () async {
    final step = sightSteps.firstWhere((s) => s.hands == SightHands.left);
    final xml = sightScoreXml(generateSight(step, Random(3)));
    final round = ScoreRound(
      bytes: utf8Bytes(xml),
      fileName: 'leitura-${step.name}.musicxml',
      mode: PlayMode.realtime,
      hand: Hand.esquerda,
    );

    final engine = FakeSoundEngine();
    final midi = FakeMidiInput();
    addTearDown(midi.dispose);
    final runner = ScoreRoundRunner(
      midiInput: midi,
      engine: engine,
      renderer: LibverovioRenderer(),
      autoTick: false,
    );
    addTearDown(runner.dispose);
    await runner.load(round);

    expect(runner.track.staves, {2});
    expect(runner.practice.hand.studentStaves, contains(2));

    final future = runner.start();
    final played = await playTimedRound(runner, midi, engine, future);
    expect(played, isNotNull);
    expect(played!.percent, 100);
  }, skip: verovioAvailable ? false : _noLib);
}
