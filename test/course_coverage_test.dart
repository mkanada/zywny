// I11 — cobertura do formato pelo curso inicial (regra 2 do I00).
//
// Lê `assets/cursos/iniciacao/` pela pasta (o mesmo conteúdo do asset, via
// `DirectoryCourseFiles`) e confere, a partir das tabelas de
// `lib/course/format/vocabulary.dart` (fonte única — nada de cópia), que
// toda marca, todo tipo e toda chave aparecem ao menos uma vez, e que os
// valores enumerados que mudam comportamento também aparecem.
//
// Se um valor não tiver lugar didático no curso, a exceção é explícita aqui,
// com o motivo num comentário.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/format/directory_course_files.dart';
import 'package:zywny/course/format/lesson_scanner.dart';
import 'package:zywny/course/format/vocabulary.dart';
import 'package:zywny/course/format/course_model.dart';

/// Chaves e valores vistos nos YAMLs escritos à mão (não nos padrões do
/// modelo: o que conta é o autor ter escrito a chave).
class _Seen {
  final marks = <String>{};
  final markKeys = <String, Set<String>>{};
  final types = <String>{};
  final typeKeys = <String, Set<String>>{};
  final passKeys = <String>{};
  final randomKeys = <String>{};
  final clefs = <String>{};
  final modes = <String>{};
  final octaves = <String>{};
  final hands = <String>{};
  final accidentals = <String>{};
  final onlys = <String>{};
  final figures = <String>{};
  final times = <String>{};
  final keys = <String>{};
  final courseKeys = <String>{};
  final lessonKeys = <String>{};
  var markdownImage = false;
  var markdownLink = false;

  void markKey(String mark, String key) {
    marks.add(mark);
    markKeys.putIfAbsent(mark, () => <String>{}).add(key);
  }

  void typeKey(String type, String key) {
    types.add(type);
    typeKeys.putIfAbsent(type, () => <String>{}).add(key);
  }
}

String _textOf(Object? value) => '$value';

void _collectYamlMap(YamlMap map, _Seen seen, String mark, String? type) {
  for (final entry in map.nodes.entries) {
    final keyNode = entry.key as YamlNode;
    final key = keyNode.value;
    if (key is! String) continue;
    final valueNode = entry.value;
    final value = valueNode.value;
    if (mark == kExerciseMark && type == null) {
      // Corpo de exercício ainda sem tipo: só `type` interessa aqui;
      // o resto é coletado depois que o tipo é conhecido.
      continue;
    }
    if (mark == kExerciseMark) {
      seen.typeKey(type!, key);
      if (key == 'pass' && valueNode is YamlMap) {
        for (final passEntry in valueNode.nodes.entries) {
          final passKey = (passEntry.key as YamlNode).value;
          if (passKey is String) seen.passKeys.add(passKey);
        }
      }
      if (key == 'notes' && valueNode is YamlMap) {
        for (final notesEntry in valueNode.nodes.entries) {
          final notesKey = (notesEntry.key as YamlNode).value;
          if (notesKey is String) {
            seen.randomKeys.add(notesKey);
            if (notesKey == 'only') {
              final onlyValue = notesEntry.value.value;
              if (onlyValue is String) seen.onlys.add(onlyValue);
            }
          }
        }
      }
      if (key == 'notes' && valueNode is YamlList) {
        // Lista fixa: cobre `notes`, sem sub-chaves.
      }
      if (key == 'clef' && value is String) seen.clefs.add(value);
      if (key == 'mode' && value is String) seen.modes.add(value);
      if (key == 'octave' && value is String) seen.octaves.add(value);
      if (key == 'hand' && value is String) seen.hands.add(value);
      if (key == 'accidentals' && value is String) {
        seen.accidentals.add(value);
      }
      if (key == 'figures' && valueNode is YamlList) {
        for (final item in valueNode.nodes) {
          final figure = item.value;
          if (figure is String) seen.figures.add(figure);
        }
      }
      if (key == 'time' && value is String) seen.times.add(value);
      if (key == 'key' && value is String) seen.keys.add(value);
    } else {
      seen.markKey(mark, key);
      if (key == 'clef' && value is String) seen.clefs.add(value);
      if (key == 'key' && value is String) seen.keys.add(value);
      if (key == 'time' && value is String) seen.times.add(value);
    }
  }
}

