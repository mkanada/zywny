// I10 — o curso inicial embutido no app.
//
// Regra 1 do I00: nenhum `if` pelo id `iniciacao` no código. O embutido
// difere de um instalado só na origem (`CourseOrigin.builtIn`, em
// `LoadedCourse`) e em não poder ser removido. O leitor é o mesmo de uma
// pasta de terceiros.

import 'asset_course_files.dart';
import 'format/course_files.dart';
import 'format/course_reader.dart';
import 'loaded_course.dart';

/// Carrega o curso inicial embutido (`assets/cursos/iniciacao/`).
///
/// Devolve `[]` quando o asset falta ou o curso não lê: a biblioteca
/// esconde a entrada de cursos, como antes do I10. [files] só existe para
/// testes (no app, os assets via `rootBundle`).
Future<List<LoadedCourse>> loadBuiltInCourses({CourseFiles? files}) async {
  try {
    final courseFiles = files ?? AssetCourseFiles(kBuiltInCoursePrefix);
    final result = await readCourse(courseFiles);
    final course = result.course;
    if (course == null) return const [];
    return [
      LoadedCourse(
        course: course,
        files: courseFiles,
        origin: CourseOrigin.builtIn,
      ),
    ];
  } on Object {
    return const [];
  }
}
