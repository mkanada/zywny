import 'dart:async';
// I03 — `play-notes` de ponta a ponta, sem aparelho: o curso `minimo/` do
// I01 → sorteio → render real pela libverovio → `ScoreRoundRunner` (treino
// de passagem única em modo espera) → aluno simulado no teclado MIDI falso →
// `PassCheck`.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_kind.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/pass_check.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/course_model.dart';
import 'package:zywny_course_format/course_reader.dart';
import 'package:zywny_course_format/directory_course_files.dart';
import 'package:zywny/practice/hand.dart';

import 'support/course_helpers.dart';
import 'support/practice_fakes.dart';
import 'support/render_helper.dart';
import 'support/simulated_student.dart';

const _noLib = 'libverovio.so ausente';

/// Uma rodada inteira: sorteia, renderiza, e o aluno simulado toca.
Future<({RoundResult? result, ScoreRound round, ScoreRoundRunner runner})>
_playRound(
  ExerciseSpec spec,
  CourseFiles files, {
  int seed = 1,
  int? wrongEvery,
}) async {
  final round = await generateRound(spec, files, Random(seed)) as ScoreRound;
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

  final files = DirectoryCourseFiles(Directory('test/fixtures/cursos/minimo'));

  Future<ExerciseSpec> minimoExercise() async {
    final result = await readCourse(files);
    return result.course!.lessons.last.exercises.single;
  }

  group('geração da rodada', () {
    test('mesma semente, mesma rodada; as notas vêm do sorteio', () async {
      final spec = await minimoExercise();
      final a = await generateRound(spec, files, Random(5)) as ScoreRound;
      final b = await generateRound(spec, files, Random(5)) as ScoreRound;
      final c = await generateRound(spec, files, Random(6)) as ScoreRound;
      expect(a.pitches, b.pitches);
      expect(a.pitches, isNot(c.pitches));
      expect(a.bytes, b.bytes);
      expect(a.pitches, hasLength(12));
      expect(a.pitches.every((p) => p >= 60 && p <= 67), isTrue);
      expect(a.noteIds.first, 'zn1');
      expect(a.mode, PlayMode.wait);
      expect(a.hand, Hand.direita);
      expect(a.fileName, endsWith('.musicxml'));
    });

    test('lista fixa de notas e duas pautas', () async {
      final fixed = await specFrom(
        'id: f\ntype: play-notes\ntitle: F\nnotes: [C4, E4, G4]',
      );
      final round = await generateRound(fixed, files, Random(1)) as ScoreRound;
      expect(round.pitches, [60, 64, 67]);
      final grand = await specFrom(
        'id: g\ntype: play-notes\ntitle: G\nclef: grand\n'
        'notes: {random: C3-C5}',
      );
      final both = await generateRound(grand, files, Random(1)) as ScoreRound;
      expect(both.hand, Hand.ambas);
    });

    test(
      'todos os tipos geram rodada (nada mais lança UnimplementedError)',
      () async {
        final choice = await specFrom(
          'id: c\ntype: choice\ntitle: C\nquestion: Q\noptions: [a, b]\n'
          'answer: a',
        );
        final round = await generateRound(choice, files, Random(1));
        expect(round, isA<QuestionRound>());
      },
    );
  });

  group('rodada com o aluno simulado (libverovio)', () {
    test('tudo certo: 100% e aprova', () async {
      final spec = await minimoExercise();
      final played = await _playRound(spec, files);
      expect(played.result, isNotNull);
      expect((played.result!.hits, played.result!.total), (12, 12));
      expect(played.result!.percent, 100);
      final verdict = PassCheck.evaluate(spec, [played.result!]);
      expect(verdict.exercisePassed, isTrue);
      expect(verdict.reason, '100% (mínimo 90%)');
      // O que o aluno tocou é o que foi sorteado: o `midi.json` bate.
      expect([
        for (final e in played.runner.track.events.where((e) => !e.ornament))
          e.pitch,
      ], played.round.pitches);
    }, skip: verovioAvailable ? false : _noLib);

    test('uma errada a cada 4 de 12: 75% < 90%, reprova com a razão', () async {
      final spec = await minimoExercise();
      final played = await _playRound(spec, files, wrongEvery: 4);
      expect((played.result!.hits, played.result!.total), (9, 12));
      expect(played.result!.percent, 75);
      final verdict = PassCheck.evaluate(spec, [played.result!]);
      expect(verdict.roundPassed, isFalse);
      expect(verdict.exercisePassed, isFalse);
      expect(verdict.reason, '75% de 90%');
      // As teclas erradas contam (o "3 erros" da tela).
      expect(played.runner.practice.wrongCount.value, 3);
    }, skip: verovioAvailable ? false : _noLib);

    test('tecla errada vira nota fantasma na pauta (como nos hinos)', () async {
      final spec = await minimoExercise();
      final round = await generateRound(spec, files, Random(1)) as ScoreRound;
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
      // O `ScoreView` faz isto ao desenhar a página.
      runner.ghosts.attachDocument(runner.document);
      unawaited(runner.start());
      await pumpEventQueue();
      final wanted = runner.practice.currentStep.value!.notes.first.pitch;
      final wrong = wanted == 72 ? 71 : wanted + 1;
      midi.press(wrong, atSeconds: engine.now);
      await pumpEventQueue();
      expect(runner.ghosts.visible, hasLength(1));
      expect(runner.ghosts.visible.single.ghost.key, wrong);
      runner.cancel();
    }, skip: verovioAvailable ? false : _noLib);

    test('uma errada a cada 5 de 12: 83% ainda reprova (limiar 90)', () async {
      final spec = await minimoExercise();
      final played = await _playRound(spec, files, wrongEvery: 5);
      expect((played.result!.hits, played.result!.total), (10, 12));
      expect(played.result!.percent, 83);
      expect(PassCheck.roundPasses(spec, played.result!), isFalse);
    }, skip: verovioAvailable ? false : _noLib);

    test('o limiar é o do autor: accuracy 80 aprova os 83%', () async {
      final spec = await specFrom(
        'id: a\ntype: play-notes\ntitle: A\nnotes: {random: C4-G4}\n'
        'pass: {accuracy: 80}',
      );
      final played = await _playRound(spec, files, wrongEvery: 5);
      expect(PassCheck.evaluate(spec, [played.result!]).exercisePassed, isTrue);
    }, skip: verovioAvailable ? false : _noLib);

    test(
      'rounds: 3 aprova só na terceira seguida; erro no meio zera',
      () async {
        final spec = await specFrom(
          'id: a\ntype: play-notes\ntitle: A\nnotes: {random: C4-G4}\n'
          'pass: {accuracy: 90, rounds: 3}',
        );
        final history = <RoundResult>[];
        Future<PassVerdict> round(int seed, {int? wrongEvery}) async {
          final played = await _playRound(
            spec,
            files,
            seed: seed,
            wrongEvery: wrongEvery,
          );
          history.add(played.result!);
          return PassCheck.evaluate(spec, history);
        }

        expect((await round(1)).reason, '1 de 3 rodadas seguidas');
        expect((await round(2)).reason, '2 de 3 rodadas seguidas');
        final failed = await round(3, wrongEvery: 4);
        expect((failed.streak, failed.reason), (0, '75% de 90%'));
        expect((await round(4)).exercisePassed, isFalse);
        expect((await round(5)).exercisePassed, isFalse);
        final last = await round(6);
        expect((last.streak, last.exercisePassed), (3, true));
      },
      skip: verovioAvailable ? false : _noLib,
    );

    test('tom, acidentes e duas pautas também rodam', () async {
      for (final body in [
        'clef: treble\nkey: G\nnotes: {random: C4-C5, count: 8}',
        'notes: {random: C4-C5, count: 10}\naccidentals: mixed',
        'clef: bass\nnotes: {random: G2-C4, count: 8}',
        'clef: grand\nnotes: {random: C3-C5, count: 10}',
      ]) {
        final spec = await specFrom('id: a\ntype: play-notes\ntitle: A\n$body');
        final played = await _playRound(spec, files, seed: 3);
        expect(played.result!.percent, 100, reason: body);
        expect(
          [
            for (final e in played.runner.track.events.where(
              (e) => !e.ornament,
            ))
              e.pitch,
          ],
          played.round.pitches,
          reason: body,
        );
      }
    }, skip: verovioAvailable ? false : _noLib);

    test('cancel() abandona a rodada: sem resultado', () async {
      final spec = await minimoExercise();
      final round = await generateRound(spec, files, Random(1)) as ScoreRound;
      final midi = FakeMidiInput();
      addTearDown(midi.dispose);
      final runner = ScoreRoundRunner(
        midiInput: midi,
        engine: FakeSoundEngine(),
        renderer: LibverovioRenderer(),
        autoTick: false,
      );
      addTearDown(runner.dispose);
      await runner.load(round);
      final future = runner.start();
      runner.cancel();
      expect(await future, isNull);
      // E dá para carregar outra rodada no mesmo executor.
      await runner.load(round);
      expect(runner.isLoaded, isTrue);
    }, skip: verovioAvailable ? false : _noLib);

    test('start() sem load() é erro de programação', () {
      final runner = ScoreRoundRunner(
        midiInput: FakeMidiInput(),
        engine: FakeSoundEngine(),
        renderer: LibverovioRenderer(),
      );
      expect(runner.start, throwsStateError);
    });
  });

  test('lib/course/exercise não importa main.dart nem widgets', () {
    final files = Directory('lib/course/exercise')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final file in files) {
      final imports = file
          .readAsLinesSync()
          .where((l) => l.startsWith('import '))
          .join('\n');
      expect(imports, isNot(contains('main.dart')), reason: file.path);
      expect(imports, isNot(contains('package:flutter/material')));
      expect(imports, isNot(contains('package:flutter/widgets')));
      expect(imports, isNot(contains('package:flutter/cupertino')));
    }
  });
}
