import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/sight_reading/sight_steps.dart';

void main() {
  test('sightStepNamed acha o passo pelo nome e recusa o resto', () {
    for (final name in ['1a', '11c', '20d']) {
      expect(sightStepNamed(name)?.name, name);
    }
    for (final name in ['0a', '21a', '1e', 'abc', '']) {
      expect(sightStepNamed(name), isNull, reason: name);
    }
  });

  test('são 80 passos, do 1a ao 20d, na ordem do treino', () {
    expect(sightSteps, hasLength(80));
    expect(sightSteps.first.name, '1a');
    expect(sightSteps.last.name, '20d');
    final names = {for (final s in sightSteps) s.name};
    expect(names, hasLength(80));
    for (var i = 0; i < sightSteps.length; i++) {
      expect(sightStep(sightSteps[i].level, sightSteps[i].sub), sightSteps[i]);
    }
  });

  test(
    'o começo segue a progressão: dó maior, uma mão por vez, depois as duas',
    () {
      expect(sightStep(1, 0).hands, SightHands.right);
      expect(sightStep(1, 0).durations, [16]);
      expect(sightStep(2, 0).hands, SightHands.left);
      expect(sightStep(3, 0).hands, SightHands.both);
      expect(sightStep(4, 0).durations, [8]);
      expect(sightStep(6, 2).threeFour, isTrue);
      expect(sightStep(6, 2).unitsPerMeasure, 12);
    },
  );

  test('de 11 a 20, cada nível é uma tonalidade nova, começando de sol', () {
    expect(sightStep(11, 0).tonic, 'G');
    expect(sightStep(12, 0).tonic, 'F');
    expect(sightStep(14, 0).tonic, 'Bb');
    expect(sightStep(20, 0).tonic, 'Db');
    for (final sub in [0, 1, 2, 3]) {
      expect(sightStep(15, sub).tonic, 'A');
    }
  });

  test('o andamento segue a tabela de cada passo', () {
    expect(
      [for (var l = 1; l <= 4; l++) sightStep(l, 0).bpm],
      [30, 30, 30, 30],
    );
    expect(sightStep(8, 0).bpm, 55);
    expect(sightStep(11, 0).bpm, 35);
    expect(sightStep(11, 3).bpm, 50);
  });

  test('toda figura cabe no compasso e os padrões ficam entre a tônica e a oitava', () {
    // Um padrão pode passar do grau mais agudo do passo (o gerador corta na
    // faixa, como no ftrain), mas nunca sai de uma oitava.
    for (final step in sightSteps) {
      // Figuras que não cabem no compasso (semibreve em 3/4) ficam de fora
      // do sorteio daquele momento: o que importa é sempre haver uma que caiba.
      expect(
        step.durations.any((d) => d <= step.unitsPerMeasure),
        isTrue,
        reason: step.name,
      );
      for (final pattern in step.patterns) {
        for (final degree in pattern) {
          expect(degree, inInclusiveRange(1, 8), reason: step.name);
        }
      }
    }
  });
}
