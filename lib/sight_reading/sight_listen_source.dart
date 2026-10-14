// E08 — o treino "só ouvido": perguntas "Onde mudou?" sobre partituras do
// treino de leitura, sem teclado, com progresso próprio.
// E10 — do nível 7, a resposta é a nota tocada na partitura, não o compasso.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/course_model.dart';

import '../course/exercise/exercise_round.dart';
import '../course/exercise/pass_check.dart';
import '../course/ui/course_flow.dart';
import '../course/ui/exercise_screen.dart';
import '../course/ui/exercise_source.dart';
import 'sight_listen.dart';
import 'sight_progress.dart';

/// Perguntas por rodada do "só ouvido".
const kSightListenCount = 5;

/// Acertos de primeira para a rodada contar como limpa (D-LEI-SOOUVIDO).
const kSightListenClean = 4;

/// Do nível 7 em diante, a resposta é a nota tocada na partitura, e não o
/// compasso (E10, D-LEI-NOTA).
const kSightListenNoteLevel = 7;

/// O treino "só ouvido": rodadas de [kSightListenCount] perguntas "Onde
/// mudou?", sem teclado, nos 80 passos, com progresso próprio.
class SightListenSource implements ExerciseSource {
  SightListenSource({required this.store, required this.progress});

  final SightReadingStore store;

  /// O progresso até a última rodada gravada.
  SightProgress progress;

  @override
  String get title => 'Ouvido ${progress.step.name}';

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
  bool get needsMidi => false;

  @override
  bool get isQuestion => true;

  @override
  bool get isRealtime => false;

  @override
  bool get alwaysMetronome => false;

  @override
  int? get bestPercent => null;

  @override
  bool get canRepeatRound => false;

  @override
  bool get chainsNextRound => false;

  @override
  String get nextRoundLabel => 'Outra rodada';

  /// Do nível [kSightListenNoteLevel] em diante, a resposta é a nota tocada
  /// (E10); antes, o compasso.
  bool get _byNote => progress.level >= kSightListenNoteLevel;

  /// As perguntas saem do passo de agora: cada rodada é um sorteio novo.
  @override
  Future<ExerciseRound> nextRound(Random rng) async {
    final step = progress.step;
    final answer = _byNote ? SightAnswer.note : SightAnswer.measure;
    return QuestionRound([
      for (var i = 0; i < kSightListenCount; i++)
        sightListenQuestion(step, rng.nextInt(1 << 31), answer: answer),
    ]);
  }

  @override
  Future<ExerciseRound> repeatRound() =>
      throw UnsupportedError('O só ouvido não repete rodadas.');

  @override
  ExerciseSpec? get questionSpec => ListenScoreSpec(
    id: 'leitura-ouvido',
    title: 'Onde mudou?',
    pass: const PassCriteria(accuracy: 80),
    line: 0,
    step: progress.step.name,
    change: ScoreChange.pitch,
    answer: _byNote ? ScoreAnswer.note : ScoreAnswer.measure,
    count: kSightListenCount,
    bpm: null,
  );

  @override
  CourseFiles get questionFiles => MemoryCourseFiles(const {});

  /// Limpa com [kSightListenClean] acertos de primeira ou mais.
  @override
  PassVerdict verdict(List<RoundResult> history) {
    final last = history.last;
    final clean = last.hits >= kSightListenClean;
    final next = progress.afterRound(wasClean: clean);
    final String reason;
    if (!clean) {
      reason =
          'menos de $kSightListenClean de primeira: a rodada não conta para subir';
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
    progress = progress.afterRound(wasClean: result.hits >= kSightListenClean);
    await store.saveListen(progress);
  }
}

/// Abre o "só ouvido" no passo em que o aluno parou.
Future<void> openSightListening(
  BuildContext context,
  CourseScreenDeps deps, {
  SightReadingStore? store,
}) async {
  final reading = store ?? SightReadingStore();
  final progress = await reading.loadListen();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExerciseScreen.source(
        source: SightListenSource(store: reading, progress: progress),
        deps: deps,
      ),
    ),
  );
}
