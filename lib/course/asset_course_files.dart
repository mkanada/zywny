// I10 — os arquivos do curso inicial embutido, lidos dos assets do app.
//
// O curso embutido difere de um instalado só na origem (`AssetCourseFiles`)
// e em não poder ser removido (regra 1 do I00): o leitor é o mesmo de uma
// pasta de terceiros. Os assets do Flutter não listam diretórios, então a
// lista vem do `AssetManifest` filtrada pelo prefixo
// `assets/cursos/iniciacao/`.

import 'package:flutter/services.dart';

import 'package:zywny_course_format/course_files.dart';

/// O prefixo do curso inicial nos assets, sem barra no fim.
const kBuiltInCoursePrefix = 'assets/cursos/iniciacao';

/// Os arquivos de um curso embutido nos assets do app.
///
/// [prefix] é o diretório do curso nos assets (`assets/cursos/iniciacao`).
/// [bundle] só existe para testes (`rootBundle` no app).
class AssetCourseFiles implements CourseFiles {
  AssetCourseFiles(this.prefix, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final String prefix;
  final AssetBundle _bundle;

  String get _root => prefix.endsWith('/') ? prefix : '$prefix/';

  @override
  String get label => prefix.split('/').lastWhere((p) => p.isNotEmpty);

  @override
  Future<List<String>> list() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final root = _root;
    final result = <String>[];
    for (final key in manifest.listAssets()) {
      if (!key.startsWith(root)) continue;
      final relative = key.substring(root.length);
      if (relative.isEmpty) continue;
      result.add(relative);
    }
    return result..sort();
  }

  @override
  Future<Uint8List> read(String path) async {
    final data = await _bundle.load('$_root$path');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
