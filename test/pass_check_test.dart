import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/pass_check.dart';

import 'support/course_helpers.dart';

RoundResult _r(int hits, int total, {double speed = 1.0}) =>
    RoundResult(hits: hits, total: total, speed: speed);

void main() {
  late final playNotes = specFrom('''
id: a
type: play-notes
title: A
notes: {random: C4-G4}
pass: {accuracy: 90, rounds: 3}
''');

  group('RoundResult', () {
    test('porcentagem inteira para baixo; nada a tocar conta 100', () {
      expect(_r(9, 10).percent, 90);
      expect(_r(89, 100).percent, 89);
      expect(_r(17, 19).percent, 89); // 89,47
      expect(_r(0, 0).percent, 100);
      expect(_r(0, 5).percent, 0);
      expect(_r(1, 1).percent, 100);
    });

    test('andamento em % sem erro de binário', () {
      expect(_r(1, 1, speed: 0.75).speedPercent, 75);
      expect(_r(1, 1, speed: 0.7).speedPercent, 70);
      expect(_r(1, 1, speed: 0.29).speedPercent, 29);
      expect(_r(1, 1, speed: 0.999).speedPercent, 99);
    });
  });

  group('limiar de precisão', () {
    test('90% de 90 passa, 89 não', () async {
      final spec = await specFrom(
        'id: a\ntype: play-notes\ntitle: A\nnotes: [C4]\n'
        'pass: {accuracy: 90}',
      );
      expect(PassCheck.roundPasses(spec, _r(90, 100)), isTrue);
      expect(PassCheck.roundPasses(spec, _r(89, 100)), isFalse);
      expect(PassCheck.roundPasses(spec, _r(9, 10)), isTrue);
      expect(PassCheck.roundPasses(spec, _r(17, 19)), isFalse);
      final verdict = PassCheck.evaluate(spec, [_r(89, 100)]);
      expect(verdict.roundPassed, isFalse);
      expect(verdict.exercisePassed, isFalse);
      expect(verdict.reason, '89% de 90%');
    });

    test('o padrão do autor é 90, e 100 exige tudo', () async {
      final padrao = await specFrom(
        'id: a\ntype: play-notes\ntitle: A\nnotes: [C4]',
      );
      expect(PassCheck.roundPasses(padrao, _r(9, 10)), isTrue);
      final perfeito = await specFrom(
        'id: a\ntype: play-notes\ntitle: A\nnotes: [C4]\n'
        'pass: {accuracy: 100}',
      );
      expect(PassCheck.roundPasses(perfeito, _r(11, 12)), isFalse);
      expect(PassCheck.roundPasses(perfeito, _r(12, 12)), isTrue);
    });

    test('total == 0 conta como 100%', () async {
      final spec = await specFrom(
        'id: a\ntype: play-notes\ntitle: A\nnotes: [C4]\n'
        'pass: {accuracy: 100}',
      );
      final verdict = PassCheck.evaluate(spec, [_r(0, 0)]);
      expect(verdict.roundPassed, isTrue);
      expect(verdict.exercisePassed, isTrue);
    });
  });

  group('rodadas seguidas', () {
    test(
      'aprova só na terceira seguida; uma reprovada zera o streak',
      () async {
        final spec = await playNotes;
        final history = <RoundResult>[];
        PassVerdict next(RoundResult r) {
          history.add(r);
          return PassCheck.evaluate(spec, history);
        }

        var v = next(_r(12, 12));
        expect(
          (v.streak, v.exercisePassed, v.reason),
          (1, false, '1 de 3 rodadas seguidas'),
        );
        v = next(_r(12, 12));
        expect(
          (v.streak, v.exercisePassed, v.reason),
          (2, false, '2 de 3 rodadas seguidas'),
        );
        v = next(_r(9, 12)); // 75%: reprova e zera
        expect((v.roundPassed, v.streak, v.exercisePassed), (false, 0, false));
        expect(v.reason, '75% de 90%');
        v = next(_r(12, 12));
        v = next(_r(12, 12));
        expect(v.exercisePassed, isFalse);
        v = next(_r(12, 12));
        expect((v.streak, v.exercisePassed), (3, true));
        expect(v.reason, '3 rodadas seguidas');
      },
    );

    test('histórico vazio', () async {
      final v = PassCheck.evaluate(await playNotes, const []);
      expect((v.roundPassed, v.streak, v.exercisePassed), (false, 0, false));
      expect(v.reason, '0 de 3 rodadas seguidas');
    });

    test('depois de aprovado, o streak continua contando', () async {
      final v = PassCheck.evaluate(await playNotes, [
        for (var i = 0; i < 5; i++) _r(12, 12),
      ]);
      expect((v.streak, v.exercisePassed), (5, true));
    });
  });

  group('andamento (`speed`)', () {
    test('rhythm: exige o andamento, e a razão diz quanto faltou', () async {
      final spec = await specFrom(
        'id: r\ntype: rhythm\ntitle: R\nfigures: [quarter]\n'
        'pass: {accuracy: 85, speed: 100}',
      );
      final slow = PassCheck.evaluate(spec, [_r(10, 10, speed: 0.5)]);
      expect(slow.roundPassed, isFalse);
      expect(slow.reason, 'faltou andamento: 50% de 100%');
      final both = PassCheck.evaluate(spec, [_r(8, 10, speed: 0.5)]);
      expect(both.reason, '80% de 85%; faltou andamento: 50% de 100%');
      expect(
        PassCheck.evaluate(spec, [_r(9, 10, speed: 1.0)]).exercisePassed,
        isTrue,
      );
      expect(PassCheck.roundPasses(spec, _r(10, 10, speed: 1.2)), isTrue);
    });

    test('play-score: só vale em tempo real', () async {
      final wait = await specFrom(
        'id: p\ntype: play-score\ntitle: P\nabc: "X:1\\nK:C\\nCDEF|"\n'
        'mode: wait',
      );
      final realtime = await specFrom(
        'id: p\ntype: play-score\ntitle: P\nabc: "X:1\\nK:C\\nCDEF|"\n'
        'mode: realtime\npass: {speed: 75}',
      );
      // No modo espera o andamento da rodada é irrelevante.
      expect(PassCheck.roundPasses(wait, _r(10, 10, speed: 0.1)), isTrue);
      expect(PassCheck.roundPasses(realtime, _r(10, 10, speed: 0.74)), isFalse);
      expect(PassCheck.roundPasses(realtime, _r(10, 10, speed: 0.75)), isTrue);
    });

    test('nos outros tipos o `speed` é ignorado', () async {
      final spec = await playNotes;
      expect(PassCheck.speedApplies(spec), isFalse);
      expect(PassCheck.roundPasses(spec, _r(12, 12, speed: 0.1)), isTrue);
      final choice = await specFrom(
        'id: c\ntype: choice\ntitle: C\nquestion: Q\noptions: [a, b]\n'
        'answer: a',
      );
      expect(PassCheck.speedApplies(choice), isFalse);
    });
  });
}
