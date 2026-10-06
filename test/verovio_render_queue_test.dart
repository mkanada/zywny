// Várias partituras ABC pedidas ao mesmo tempo (uma lição com duas pautas
// abre as duas juntas). O leitor de ABC do Verovio guarda estado em globais;
// sem a fila do `renderScoreToVsb`, dois isolates lendo ABC juntos
// derrubavam o app (`std::out_of_range`, visto no celular na lição 2).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/score/abc_source.dart';

import 'support/render_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders ABC simultâneos não se atropelam', () async {
    final sources = [
      abcSource('C D E F G'),
      abcSource('G A B c', key: 'G', time: '4/4'),
    ];
    String fingerprint(dynamic doc) =>
        '${doc.timemap?.length}|${(doc.glyphs.keys.toList()..sort()).join(',')}';
    Uint8List bytes(String abc) => Uint8List.fromList(utf8.encode(abc));
    // Cada uma sozinha, em sequência: a referência.
    final alone = [
      for (final s in sources)
        fingerprint(await renderBytes(bytes(s), 'lesson.abc')),
    ];
    expect(alone[0], isNot(alone[1]));
    final jobs = [
      for (var i = 0; i < 12; i++)
        renderBytes(bytes(sources[i % 2]), 'lesson.abc'),
    ];
    final docs = await Future.wait(jobs);
    for (var i = 0; i < docs.length; i++) {
      expect(fingerprint(docs[i]), alone[i % 2], reason: 'render $i');
    }
  }, skip: verovioAvailable ? false : 'libverovio.so do bridge ausente');
}
