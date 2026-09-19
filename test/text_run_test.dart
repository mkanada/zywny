// Testes de R04b — run de texto: linha de base, tamanho e cor (§5.4).
//
// Cobre os critérios de aceite 2-5 do passo. O `drawParagraph` é observado
// via `RecordingCanvas` (deslocamento) e via rasterização real (cor).
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';

import 'support/recording_canvas.dart';
import 'support/ttf_metrics.dart';

SceneText _run({
  String text = 'Lent',
  double x = 200,
  double y = 1000,
  double size = 405,
  SceneTextAlign align = SceneTextAlign.left,
  String? color,
}) {
  return SceneText(
    text: text,
    x: x,
    y: y,
    size: size,
    align: align,
    letterSpacing: 0.0,
    bold: false,
    italic: false,
    family: 'Times',
    color: color,
  );
}

ScenePage _textPage(SceneChild child, {double fitScale = 1.0}) {
  return ScenePage(
    index: 0,
    width: 1000,
    height: 1000,
    contentHeight: 1000,
    viewBoxFactor: 10.0,
    viewBox: const ui.Rect.fromLTRB(0, 0, 1000, 1000),
    baseWidth: 1000,
    baseHeight: 1000,
    userScaleX: 1.0,
    userScaleY: 1.0,
    widthPx: 1000,
    heightPx: 1000,
    fit: PageFit(scale: fitScale, tx: 0.0, ty: 0.0),
    origin: ui.Offset.zero,
    root: SceneNode(className: 'g', hidden: false, children: [child]),
    elements: const [],
    byId: const {},
  );
}

SceneNode _node({String? color, List<SceneChild> children = const []}) {
  return SceneNode(
    className: 'g',
    color: color,
    hidden: false,
    children: children,
  );
}

/// Cor média dos pixels "tintados" (dominância de um canal sobre os outros
/// dois em pelo menos 30/255): ignora o branco e o cinza antialiased.
({int count, double r, double g, double b}) _inkStats(ByteData pixels) {
  var count = 0;
  var r = 0;
  var g = 0;
  var b = 0;
  for (var k = 0; k < pixels.lengthInBytes; k += 4) {
    final pr = pixels.getUint8(k);
    final pg = pixels.getUint8(k + 1);
    final pb = pixels.getUint8(k + 2);
    final dominant =
        (pr > pg + 30 && pr > pb + 30) ||
        (pg > pr + 30 && pg > pb + 30) ||
        (pb > pr + 30 && pb > pg + 30);
    if (dominant) {
      count += 1;
      r += pr;
      g += pg;
      b += pb;
    }
  }
  if (count == 0) {
    return (count: 0, r: 0, g: 0, b: 0);
  }
  return (count: count, r: r / count, g: g / count, b: b / count);
}

Future<({int count, double r, double g, double b})> _paintInk(
  SceneChild child,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 100, 100),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  ScenePainter(_textPage(child, fitScale: 0.1), const {}).paint(canvas);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(100, 100);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return _inkStats(bytes!);
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadScoreFonts();
  });

  test('linha de base: topo em y-ascent da TTF (tol 0,5 viewBox)', () async {
    final bytes = await rootBundle.load(kScoreFontAssets[0]);
    final ttf = TtfAdvances.parse(
      bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final painter = painterForRun(_run(), const Color(0xFF000000));
    final dy = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    // O topo da caixa pintada é `y - dy`: tem que bater com o ascendente
    // derivado do `hhea` da TTF carregada.
    expect(1000 - dy, closeTo(1000 - ttf.ascentOf(405), 0.5));
  });

  test('fiação: drawParagraph recebe (x, y-dy)', () {
    final run = _run();
    final dy = painterForRun(
      run,
      const Color(0xFF000000),
    ).computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final canvas = RecordingCanvas();
    ScenePainter(_textPage(run), const {}).paint(canvas);
    expect(canvas.drawParagraphs, hasLength(1));
    final call = canvas.drawParagraphs.single;
    expect(call.offset.dx, closeTo(200, 1e-9));
    expect(call.offset.dy, closeTo(1000 - dy, 1e-9));
  });

  test('escala: dobrar size dobra a largura (tol 1%)', () {
    const color = Color(0xFF000000);
    final w405 = painterForRun(_run(size: 405), color).width;
    final w810 = painterForRun(_run(size: 810), color).width;
    expect(w810 / w405, closeTo(2.0, 0.01));
  });

  test('noScaling: imune ao scaler do ambiente', () {
    const color = Color(0xFF000000);
    final ours = painterForRun(_run(), color);
    final manual = TextPainter(
      text: const TextSpan(
        text: 'Lent',
        style: TextStyle(
          fontFamily: kScoreTextFamily,
          fontSize: 405,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    expect(ours.width, manual.width);
    // Sanidade: um pintor que respeita scaler dobra com linear(2.0) — ou
    // seja, a igualdade acima é significativa, não vacuous.
    final scaled = TextPainter(
      text: const TextSpan(
        text: 'Lent',
        style: TextStyle(
          fontFamily: kScoreTextFamily,
          fontSize: 405,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(2.0),
    )..layout();
    expect(scaled.width, closeTo(manual.width * 2, 1e-6));
  });

  test('cor: herda do nó; explícita sobrepõe', () async {
    final red = await _paintInk(_node(color: '#ff0000', children: [_run()]));
    expect(red.count, greaterThan(0));
    expect(red.r, greaterThan(red.g + 30));
    expect(red.r, greaterThan(red.b + 30));

    final green = await _paintInk(
      _node(
        color: '#ff0000',
        children: [_run(color: '#00ff00')],
      ),
    );
    expect(green.count, greaterThan(0));
    expect(green.g, greaterThan(green.r + 30));
    expect(green.g, greaterThan(green.b + 30));
  });
}