Future<_Seen> _collectSeen(DirectoryCourseFiles files) async {
  final seen = _Seen();
  final paths = await files.list();
  for (final path in paths) {
    if (path != 'course.md' && !path.startsWith('lessons/')) continue;
    // Só markdown: a mídia (.png, .ogg, .musicxml) não é texto.
    if (!path.endsWith('.md')) continue;
    final text = utf8.decode(await files.read(path));
    if (path == 'course.md' || path.startsWith('lessons/')) {
      final scanned = scanLessonFile(
        text,
        onError: (line, message) => fail('$path:$line $message'),
      );
      if (path == 'course.md') {
        final front = scanned.front;
        expect(front, isNotNull, reason: 'course.md sem front matter');
        final map = loadYamlNode(front!.yaml);
        if (map is YamlMap) {
          for (final entry in map.nodes.entries) {
            final key = (entry.key as YamlNode).value;
            if (key is String) seen.courseKeys.add(key);
          }
        }
        // O corpo do course.md é só apresentação: procure imagem/link aqui
        // também (hoje não tem, mas o mecanismo é o mesmo das lições).
        for (final segment in scanned.segments) {
          if (segment is TextSegment) {
            if (segment.text.contains(RegExp(r'!\[.*?\]\(.*?\)'))) {
              seen.markdownImage = true;
            }
            if (segment.text.contains('https://')) seen.markdownLink = true;
          }
        }
        continue;
      }
      // Lição: front matter + marcas.
      final front = scanned.front;
      expect(front, isNotNull, reason: '$path sem front matter');
      final frontMap = loadYamlNode(front!.yaml);
      if (frontMap is YamlMap) {
        for (final entry in frontMap.nodes.entries) {
          final key = (entry.key as YamlNode).value;
          if (key is String) seen.lessonKeys.add(key);
        }
      }
      for (final segment in scanned.segments) {
        if (segment is TextSegment) {
          if (segment.text.contains(RegExp(r'!\[.*?\]\(.*?\)'))) {
            seen.markdownImage = true;
          }
          if (segment.text.contains('https://')) seen.markdownLink = true;
          continue;
        }
        if (segment is! MarkSegment) continue;
        final name = segment.name;
        final body = segment.body.trim();
        YamlNode node;
        try {
          node = loadYamlNode(body.isEmpty ? '{}' : body);
        } on YamlException catch (e) {
          fail('YAML inválido em $path:${segment.bodyLine}: ${e.message}');
        }
        if (node is! YamlMap) fail('corpo não é mapa em $path:${segment.line}');
        final map = node;
        if (name == kExerciseMark) {
          final typeNode = map.nodes.entries
              .where((e) => (e.key as YamlNode).value == 'type')
              .map((e) => e.value)
              .firstOrNull;
          final type = typeNode?.value;
          if (type is! String)
            fail('exercício sem type em $path:${segment.line}');
          seen.marks.add(kExerciseMark);
          seen.types.add(_textOf(type));
          _collectYamlMap(map, seen, name, _textOf(type));
        } else {
          _collectYamlMap(map, seen, name, null);
        }
      }
    }
  }
  return seen;
}

