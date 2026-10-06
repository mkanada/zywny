import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/question_session.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny/practice/hand.dart';

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

/// O aluno simulado das perguntas (I07): responde tudo certo, erra a cada
/// n ([wrongEvery]) ou deixa estourar o `time-limit` ([late]).
///
/// - Botões (`name-note`, `count-beats`, `choice`): a certa de primeira,
///   exceto a cada n-ésima (uma errada antes da certa).
/// - Teclado (`find-key`): a altura esperada (exata, que vale nos dois
///   `octave`), exceto a cada n-ésima (um semitom acima antes da certa).
/// - [late]: em cada pergunta, avança o relógio simulado além do
///   `time-limit` (tempos grandes, sem depender do relógio de parede) e
///   espera o 1,5 s de revelação — conta como erro e avança.
///
/// Devolve o resultado da sessão (para o `PassCheck`).
Future<RoundResult> answerQuestions(
  QuestionSession session, {
  int? wrongEvery,
  bool late = false,
}) async {
  // Tempos grandes (bem além do relógio de parede) para o `late` não
  // depender do `now` da sessão.
  var t = 1e12;
  var n = 0;
  var guard = 0;
  while (!session.done) {
    if (guard++ > 5000) {
      throw StateError('o aluno simulado não terminou as perguntas');
    }
    final question = session.current!;
    n++;
    if (late) {
      final limit = session.timeLimit ?? 5;
      t += limit + 0.1;
      expect(session.tick(t), isTrue, reason: 'o estouro não revelou');
      expect(session.revealing, isTrue);
      // Resposta no pisca é ignorada.
      if (question.correct != null) {
        expect(session.answerChoice(question.correct!), isNull);
      } else if (question.expectedPitch != null) {
        expect(session.answerPitch(question.expectedPitch!), isNull);
      }
      t += kAnswerRevealSeconds + 0.1;
      expect(session.tick(t), isTrue, reason: 'a revelação não avançou');
      continue;
    }
    final isWrongTurn = wrongEvery != null && n % wrongEvery == 0;
    if (question.expectedPitch != null) {
      if (isWrongTurn) {
        // Um semitom acima (outra classe, então erra no `any` também —
        // exceto B→C, que muda de classe do mesmo jeito).
        final wrong = question.expectedPitch! + 1;
        expect(session.answerPitch(wrong), isFalse);
      }
      expect(
        session.answerPitch(question.expectedPitch!),
        isTrue,
        reason: 'a certa não avançou (pergunta $n)',
      );
    } else {
      final correct = question.correct!;
      if (isWrongTurn) {
        final wrong = (correct + 1) % question.answers.length;
        expect(session.answerChoice(wrong), isFalse);
      }
      expect(
        session.answerChoice(correct),
        isTrue,
        reason: 'a certa não avançou (pergunta $n)',
      );
    }
    await pumpEventQueue();
  }
  return session.result();
}

/// O aluno simulado do tempo real (I08): toca cada evento da pauta do aluno
/// no instante certo do relógio falso (latência 0), com desvio opcional.
///
/// [wrongEvery] = n: a cada n-ésimo evento, atrasa [lateMs] (fora da janela,
/// vira `missed` + `wrong`) em vez de tocar no tempo. Sem ele, tudo no tempo.
///
/// [runner] com `autoTick: false`; [load] e [start] por conta do chamador.
Future<RoundResult?> playTimedRound(
  ScoreRoundRunner runner,
  FakeMidiInput midi,
  FakeSoundEngine engine,
  Future<RoundResult?> result, {
  int? wrongEvery,
  double lateMs = 300,
}) async {
  var done = false;
  unawaited(result.whenComplete(() => done = true));
  final practice = runner.practice;
  final range = practice.range;
  final jumps = practice.rangeJumps;
  bool inGap(double ms) {
    for (final gap in jumps) {
      if (ms >= gap.startMs && ms < gap.endMs) return true;
    }
    return false;
  }

  final staves = practice.hand.studentStaves;
  final events = [
    for (final e in runner.track.events)
      if (staves.contains(e.staff) &&
          !e.ornament &&
          (range == null ||
              (e.onMs >= range.startMs - 1 &&
                  e.onMs < range.endMs - 1 &&
                  !inGap(e.onMs))))
        e,
  ];
  var guard = 0;
  var index = 0;
  for (final event in events) {
    if (done) break;
    if (guard++ > 10000) {
      throw StateError('o aluno simulado não terminou a rodada com tempo');
    }
    index++;
    final late = wrongEvery != null && index % wrongEvery == 0;
    _advanceTo(engine, runner, event.onMs);
    // O carimbo MIDI é o relógio do dispositivo (`engine.now`): o avanço
    // acima já o pôs no instante do evento; o atraso soma o desvio em ms
    // musicais (a velocidade está no `scheduler.speed`).
    final speed = runner.scheduler.speed;
    final at = engine.now + (late ? lateMs / 1000 / speed : 0);
    midi.press(event.pitch, atSeconds: at);
    await pumpEventQueue();
    midi.release(event.pitch, atSeconds: at);
    await pumpEventQueue();
  }
  // O que faltou vira `missed` quando a posição passa do fim + folga: anda
  // até lá (o `onRangeDone` do tempo real chega pelo `Timer` de 30 ms).
  if (range != null) {
    _advanceTo(engine, runner, range.endMs + 500);
  } else {
    _advanceTo(engine, runner, runner.track.durationMs + 500);
  }
  return result;
}
