import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/sight_reading/sight_generator.dart';
import 'package:zywny/sight_reading/sight_steps.dart';

void main() {
  // Cada passo, com várias sementes: o sorteio tem que respeitar a tabela
  // sempre, não só numa rodada sortuda.
  for (final step in sightSteps) {
    test(
      'passo ${step.name}: compassos completos, graus na faixa, mãos certas',
      () {
        for (var seed = 0; seed < 12; seed++) {
          final ex = generateSight(step, Random(seed));
          expect(ex.right, hasLength(sightMeasures), reason: step.name);
          expect(ex.left, hasLength(sightMeasures), reason: step.name);
          for (final pauta in [ex.right, ex.left]) {
            for (final measure in pauta) {
              final total = measure.fold<int>(0, (sum, n) => sum + n.units);
              expect(total, step.unitsPerMeasure, reason: step.name);
              for (final note in measure) {
                if (!note.isRest) {
                  expect(
                    note.degree,
                    inInclusiveRange(1, 8),
                    reason: step.name,
                  );
                }
              }
            }
          }
          // A mão que não toca é pausa de compasso inteiro.
          if (step.hands == SightHands.right) {
            expect(_allRests(ex.left), isTrue, reason: step.name);
          }
          if (step.hands == SightHands.left) {
            expect(_allRests(ex.right), isTrue, reason: step.name);
          }
          if (step.hands == SightHands.both) {
            expect(_allRests(ex.right), isFalse, reason: step.name);
            expect(_allRests(ex.left), isFalse, reason: step.name);
          }
        }
      },
    );
  }

  test('a mesma semente dá a mesma rodada', () {
    final step = sightStep(9, 2);
    String show(SightExercise ex) => [
      for (final pauta in [ex.right, ex.left])
        [
          for (final m in pauta) [for (final n in m) '${n.units}:${n.degree}'],
        ],
    ].toString();
    expect(
      show(generateSight(step, Random(7))),
      show(generateSight(step, Random(7))),
    );
  });

  test('a melodia de um passo sem pausas não tem pausa', () {
    final ex = generateSight(sightStep(1, 3), Random(3));
    expect(ex.right.expand((m) => m).any((n) => n.isRest), isFalse);
  });

  test('o exercício termina na tônica: a última nota que soa é o dó', () {
    for (final step in sightSteps) {
      for (var seed = 0; seed < 12; seed++) {
        final ex = generateSight(step, Random(seed));
        for (final pauta in [ex.right, ex.left]) {
          final last = pauta.last;
          if (_silent(last)) continue;
          expect(last.last.isRest, isFalse, reason: step.name);
          expect(last.last.degree, 1, reason: step.name);
        }
      }
    }
  });

  test('sem síncope: nenhuma figura cruza um tempo que ela não começa', () {
    for (final step in sightSteps) {
      // O passo de síncopas é o único que pode sincopar (ver o teste dele).
      if (step.syncopated) continue;
      final strong = step.unitsPerMeasure == 16 ? [0, 8] : [0];
      for (var seed = 0; seed < 12; seed++) {
        final ex = generateSight(step, Random(seed));
        for (final pauta in [ex.right, ex.left]) {
          for (final measure in pauta) {
            var pos = 0;
            for (final n in measure) {
              final where = '${step.name} seed $seed pos $pos';
              if (pos % 4 != 0) {
                // Começou fora do tempo: tem que terminar até o tempo seguinte.
                expect(pos % 4 + n.units, lessThanOrEqualTo(4), reason: where);
              } else if (!strong.contains(pos)) {
                // Começou num tempo fraco: não pode passar do tempo forte.
                final next = strong.firstWhere(
                  (s) => s > pos,
                  orElse: () => step.unitsPerMeasure,
                );
                expect(pos + n.units, lessThanOrEqualTo(next), reason: where);
              }
              pos += n.units;
            }
          }
        }
      }
    }
  });

  test(
    'o passo de síncopas sincopa: alguma figura atravessa o tempo seguinte',
    () {
      final step = sightStep(9, 2);
      expect(step.syncopated, isTrue);
      var found = false;
      for (var seed = 0; seed < 40 && !found; seed++) {
        for (final measure in generateSight(step, Random(seed)).right) {
          var pos = 0;
          for (final n in measure) {
            if (pos % 4 != 0 && pos % 4 + n.units > 4) found = true;
            pos += n.units;
          }
        }
      }
      expect(found, isTrue);
    },
  );

  test('o nível 9 tem a semicolcheia que fecha a colcheia pontuada', () {
    for (final sub in [0, 1, 3]) {
      expect(sightStep(9, sub).durations, containsAll([1, 3]));
    }
  });

  test('as duas mãos com acompanhamento: a direita cai no acorde nos tempos fortes', () {
    var checked = 0;
    for (final step in sightSteps.where((s) => s.hands == SightHands.both)) {
      final strong = step.unitsPerMeasure == 16 ? [0, 8] : [0];
      for (var seed = 0; seed < 40; seed++) {
        final ex = generateSight(step, Random(seed));
        if (ex.texture != SightTexture.acompanhamento) continue;
        // O último compasso leva a cadência na tônica: fica de fora.
        for (var m = 0; m < sightMeasures - 1; m++) {
          var pos = 0;
          for (final n in ex.right[m]) {
            final bass = _soundingDegree(ex.left[m], pos);
            if (!n.isRest && bass != null && strong.contains(pos)) {
              expect(_inChord(n.degree!, bass), isTrue, reason: step.name);
              checked++;
            }
            pos += n.units;
          }
        }
      }
    }
    expect(checked, greaterThan(0));
  });

  test('as vozes das duas mãos seguem a maneira sorteada', () {
    final seen = <SightTexture>{};
    for (final step in sightSteps.where(
      (s) => s.hands == SightHands.both && s.level >= 11,
    )) {
      for (var seed = 0; seed < 40; seed++) {
        final ex = generateSight(step, Random(seed));
        final texture = ex.texture!;
        seen.add(texture);
        if (texture == SightTexture.perguntaResposta) {
          for (var m = 0; m < sightMeasures; m++) {
            if (m.isEven) {
              expect(_silent(ex.left[m]), isTrue, reason: step.name);
            } else {
              expect(_silent(ex.right[m]), isTrue, reason: step.name);
            }
          }
          continue;
        }
        if (texture == SightTexture.acompanhamento) continue;
        // Ritmo igual nas duas mãos: compara nota a nota. A cadência mexe na
        // última nota, então ela fica de fora.
        for (var m = 0; m < sightMeasures; m++) {
          final notes = ex.right[m].length;
          final count = m == sightMeasures - 1 ? notes - 1 : notes;
          for (var i = 0; i < count; i++) {
            final r = ex.right[m][i];
            final l = ex.left[m][i];
            expect(l.units, r.units, reason: step.name);
            if (r.isRest) {
              expect(l.isRest, isTrue, reason: step.name);
              continue;
            }
            final d = r.degree!;
            final e = l.degree!;
            switch (texture) {
              case SightTexture.tercas:
                expect((d - e) % 7, 2, reason: step.name);
              case SightTexture.sextas:
                expect((d - e) % 7, 5, reason: step.name);
              case SightTexture.contrario:
                expect((d + e) % 7, 2, reason: step.name);
              default:
                fail('textura ${texture.name} não é uma voz');
            }
          }
        }
      }
    }
    expect(seen, containsAll(SightTexture.values));
  });

  test('passo de uma mão não sorteia maneira nenhuma', () {
    expect(generateSight(sightStep(1, 0), Random(1)).texture, isNull);
  });
}

bool _allRests(List<List<SightNote>> pauta) =>
    pauta.every((m) => m.every((n) => n.isRest));

/// O grau que soa no [pos] de um compasso da pauta, ou `null` se é pausa.
int? _soundingDegree(List<SightNote> measure, int pos) {
  var at = 0;
  for (final n in measure) {
    if (pos < at + n.units) return n.degree;
    at += n.units;
  }
  return null;
}

/// Se [degree] é uma nota da tríade armada sobre o grau [bass] (1, 3, 5 dele).
bool _inChord(int degree, int bass) =>
    [0, 2, 4].any((s) => (bass - 1 + s) % 7 == (degree - 1) % 7);

/// Se o compasso inteiro é pausa.
bool _silent(List<SightNote> measure) => measure.every((n) => n.isRest);
