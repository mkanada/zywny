import 'package:meta/meta.dart';

import '../format/course_model.dart';
import 'exercise_round.dart';

/// O veredito do histórico de rodadas de um exercício.
@immutable
class PassVerdict {
  const PassVerdict({
    required this.roundPassed,
    required this.streak,
    required this.exercisePassed,
    required this.reason,
  });

  /// A última rodada passou nos critérios (precisão e, onde vale, andamento).
  final bool roundPassed;

  /// Rodadas aprovadas **seguidas** no fim do histórico.
  final int streak;

  /// `streak >= pass.rounds`.
  final bool exercisePassed;

  /// Em português, pronta para a tela: "82% de 90%", "faltou andamento: 50%
  /// de 100%", "2 de 3 rodadas seguidas".
  final String reason;
}

/// Aplica o `pass` do autor ao histórico de rodadas. O limiar é o do autor
/// (`accuracy`), **não** o `kTrailPassAccuracy` da trilha.
class PassCheck {
  const PassCheck._();

  /// O `speed` do `pass` só vale em tempo real: `rhythm` e `play-score` com
  /// `mode: realtime`.
  static bool speedApplies(ExerciseSpec spec) =>
      spec is RhythmSpec ||
      (spec is PlayScoreSpec && spec.mode == PlayMode.realtime);

  /// Passou? Precisão ≥ `accuracy` e, onde o andamento vale, andamento ≥
  /// `speed`.
  static bool roundPasses(ExerciseSpec spec, RoundResult round) =>
      round.percent >= spec.pass.accuracy &&
      (!speedApplies(spec) || round.speedPercent >= spec.pass.speed);

  static PassVerdict evaluate(ExerciseSpec spec, List<RoundResult> history) {
    final pass = spec.pass;
    if (history.isEmpty) {
      return PassVerdict(
        roundPassed: false,
        streak: 0,
        exercisePassed: false,
        reason: pass.rounds > 1
            ? '0 de ${pass.rounds} rodadas seguidas'
            : 'nenhuma rodada ainda',
      );
    }
    var streak = 0;
    for (final round in history.reversed) {
      if (!roundPasses(spec, round)) break;
      streak++;
    }
    final last = history.last;
    final roundPassed = roundPasses(spec, last);
    final exercisePassed = streak >= pass.rounds;

    final String reason;
    if (!roundPassed) {
      final parts = <String>[];
      if (last.percent < pass.accuracy) {
        parts.add('${last.percent}% de ${pass.accuracy}%');
      }
      if (speedApplies(spec) && last.speedPercent < pass.speed) {
        parts.add('faltou andamento: ${last.speedPercent}% de ${pass.speed}%');
      }
      reason = parts.join('; ');
    } else if (!exercisePassed) {
      reason = '$streak de ${pass.rounds} rodadas seguidas';
    } else {
      reason = pass.rounds > 1
          ? '${pass.rounds} rodadas seguidas'
          : '${last.percent}% (mínimo ${pass.accuracy}%)';
    }
    return PassVerdict(
      roundPassed: roundPassed,
      streak: streak,
      exercisePassed: exercisePassed,
      reason: reason,
    );
  }
}
