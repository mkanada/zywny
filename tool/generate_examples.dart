// Gera as evidências visuais de A05b em `docs/exemplos/` (frames PNG).
//
//   cd score_bridge && flutter test tool/generate_examples.dart
//
// Determinístico: o relógio é o do Flutter Tester (`pump` com durações) e o
// player usa `seek` para cair em cada instante. O roteiro exato (instantes)
// vai impresso e gravado em `docs/exemplos/*/roteiro.md`.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';

import '../test/support/render_helpers.dart';

const _out = '../docs/exemplos';
const _width = 900.0;

VsbDocument _load(String part) => corpusDoc(part)!;

Future<ByteData> _shot(WidgetTester tester, GlobalKey key, int w, int h) =>
    captureBytes(tester, key, w, h);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadScoreFonts();
  });

  testWidgets('destaque de notas em fases diferentes', (tester) async {
    const piece = 'Gymnopedie';
    final doc = _load(piece);
    final controller = ScoreController(document: doc);
    final page = doc.pages[0];
    final h = (_width * page.heightPx / page.widthPx).round();
    final key = await pumpAtSize(
      tester,
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: _width,
          child: ScorePageView(
            document: doc,
            pageIndex: 0,
            controller: controller,
          ),
        ),
      ),
      _width.round(),
      h,
    );
    final ids = animatableIdsFromTimemap(doc.timemap)
        .where((id) => doc.geometry.elementOf(id)?.className == 'note')
        .where((id) => doc.geometry.elementOf(id)!.page == 0)
        .take(12)
        .toList();
    final dir = '$_out/destaque-notas/$piece';
    // Cinco notas acesas em instantes escalonados, com curvas diferentes.
    controller.highlight(
      ids[0],
      attack: const Duration(milliseconds: 200),
      hold: const Duration(milliseconds: 600),
      release: const Duration(milliseconds: 800),
    );
    await tester.pump();
    final schedule = <(int, void Function())>[
      (
        300,
        () => controller.highlight(ids[3], release: const Duration(seconds: 2)),
      ),
      (
        300,
        () => controller.highlight(
          ids[5],
          color: const ui.Color(0xFF1565C0),
          attack: const Duration(milliseconds: 300),
          hold: const Duration(seconds: 1),
          release: const Duration(milliseconds: 600),
        ),
      ),
      (
        300,
        () => controller.highlight(
          ids[7],
          release: const Duration(milliseconds: 1500),
        ),
      ),
    ];
    final frames = <String>[];
    var t = 0;
    Future<void> snap(String label) async {
      final bytes = await _shot(tester, key, _width.round(), h);
      final crop = _cropAround(doc, ids.take(8).toList(), _width);
      await writePng(
        tester,
        _crop(bytes, _width.round(), crop),
        crop.width.round(),
        crop.height.round(),
        '$dir/frame-$label.png',
      );
      frames.add('$label (t = $t ms)');
    }

    await tester.pump(const Duration(milliseconds: 100));
    t += 100;
    await snap('1-t0100');
    for (final (dt, act) in schedule) {
      act();
      await tester.pump(Duration(milliseconds: dt));
      t += dt;
    }
    await snap('2-t0700');
    await tester.pump(const Duration(milliseconds: 400));
    t += 400;
    await snap('3-t1100');
    await tester.pump(const Duration(milliseconds: 600));
    t += 600;
    await snap('4-t1700');
    await tester.pump(const Duration(milliseconds: 1500));
    t += 1500;
    await snap('5-t3200');
    controller.clearAll();
    File('$dir/roteiro.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('''# Destaque de notas — $piece, página 1

Gerado por `flutter test tool/generate_examples.dart` (em `score_bridge/`).

Notas (ids do timemap na página 1): `${ids.take(8).join(', ')}`.

Roteiro (relógio simulado do Flutter Tester):

- t = 0: `highlight(ids[0], attack: 200 ms, hold: 600 ms, release: 800 ms)`
- t = 100 ms: frame 1
- t = 100 ms: `highlight(ids[3], release: 2 s)`; t = 400 ms:
  `highlight(ids[5], azul, attack: 300 ms, hold: 1 s, release: 600 ms)`;
  t = 700 ms: `highlight(ids[7], release: 1,5 s)`
- ${frames.join('\n- ')}

Cada frame é um recorte da região das notas; nenhuma nota "salta" — cada uma
tem a própria fase (attack, hold, release) ao mesmo tempo.
''');
    controller.dispose();
  });

  testWidgets('virada de página por haste, dirigida pelo player', (
    tester,
  ) async {
    const piece = 'Nocturne';
    final doc = _load(piece);
    final controller = ScoreController(document: doc);
    final vc = ScoreViewController();
    final player = ScorePlayer(
      document: doc,
      controller: controller,
      view: vc,
      release: const Duration(milliseconds: 600),
    );
    final page = doc.pages[0];
    final h = (_width * page.heightPx / page.widthPx).round();
    final key = await pumpAtSize(
      tester,
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: _width,
          height: h.toDouble(),
          child: ScoreView(
            document: doc,
            controller: controller,
            viewController: vc,
            curtain: player.curtain,
          ),
        ),
      ),
      _width.round(),
      h,
    );
    final ms = player.measures;
    final i = ms.indexWhere(
      (m) => m.page == 0 && ms[ms.indexOf(m) + 1].page == 1,
    );
    final m = ms[i];
    final next = ms[i + 1];
    final d = ((m.endMs - m.startMs) / 4).clamp(0, 1000).toDouble();
    final dir = '$_out/virada-pagina/$piece';
    final steps = <(String, double)>[
      ('1-repouso', m.startMs - 800),
      ('2-meio-da-entrada', m.startMs + d / 2),
      ('3-estacionada', (m.startMs + d + next.startMs) / 2),
      ('4-meio-da-conclusao', next.startMs + d / 2),
      ('5-repouso-seguinte', next.startMs + d + 800),
    ];
    final lines = <String>[];
    for (final (label, at) in steps) {
      player.seek(Duration(microseconds: (at * 1000).round()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final bytes = await _shot(tester, key, _width.round(), h);
      await writePng(tester, bytes, _width.round(), h, '$dir/frame-$label.png');
      lines.add(
        '$label: `seek(${at.round()} ms)` — haste '
        '${player.curtain.value == null ? "ausente" : "edgeX = ${player.curtain.value!.edgeX.toStringAsFixed(0)}"}, '
        'página ${vc.currentPage + 1}',
      );
    }
    File('$dir/roteiro.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('''# Virada de página por haste — $piece

Gerado por `flutter test tool/generate_examples.dart` (em `score_bridge/`).

Página 1 → 2; último compasso da página 1: `${m.id}` (${m.startMs}–${m.endMs} ms),
primeiro da página 2 começa em ${next.startMs} ms; `D = min(1 s, duração/4)` =
${d.round()} ms. Player com `release: 600 ms`, `ScoreView` com a haste azul
padrão (`barWidth` = 2 × noteheadBlack, teto 1 s).

Cada frame é `player.seek(t)` seguido de um quadro:

- ${lines.join('\n- ')}

Nos frames 2–4 as notas do compasso tocando estão destacadas em vermelho, à
direita da haste; à esquerda dela aparece a página seguinte.
''');
    controller.clearAll();
    player.dispose();
    controller.dispose();
  });
}

/// Retângulo (px do frame) que cobre as notas [ids], com folga.
Rect _cropAround(VsbDocument doc, List<String> ids, double width) {
  Rect? r;
  for (final id in ids) {
    final rect = doc.geometry.rectForId(id, pageWidth: width)!;
    r = r == null ? rect : r.expandToInclude(rect);
  }
  final pad = 40.0;
  return Rect.fromLTRB(
    (r!.left - pad).clamp(0, width),
    (r.top - pad).clamp(0, double.infinity),
    (r.right + pad).clamp(0, width),
    r.bottom + pad,
  );
}

/// Recorta [bytes] (RGBA de largura [w]) em [crop].
ByteData _crop(ByteData bytes, int w, Rect crop) {
  final cw = crop.width.round();
  final ch = crop.height.round();
  final out = ByteData(cw * ch * 4);
  final x0 = crop.left.round();
  final y0 = crop.top.round();
  final rows = bytes.lengthInBytes ~/ 4 ~/ w;
  for (var y = 0; y < ch; y++) {
    for (var x = 0; x < cw; x++) {
      final sy = y0 + y;
      final sx = x0 + x;
      if (sy >= rows) continue;
      for (var c = 0; c < 4; c++) {
        out.setUint8(
          (y * cw + x) * 4 + c,
          bytes.getUint8((sy * w + sx) * 4 + c),
        );
      }
    }
  }
  return out;
}
