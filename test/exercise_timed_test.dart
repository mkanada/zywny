// I08, critério 1 — `test/exercise_timed_test.dart`: semente fixa, render
// real quando a `libverovio.so` existir.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_kind.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/pass_check.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny/course/format/course_files.dart';
import 'package:zywny/course/format/course_model.dart';
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/music/note_name.dart';
import 'package:zywny/course/score/round_score.dart';
import 'package:zywny/practice/hand.dart';

import 'support/course_helpers.dart';
import 'support/practice_fakes.dart';
import 'support/render_helper.dart';
import 'support/simulated_student.dart';

const _noLib = 'libverovio.so ausente';

Future<({RoundResult? result, ScoreRound round, ScoreRoundRunner runner})>
_playTimed(
  ExerciseSpec spec,
  CourseFiles files,
  ScoreRound round, {
  int? wrongEvery,
  double lateMs = 300,
}) async {
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
  final result = await playTimedRound(
    runner,
    midi,
    engine,
    runner.start(),
    wrongEvery: wrongEvery,
    lateMs: lateMs,
  );
  return (result: result, round: round, runner: runner);
}

Future<({RoundResult? result, ScoreRound round, ScoreRoundRunner runner})>
_playWait(
  ExerciseSpec spec,
  CourseFiles files,
  ScoreRound round, {
  int? wrongEvery,
}) async {
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
  final result = await playScoreRound(
    runner,
    midi,
    engine,
    runner.start(),
    wrongEvery: wrongEvery,
  );
  return (result: result, round: round, runner: runner);
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('rhythm sorteado (tempo real)', () {
    test('tudo no tempo aprova', () async {
      final spec = await specFrom(
        'id: r\ntype: rhythm\ntitle: R\n'
        'figures: [quarter, half, quarter-rest]\nmeasures: 4\nbpm: 80',
      );
      final files = oneLessonCourse('oi');
      final round = await generateRound(spec, files, Random(7)) as ScoreRound;
      expect(round.mode, PlayMode.realtime);
      final played = await _playTimed(spec, files, round);
      expect(played.result, isNotNull);
      expect(played.result!.percent, 100);
      expect(PassCheck.evaluate(spec, [played.result!]).exercisePassed, isTrue);
    }, skip: verovioAvailable ? false : _noLib);

    test('metade fora da janela reprova', () async {
      final spec = await specFrom(
        'id: r\ntype: rhythm\ntitle: R\n'
        'figures: [quarter, half, quarter-rest]\nmeasures: 4\nbpm: 80',
      );
      final files = oneLessonCourse('oi');
      final round = await generateRound(spec, files, Random(7)) as ScoreRound;
      final played = await _playTimed(
        spec,
        files,
        round,
        wrongEvery: 2,
        lateMs: 300,
      );
      expect(played.result!.percent, lessThan(90));
      final verdict = PassCheck.evaluate(spec, [played.result!]);
      expect(verdict.exercisePassed, isFalse);
    }, skip: verovioAvailable ? false : _noLib);
  });

  group('play-score em tempo real e andamento', () {
    MemoryCourseFiles filesWithScore(String xml) => MemoryCourseFiles({
      'course.md':
          '---\nformat: 1\nid: t\ntitle: T\nauthor: a\nversion: "1"\n'
          'lessons: [um]\n---\n\nOi.\n',
      'lessons/01-um.md':
          '---\nid: um\ntitle: Um\n---\n\n'
          '```zywny-exercise\nid: p\ntype: play-score\ntitle: P\n'
          'file: media/score.musicxml\nhand: both\nmode: realtime\n'
          'pass: {accuracy: 85, speed: 100}\n```\n',
      'media/score.musicxml': xml,
    });

    test('a 100% aprova; a 50% reprova por andamento', () async {
      final xml = notesScore([
        for (var i = 0; i < 8; i++) parsePitch('C4', i),
      ], time: '4/4');
      final files = filesWithScore(xml);
      final result = await readCourse(files);
      expect(result.course, isNotNull, reason: result.issues.join('\n'));
      final spec = result.course!.lessons.single.exercises.single;
      expect(spec, isA<PlayScoreSpec>());

      final base = await generateRound(spec, files, Random(1)) as ScoreRound;
      final full = await _playTimed(spec, files, base.copyWith(speed: 1.0));
      expect(full.result!.percent, 100);
      expect(PassCheck.evaluate(spec, [full.result!]).exercisePassed, isTrue);

      final slow = await _playTimed(spec, files, base.copyWith(speed: 0.5));
      expect(slow.result!.percent, 100);
      final verdict = PassCheck.evaluate(spec, [slow.result!]);
      expect(verdict.roundPassed, isFalse);
      expect(verdict.exercisePassed, isFalse);
      expect(verdict.reason, 'faltou andamento: 50% de 100%');
    }, skip: verovioAvailable ? false : _noLib);

    test(
      'hand right numa partitura de duas pautas: só a pauta 1 é avaliada',
      () async {
        final xml = notesScore([
          parsePitch('C3', 0),
          parsePitch('E4', 1),
          parsePitch('G4', 2),
          parsePitch('C4', 3),
          parsePitch('D3', 4),
          parsePitch('F4', 5),
        ], clef: Clef.grand);
        final files = MemoryCourseFiles({
          'course.md':
              '---\nformat: 1\nid: t\ntitle: T\nauthor: a\nversion: "1"\n'
              'lessons: [um]\n---\n\nOi.\n',
          'lessons/01-um.md':
              '---\nid: um\ntitle: Um\n---\n\n'
              '```zywny-exercise\nid: p\ntype: play-score\ntitle: P\n'
              'file: media/score.musicxml\nhand: right\nmode: wait\n```\n',
          'media/score.musicxml': xml,
        });
        final result = await readCourse(files);
        expect(result.course, isNotNull, reason: result.issues.join('\n'));
        final spec = result.course!.lessons.single.exercises.single;
        final round = await generateRound(spec, files, Random(1)) as ScoreRound;
        expect(round.hand, Hand.direita);

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
        // Só a pauta 1 entra na avaliação.
        expect(runner.practice.hand.studentStaves, {1});
        final future = runner.start();
        final played = await playScoreRound(runner, midi, engine, future);
        expect(played, isNotNull);
        expect(played!.percent, 100);
        // O app toca a pauta 2: o agendador recebe as notas dela.
        final scheduledPitches = {
          for (final s in engine.scheduled)
            if ((s.status & 0xF0) == 0x90) s.d1,
        };
        final staff2 = {
          for (final e in runner.track.events)
            if (e.staff == 2) e.pitch,
        };
        expect(staff2, isNotEmpty);
        expect(scheduledPitches.intersection(staff2), isNotEmpty);
        // E o total é só da pauta do aluno (não das duas).
        final staff1Count = runner.track.events
            .where((e) => e.staff == 1 && !e.ornament)
            .length;
        expect(played.total, staff1Count);
      },
      skip: verovioAvailable ? false : _noLib,
    );

    test('measures "2-3": só esses compassos entram no total', () async {
      final notes = [
        for (var i = 0; i < 16; i++)
          parsePitch(['C', 'D', 'E', 'F'][i % 4], 4, i),
      ];
      final xml = notesScore(notes, time: '4/4');
      final files = MemoryCourseFiles({
        'course.md':
            '---\nformat: 1\nid: t\ntitle: T\nauthor: a\nversion: "1"\n'
            'lessons: [um]\n---\n\nOi.\n',
        'lessons/01-um.md':
            '---\nid: um\ntitle: Um\n---\n\n'
            '```zywny-exercise\nid: p\ntype: play-score\ntitle: P\n'
            'file: media/score.musicxml\nhand: both\nmode: wait\n'
            'measures: "2-3"\n```\n',
        'media/score.musicxml': xml,
      });
      final result = await readCourse(files);
      expect(result.course, isNotNull, reason: result.issues.join('\n'));
      final spec =
          result.course!.lessons.single.exercises.single as PlayScoreSpec;
      expect(spec.measures.toString(), '2-3');
      final round = await generateRound(spec, files, Random(1)) as ScoreRound;
      final played = await _playWait(spec, files, round);
      // 4 compassos de 4 semínimas; "2-3" são 8 notas.
      expect(played.result, isNotNull);
      expect(played.result!.total, 8);
      expect(played.result!.percent, 100);
    }, skip: verovioAvailable ? false : _noLib);

    test('mode wait: speed não vale e a rodada passa em espera', () async {
      final bad = await readCourse(
        oneLessonCourse(
          '```zywny-exercise\nid: p\ntype: play-score\ntitle: P\n'
          'abc: "X:1\\nT:t\\nM:4/4\\nL:1/4\\nK:C\\nC D E F|"\n'
          'mode: wait\npass: {speed: 80}\n```\n',
        ),
      );
      expect(bad.course, isNull);
      expect(
        bad.issues.join('\n'),
        contains('o modo espera não tem andamento'),
      );

      final spec = await specFrom(
        'id: p\ntype: play-score\ntitle: P\n'
        'abc: "X:1\\nT:t\\nM:4/4\\nL:1/4\\nK:C\\nC D E F|"\nmode: wait',
      );
      expect(PassCheck.speedApplies(spec), isFalse);
      final files = oneLessonCourse('oi');
      final round = await generateRound(spec, files, Random(1)) as ScoreRound;
      expect(round.mode, PlayMode.wait);
      final played = await _playWait(spec, files, round.copyWith(speed: 0.5));
      // O andamento não vale em espera: aprova mesmo a 50%.
      expect(played.result!.percent, 100);
      expect(PassCheck.roundPasses(spec, played.result!), isTrue);
    }, skip: verovioAvailable ? false : _noLib);
  });
}

// Notas sem repetição imediata para o sorteio não reclamar.
Pitch parsePitch(String step, int octave, [int voice = 0]) {
  const steps = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  final base = steps[(steps.indexOf(step) + voice) % steps.length];
  return Pitch(base, 0, octave);
}
