// T05: RhythmSession (qualquer tecla, no ritmo) e métricas de ritmo do
// PracticeReport.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:zywny/music/performance_track.dart';
import 'package:zywny/practice/practice_report.dart';
import 'package:zywny/practice/rhythm_session.dart';

SoundEvent _ev(
  String id,
  int pitch,
  double onMs, {
  int staff = 1,
  bool ornament = false,
}) => SoundEvent(
  id: id,
  pitch: pitch,
  onMs: onMs,
  offMs: onMs + 400,
  staff: staff,
  channel: 0,
  program: 0,
  velocity: 80,
  ornament: ornament,
);

RhythmSession _synthetic(List<SoundEvent> events, {double speed = 1}) =>
    RhythmSession.forStaves(
      PerformanceTrack.fromEvents(events),
      staves: {1, 2},
      speed: speed,
    );

PerformanceTrack _loadTrack(String fixture) {
  final bytes = File('test/fixtures/$fixture').readAsBytesSync();
  return PerformanceTrack.fromDocument(
    VsbDocument.fromBytes(Uint8List.fromList(bytes)),
  );
}

double _gaussianNoise(Random rng, double sigma) {
  final u1 = 1 - rng.nextDouble();
  final u2 = rng.nextDouble();
  return sqrt(-2 * log(u1)) * cos(2 * pi * u2) * sigma;
}

List<RhythmVerdict> _collect(RhythmSession s) {
  final out = <RhythmVerdict>[];
  s.verdicts.listen(out.add);
  return out;
}

