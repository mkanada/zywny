// I11 — aluno simulado em todo exercício do curso inicial (regra 3 do I00).
//
// Para cada `ExerciseMark` do curso, testes gerados (um `test` por exercício
// e caso, nome = `lição/exercício: caso`):
// - certo → `exercisePassed` depois de `rounds` rodadas;
// - errado acima do limite → reprova a rodada;
// - onde `speed` vale: a 50% do pedido → reprova com motivo de andamento;
// - onde `time-limit` vale: deixar estourar todas → reprova.
//
// Semente fixa por exercício, derivada do id com hash estável (FNV-1a do
// id — `id.hashCode` muda entre execuções na Web/VM). Exercício com
// partitura precisa da `libverovio.so` para renderizar: sem ela, o teste é
// pulado (como `test/vsb_render_test.dart`), não falha.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_kind.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/pass_check.dart';
import 'package:zywny/course/exercise/question_session.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny_course_format/course_model.dart';
import 'package:zywny_course_format/course_reader.dart';
import 'package:zywny_course_format/directory_course_files.dart';

import 'support/practice_fakes.dart';
import 'support/render_helper.dart';
import 'support/simulated_student.dart';

/// FNV-1a de 32 bits, estável entre execuções e plataformas (o `hashCode`
/// do Dart muda). O `Random` recebe o valor como semente.
int _stableSeed(String id) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < id.length; i++) {
    hash ^= id.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// Tipos que rodam como partitura (precisam do Verovio para renderizar).
/// (Usado só como documentação: o `skip` é decidido pelo `type` do texto.)

/// `wrongEvery` que derruba abaixo do `accuracy`: metade de primeira (50%)
/// reprova qualquer limiar do curso (80–90); com uma pergunta só, erra ela.
int _wrongEvery(int total) => total <= 1 ? 1 : 2;

Future<RoundResult?> _playScoreCorrect(
  ScoreRound round, {
  double speed = 1.0,
}) async {
  final effective = round.speed == speed ? round : round.copyWith(speed: speed);
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
  await runner.load(effective);
  if (effective.mode == PlayMode.realtime) {
    return playTimedRound(runner, midi, engine, runner.start());
  }
  return playScoreRound(runner, midi, engine, runner.start());
}

Future<RoundResult?> _playScoreWrong(ScoreRound round, int wrongEvery) async {
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
  if (round.mode == PlayMode.realtime) {
    return playTimedRound(
      runner,
      midi,
      engine,
      runner.start(),
      wrongEvery: wrongEvery,
    );
  }
  return playScoreRound(
    runner,
    midi,
    engine,
    runner.start(),
    wrongEvery: wrongEvery,
  );
}

Future<RoundResult> _playQuestionsCorrect(
  QuestionRound round,
  int? timeLimit,
) async {
  final session = QuestionSession(round.questions, timeLimit: timeLimit);
  final result = await answerQuestions(session);
  expect(session.done, isTrue);
  return result;
}

Future<RoundResult> _playQuestionsWrong(
  QuestionRound round,
  int? timeLimit,
  int wrongEvery,
) async {
  final session = QuestionSession(round.questions, timeLimit: timeLimit);
  final result = await answerQuestions(session, wrongEvery: wrongEvery);
  expect(session.done, isTrue);
  return result;
}

Future<RoundResult> _playQuestionsLate(
  QuestionRound round,
  int? timeLimit,
) async {
  final session = QuestionSession(round.questions, timeLimit: timeLimit);
  final result = await answerQuestions(session, late: true);
  expect(session.done, isTrue);
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Nomes dos testes sem await: os ids e tipos vêm do texto (o curso é lido
  // de novo dentro de cada teste). `id.hashCode` não serve como semente —
  // muda entre execuções — por isso FNV-1a do id.
  final lessonDir = Directory('assets/cursos/iniciacao/lessons');
  final lessonFiles = lessonDir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final entries =
      <
        ({
          String lesson,
          String exercise,
          String type,
          bool hasTimeLimit,
          String? mode,
        })
      >[];
  final lessonIdPattern = RegExp(r'^id:\s*([a-z0-9-]+)\s*$', multiLine: true);
  final exerciseBlockPattern = RegExp(
    r'```zywny-exercise\s*\n(.*?)```',
    dotAll: true,
  );
  final idInBlock = RegExp(r'^\s*id:\s*([a-z0-9-]+)\s*$', multiLine: true);
  final typeInBlock = RegExp(r'^\s*type:\s*([a-z-]+)\s*$', multiLine: true);
  final timeLimitInBlock = RegExp(r'time-limit\s*:', multiLine: true);
  final modeInBlock = RegExp(r'^\s*mode:\s*([a-z]+)\s*$', multiLine: true);
  for (final file in lessonFiles) {
    final text = file.readAsStringSync();
    final lessonMatch = lessonIdPattern.firstMatch(text);
    if (lessonMatch == null) continue;
    final lessonId = lessonMatch.group(1)!;
    for (final block in exerciseBlockPattern.allMatches(text)) {
      final body = block.group(1)!;
      final idMatch = idInBlock.firstMatch(body);
      final typeMatch = typeInBlock.firstMatch(body);
      if (idMatch == null || typeMatch == null) continue;
      entries.add((
        lesson: lessonId,
        exercise: idMatch.group(1)!,
        type: typeMatch.group(1)!,
        hasTimeLimit: timeLimitInBlock.hasMatch(body),
        mode: modeInBlock.firstMatch(body)?.group(1),
      ));
    }
  }

  Future<ExerciseSpec> loadSpec(String lessonId, String exerciseId) async {
    final files = DirectoryCourseFiles(Directory('assets/cursos/iniciacao'));
    final read = await readCourse(files);
    if (read.issues.isNotEmpty) {
      throw StateError(
        'curso inválido:\n${read.issues.map((i) => '$i').join('\n')}',
      );
    }
    final course = read.course!;
    for (final lesson in course.lessons) {
      if (lesson.id != lessonId) continue;
      for (final spec in lesson.exercises) {
        if (spec.id == exerciseId) return spec;
      }
    }
    throw StateError('exercício não achado: $lessonId/$exerciseId');
  }

  DirectoryCourseFiles courseFiles() =>
      DirectoryCourseFiles(Directory('assets/cursos/iniciacao'));

  const scoreTypes = {'play-notes', 'rhythm', 'play-score'};

  for (final entry in entries) {
    final base = '${entry.lesson}/${entry.exercise}';
    final seed = _stableSeed(entry.exercise);
    final isScore = scoreTypes.contains(entry.type);
    final skipScore = isScore && !verovioAvailable
        ? 'libverovio.so ausente'
        : null;

    test('$base: certo aprova', () async {
      final spec = await loadSpec(entry.lesson, entry.exercise);
      final files = courseFiles();
      final history = <RoundResult>[];
      for (var i = 0; i < spec.pass.rounds; i++) {
        final round = await generateRound(spec, files, Random(seed + i));
        if (round is ScoreRound) {
          // No tempo real, a 100% (o escrito): passa em qualquer `speed`.
          final result = await _playScoreCorrect(round);
          expect(result, isNotNull);
          history.add(result!);
        } else if (round is QuestionRound) {
          history.add(await _playQuestionsCorrect(round, spec.pass.timeLimit));
        } else {
          fail('rodada desconhecida para ${spec.id}');
        }
      }
      final verdict = PassCheck.evaluate(spec, history);
      expect(verdict.exercisePassed, isTrue, reason: verdict.reason);
    }, skip: skipScore);

    test('$base: errando acima do limite reprova', () async {
      final spec = await loadSpec(entry.lesson, entry.exercise);
      final files = courseFiles();
      final round = await generateRound(spec, files, Random(seed));
      if (round is ScoreRound) {
        // Total de passos só se sabe depois de renderizar: 2 dá ~50%,
        // abaixo de qualquer `accuracy` do curso (80–90). Com um passo só,
        // erra ele.
        final totalGuess = round.pitches.isNotEmpty ? round.pitches.length : 12;
        final result = await _playScoreWrong(round, _wrongEvery(totalGuess));
        expect(result, isNotNull);
        expect(
          PassCheck.roundPasses(spec, result!),
          isFalse,
          reason: '${result.hits}/${result.total} = ${result.percent}%',
        );
      } else if (round is QuestionRound) {
        final result = await _playQuestionsWrong(
          round,
          spec.pass.timeLimit,
          _wrongEvery(round.questions.length),
        );
        expect(
          PassCheck.roundPasses(spec, result),
          isFalse,
          reason: '${result.hits}/${result.total} = ${result.percent}%',
        );
      } else {
        fail('rodada desconhecida para ${spec.id}');
      }
    }, skip: skipScore);

    // `speed` só vale em `rhythm` e `play-score` com `mode: realtime`.
    final wantsSpeed =
        entry.type == 'rhythm' ||
        (entry.type == 'play-score' && entry.mode == 'realtime');
    if (wantsSpeed) {
      test('$base: a 50% reprova por andamento', () async {
        final spec = await loadSpec(entry.lesson, entry.exercise);
        if (!PassCheck.speedApplies(spec)) return;
        final files = courseFiles();
        final round =
            await generateRound(spec, files, Random(seed)) as ScoreRound;
        final result = await _playScoreCorrect(round, speed: 0.5);
        expect(result, isNotNull);
        // Tocando certo, a precisão passa; o que reprova é o andamento.
        expect(result!.percent, 100);
        final verdict = PassCheck.evaluate(spec, [result]);
        expect(verdict.roundPassed, isFalse);
        expect(verdict.reason, contains('faltou andamento'));
        expect(verdict.reason, contains('50% de ${spec.pass.speed}%'));
      }, skip: skipScore);
    }

    if (entry.hasTimeLimit) {
      test('$base: estourando o tempo reprova', () async {
        final spec = await loadSpec(entry.lesson, entry.exercise);
        if (spec.pass.timeLimit == null) return;
        final files = courseFiles();
        final round =
            await generateRound(spec, files, Random(seed)) as QuestionRound;
        final result = await _playQuestionsLate(round, spec.pass.timeLimit);
        expect(result.percent, 0);
        expect(PassCheck.roundPasses(spec, result), isFalse);
      });
    }
  }
}
