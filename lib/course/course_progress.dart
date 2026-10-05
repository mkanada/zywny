// I09 — progresso por curso: o que o aluno já fez, guardado por curso.
//
// Como o `TrailProgressStore` (J03/J09): um JSON por curso em
// `shared_preferences`, chave `course_progress:<courseId>`. O registro é por
// id de exercício (estável, como o progresso da trilha); lição ou exercício
// que sumiu do curso fica guardado e é ignorado — volta se o id voltar.
//
// Aprovado uma vez, fica aprovado: refazer depois não tira o selo; a melhor
// % sobe, não desce.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercise/exercise_round.dart';
import 'exercise/pass_check.dart';
import 'format/course_model.dart';

/// O que o aluno fez num exercício: melhor % e quantas aprovadas seguidas.
@immutable
class ExerciseRecord {
  const ExerciseRecord({
    required this.passed,
    required this.streak,
    required this.bestPercent,
    required this.lastAt,
  });

  /// Já aprovado ao menos uma vez (o selo nunca sai).
  final bool passed;

  /// Rodadas aprovadas seguidas no fim do histórico (cruza sessões).
  final int streak;

  /// Melhor porcentagem de qualquer tentativa (0–100).
  final int bestPercent;

  /// Última tentativa, ms desde a época.
  final int lastAt;

  Map<String, Object?> toJson() => {
    'p': passed,
    's': streak,
    'b': bestPercent,
    't': lastAt,
  };

