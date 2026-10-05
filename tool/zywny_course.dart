// Validador de curso do zywny.
//
//   dart run tool/zywny_course.dart validate <pasta>
//
// Imprime `arquivo:linha: erro|aviso: mensagem`, um por linha, e sai com
// código 1 se houver erro. Não usa Flutter: roda com `dart run`.
import 'dart:io';

import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/format/directory_course_files.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 || args.first != 'validate') {
    stderr.writeln('Uso: dart run tool/zywny_course.dart validate <pasta>');
    exitCode = 64;
    return;
  }
  final directory = Directory(args[1]);
  if (!directory.existsSync()) {
    stderr.writeln('A pasta `${args[1]}` não existe.');
    exitCode = 66;
    return;
  }
  final result = await readCourse(DirectoryCourseFiles(directory));
  for (final issue in result.issues) {
    stdout.writeln(issue);
  }
  if (result.hasErrors) exitCode = 1;
}
