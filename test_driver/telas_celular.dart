// Lado do computador de `integration_test/telas_celular_test.dart`: recebe
// as telas fotografadas no aparelho e grava um PNG por tela em
// `docs/telas/celular/` (ou em `TELAS_DIR`). Rode com `just telas`.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  // Um roteiro que para no meio ainda entrega o que já fotografou.
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final shots = (data?['telas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dir = Directory(
      Platform.environment['TELAS_DIR'] ?? 'docs/telas/celular',
    );
    dir.createSync(recursive: true);
    for (final entry in shots.entries) {
      File('${dir.path}/${entry.key}.png')
          .writeAsBytesSync(base64Decode(entry.value as String));
    }
    stdout.writeln('${shots.length} telas em ${dir.path}');
  },
);