void main() {
  group('RhythmSession', () {
    test('Gymnopédie (pauta 1), σ=20ms e pitches aleatórios: ≥99% correct, '
        '0 extra', () {
      final track = _loadTrack('erik-satie.vsb');
      final s = RhythmSession.forStaves(track, staves: {1}, speed: 1);
      final verdicts = _collect(s);
      final rng = Random(7);
      for (final o in s.onsets) {
        s.hit(o.onMs + _gaussianNoise(rng, 20), velocity: rng.nextInt(127));
      }
      s.tick(track.durationMs + 1000);
      expect(s.onsets, isNotEmpty);
      expect(verdicts.where((v) => v.kind == RhythmVerdictKind.extra), isEmpty);
      final ok = verdicts.where((v) => v.kind == RhythmVerdictKind.correct);
      expect(ok.length / s.onsets.length, greaterThanOrEqualTo(0.99));
    });

    test('acorde de 3 notas em 30ms: 1 correct com os 3 ids, 0 extra', () {
      final s = _synthetic([
        _ev('a', 60, 1000),
        _ev('b', 64, 1000),
        _ev('c', 67, 1000),
      ]);
      final verdicts = _collect(s);
      s.hit(1000);
      s.hit(1015);
      s.hit(1030);
      expect(verdicts, hasLength(1));
      expect(verdicts.single.kind, RhythmVerdictKind.correct);
      expect(verdicts.single.eventIds, unorderedEquals(['a', 'b', 'c']));
    });

    test('as mesmas 3 teclas espalhadas em 200ms: 1 casamento + extras', () {
      final s = _synthetic([
        _ev('a', 60, 1000),
        _ev('b', 64, 1000),
        _ev('c', 67, 1000),
      ]);
      final verdicts = _collect(s);
      s.hit(1000);
      s.hit(1100);
      s.hit(1200);
      expect(verdicts.map((v) => v.kind), [
        RhythmVerdictKind.correct,
        RhythmVerdictKind.extra,
        RhythmVerdictKind.extra,
      ]);
    });

    test('acordes de pautas diferentes no mesmo onMs viram um alvo só', () {
      final s = _synthetic([_ev('a', 60, 1000), _ev('b', 40, 1000, staff: 2)]);
      expect(s.onsets, hasLength(1));
      expect(s.onsets.single.eventIds, unorderedEquals(['a', 'b']));
    });

    test('pular um compasso: só esses onsets são missed; toque numa pausa '
        'longa: 1 extra', () {
      final events = [for (var i = 0; i < 12; i++) _ev('e$i', 60, i * 500.0)];
      final s = _synthetic(events);
      final verdicts = _collect(s);
      for (var i = 0; i < 12; i++) {
        if (i >= 4 && i < 8) continue;
        s.hit(i * 500.0, atMs: i * 500.0);
      }
      s.tick(20000);
      final missed = verdicts.where((v) => v.kind == RhythmVerdictKind.missed);
      expect(missed.map((v) => v.onsetIndex), [4, 5, 6, 7]);

      final s2 = _synthetic([_ev('a', 60, 0), _ev('b', 60, 4000)]);
      final v2 = _collect(s2);
      s2.hit(2000);
      expect(v2.single.kind, RhythmVerdictKind.extra);
      expect(v2.single.onsetIndex, isNull);
    });

    group('speed 0.5 (janelas 60/130ms viram 30/65ms musicais)', () {
      RhythmVerdict one(double delta) {
        final s = _synthetic([_ev('a', 60, 1000)], speed: 0.5);
        final v = _collect(s);
        s.hit(1000 + delta);
        return v.single;
      }

      test('borda da janela ok', () {
        expect(one(30).kind, RhythmVerdictKind.correct);
        expect(one(31).kind, RhythmVerdictKind.late);
        expect(one(-31).kind, RhythmVerdictKind.early);
      });

      test('borda da janela máxima', () {
        expect(one(65).kind, RhythmVerdictKind.late);
        expect(one(66).kind, RhythmVerdictKind.extra);
      });
    });

    test('onset só de ornamento não vira alvo; ligadura não gera onset', () {
      final s = _synthetic([
        _ev('orn', 60, 500, ornament: true),
        _ev('real', 62, 1000),
      ]);
      expect(s.onsets.map((o) => o.onMs), [1000]);
      final verdicts = _collect(s);
      s.tick(600);
      expect(verdicts, isEmpty);

      // Nota ligada: N03 só emite o evento inicial (offMs cobre as duas).
      final tied = _synthetic([
        SoundEvent(
          id: 't',
          pitch: 60,
          onMs: 0,
          offMs: 2000,
          staff: 1,
          channel: 0,
          program: 0,
          velocity: 80,
          ornament: false,
        ),
      ]);
      expect(tied.onsets, hasLength(1));
    });

    test('resetTo descarta os onsets antes do ponto', () {
      final s = _synthetic([_ev('a', 60, 0), _ev('b', 60, 1000)]);
      final verdicts = _collect(s);
      s.resetTo(900);
      s.tick(500);
      expect(verdicts, isEmpty);
      s.hit(1000);
      expect(verdicts.single.onsetIndex, 1);
    });
  });

  group('PracticeReport.rhythm', () {
    RhythmReportEntry r(RhythmVerdictKind k, int measure, {double delta = 0}) =>
        RhythmReportEntry(
          RhythmVerdict(
            onsetIndex: k == RhythmVerdictKind.extra ? null : 0,
            eventIds: k == RhythmVerdictKind.extra ? const [] : const ['x'],
            kind: k,
            deltaMs: delta,
          ),
          measure,
        );

    test('delta médio, desvio, extras e piores compassos', () {
      final report = PracticeReport.rhythm([
        r(RhythmVerdictKind.correct, 0, delta: -30),
        r(RhythmVerdictKind.correct, 0, delta: -10),
        r(RhythmVerdictKind.late, 1, delta: 90),
        r(RhythmVerdictKind.early, 1, delta: -70),
        r(RhythmVerdictKind.missed, 2),
        r(RhythmVerdictKind.missed, 2),
        r(RhythmVerdictKind.extra, 1),
      ]);
      expect(report.total, 6);
      expect(report.extra, 1);
      expect(report.correct, 2);
      expect(report.accuracy, closeTo(2 / 6, 1e-9));
      // (-30 - 10 + 90 - 70) / 4 = -5
      expect(report.meanDeltaMs, closeTo(-5, 1e-9));
      // desvios: -25, -5, 95, -65 → (625+25+9025+4225)/4 = 3475
      expect(report.stdDevMs, closeTo(sqrt(3475), 1e-9));
      expect(report.worstMeasures().first.index, 2);
    });

    test('delta em ms de parede a speed 0.5', () {
      final report = PracticeReport.rhythm([
        r(RhythmVerdictKind.correct, 0, delta: -25),
      ], speed: 0.5);
      expect(report.meanDeltaMs, closeTo(-50, 1e-9));
    });
  });
}
