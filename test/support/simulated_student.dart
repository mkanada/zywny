import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';

import 'practice_fakes.dart';

/// O **aluno simulado**: toca uma rodada de partitura no modo espera usando o
/// teclado MIDI falso, sem aparelho e sem tempo real.
///
/// Lê o passo pendente do `PracticeController`, anda o relógio falso até o
/// instante dele e aperta/solta as teclas. Com [wrongEvery] = n, aperta uma
/// tecla errada **antes** de cada n-ésimo passo (o passo deixa de contar
/// "de primeira"). Devolve o resultado da rodada (`null` se foi cancelada).
///
/// [runner] precisa ter sido criado com `autoTick: false` e um
/// [FakeSoundEngine]; [load] e [start] ficam por conta do chamador, que
/// passa o [Future] do `start()` em [result].
Future<RoundResult?> playScoreRound(
  ScoreRoundRunner runner,
  FakeMidiInput midi,
  FakeSoundEngine engine,
  Future<RoundResult?> result, {
  int? wrongEvery,
}) async {
  var done = false;
  unawaited(result.whenComplete(() => done = true));
  final practice = runner.practice;
  var stepNumber = 0;
  var guard = 0;
  while (!done) {
    if (guard++ > 2000) {
      throw StateError('o aluno simulado não terminou a rodada');
    }
    final step = practice.currentStep.value;
    if (step == null) {
      await pumpEventQueue();
      continue;
    }
    stepNumber++;
    _advanceTo(engine, runner, step.onMs);
    final wanted = {for (final e in step.notes) e.pitch};
    if (wrongEvery != null && stepNumber % wrongEvery == 0) {
      final wrong = [21, 22, 23].firstWhere((p) => !wanted.contains(p));
      midi.press(wrong, atSeconds: engine.now);
      await pumpEventQueue();
      midi.release(wrong, atSeconds: engine.now);
      await pumpEventQueue();
    }
    for (final pitch in wanted) {
      midi.press(pitch, atSeconds: engine.now);
    }
    await pumpEventQueue();
    // Tecla repetida no passo seguinte exige soltar e apertar de novo.
    for (final pitch in wanted) {
      midi.release(pitch, atSeconds: engine.now);
    }
    await pumpEventQueue();
  }
  return result;
}

void _advanceTo(
  FakeSoundEngine engine,
  ScoreRoundRunner runner,
  double targetMs,
) {
  var guard = 0;
  while (runner.scheduler.positionMs < targetMs) {
    engine.now += 0.025;
    runner.scheduler.pump();
    if (guard++ > 200000) {
      throw StateError('o relógio não chegou a $targetMs ms');
    }
  }
}
