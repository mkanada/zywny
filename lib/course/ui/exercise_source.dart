import 'dart:math';

import 'package:zywny_course_format/course_model.dart';

import '../course_progress.dart';
import '../exercise/exercise_kind.dart';
import '../exercise/exercise_round.dart';
import '../exercise/pass_check.dart';
import '../loaded_course.dart';
import 'exercise_card.dart';

/// De onde a tela de exercício tira as rodadas e o que conta como passagem.
/// Hoje são duas: a lição do curso ([CourseExerciseSource]) e o treino de
/// leitura à primeira vista (`SightReadingSource`).
abstract class ExerciseSource {
  /// O título da barra da tela.
  String get title;

  /// Identifica o exercício (a tela usa para guardar o que já mostrou).
  String get id;

  /// A meta do exercício, em uma linha.
  String get goal;

  /// Andamento inicial (1,0 é o escrito).
  double get startSpeed;

  /// Precisa de teclado MIDI (o aviso de conexão depende disso).
  bool get needsMidi;

  /// Perguntas (`find-key`, `name-note`…) em vez de partitura.
  bool get isQuestion;

  /// A rodada de partitura é em tempo real: o andamento e o metrônomo valem.
  bool get isRealtime;

  /// O metrônomo toca mesmo sem ser tempo real (exercício de ritmo).
  bool get alwaysMetronome;

  /// Sorteia ou monta a próxima rodada.
  Future<ExerciseRound> nextRound(Random rng);

  /// Se [repeatRound] refaz a última rodada igual: a tela então oferece
  /// "Tocar de novo" no resultado.
  bool get canRepeatRound;

  /// Refaz a última rodada, com o mesmo conteúdo. Só com [canRepeatRound].
  Future<ExerciseRound> repeatRound();

  /// O veredito depois da última rodada de [history].
  PassVerdict verdict(List<RoundResult> history);

  /// Melhor % guardado antes da rodada atual, para o painel comparar.
  int? get bestPercent;

  /// Guarda o resultado da rodada.
  Future<void> recordRound(RoundResult result);
}

/// A lição do curso: a rodada vem do tipo do exercício, o `pass` do autor
/// decide a passagem e o progresso vai para o curso.
class CourseExerciseSource implements ExerciseSource {
  CourseExerciseSource({
    required this.loaded,
    required this.spec,
    required this.progress,
  });

  final LoadedCourse loaded;
  final ExerciseSpec spec;
  final CourseProgressStore progress;

  @override
  String get title => spec.title;

  @override
  String get id => spec.id;

  @override
  String get goal => exerciseGoal(spec);

  @override
  double get startSpeed => spec.pass.speed / 100.0;

  @override
  bool get needsMidi => exerciseNeedsMidi(spec);

  @override
  bool get isQuestion =>
      spec.type == ExerciseType.findKey ||
      spec.type == ExerciseType.nameNote ||
      spec.type == ExerciseType.countBeats ||
      spec.type == ExerciseType.choice;

  @override
  bool get isRealtime {
    final s = spec;
    return s is RhythmSpec ||
        (s is PlayScoreSpec && s.mode == PlayMode.realtime);
  }

  @override
  bool get alwaysMetronome => spec is RhythmSpec;

  @override
  Future<ExerciseRound> nextRound(Random rng) =>
      generateRound(spec, loaded.files, rng);

  @override
  bool get canRepeatRound => false;

  @override
  Future<ExerciseRound> repeatRound() =>
      throw UnsupportedError('A lição não repete rodadas.');

  @override
  PassVerdict verdict(List<RoundResult> history) =>
      PassCheck.evaluate(spec, history);

  @override
  int? get bestPercent => progress[loaded.id].records[spec.id]?.bestPercent;

  @override
  Future<void> recordRound(RoundResult result) =>
      progress.recordAttempt(loaded.id, spec, result);
}
