import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/course/format/course_model.dart';
import 'package:zywny/course/score/abc_source.dart';

import 'support/render_helper.dart';

void main() {
  group('abcSource: cabeçalho montado', () {
    test('clave de sol, sem tom nem compasso', () {
      expect(
        abcSource('C D E F|'),
        'X:1\nT:lesson\nL:1/4\nK:C clef=treble\nC D E F|\n',
      );
    });

    test('sem `time` não há linha M: (M:none desenha um "0")', () {
      expect(abcSource('C', time: null), isNot(contains('M:')));
    });

    test('cada clave e cada tom', () {
      for (final clef in [Clef.treble, Clef.bass]) {
        for (final key in ['C', 'G', 'F#', 'Bb', 'Am', 'F#m', 'Bbm']) {
          final abc = abcSource('C D', clef: clef, key: key, time: '3/4');
          expect(
            abc,
            'X:1\nT:lesson\nL:1/4\nM:3/4\nK:$key clef=${clef.wire}\nC D\n',
          );
        }
      }
    });

    test('todas as fórmulas de compasso e a unidade', () {
      for (final time in ['4/4', '3/4', '2/4', '6/8', 'C']) {
        expect(abcSource('C', time: time), contains('\nM:$time\n'));
      }
      expect(abcSource('C', unit: '1/8'), contains('\nL:1/8\n'));
    });

    test('o corpo é aparado e termina em quebra de linha', () {
      expect(abcSource('\n  C D E  \n\n'), endsWith('clef=treble\nC D E\n'));
    });

    test('ABC com X: passa intacto, mesmo com clef/key/time', () {
      const full = 'X:7\nT:meu\nM:6/8\nK:D\nD E F|\n';
      expect(
        abcSource(full, clef: Clef.bass, key: 'G', time: '2/4'),
        same(full),
      );
      expect(abcSource('  \nX:1\nK:C\nC'), startsWith('  \nX:1'));
    });

    test('clef grand não existe no ABC (uma pauta só)', () {
      expect(() => abcSource('C', clef: Clef.grand), throwsArgumentError);
    });
  });

  // O que o leitor de ABC do fork desenha e toca, medido pelo mesmo caminho
  // do app nativo (arquivo `.abc` → libverovio → `.vsb` → `midi.json`).
  group('alcance do ABC (libverovio)', () {
    final dir = Directory('test/fixtures/abc');

    Future<List<({int pitch, int staff, double on, double off})>> render(
      String name,
    ) async {
      final bytes = File('${dir.path}/$name.abc').readAsBytesSync();
      final doc = await renderBytes(bytes, '$name.abc');
      expect(doc.pages, isNotEmpty, reason: name);
      expect(doc.timemap, isNotEmpty, reason: '$name: sem timemap');
      return [
        for (final n in doc.midi!.notes)
          (pitch: n.pitch, staff: n.staff, on: n.onMs, off: n.offMs),
      ];
    }

    const pitches = <String, List<int>>{
      'oitavas': [
        48,
        50,
        52,
        53,
        60,
        62,
        64,
        65,
        72,
        74,
        76,
        77,
        84,
        86,
        88,
        89,
      ],
      'acidentes': [60, 61, 62, 63, 64, 66, 67, 70, 70, 69, 71, 72],
      'armadura-g': [67, 69, 71, 72, 74, 76, 78, 79],
      'armadura-bb': [70, 72, 74, 75, 77, 79, 81, 82],
      'armadura-am': [69, 71, 72, 74, 76, 77, 79, 81],
      'clave-fa': [48, 50, 52, 53, 55, 57, 59, 60],
      'clave-fa-tom': [53, 55, 57, 58, 60, 62, 64, 65],
      'compasso-2-4': [60, 62, 64, 65, 67, 69],
      'compasso-3-4': [60, 62, 64, 65, 67, 69],
      'compasso-c': [60, 62, 64, 65, 67, 69, 71, 72],
      'compasso-6-8': [60, 62, 64, 65, 67, 69, 71, 72, 71, 69, 67, 65],
      'anacruse': [67, 72, 74, 76, 77, 79, 81, 83, 84],
      'acorde': [60, 64, 67, 62, 65, 69, 64, 67, 71, 65, 72, 77],
      'pausas': [60, 62, 64, 65],
      'ponto': [60, 62, 64, 65, 67, 69, 71],
      'ligadura': [60, 62, 62],
      'letra': [60, 62, 64, 65],
      'sem-titulo': [60, 62, 64, 65],
      'tempo': [60, 62, 64, 65],
    };

    for (final entry in pitches.entries) {
      test('${entry.key}: alturas do midi.json', () async {
        final notes = await render(entry.key);
        expect([for (final n in notes) n.pitch], entry.value);
        expect({for (final n in notes) n.staff}, {1});
      }, skip: verovioAvailable ? false : 'libverovio.so ausente');
    }

    test(
      'REGRESSÃO: ABC em Dó maior depois de um com bemóis não herda os bemóis',
      () async {
        // O leitor de ABC guardava a armadura em variáveis globais e só as
        // atualizava com `K:` que tem acidentes: `K:C` herdava os bemóis do
        // ABC anterior (Si♭, Mi♭), no mesmo processo. Corrigido no fork
        // (ioabc.cpp); a libverovio, o wasm e o .so do Android precisam
        // ter sido refeitos depois disso.
        await render('armadura-bb');
        final notes = await render('armadura-am');
        expect(
          [for (final n in notes) n.pitch],
          [69, 71, 72, 74, 76, 77, 79, 81],
        );
        await render('armadura-g');
        final c = await render('compasso-c');
        expect(c[6].pitch, 71); // o Si de Dó maior, não 70
      },
      skip: verovioAvailable ? false : 'libverovio.so ausente',
    );

    test('repetição |: :| toca o trecho duas vezes', () async {
      final notes = await render('repeticao');
      expect(notes, hasLength(16));
      expect(
        [for (final n in notes.take(8)) n.pitch],
        [for (final n in notes.skip(8)) n.pitch],
      );
    }, skip: verovioAvailable ? false : 'libverovio.so ausente');

    test('figuras, ponto, pausa, ligadura e andamento: durações', () async {
      List<double> offs(
        List<({int pitch, int staff, double on, double off})> l,
      ) => [for (final n in l) n.off - n.on];
      expect(offs(await render('figuras')).take(5), [
        500,
        1000,
        500,
        2000,
        250,
      ]);
      expect(offs(await render('ponto')).take(3), [750, 250, 500]);
      expect(offs(await render('ligadura')), [2000, 500, 1500]);
      // pausa: a segunda nota começa depois de uma semínima de silêncio.
      expect((await render('pausas'))[1].on, 1000);
      // Q:1/4=60 dobra a duração de 120 bpm.
      expect(offs(await render('tempo')).first, 1000);
      // 6/8 com L:1/8: colcheia = metade da semínima.
      expect(offs(await render('compasso-6-8')).first, 250);
    }, skip: verovioAvailable ? false : 'libverovio.so ausente');

    test('quiáltera de colcheias soa em tempo de quiáltera', () async {
      final notes = await render('quialtera');
      expect(notes[0].off - notes[0].on, closeTo(500 / 3, 0.5));
      expect(notes[3].on, closeTo(500, 0.5));
    }, skip: verovioAvailable ? false : 'libverovio.so ausente');

    // ---- Limites. Se o fork passar a fazer isto, estes testes falham e a
    // especificação (`formato-v1.md`, "Partituras") precisa ser atualizada.
    test('LIMITE: corpo sem cabeçalho não carrega', () async {
      final bytes = File('${dir.path}/corpo-puro.abc').readAsBytesSync();
      await expectLater(
        renderBytes(bytes, 'corpo-puro.abc'),
        throwsA(anything),
      );
    }, skip: verovioAvailable ? false : 'libverovio.so ausente');

    test(
      'LIMITE: duas vozes saem uma depois da outra, na mesma pauta',
      () async {
        final notes = await render('duas-pautas');
        expect({for (final n in notes) n.staff}, {1});
        // As oito graves só começam depois das oito agudas terminarem.
        expect(notes[8].on, greaterThanOrEqualTo(notes[7].off));
      },
      skip: verovioAvailable ? false : 'libverovio.so ausente',
    );

    test('LIMITE: quiáltera de semínimas perde a quiáltera', () async {
      final notes = await render('quialtera-seminima');
      expect(notes, hasLength(10));
      expect(notes.first.off - notes.first.on, 500); // devia ser 333
    }, skip: verovioAvailable ? false : 'libverovio.so ausente');

    test('LIMITE: [K:bass] no meio da linha vira o tom Si', () async {
      final notes = await render('clave-fa-inline');
      expect(notes.first.pitch, 47); // B2, não C3 (48)
    }, skip: verovioAvailable ? false : 'libverovio.so ausente');
  });
}
