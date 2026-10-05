// I07, critério 1 — `test/question_session_test.dart`: de primeira ×
// depois do erro; `time-limit` estourado conta como erro e avança; relógio
// simulado.
import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/question_session.dart';

Question _button(String prompt, List<String> answers, int correct) =>
    Question(prompt: prompt, answers: answers, correct: correct);

void main() {
  group('QuestionSession', () {
    test('tudo de primeira: 2/2', () {
      final session = QuestionSession([
        _button('Q1', ['a', 'b'], 0),
        _button('Q2', ['a', 'b'], 1),
      ]);
      expect(session.answerChoice(0), isTrue);
      expect(session.answerChoice(1), isTrue);
      expect(session.done, isTrue);
      final result = session.result();
      expect((result.hits, result.total, result.percent), (2, 2, 100));
    });

    test('errou uma vez: não conta como de primeira, mas avança na certa',
        () {
      final session = QuestionSession([
        _button('Q1', ['a', 'b'], 0),
        _button('Q2', ['a', 'b'], 1),
      ]);
      expect(session.answerChoice(1), isFalse);
      expect(session.done, isFalse);
      expect(session.current, isNotNull);
      expect(session.answerChoice(0), isTrue);
      expect(session.answerChoice(1), isTrue);
      final result = session.result();
      expect((result.hits, result.total, result.percent), (1, 2, 50));
    });

    test('time-limit estourado conta como erro, revela 1,5 s e avança', () {
      var t = 0.0;
      final session = QuestionSession(
        [
          _button('Q1', ['a', 'b'], 0),
          _button('Q2', ['a', 'b'], 1),
        ],
        timeLimit: 5,
        now: () => t,
      );
      // Estoura a primeira.
      t = 5.1;
      expect(session.tick(), isTrue);
      expect(session.revealing, isTrue);
      expect(session.index, 0);
      // No pisca, a resposta é ignorada.
      expect(session.answerChoice(0), isNull);
      // Antes de 1,5 s, não avança.
      t = 5.1 + 1.4;
      expect(session.tick(), isFalse);
      expect(session.index, 0);
      // Depois de 1,5 s, avança (já sem ser de primeira).
      t = 5.1 + 1.6;
      expect(session.tick(), isTrue);
      expect(session.revealing, isFalse);
      expect(session.index, 1);
      // A segunda, de primeira.
      expect(session.answerChoice(1), isTrue);
      expect(session.done, isTrue);
      final result = session.result();
      expect((result.hits, result.total), (1, 2));
    });

    test('tick com agora explícito (sem relógio injetado)', () {
      final session = QuestionSession(
        [_button('Q1', ['a', 'b'], 0)],
        timeLimit: 5,
      );
      // Tempos grandes, sem depender do relógio de parede.
      expect(session.tick(1e12 + 10), isTrue);
      expect(session.revealing, isTrue);
      expect(session.tick(1e12 + 10 + 1.6), isTrue);
      expect(session.done, isTrue);
      expect(session.result().hits, 0);
    });

    test('find-key any aceita outra oitava, exact não', () {
      final any = QuestionSession([
        const Question(expectedPitch: 60, anyOctave: true),
      ]);
      expect(any.answerPitch(72), isTrue);

      final exact = QuestionSession([
        const Question(expectedPitch: 60),
      ]);
      expect(exact.answerPitch(72), isFalse);
      expect(exact.answerPitch(60), isTrue);
    });

    test('find-key errou a tecla: não é de primeira', () {
      final session = QuestionSession([
        const Question(expectedPitch: 60),
        const Question(expectedPitch: 62),
      ]);
      expect(session.answerPitch(61), isFalse);
      expect(session.answerPitch(60), isTrue);
      expect(session.answerPitch(62), isTrue);
      expect(session.result().hits, 1);
    });
  });
}
