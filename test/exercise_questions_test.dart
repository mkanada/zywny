// I07, critério 2 — `test/exercise_questions_test.dart`: um exercício de
// cada tipo com semente fixa, aluno simulado tudo certo → aprova; acima do
// limite de erros → reprova com `reason`; `find-key` `any` aceita outra
// oitava e `exact` não.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_kind.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/pass_check.dart';
import 'package:zywny/course/exercise/question_session.dart';

import 'support/course_helpers.dart';
import 'support/simulated_student.dart';

// Arquivos de mentira para `generateRound` (só o `minimo/` não tem os tipos;
// `specFrom` cria o curso em memória e o `files` aqui é só para o tipo que
// lê `file:` — nenhum destes lê).
final _files = oneLessonCourse('oi');

final files = _files;

Future<RoundResult> _playAllCorrect(String body, {int seed = 7}) async {
  final spec = await specFrom(body);
  final round =
      await generateRound(spec, _files, Random(seed)) as QuestionRound;
  final session = QuestionSession(
    round.questions,
    timeLimit: spec.pass.timeLimit,
  );
  final result = await answerQuestions(session);
  expect(session.done, isTrue);
  return result;
}

void main() {
  group('geração determinística', () {
    test('mesma semente, mesma rodada', () async {
      final spec = await specFrom(
        'id: n\ntype: name-note\ntitle: N\nnotes: {random: C4-G4}',
      );
      final a = await generateRound(spec, _files, Random(5)) as QuestionRound;
      final b = await generateRound(spec, _files, Random(5)) as QuestionRound;
      final c = await generateRound(spec, _files, Random(6)) as QuestionRound;
      expect(
        [for (final q in a.questions) q.highlightId],
        [for (final q in b.questions) q.highlightId],
      );
      expect(
        (a.questions.first.answers, a.questions.first.correct),
        (b.questions.first.answers, b.questions.first.correct),
      );
      expect([
        for (final q in a.questions) q.correct,
      ], isNot([for (final q in c.questions) q.correct]));
    });

    test('find-key any × exact no sorteio', () async {
      final anySpec = await specFrom(
        'id: f\ntype: find-key\ntitle: F\nnotes: [C4]\noctave: any',
      );
      final anyRound =
          await generateRound(anySpec, _files, Random(1)) as QuestionRound;
      expect(anyRound.questions.single.anyOctave, isTrue);
      expect(anyRound.questions.single.expectedPitch, 60);

      final exactSpec = await specFrom(
        'id: f\ntype: find-key\ntitle: F\nnotes: [C4]\noctave: exact',
      );
      final exactRound =
          await generateRound(exactSpec, _files, Random(1)) as QuestionRound;
      expect(exactRound.questions.single.anyOctave, isFalse);
    });
  });

  group('aluno simulado aprova e reprova', () {
    test('find-key tudo certo aprova', () async {
      const body =
          'id: f\ntype: find-key\ntitle: F\nnotes: {random: C4-B4, count: 10}';
      final spec = await specFrom(body);
      final round =
          await generateRound(spec, _files, Random(7)) as QuestionRound;
      final session = QuestionSession(round.questions);
      final result = await answerQuestions(session);
      expect(result.total, 10);
      expect(result.percent, 100);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isTrue);
    });

    test('find-key com muitos erros reprova com a razão', () async {
      const body =
          'id: f\ntype: find-key\ntitle: F\nnotes: {random: C4-B4, count: 10}';
      final spec = await specFrom(body);
      final round =
          await generateRound(spec, _files, Random(7)) as QuestionRound;
      final session = QuestionSession(round.questions);
      final result = await answerQuestions(session, wrongEvery: 2);
      // Metade de primeira: 50% < 90%.
      expect(result.percent, 50);
      final verdict = PassCheck.evaluate(spec, [result]);
      expect(verdict.exercisePassed, isFalse);
      expect(verdict.reason, '50% de 90%');
    });

    test(
      'find-key any aceita outra oitava, exact não (ponta a ponta)',
      () async {
        final anySpec = await specFrom(
          'id: f\ntype: find-key\ntitle: F\nnotes: [C4]\noctave: any',
        );
        final anyRound =
            await generateRound(anySpec, _files, Random(1)) as QuestionRound;
        final any = QuestionSession(anyRound.questions);
        expect(any.answerPitch(72), isTrue);

        final exactSpec = await specFrom(
          'id: f\ntype: find-key\ntitle: F\nnotes: [C4]\noctave: exact',
        );
        final exactRound =
            await generateRound(exactSpec, _files, Random(1)) as QuestionRound;
        final exact = QuestionSession(exactRound.questions);
        expect(exact.answerPitch(72), isFalse);
        expect(exact.answerPitch(60), isTrue);
      },
    );

    test('name-note tudo certo aprova', () async {
      const body =
          'id: n\ntype: name-note\ntitle: N\nnotes: {random: C4-G4, count: 12}';
      final result = await _playAllCorrect(body);
      expect(result.percent, 100);
      final spec = await specFrom(body);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isTrue);
    });

    test('name-note com erros reprova', () async {
      const body =
          'id: n\ntype: name-note\ntitle: N\nnotes: {random: C4-G4, count: 12}';
      final spec = await specFrom(body);
      final round =
          await generateRound(spec, _files, Random(7)) as QuestionRound;
      final session = QuestionSession(round.questions);
      final result = await answerQuestions(session, wrongEvery: 3);
      // 8 de 12 de primeira: 66% < 90%.
      expect(result.percent, 66);
      expect(PassCheck.evaluate(spec, [result]).reason, '66% de 90%');
    });

    test('count-beats tudo certo aprova', () async {
      const body =
          'id: c\ntype: count-beats\ntitle: C\ntime: 4/4\n'
          'figures: [whole, half, quarter, quarter-rest]';
      final result = await _playAllCorrect(body);
      expect(result.total, 8);
      expect(result.percent, 100);
    });

    test('count-beats com erros reprova', () async {
      const body =
          'id: c\ntype: count-beats\ntitle: C\ntime: 4/4\n'
          'figures: [whole, half, quarter, quarter-rest]';
      final spec = await specFrom(body);
      final round =
          await generateRound(spec, _files, Random(7)) as QuestionRound;
      final session = QuestionSession(round.questions);
      final result = await answerQuestions(session, wrongEvery: 2);
      expect(result.percent, 50);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isFalse);
    });

    test('choice tudo certo aprova (100% ou 0%)', () async {
      const body =
          'id: c\ntype: choice\ntitle: C\nquestion: Quanto vale?\n'
          'options: [1, 2, 4]\nanswer: 2';
      final result = await _playAllCorrect(body);
      expect((result.hits, result.total), (1, 1));
      final spec = await specFrom(body);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isTrue);
    });

    test('choice errando uma vez zera (0%)', () async {
      const body =
          'id: c\ntype: choice\ntitle: C\nquestion: Quanto vale?\n'
          'options: [1, 2, 4]\nanswer: 2';
      final spec = await specFrom(body);
      final round =
          await generateRound(spec, _files, Random(1)) as QuestionRound;
      final session = QuestionSession(round.questions);
      expect(session.answerChoice(0), isFalse);
      expect(session.answerChoice(1), isTrue);
      final result = session.result();
      expect(result.percent, 0);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isFalse);
    });

    test('time-limit estourado reprova (late)', () async {
      const body =
          'id: n\ntype: name-note\ntitle: N\nnotes: [C4, D4]\n'
          'pass: {time-limit: 5}';
      final spec = await specFrom(body);
      final round =
          await generateRound(spec, _files, Random(1)) as QuestionRound;
      final session = QuestionSession(
        round.questions,
        timeLimit: spec.pass.timeLimit,
      );
      final result = await answerQuestions(session, late: true);
      expect(result.percent, 0);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isFalse);
    });
  });
}
