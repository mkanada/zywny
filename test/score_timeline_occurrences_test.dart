// `ScoreTimeline` por ocorrência de compasso (E02b).
//
// Usa dois `.vsb` com `measureOn` (E01b), gerados com `--xml-id-seed 42`
// para os ids ficarem estáveis entre gerações: `erik-satie.vsb` (já
// existia, de R01/S08, regenerado em E01b) e `maple-leaf-rag.vsb` (novo
// nesta versão), ambos em `test/fixtures/`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';

VsbDocument _fixture(String name) =>
    VsbDocument.fromBytes(File('test/fixtures/$name').readAsBytesSync());

/// O mesmo documento sem `measureOn`, para exercitar o caminho de fallback
/// (pelas notas) com exatamente os mesmos ids/notas do caminho com
/// `measureOn`.
VsbDocument _stripMeasureOn(VsbDocument doc) => VsbDocument(
  manifest: doc.manifest,
  glyphs: doc.glyphs,
  pages: doc.pages,
  timemap: [
    for (final e in doc.timemap!)
      TimemapEntry(
        qstamp: e.qstamp,
        qfrac: e.qfrac,
        tstamp: e.tstamp,
        on: e.on,
        off: e.off,
        restsOn: e.restsOn,
        restsOff: e.restsOff,
        tempo: e.tempo,
      ),
  ],
  meta: doc.meta,
);

void main() {
  late VsbDocument gymnopedie;
  late VsbDocument mapleLeafRag;

  setUpAll(() {
    gymnopedie = _fixture('erik-satie.vsb');
    mapleLeafRag = _fixture('maple-leaf-rag.vsb');
  });

  group('ocorrências (critério 1)', () {
    test('Gymnopédie: 78 ocorrências, 31 na passagem 2', () {
      final tl = ScoreTimeline(gymnopedie);
      expect(tl.measures, hasLength(78));
      expect(tl.measures.where((m) => m.pass == 2), hasLength(31));
      expect(tl.measures.where((m) => m.pass == 1), hasLength(47));
    });

    test('Maple Leaf Rag: 130 ocorrências, 45 na passagem 2', () {
      final tl = ScoreTimeline(mapleLeafRag);
      expect(tl.measures, hasLength(130));
      expect(tl.measures.where((m) => m.pass == 2), hasLength(45));
      expect(tl.measures.where((m) => m.pass == 1), hasLength(85));
    });

    test('caminho measureOn == caminho pelas notas (mesmo documento, com/sem measureOn)', () {
      for (final doc in [gymnopedie, mapleLeafRag]) {
        final withMeasureOn = ScoreTimeline(doc).measures;
        final withoutMeasureOn = ScoreTimeline(_stripMeasureOn(doc)).measures;
        expect(withoutMeasureOn, hasLength(withMeasureOn.length));
        for (var i = 0; i < withMeasureOn.length; i++) {
          expect(withoutMeasureOn[i].id, withMeasureOn[i].id, reason: 'i=$i');
          expect(
            withoutMeasureOn[i].pass,
            withMeasureOn[i].pass,
            reason: 'i=$i',
          );
          expect(
            withoutMeasureOn[i].page,
            withMeasureOn[i].page,
            reason: 'i=$i',
          );
        }
      }
    });
  });

  group('startMs/endMs e página (critério 2)', () {
    test('startMs estritamente crescente; endMs encadeia; página do compasso na cena', () {
      for (final doc in [gymnopedie, mapleLeafRag]) {
        final tl = ScoreTimeline(doc);
        final ms = tl.measures;
        for (var i = 0; i < ms.length; i++) {
          expect(
            doc.pages[ms[i].page].byId.containsKey(ms[i].id),
            isTrue,
            reason: '${ms[i]}',
          );
          if (i + 1 < ms.length) {
            expect(ms[i + 1].startMs, greaterThan(ms[i].startMs));
            expect(ms[i].endMs, ms[i + 1].startMs);
          } else {
            expect(ms[i].endMs, tl.durationMs.round());
          }
        }
      }
    });
  });

  group('página em repouso durante a Maple Leaf Rag (critério 3)', () {
    test('45000ms -> página 0; 58000ms -> página 1; 97500ms -> página 1', () {
      final tl = ScoreTimeline(mapleLeafRag);
      expect(tl.restPageAt(45000), 0);
      expect(tl.restPageAt(58000), 1);
      expect(tl.restPageAt(97500), 1);
    });
  });

  group('salto leva ao compasso de destino certo (critério 4)', () {
    test('39900ms: o compasso 19 (2ª passagem) começa a tocar', () {
      final tl = ScoreTimeline(mapleLeafRag);
      // Medido com o mesmo --xml-id-seed 42 (docs/plano/E02b, notas de
      // execução): o compasso de ordem de documento 19 é 'qqplm6a'.
      const compasso19 = 'qqplm6a';
      final atJump = tl.measureIndexAt(39901);
      final destination = tl.measures[atJump];
      expect(destination.id, compasso19);
      expect(destination.pass, 2);
      expect(destination.startMs, 39900);
      // É de fato um salto: a ocorrência anterior (compasso 34, fim da 1ª
      // passagem do 2º ritornelo) não é a de doc-order anterior a 19.
      final before = tl.measures[atJump - 1];
      expect(before.id, isNot(compasso19));
      expect(before.pass, 1);
    });
  });

  group('occurrencesOf (critério 6)', () {
    test(
      'compasso 19 (2 ocorrências) e compasso 34, casa 1 (1 ocorrência)',
      () {
        final tl = ScoreTimeline(mapleLeafRag);
        const compasso19 = 'qqplm6a';
        final occ19 = tl.occurrencesOf(compasso19);
        expect(occ19, hasLength(2));
        expect(tl.measures[occ19[0]].pass, 1);
        expect(tl.measures[occ19[1]].pass, 2);

        // Uma nota do compasso 19: as mesmas 2 ocorrências.
        final noteIn19 = tl.measures[occ19.first].noteIds.first;
        expect(tl.occurrencesOf(noteIn19), occ19);

        // O id expandido dessa nota (2ª passagem): só a ocorrência da 2ª.
        expect(tl.occurrencesOf('$noteIn19-rend2'), [occ19[1]]);

        // Um compasso de ocorrência única (casa 1, ex.: compasso 34): 1 só.
        final counts = <String, List<int>>{};
        for (var i = 0; i < tl.measures.length; i++) {
          counts.putIfAbsent(tl.measures[i].id, () => []).add(i);
        }
        final onceEntry = counts.entries.firstWhere((e) => e.value.length == 1);
        expect(tl.occurrencesOf(onceEntry.key), onceEntry.value);
        final noteOnce = tl.measures[onceEntry.value.single].noteIds.first;
        expect(tl.occurrencesOf(noteOnce), onceEntry.value);
      },
    );
  });
}
