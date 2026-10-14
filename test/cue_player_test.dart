// E02 — `playCues` agenda os sons da pergunta em sequência, com silêncio entre
// eles, e cala o que estava soando antes.
import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/cue_player.dart';
import 'package:zywny/course/exercise/exercise_round.dart';

import 'support/practice_fakes.dart';

void main() {
  test('dois sons: um depois do outro, com silêncio entre eles', () {
    final engine = FakeSoundEngine()..now = 0;
    final total = playCues(engine, [
      const SoundCue([60]),
      const SoundCue([64]),
    ]);

    expect(engine.allNotesOffCalls, 1);
    expect(engine.scheduled, hasLength(4));
    final [on60, off60, on64, off64] = engine.scheduled;
    expect(on60.at, closeTo(0.02, 1e-9));
    expect(on60.status, 0x90);
    expect(on60.d1, 60);
    expect(off60.at, closeTo(1.02, 1e-9));
    expect(off60.status, 0x80);
    expect(off60.d1, 60);
    expect(on64.at, closeTo(1.32, 1e-9));
    expect(on64.status, 0x90);
    expect(on64.d1, 64);
    expect(off64.at, closeTo(2.32, 1e-9));
    expect(off64.status, 0x80);
    expect(off64.d1, 64);
    expect(total, closeTo(2.3, 1e-9));
  });

  test('um acorde: as notas ligadas soam no mesmo instante', () {
    final engine = FakeSoundEngine()..now = 0;
    playCues(engine, [
      const SoundCue([60, 64, 67]),
    ]);

    final ons = engine.scheduled.where((e) => e.status == 0x90).toList();
    expect(ons.map((e) => e.d1), [60, 64, 67]);
    expect(ons.map((e) => e.at).toSet(), hasLength(1));
  });

  test('velocidade padrão 90 nas notas ligadas, 0 nas desligadas', () {
    final engine = FakeSoundEngine()..now = 0;
    playCues(engine, [
      const SoundCue([60]),
    ]);

    expect(engine.scheduled.first.d2, 90);
    expect(engine.scheduled.last.d2, 0);
  });

  test('sem sons: não agenda nada e ainda cala o que soava', () {
    final engine = FakeSoundEngine()..now = 0;
    final total = playCues(engine, const []);

    expect(total, 0);
    expect(engine.scheduled, isEmpty);
    expect(engine.allNotesOffCalls, 1);
  });

  test(
    'playTimed: cada nota liga e desliga na sua hora, a partir do relógio',
    () {
      final engine = FakeSoundEngine()..now = 0;
      final total = playTimed(engine, [
        const TimedNote(60, 0, 1),
        const TimedNote(64, 1.5, 0.5),
      ]);

      expect(engine.allNotesOffCalls, 1);
      expect(engine.scheduled, hasLength(4));
      final [on60, off60, on64, off64] = engine.scheduled;
      expect(on60.at, closeTo(0.02, 1e-9));
      expect(on60.status, 0x90);
      expect(on60.d1, 60);
      expect(on60.d2, 90);
      expect(off60.at, closeTo(1.02, 1e-9));
      expect(off60.status, 0x80);
      expect(off60.d1, 60);
      expect(off60.d2, 0);
      expect(on64.at, closeTo(1.52, 1e-9));
      expect(on64.d1, 64);
      expect(off64.at, closeTo(2.02, 1e-9));
      expect(off64.d1, 64);
      expect(total, closeTo(2.0, 1e-9));
    },
  );

  test(
    'playTimed: notas que se sobrepõem soam juntas, cada uma na sua hora',
    () {
      final engine = FakeSoundEngine()..now = 0;
      playTimed(engine, [
        const TimedNote(60, 0, 2),
        const TimedNote(67, 0.5, 2),
      ]);

      final ons = engine.scheduled.where((e) => e.status == 0x90).toList();
      expect(ons.map((e) => e.d1), [60, 67]);
      expect(ons[1].at - ons[0].at, closeTo(0.5, 1e-9));
    },
  );

  test('playTimed sem notas: não agenda nada, cala o que soava e dura 0', () {
    final engine = FakeSoundEngine()..now = 0;
    final total = playTimed(engine, const []);

    expect(total, 0);
    expect(engine.scheduled, isEmpty);
    expect(engine.allNotesOffCalls, 1);
  });
}
