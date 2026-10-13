import 'dart:math';

import 'package:flutter/material.dart';
import 'package:zywny_course_format/course_model.dart';

import '../course/exercise/exercise_round.dart';
import '../course/exercise/pass_check.dart';
import '../course/score/abc_source.dart' show utf8Bytes;
import '../course/ui/course_flow.dart';
import '../course/ui/exercise_screen.dart';
import '../course/ui/exercise_source.dart';
import '../practice/hand.dart';
import 'sight_generator.dart';
import 'sight_progress.dart';
import 'sight_score.dart';
import 'sight_steps.dart';

/// O treino de leitura à primeira vista como fonte da tela de exercício. Cada
/// rodada é uma partitura nova do passo atual, tocada em tempo real no
/// andamento do passo.
class SightReadingSource implements ExerciseSource {
  SightReadingSource({required this.store, required this.progress});

  final SightReadingStore store;

  /// O progresso até a última rodada gravada.
  SightProgress progress;

  @override
  String get title => 'Leitura ${progress.step.name}';

  @override
  String get id => progress.step.name;

  /// Quantas rodadas limpas faltam para o próximo subnível.
  @override
  String get goal {
    final left = progress.remaining;
    return '$left ${left == 1 ? 'limpa' : 'limpas'} para subir';
  }

  @override
  double get startSpeed => 1.0;

  @override
  bool get needsMidi => true;

  @override
  bool get isQuestion => false;

  @override
  bool get isRealtime => true;

  @override
  bool get alwaysMetronome => false;

  /// Não há melhor % guardado: o progresso é por passo, não por rodada.
  @override
  int? get bestPercent => null;

  /// O passo e a semente da última rodada sorteada: [repeatRound] refaz a
  /// mesma partitura a partir deles, mesmo que o progresso já tenha andado.
  SightStep? _lastStep;
  int? _lastSeed;

  @override
  Future<ExerciseRound> nextRound(Random rng) async {
    _lastStep = progress.step;
    _lastSeed = rng.nextInt(1 << 31);
    return _round(_lastStep!, _lastSeed!);
  }

  @override
  bool get canRepeatRound => _lastSeed != null;

  @override
  Future<ExerciseRound> repeatRound() => _round(_lastStep!, _lastSeed!);

  Future<ExerciseRound> _round(SightStep step, int seed) async {
    final xml = sightScoreXml(generateSight(step, Random(seed)));
    return ScoreRound(
      bytes: utf8Bytes(xml),
      fileName: 'leitura-${step.name}.musicxml',
      mode: PlayMode.realtime,
      hand: _handOf(step.hands),
    );
  }

  /// A rodada conta se saiu sem erro. O veredito descreve o que a rodada
  /// faz pelo progresso, antes de gravar.
  @override
  PassVerdict verdict(List<RoundResult> history) {
    final last = history.last;
    final clean = last.hits >= last.total;
    final next = progress.afterRound(wasClean: clean);
    final String reason;
    if (!clean) {
      reason = 'com erro: a rodada não conta para subir';
    } else if (next.clean == 0) {
      reason = 'passo ${progress.step.name} concluído';
    } else {
      reason = '${next.clean} de $sightCleanToAdvance rodadas limpas';
    }
    return PassVerdict(
      roundPassed: clean,
      streak: next.clean,
      exercisePassed: false,
      reason: reason,
    );
  }

  @override
  Future<void> recordRound(RoundResult result) async {
    progress = progress.afterRound(wasClean: result.hits >= result.total);
    await store.save(progress);
  }
}

Hand _handOf(SightHands hands) => switch (hands) {
  SightHands.right => Hand.direita,
  SightHands.left => Hand.esquerda,
  SightHands.both => Hand.ambas,
};

/// Abre o treino de leitura à primeira vista no passo em que o aluno parou.
Future<void> openSightReading(
  BuildContext context,
  CourseScreenDeps deps, {
  SightReadingStore? store,
}) async {
  final reading = store ?? SightReadingStore();
  final progress = await reading.load();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExerciseScreen.source(
        source: SightReadingSource(store: reading, progress: progress),
        deps: deps,
      ),
    ),
  );
}
