import 'package:zywny/course/format/course_files.dart';
import 'package:zywny/course/format/course_model.dart';
import 'package:zywny/course/format/course_reader.dart';

/// Um curso de uma lição só, com o [body] (markdown com marcas) dentro.
MemoryCourseFiles oneLessonCourse(
  String body, {
  Map<String, Object> extra = const {},
}) => MemoryCourseFiles({
  'course.md':
      '---\nformat: 1\nid: t\ntitle: T\nauthor: a\nversion: "1"\n'
      'lessons: [um]\n---\n\nOi.\n',
  'lessons/01-um.md': '---\nid: um\ntitle: Um\n---\n\n$body',
  ...extra,
});

/// O [ExerciseSpec] lido de um bloco `zywny-exercise` (só o conteúdo, sem as
/// cercas). Falha o teste se o curso não valida.
Future<ExerciseSpec> specFrom(String exerciseBody) async {
  final result = await readCourse(
    oneLessonCourse('```zywny-exercise\n$exerciseBody\n```\n'),
  );
  if (result.course == null) {
    throw StateError(
      'curso inválido:\n${result.issues.map((i) => '$i').join('\n')}',
    );
  }
  return result.course!.lessons.single.exercises.single;
}
