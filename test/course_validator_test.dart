import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/format/directory_course_files.dart';

import 'support/render_helper.dart' show verovioAvailable;

/// Cada pasta de `test/fixtures/cursos/` tem um `esperado.txt` com a saída
/// exata do validador (o que o professor vai ver).
///
/// I11: a lista cobre, no mínimo, marca desconhecida (com sugestão), chave
/// desconhecida (com sugestão), YAML inválido, front matter sem `---`,
/// `format: 2`, arquivo de mídia ausente, imagem remota, `link` `http://`,
/// `requires` circular, `requires` de lição posterior, id repetido (lição e
/// exercício), lição listada sem arquivo, `abc` e `file` juntos, `speed` em
/// modo espera, nota inválida (`H4`), faixa invertida, `answer` fora das
/// `options` e ABC que não renderiza (este depende do `--render` do I12 e da
/// `libverovio.so`; pulado aqui).
void main() {
  final root = Directory('test/fixtures/cursos');
  final courses = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('há cursos de teste', () {
    expect(courses.length, greaterThan(10));
  });

  for (final course in courses) {
    final name = course.path.split('/').last;
    if (name == 'erro-render') {
      // I12: só vale com o `--render` (Verovio): o `readCourse` puro não dá
      // erro aqui (ABC sem notas passa no validador). Testa a linha de
      // comando de verdade, que usa o Verovio por FFI.
      test('$name: o --render dá a mensagem esperada', () async {
        final expected = File('${course.path}/esperado.txt').readAsStringSync();
        final run = await Process.run('dart', [
          'run',
          'tool/zywny_course.dart',
          'validate',
          course.path,
          '--render',
        ]);
        expect(run.stdout, expected);
        expect(run.exitCode, 1);
      }, skip: verovioAvailable ? false : 'libverovio.so ausente');
      test('$name: sem --render não há erro (só o formato)', () async {
        final result = await readCourse(DirectoryCourseFiles(course));
        expect(result.issues, isEmpty);
        expect(result.course, isNotNull);
      });
      continue;
    }
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

  test('toda mensagem de "Erros comuns" existe nas fixtures', () {
    // A especificação não promete mensagem que o validador não dá (I11.4).
    final spec = File('docs/licoes/formato-v1.md').readAsStringSync();
    final section = spec.split('## 11. Erros comuns').last.split('\n## ').first;
    final bullets = [
      for (final line in section.split('\n'))
        if (line.startsWith('- ')) line,
    ];
    // Um trecho distintivo por mensagem, na ordem da especificação.
    const distinctive = [
      'chave desconhecida',
      'marca desconhecida',
      'não foi fechada',
      'YAML inválido',
      'falta a chave obrigatória',
      'id de exercício repetido',
      'forma um ciclo',
      'vem depois',
      'não existe na pasta do curso',
      'não vale',
      'não tem andamento',
      'precisa ser igual a uma das',
      'já traz o cabeçalho',
      'não é uma nota',
      'aparece como texto',
    ];
    expect(
      bullets,
      hasLength(distinctive.length),
      reason:
          'a seção "Erros comuns" mudou: atualize `distinctive` e as fixtures',
    );
    for (var i = 0; i < distinctive.length; i++) {
      expect(
        bullets[i],
        contains(distinctive[i]),
        reason: 'mensagem ${i + 1} da especificação mudou?',
      );
    }
    final combined = [
      for (final course in courses)
        if (course.path.split('/').last != 'erro-render')
          File('${course.path}/esperado.txt').readAsStringSync(),
    ].join('\n');
    for (final phrase in distinctive) {
      expect(
        combined,
        contains(phrase),
        reason:
            'a especificação promete "$phrase", mas nenhuma fixture o mostra',
      );
    }
  });
}
