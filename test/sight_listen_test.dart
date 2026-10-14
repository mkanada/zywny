// E05 — a frase que soa, a mudança sorteada e a pergunta pronta.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/sight_reading/sight_change.dart';
import 'package:zywny/sight_reading/sight_generator.dart';
import 'package:zywny/sight_reading/sight_listen.dart';
import 'package:zywny/sight_reading/sight_phrase.dart';
import 'package:zywny/sight_reading/sight_score.dart';
import 'package:zywny/sight_reading/sight_steps.dart';

List<SightEvent> _written(SightStep step, int seed) =>
    sightEvents(generateSight(step, Random(seed)));

/// Quantos dezesseis avos cada pauta tem em cada compasso.
Map<String, int> _unitsByMeasure(List<SightEvent> events) {
  final sums = <String, int>{};
  for (final e in events) {
    final key = '${e.staff}-${e.measure}';
    sums[key] = (sums[key] ?? 0) + e.units;
  }
  return sums;
}

/// Os índices em que as duas frases soam alturas diferentes.
List<int> _differences(List<SightEvent> a, List<SightEvent> b) => [
  for (var i = 0; i < a.length; i++)
    if (a[i].midi != b[i].midi) i,
];

void main() {
  group('sightEvents e sightTimedNotes', () {
    test('o 1a tem quatro semibreves na mão direita, uma por compasso', () {
      final events = _written(sightStep(1, 0), 1);
      expect(events, hasLength(4));
      expect(events.map((e) => e.start), [0, 16, 32, 48]);
      expect(events.every((e) => e.staff == 1), isTrue);
      expect(events.every((e) => e.units == 16), isTrue);
      expect(events.first.ids, ['s1-m1-n1']);
    });

    test('a 60 bpm, a semibreve soa 4 s × 0,95', () {
      final step = sightStep(1, 0);
      final plain = sightTimedNotes(
        step,
        _written(step, 1),
        bpm: 60,
        withTonic: false,
      );
      expect(plain.first.start, 0);
      expect(plain.first.seconds, closeTo(3.8, 1e-9));
      expect(plain[1].start, closeTo(4, 1e-9));
    });

    test('com o acorde, a frase começa em 1,8 s e o acorde é a tônica', () {
      final step = sightStep(1, 0);
      final notes = sightTimedNotes(step, _written(step, 1), bpm: 60);
      expect(notes.take(4).map((n) => n.pitch), [60, 64, 67, 48]);
      expect(notes.first.seconds, closeTo(kSightChordSeconds, 1e-9));
      expect(notes[4].start, closeTo(1.8, 1e-9));
    });

    test('o andamento da frase é o do passo, nunca abaixo de 72', () {
      expect(sightListenBpm(sightStep(1, 0)), 72);
      expect(sightListenBpm(sightStep(1, 0)), greaterThanOrEqualTo(72));
    });
  });

  group('changeSight', () {
    test('pitch: uma nota muda de grau; a primeira nunca muda', () {
      for (final step in sightSteps) {
        for (var seed = 1; seed <= 20; seed++) {
          final written = _written(step, seed);
          final changed = changeSight(
            step,
            written,
            SightChange.pitch,
            Random(seed ^ 0x5eed),
          );
          final where = '${step.name} semente $seed';
          expect(changed, isNotNull, reason: where);
          final played = changed!.played;
          expect(played, hasLength(written.length), reason: where);
          final diff = _differences(written, played);
          expect(diff, hasLength(1), reason: where);
          expect(diff.single, greaterThan(0), reason: where);
          final i = diff.single;
          expect(
            played[i].midi,
            sightMidi(step, played[i].degree, staff: played[i].staff),
            reason: where,
          );
          expect(changed.changedIds, written[i].ids.toSet(), reason: where);
          expect(changed.measure, written[i].measure, reason: where);
        }
      }
    });

    test(
      'rhythm: a soma de cada pauta não muda; uma figura a mais ou a menos',
      () {
        for (final step in sightSteps) {
          for (var seed = 1; seed <= 20; seed++) {
            final written = _written(step, seed);
            final changed = changeSight(
              step,
              written,
              SightChange.rhythm,
              Random(seed ^ 0x5eed),
            );
            final where = '${step.name} semente $seed';
            expect(changed, isNotNull, reason: where);
            final played = changed!.played;
            expect(
              _unitsByMeasure(played),
              _unitsByMeasure(written),
              reason: where,
            );
            final diff = played.length - written.length;
            expect(diff.abs(), 1, reason: where);
            // Dividir troca uma nota por duas; juntar, duas por uma.
            expect(
              changed.changedIds,
              hasLength(diff == 1 ? 1 : 2),
              reason: where,
            );
            for (var k = 1; k < played.length; k++) {
              expect(
                sightEventOrder(played[k - 1], played[k]),
                lessThanOrEqualTo(0),
                reason: where,
              );
            }
          }
        }
      },
    );

    test(
      'accidental: no 11c (Sol), o Fá♯ escrito soa Fá, um semitom abaixo',
      () {
        final step = sightStep(11, 2);
        expect(sightChangesFor(step), contains(SightChange.accidental));
        var found = 0;
        for (var seed = 1; seed <= 40; seed++) {
          final written = _written(step, seed);
          final changed = changeSight(
            step,
            written,
            SightChange.accidental,
            Random(seed ^ 0x5eed),
          );
          if (changed == null) continue;
          found++;
          final diff = _differences(written, changed.played);
          expect(diff, hasLength(1), reason: 'semente $seed');
          final i = diff.single;
          expect(i, greaterThan(0), reason: 'semente $seed');
          expect(written[i].degree, 7, reason: 'em Sol, o acidente é o Fá♯');
          expect(changed.played[i].midi, written[i].midi - 1);
        }
        expect(found, greaterThan(0));
      },
    );

    test('accidental: sem armadura não há onde pôr, e devolve null', () {
      final step = sightStep(1, 0);
      expect(sightChangesFor(step), isNot(contains(SightChange.accidental)));
      final written = _written(step, 1);
      expect(
        changeSight(step, written, SightChange.accidental, Random(1)),
        isNull,
      );
    });
  });

  group('sightListenQuestion', () {
    test('a mesma semente dá a mesma pergunta', () {
      final step = sightStep(5, 2);
      final a = sightListenQuestion(step, 7);
      final b = sightListenQuestion(step, 7);
      expect(a.correct, b.correct);
      expect(a.answers, b.answers);
      expect(a.compare!.scoreBytes, b.compare!.scoreBytes);
      expect(a.compare!.changedIds, b.compare!.changedIds);
      expect(
        a.compare!.played.map((n) => n.pitch),
        b.compare!.played.map((n) => n.pitch),
      );
    });

    test('measure: o certo está entre 0 e 3 e é o de uma nota que mudou; os '
        'quatro compassos aparecem em 40 sementes', () {
      final step = sightStep(5, 2);
      final corrects = <int>{};
      for (var seed = 1; seed <= 40; seed++) {
        final q = sightListenQuestion(step, seed);
        expect(q.answers, ['1', '2', '3', '4']);
        final c = q.correct!;
        corrects.add(c);
        expect(q.compare!.measure, c);
        expect(
          q.compare!.changedIds.any((id) => id.contains('-m${c + 1}-')),
          isTrue,
          reason: 'semente $seed',
        );
      }
      expect(corrects, {0, 1, 2, 3});
    });

    test('note (E10): sem botões e sempre muda; os ids de changedIds são '
        'notas da partitura desta pergunta', () {
      final step = sightStep(5, 2);
      for (var seed = 1; seed <= 40; seed++) {
        final q = sightListenQuestion(step, seed, answer: SightAnswer.note);
        expect(q.answers, isEmpty, reason: 'semente $seed');
        expect(q.correct, isNull, reason: 'semente $seed');
        final ids = q.compare!.changedIds;
        expect(ids, isNotEmpty, reason: 'semente $seed');
        final score = utf8.decode(q.compare!.scoreBytes);
        for (final id in ids) {
          expect(score, contains('id="$id"'), reason: 'semente $seed');
        }
      }
    });

    test(
      'sameDifferent: metade das vezes nada muda; as duas respostas aparecem',
      () {
        final step = sightStep(5, 2);
        final answers = <int>{};
        for (var seed = 1; seed <= 40; seed++) {
          final q = sightListenQuestion(
            step,
            seed,
            answer: SightAnswer.sameDifferent,
          );
          expect(q.answers, ['Igual', 'Diferente']);
          final c = q.correct!;
          answers.add(c);
          if (c == 0) {
            expect(q.compare!.changedIds, isEmpty);
            expect(q.compare!.measure, isNull);
            expect(
              q.compare!.played.map((n) => n.pitch),
              q.compare!.written.map((n) => n.pitch),
            );
          } else {
            expect(q.compare!.changedIds, isNotEmpty);
            expect(q.compare!.measure, isNotNull);
          }
        }
        expect(answers, {0, 1});
      },
    );

    test('o acidente cabe em todo passo com armadura, salvo 11a e 11b (sem Fá♯ '
        'nos graus que o gerador sorteia)', () {
      final semAcidente = <String>[];
      for (final step in sightSteps.where((s) => s.tonic != 'C')) {
        try {
          sightListenQuestion(step, 1, change: SightChange.accidental);
        } on StateError {
          semAcidente.add(step.name);
        }
      }
      expect(semAcidente, ['11a', '11b']);
    });

    test('bpm sobrepõe o andamento do passo', () {
      final q = sightListenQuestion(sightStep(1, 0), 1, bpm: 60);
      // O acorde são quatro notas; a primeira figura da frase vem depois.
      expect(q.compare!.written.skip(4).first.seconds, closeTo(3.8, 1e-9));
    });
  });

  // O acorde de referência é o da tônica, o mesmo que toca antes da frase, e
  // vai junto da pergunta (na pergunta de ouvido e no ditado).
  group('acorde de referência', () {
    test('1c: o acorde de Dó (60, 64, 67 e 48), igual ao que toca', () {
      final step = sightStep(1, 2);
      const chord = [60, 64, 67, 48];
      expect(sightChordMidis(step), chord);
      expect(sightListenQuestion(step, 7).compare!.reference, chord);
      expect(
        sightListenQuestion(step, 7, answer: SightAnswer.note).compare!
            .reference,
        chord,
      );
      expect(sightDictationQuestions(step, 7).first.compare!.reference, chord);
    });
  });

  // E09 — o ditado: uma pergunta por nota da pauta ditada, menos a primeira.
  group('ditado', () {
    test('1c: três perguntas (quatro semibreves, menos a primeira), todas '
        'com a mesma frase e qualquer oitava', () {
      final questions = sightDictationQuestions(sightStep(1, 2), 7);
      expect(questions, hasLength(3));
      final phrase = questions.first.compare!;
      for (final q in questions) {
        expect(identical(q.compare, phrase), isTrue);
        expect(q.anyOctave, isTrue);
        expect(q.answers, isEmpty);
      }
      expect(questions.map((q) => q.highlightId), [
        's1-m2-n1',
        's1-m3-n1',
        's1-m4-n1',
      ]);
    });

    test('a resposta de cada pergunta é a altura da nota escrita, e a frase '
        'soa como está escrita', () {
      final questions = sightDictationQuestions(sightStep(1, 2), 7);
      final compare = questions.first.compare!;
      // O acorde (quatro notas) vem antes; a primeira nota é escrita.
      expect(
        questions.map((q) => q.expectedPitch).toList(),
        compare.written.skip(4 + 1).map((n) => n.pitch).toList(),
      );
      expect(compare.changedIds, isEmpty);
      expect(compare.measure, isNull);
      expect(
        compare.played.map((n) => n.pitch).toList(),
        compare.written.map((n) => n.pitch).toList(),
      );
      expect(compare.promptBytes, isNotNull);
    });

    test('o passo de fá dita a pauta de fá (ids s2-)', () {
      final questions = sightDictationQuestions(sightStep(2, 0), 7);
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q.highlightId, startsWith('s2-'));
      }
    });

    test('todo passo tem perguntas, e os ids não se repetem numa frase', () {
      for (final step in sightSteps) {
        final questions = sightDictationQuestions(step, 3);
        expect(questions, isNotEmpty, reason: step.name);
        final ids = [for (final q in questions) q.highlightId];
        expect(ids.toSet(), hasLength(ids.length), reason: step.name);
      }
    });
  });
}
