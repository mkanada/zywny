import 'dart:async';

import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny/practice/hand.dart';

import 'practice_fakes.dart';

/// O MIDI de teste: um teclado "conectado" (ou nenhum, com [list] vazia).
class FakeMidiCommand implements MidiCommand {
  List<MidiDevice> list = [];
  final StreamController<MidiSetupChange> setup =
      StreamController<MidiSetupChange>.broadcast();

  @override
  Future<List<MidiDevice>?> get devices async => list;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => setup.stream;

  @override
  Future<void> connectToDevice(
    MidiDevice device, {
    Duration? awaitConnectionTimeout,
  }) async {
    device.connected = true;
  }

  @override
  void disconnectDevice(MidiDevice device) => device.connected = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Toca cada nota da pauta do aluno no instante dela, como o aluno simulado
/// do tempo real (`playTimedRound`): anda o agendador até o evento e aperta.
Future<void> playAllCorrect(
  WidgetTester tester,
  ScoreRoundRunner runner,
  FakeMidiInput midi,
  FakeSoundEngine engine,
  Future<RoundResult?> result,
) async {
  var done = false;
  unawaited(result.whenComplete(() => done = true));
  final staves = runner.practice.hand.studentStaves;
  final events = [
    for (final e in runner.track.events)
      if (staves.contains(e.staff) && !e.ornament) e,
  ];
  for (final event in events) {
    if (done) break;
    advance(engine, runner, event.onMs);
    midi.press(event.pitch, atSeconds: engine.now);
    await tester.pump();
    midi.release(event.pitch, atSeconds: engine.now);
    await tester.pump();
  }
  advance(engine, runner, runner.track.durationMs + 500);
  for (var i = 0; !done && i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await result;
}

/// Anda o relógio do motor até [ms] (em milissegundos musicais).
void advance(FakeSoundEngine engine, ScoreRoundRunner runner, double ms) {
  var guard = 0;
  while (runner.scheduler.positionMs < ms) {
    engine.now += 0.025;
    runner.scheduler.pump();
    if (guard++ > 200000) throw StateError('o relógio não chegou a $ms ms');
  }
}
