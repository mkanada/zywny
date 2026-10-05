import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:zywny/library/library_envelope.dart';

import 'library_fixtures.dart' show TestKeys;

/// Um curso mínimo válido em memória (`id` parametrizável).
Map<String, String> minimalCourse({
  String id = 'curso-teste',
  String version = '1',
}) => {
  'course.md':
      '---\nformat: 1\nid: $id\ntitle: Curso Teste\nauthor: zywny\n'
      'version: "$version"\nlessons: [a]\n---\n\nApresentação.\n',
  'lessons/01-a.md':
      '---\nid: a\ntitle: Primeira\n---\n\nLeia isto.\n\n'
      '```zywny-exercise\nid: ex-a\ntype: choice\ntitle: Escolha\n'
      'question: Quanto é 1+1?\noptions: [1, 2]\nanswer: 1\n'
      'pass: {accuracy: 90}\n```\n',
};

/// O mesmo, com outra versão (para o teste de substituir).
Map<String, String> minimalCourseV2() => minimalCourse(version: '2');

/// Zipa [files] (como o `tool/build_course.py`) e sela com [keys]:
/// um `.zywny` de curso válido para os testes (nunca as chaves de `keys/`).
Future<Uint8List> sealCourse(Map<String, String> files, TestKeys keys) {
  final archive = Archive();
  final names = files.keys.toList()..sort();
  for (final name in names) {
    archive.add(ArchiveFile.bytes(name, utf8.encode(files[name]!)));
  }
  final zip = Uint8List.fromList(ZipEncoder().encode(archive));
  return LibraryEnvelope.seal(zip, privateSeed: keys.seed, publicKey: keys.pub);
}

/// O zip sem selar (para o teste "sem envelope").
Uint8List plainCourseZip(Map<String, String> files) {
  final archive = Archive();
  final names = files.keys.toList()..sort();
  for (final name in names) {
    archive.add(ArchiveFile.bytes(name, utf8.encode(files[name]!)));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
