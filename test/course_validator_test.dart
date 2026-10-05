import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/format/directory_course_files.dart';

/// Cada pasta de `test/fixtures/cursos/` tem um `esperado.txt` com a saída
/// exata do validador (o que o professor vai ver).
void main() {
  final root = Directory('test/fixtures/cursos');
  final courses = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('há cursos de teste', () {
    expect(courses.length, greaterThan(10));
  });

  for (final course in courses) {
    final name = course.path.split('/').last;
    test('$name: a saída do validador é a esperada', () async {
      final expected = File('${course.path}/esperado.txt').readAsStringSync();
      final result = await readCourse(DirectoryCourseFiles(course));
      final actual = [for (final issue in result.issues) '$issue\n'].join();
      expect(actual, expected);
      expect(result.course == null, result.hasErrors);
      if (name.startsWith('erro-') && !name.contains('lista')) {
        expect(result.hasErrors, isTrue);
      }
    });
  }

  test('lib/course/format não importa Flutter', () {
    final dir = Directory('lib/course/format');
    final files = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    );
    expect(files, isNotEmpty);
    for (final file in files) {
      final imports = file
          .readAsLinesSync()
          .where((l) => l.startsWith('import '))
          .join('\n');
      expect(imports, isNot(contains('package:flutter')), reason: file.path);
      expect(imports, isNot(contains('dart:ui')), reason: file.path);
    }
  });
}