void main() {
  test('o curso inicial cobre todo o vocabulário do formato', () async {
    final files = DirectoryCourseFiles(Directory('assets/cursos/iniciacao'));
    final read = await readCourse(files);
    expect(
      read.issues,
      isEmpty,
      reason: read.issues.map((i) => '$i').join('\n'),
    );
    expect(read.course, isNotNull);
    final seen = await _collectSeen(files);
    final missing = <String>[];

    // 1. Marcas e tipos.
    for (final mark in kMarkNames) {
      if (!seen.marks.contains(mark)) {
        missing.add('marca `zywny-$mark` não aparece no curso inicial');
      }
    }
    for (final type in ExerciseType.values) {
      if (!seen.types.contains(type.wire)) {
        missing.add('tipo `${type.wire}` não aparece no curso inicial');
      }
    }

    // 2. (marca, chave): cada chave de cada marca de conteúdo.
    for (final entry in kContentMarkKeys.entries) {
      final mark = entry.key;
      for (final key in entry.value.keys) {
        if (!(seen.markKeys[mark]?.contains(key) ?? false)) {
          missing.add('`$key` da marca `zywny-$mark` não aparece no curso');
        }
      }
    }

    // 3. (tipo, chave): cada chave aceita em cada tipo de exercício.
    for (final type in ExerciseType.values) {
      final expected = exerciseKeys(type).keys;
      final got = seen.typeKeys[type.wire] ?? const <String>{};
      for (final key in expected) {
        if (!got.contains(key)) {
          missing.add('`$key` do tipo `${type.wire}` não aparece no curso');
        }
      }
    }

    // 4. Chaves de `pass` e do sorteio `notes: {random, count, only}`.
    for (final key in kPassKeys.keys) {
      if (!seen.passKeys.contains(key)) {
        missing.add('`$key` do `pass` não aparece no curso inicial');
      }
    }
    for (final key in kRandomNotesKeys.keys) {
      if (!seen.randomKeys.contains(key)) {
        missing.add('`$key` do sorteio `notes` não aparece no curso');
      }
    }

    // 5. Valores enumerados que mudam comportamento.
    void checkValues(String what, Set<String> got, List<String> want) {
      for (final value in want) {
        if (!got.contains(value)) {
          missing.add('`$what: $value` não aparece no curso inicial');
        }
      }
    }

    checkValues('clef', seen.clefs, ['treble', 'bass', 'grand']);
    checkValues('mode', seen.modes, ['wait', 'realtime']);
    checkValues('octave', seen.octaves, ['any', 'exact']);
    checkValues('hand', seen.hands, ['right', 'left', 'both']);
    checkValues('accidentals', seen.accidentals, [
      'none',
      'sharps',
      'flats',
      'mixed',
    ]);
    checkValues('only', seen.onlys, ['lines', 'spaces']);
    checkValues('figures', seen.figures, [
      for (final figure in Figure.values) figure.wire,
    ]);
    checkValues('time', seen.times, kTimeSignatures);
    // Tons: o curso inicial usa G, F, D e Bb, um de cada família didática
    // (um sustenido, um bemol, dois sustenidos, dois bemóis). Os outros 24
    // tons do formato (Cb, G#m, …) não têm lugar didático num curso para
    // quem nunca leu partitura — exceção explícita, com motivo.
    checkValues('key', seen.keys, ['G', 'F', 'D', 'Bb']);

    // 6. Curso, lição, imagem e link markdown (I10: "imagem e link markdown").
    for (final key in kCourseKeys.keys) {
      if (!seen.courseKeys.contains(key)) {
        missing.add('`$key` do `course.md` não aparece no curso inicial');
      }
    }
    for (final key in kLessonKeys.keys) {
      // `requires` aparece em quase todas, mas confira como as outras.
      if (!seen.lessonKeys.contains(key)) {
        missing.add('`$key` do front matter da lição não aparece no curso');
      }
    }
    if (!seen.markdownImage) {
      missing.add('imagem markdown `![legenda](media/x.png)` não aparece');
    }
    if (!seen.markdownLink) {
      missing.add('link `https://…` no texto não aparece no curso inicial');
    }

    expect(missing, isEmpty, reason: 'cobertura:\n- ${missing.join('\n- ')}');
  });
}