  factory ExerciseRecord.fromJson(Map<String, dynamic> json) {
    final best = json['b'];
    final streak = json['s'];
    final lastAt = json['t'];
    return ExerciseRecord(
      passed: json['p'] == true,
      streak: streak is num ? streak.round().clamp(0, 1000) : 0,
      bestPercent: best is num ? best.round().clamp(0, 100) : 0,
      lastAt: lastAt is num ? lastAt.round() : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExerciseRecord &&
      other.passed == passed &&
      other.streak == streak &&
      other.bestPercent == bestPercent &&
      other.lastAt == lastAt;

  @override
  int get hashCode => Object.hash(passed, streak, bestPercent, lastAt);
}

/// O que o aluno fez num curso. Imutável: `recordAttempt`/`markLessonDone`
/// devolvem um novo valor.
@immutable
class CourseProgress {
  const CourseProgress({
    required this.courseId,
    this.records = const {},
    this.doneLessons = const {},
    this.lastLessonId,
  });

  final String courseId;

  /// Por id de exercício. Id que saiu do curso fica aqui guardado e é
  /// ignorado nos derivados — e volta a valer se o id voltar.
  final Map<String, ExerciseRecord> records;

  /// Lições sem exercício concluídas ("Concluir" ou leitura até o fim).
  final Set<String> doneLessons;

  /// Última lição aberta, para o "Continuar".
  final String? lastLessonId;

  static CourseProgress empty(String courseId) =>
      CourseProgress(courseId: courseId);

  /// Registra uma rodada de [spec]: o `streak` conta aprovações seguidas
  /// (inclusive entre sessões); `passed` nunca volta a `false`; `bestPercent`
  /// só sobe.
  CourseProgress recordAttempt(ExerciseSpec spec, RoundResult result) {
    final previous = records[spec.id];
    final passes = PassCheck.roundPasses(spec, result);
    final streak = passes ? (previous?.streak ?? 0) + 1 : 0;
    final best = previous == null || result.percent > previous.bestPercent
        ? result.percent
        : previous.bestPercent;
    return CourseProgress(
      courseId: courseId,
      records: {
        ...records,
        spec.id: ExerciseRecord(
          passed: (previous?.passed ?? false) || streak >= spec.pass.rounds,
          streak: streak,
          bestPercent: best,
          lastAt: DateTime.now().millisecondsSinceEpoch,
        ),
      },
      doneLessons: doneLessons,
      lastLessonId: lastLessonId,
    );
  }

  CourseProgress markLessonDone(String lessonId) => CourseProgress(
    courseId: courseId,
    records: records,
    doneLessons: {...doneLessons, lessonId},
    lastLessonId: lastLessonId,
  );

  CourseProgress touchLesson(String lessonId) => CourseProgress(
    courseId: courseId,
    records: records,
    doneLessons: doneLessons,
    lastLessonId: lessonId,
  );

  /// Lição feita: todos os exercícios aprovados; sem exercício, concluída
  /// ("Concluir" ou leitura até o fim).
  bool lessonDone(Lesson lesson) {
    final specs = lesson.exercises.toList();
    if (specs.isEmpty) return doneLessons.contains(lesson.id);
    return specs.every((spec) => records[spec.id]?.passed ?? false);
  }

  /// Lição aberta: todo `requires` feito (só lições anteriores, como o
  /// validador garante). A trava é de sequência sugerida, não de acesso.
  bool lessonOpen(Lesson lesson, Course course) {
    final byId = {for (final l in course.lessons) l.id: l};
    for (final required in lesson.requires) {
      final dep = byId[required];
      if (dep == null) continue;
      if (!lessonDone(dep)) return false;
    }
    return true;
  }

  /// Títulos que faltam para abrir [lesson], na ordem do curso.
  List<String> missingFor(Lesson lesson, Course course) {
    final byId = {for (final l in course.lessons) l.id: l};
    return [
      for (final required in lesson.requires)
        if (byId[required] case final dep?
            when !lessonDone(dep))
          dep.title,
    ];
  }

  /// (feitas, total) de lições, para a lista.
  ({int done, int total}) lessonCounts(Course course) {
    var done = 0;
    for (final lesson in course.lessons) {
      if (lessonDone(lesson)) done++;
    }
    return (done: done, total: course.lessons.length);
  }

  /// "X de Y exercícios" de uma lição (só com exercícios).
  ({int done, int total})? exerciseCounts(Lesson lesson) {
    final specs = lesson.exercises.toList();
    if (specs.isEmpty) return null;
    var done = 0;
    for (final spec in specs) {
      if (records[spec.id]?.passed ?? false) done++;
    }
    return (done: done, total: specs.length);
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'course': courseId,
    'records': {for (final e in records.entries) e.key: e.value.toJson()},
    'doneLessons': doneLessons.toList()..sort(),
    'lastLessonId': ?lastLessonId,
  };

  factory CourseProgress.fromJson(String courseId, Map<String, dynamic> json) {
    final records = <String, ExerciseRecord>{};
    final stored = json['records'];
    if (stored is Map) {
      stored.forEach((key, value) {
        if (key is String && value is Map) {
          records[key] = ExerciseRecord.fromJson(
            value.cast<String, dynamic>(),
          );
        }
      });
    }
    final doneLessons = <String>{};
    final storedDone = json['doneLessons'];
    if (storedDone is List) {
      for (final id in storedDone) {
        if (id is String) doneLessons.add(id);
      }
    }
    final last = json['lastLessonId'];
    return CourseProgress(
      courseId: courseId,
      records: records,
      doneLessons: doneLessons,
      lastLessonId: last is String && last.isNotEmpty ? last : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CourseProgress &&
      other.courseId == courseId &&
      mapEquals(other.records, records) &&
      setEquals(other.doneLessons, doneLessons) &&
      other.lastLessonId == lastLessonId;

  @override
  int get hashCode =>
      Object.hash(courseId, records, Object.hashAllUnordered(doneLessons));
}

/// Guarda um progresso por curso (`course_progress:<courseId>`, JSON).
/// Avisa quem escuta a cada mudança — a lista refaz a linha do curso ao
/// voltar da lição sem reabrir nada.
class CourseProgressStore extends ChangeNotifier {
  CourseProgressStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  final Map<String, CourseProgress> _byId = {};

  static String keyFor(String courseId) => 'course_progress:$courseId';

  CourseProgress operator [](String courseId) =>
      _byId[courseId] ?? CourseProgress.empty(courseId);

  /// Garante o curso na memória (uma chave só). Avisa quem escuta para a
  /// lista e a tela do curso mostrarem o progresso guardado ao abrir.
  Future<CourseProgress> ensureLoaded(String courseId) async {
    if (_byId.containsKey(courseId)) return this[courseId];
    final stored = await _read(courseId);
    if (stored != null) {
      _byId[courseId] = stored;
      notifyListeners();
    }
    return this[courseId];
  }

  Future<CourseProgress?> _read(String courseId) async {
    try {
      final text = await _prefs.getString(keyFor(courseId));
      if (text == null) return null;
      return CourseProgress.fromJson(
        courseId,
        jsonDecode(text) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _write(CourseProgress progress) {
    _byId[progress.courseId] = progress;
    notifyListeners();
    return _prefs.setString(
      keyFor(progress.courseId),
      jsonEncode(progress.toJson()),
    );
  }

  Future<void> recordAttempt(String courseId, ExerciseSpec spec, RoundResult result) {
    return _write(this[courseId].recordAttempt(spec, result));
  }

  Future<void> markLessonDone(String courseId, String lessonId) {
    return _write(this[courseId].markLessonDone(lessonId));
  }

  Future<void> touchLesson(String courseId, String lessonId) {
    final current = this[courseId];
    if (current.lastLessonId == lessonId) return Future.value();
    return _write(current.touchLesson(lessonId));
  }
}

/// Progresso só em memória: rascunho (I12, que não guarda nada) e testes.
/// Nada chega ao `shared_preferences`.
class MemoryCourseProgressStore extends CourseProgressStore {
  MemoryCourseProgressStore() : super(prefs: _NeverPrefs());

  @override
  Future<CourseProgress?> _read(String courseId) async => null;

  @override
  Future<void> _write(CourseProgress progress) async {
    // ignore: invalid_use_of_visible_for_testing_member — memória de teste.
    _byIdOf(this)[progress.courseId] = progress;
    notifyListeners();
  }

  static Map<String, CourseProgress> _byIdOf(CourseProgressStore store) =>
      store._byId;
}

/// Um `SharedPreferencesAsync` que nunca é usado (o de memória passa por
/// cima da leitura e da escrita).
class _NeverPrefs implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('só memória');
}
