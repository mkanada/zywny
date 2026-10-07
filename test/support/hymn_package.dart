import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:zywny_library/library_envelope.dart';
import 'package:zywny_library/library_package.dart';

/// Os hinos de verdade, só para os testes manuais (que dependem do Verovio
/// nativo): lê `dist/hinos.zywny` (`just pacote-hinos`) com a chave de
/// `keys/`. Devolve `null` se um dos dois não existe.
Future<LibraryPackage?> openLocalHymnPackage() async {
  final package = File('dist/hinos.zywny');
  final key = File('keys/biblioteca.public.b64');
  if (!package.existsSync() || !key.existsSync()) return null;
  return openLibraryPackage(
    package.readAsBytesSync(),
    Uint8List.fromList(base64.decode(key.readAsStringSync().trim())),
  );
}
