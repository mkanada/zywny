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

  group('listen-note', () {
    test(
      'teclado com referência: a nota e a referência soam em ordem',
      () async {
        final spec = await specFrom(
          'id: l\ntype: listen-note\ntitle: L\nnotes: [E4]\nreference: C4',
        );
        final round =
            await generateRound(spec, _files, Random(1)) as QuestionRound;
        final question = round.questions.single;
        expect(question.expectedPitch, 64);
        expect(question.anyOctave, isTrue);
        expect(
          [for (final cue in question.sound) cue.pitches],
          [
            [60],
            [64],
          ],
        );
      },
    );

    test('sem referência, o som é só a nota', () async {
      final spec = await specFrom(
        'id: l\ntype: listen-note\ntitle: L\nnotes: [E4]',
      );
      final round =
          await generateRound(spec, _files, Random(1)) as QuestionRound;
      expect(
        [for (final cue in round.questions.single.sound) cue.pitches],
        [
          [64],
        ],
      );
    });

    test('botões: as letras são as respostas, sem altura esperada', () async {
      final spec = await specFrom(
        'id: l\ntype: listen-note\ntitle: L\nnotes: [D4]\n'
        'input: buttons\nchoices: [C, D, E]',
      );
      final round =
          await generateRound(spec, _files, Random(1)) as QuestionRound;
      final question = round.questions.single;
      expect(question.answers, ['C', 'D', 'E']);
      expect(question.correct, 1);
      expect(question.expectedPitch, isNull);
    });

    test('tom de Sol no sorteio: nenhum Fá natural', () async {
      final spec = await specFrom(
        'id: l\ntype: listen-note\ntitle: L\n'
        'notes: {random: F4-F5, count: 30}\nkey: G',
      );
      final round =
          await generateRound(spec, _files, Random(3)) as QuestionRound;
      expect([
        for (final q in round.questions) q.expectedPitch! % 12,
      ], everyElement(isNot(5)));
    });

    test('aluno simulado tudo certo aprova', () async {
      const body =
          'id: l\ntype: listen-note\ntitle: L\n'
          'notes: {random: C4-B4, count: 8}\nreference: C4\n'
          'pass: {accuracy: 60}';
      final spec = await specFrom(body);
      final result = await _playAllCorrect(body);
      expect(result.percent, 100);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isTrue);
    });
  });

  group('listen-interval', () {
    test('melódico, subindo: a 2ª nota é a 3ª ou a 5ª acima', () async {
      final spec = await specFrom(
        'id: i\ntype: listen-interval\ntitle: I\nnotes: [C4]\n'
        'intervals: [M3, P5]',
      );
      final round =
          await generateRound(spec, _files, Random(1)) as QuestionRound;
      final question = round.questions.single;
      expect(question.answers, ['3ª maior', '5ª justa']);
      expect(question.sound, hasLength(2));
      expect(question.sound[0].pitches, [60]);
      final second = question.sound[1].pitches.single;
      expect(second, anyOf(64, 67));
      expect(question.correct, second == 64 ? 0 : 1);
    });

    test('melódico, descendo: a 2ª nota fica abaixo', () async {
      final spec = await specFrom(
        'id: i\ntype: listen-interval\ntitle: I\n'
        'notes: {random: C4-C5, count: 30}\nintervals: [M3, P5]\n'
        'direction: down',
      );
      final round =
          await generateRound(spec, _files, Random(2)) as QuestionRound;
      for (final question in round.questions) {
        final first = question.sound[0].pitches.single;
        final second = question.sound[1].pitches.single;
        expect(second, lessThan(first));
      }
    });

    test('harmônico: uma pergunta com as duas notas juntas, 1,5 s', () async {
      final spec = await specFrom(
        'id: i\ntype: listen-interval\ntitle: I\nnotes: [C4]\n'
        'intervals: [M3, P5]\nplay: harmonic',
      );
      final round =
          await generateRound(spec, _files, Random(1)) as QuestionRound;
      final cue = round.questions.single.sound.single;
      expect(cue.pitches, hasLength(2));
      expect(cue.pitches.first, 60);
      expect(cue.pitches.last, anyOf(64, 67));
      expect(cue.seconds, 1.5);
    });

    test('direction: both sorteia as duas direções', () async {
      final spec = await specFrom(
        'id: i\ntype: listen-interval\ntitle: I\n'
        'notes: {random: C4-C5, count: 40}\nintervals: [m2, M2]\n'
        'direction: both',
      );
      final round =
          await generateRound(spec, _files, Random(4)) as QuestionRound;
      final ups = [
        for (final q in round.questions)
          if (q.sound[1].pitches.single > q.sound[0].pitches.single) q,
      ];
      final downs = [
        for (final q in round.questions)
          if (q.sound[1].pitches.single < q.sound[0].pitches.single) q,
      ];
      expect(ups, isNotEmpty);
      expect(downs, isNotEmpty);
      expect(ups.length + downs.length, round.questions.length);
    });

    test('aluno simulado tudo certo aprova', () async {
      const body =
          'id: i\ntype: listen-interval\ntitle: I\n'
          'notes: {random: C4-G4, count: 8}\nintervals: [m2, M2]\n'
          'pass: {accuracy: 70}';
      final spec = await specFrom(body);
      final result = await _playAllCorrect(body);
      expect(result.percent, 100);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isTrue);
    });
  });

  group('listen-score', () {
    test('answer: measure, passo 4c: cada pergunta é uma partitura', () async {
      final spec = await specFrom(
        'id: s\ntype: listen-score\ntitle: S\nstep: 4c\ncount: 3',
      );
      final round =
          await generateRound(spec, _files, Random(3)) as QuestionRound;
      expect(round.questions, hasLength(3));
      for (final question in round.questions) {
        expect(question.compare, isNotNull);
        expect(question.answers, ['1', '2', '3', '4']);
        expect(question.correct, question.compare!.measure);
      }
    });

    test('answer: same-different: "Igual" sai quando nada muda', () async {
      final spec = await specFrom(
        'id: s\ntype: listen-score\ntitle: S\nstep: 4c\ncount: 10\n'
        'answer: same-different',
      );
      final round =
          await generateRound(spec, _files, Random(7)) as QuestionRound;
      expect(round.questions, hasLength(10));
      for (final question in round.questions) {
        expect(question.answers, ['Igual', 'Diferente']);
        final same = question.compare!.changedIds.isEmpty;
        expect(question.correct == 0, same);
      }
    });

    test('aluno simulado tudo certo aprova', () async {
      const body =
          'id: s\ntype: listen-score\ntitle: S\nstep: 1c\ncount: 5\n'
          'pass: {accuracy: 60}';
      final spec = await specFrom(body);
      final result = await _playAllCorrect(body);
      expect(result.percent, 100);
      expect(PassCheck.evaluate(spec, [result]).exercisePassed, isTrue);
    });
  });
}
