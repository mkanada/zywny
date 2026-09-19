// Testes de R02b — percurso, ajuste de página e cor herdada (§3/§5.1/§6).
//
// Cobre os critérios de aceite 2-7 do passo, usando o `RecordingCanvas`
// de `support/recording_canvas.dart`.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';

import 'support/recording_canvas.dart';

SceneNode _node({
  String? id,
  String? color,
  bool hidden = false,
  SceneRotate? rotate,
  List<SceneChild> children = const [],
}) {
  return SceneNode(
    id: id,
    className: 'g',
    color: color,
    hidden: hidden,
    rotate: rotate,
    children: children,
  );
}

SceneRect _fillRect(double x, {ScenePaint fill = ScenePaint.inherit}) {
  return SceneRect(
    x: x,
    y: 0,
    w: 10,
    h: 10,
    rx: 0,
    fill: fill,
    fillOpacity: 1.0,
    stroke: ScenePaint.inherit,
    strokeWidth: null,
    strokeOpacity: 1.0,
    lineCap: SceneLineCap.defaultCap,
    lineJoin: SceneLineJoin.defaultJoin,
    dash: null,
  );
}

ScenePage _page(SceneNode root) {
  return ScenePage(
    index: 0,
    width: 1000,
    height: 1000,
    contentHeight: 1000,
    viewBoxFactor: 10.0,
    viewBox: const Rect.fromLTRB(0, 0, 1000, 1000),
    baseWidth: 1000,
    baseHeight: 1000,
    userScaleX: 1.0,
    userScaleY: 1.0,
    widthPx: 1000,
    heightPx: 1000,
    fit: const PageFit(scale: 1.0, tx: 0.0, ty: 0.0),
    origin: Offset.zero,
    root: root,
    elements: const [],
    byId: const {},
  );
}

void main() {
  test('ajuste de página: (0,0) e canto do viewBox (valores à mão)', () {
    final bytes = File('test/fixtures/erik-satie.vsb').readAsBytesSync();
    final doc = VsbDocument.fromBytes(bytes);
    final page = doc.pages.first;

    // Valores lidos do fixture (página 1, índice 0).
    expect(page.fit.scale, 0.1);
    expect(page.fit.tx, 0.0);
    expect(page.fit.ty, 0.0);
    expect(page.origin, const Offset(500, 500));
    expect(page.viewBox, const Rect.fromLTRB(0, 0, 21000, 29700));

    final canvas = RecordingCanvas();
    ScenePainter(page, doc.glyphs).paint(canvas);

    // A transformação é translate(tx,ty) -> scale(s) -> translate(origin):
    // (x, y) -> (tx + (x + ox) * s, ty + (y + oy) * s), calculada aqui com
    // literais, não com a fórmula do código.
    final origin = canvas.transformPoint(0, 0);
    expect(origin.dx, closeTo(0 + (0 + 500) * 0.1, 1e-9)); // 50
    expect(origin.dy, closeTo(0 + (0 + 500) * 0.1, 1e-9)); // 50
    expect(canvas.ops.take(3), ['translate', 'scale', 'translate']);

    // Canto do viewBox: (0 + (21000 + 500) * 0.1, 0 + (29700 + 500) * 0.1).
    // NOTA: dá (2150, 3020), ou seja, 50px além de widthPx × heightPx
    // (2100 × 2970) — a margem `origin` é somada depois da escala (§3), de
    // modo que o canto do viewBox não é visível. O critério do passo previa
    // "dentro de widthPx × heightPx"; o número medido corrige o critério
    // (ver Notas de execução). O conteúdo real fica dentro: a bbox mais à
    // direita do corpus termina em 20008.5 -> 2050.85px.
    final corner = canvas.transformPoint(21000, 29700);
    expect(corner.dx, closeTo(2150.0, 1e-9));
    expect(corner.dy, closeTo(3020.0, 1e-9));
    expect(corner.dx, greaterThan(page.widthPx));
  });

  test('herança de cor: 3 níveis, raiz preta, meio/folha vermelhas', () {
    final root = _node(
      children: [
        _fillRect(10),
        _node(
          color: '#ff0000',
          children: [
            _fillRect(20),
            _node(
              children: [
                _fillRect(30),
                _fillRect(40, fill: const ColorPaint('#00ff00')),
              ],
            ),
          ],
        ),
      ],
    );
    final canvas = RecordingCanvas();
    ScenePainter(_page(root), const {}).paint(canvas);

    expect(canvas.drawPaths, hasLength(4));
    expect(canvas.drawPaths[0].paint.color, const Color(0xFF000000));
    expect(canvas.drawPaths[1].paint.color, const Color(0xFFFF0000));
    expect(canvas.drawPaths[2].paint.color, const Color(0xFFFF0000));
    // `fill` explícito ignora a herança.
    expect(canvas.drawPaths[3].paint.color, const Color(0xFF00FF00));
  });

  test('colorOverrides substitui a cor do nó e da subárvore', () {
    final root = _node(
      children: [
        _node(id: 'n1', color: '#ff0000', children: [_fillRect(10)]),
        _node(color: '#ff0000', children: [_fillRect(20)]),
      ],
    );
    final canvas = RecordingCanvas();
    ScenePainter(
      _page(root),
      const {},
      colorOverrides: const {'n1': Color(0xFF0000FF)},
    ).paint(canvas);

    expect(canvas.drawPaths, hasLength(2));
    expect(canvas.drawPaths[0].paint.color, const Color(0xFF0000FF));
    expect(canvas.drawPaths[1].paint.color, const Color(0xFFFF0000));
  });

  test('hidden: nó invisível não desenha nada, nem os filhos', () {
    final root = _node(
      children: [
        _fillRect(10),
        _node(
          hidden: true,
          children: [_fillRect(20), _fillRect(30), _fillRect(40)],
        ),
        _fillRect(50),
      ],
    );
    final canvas = RecordingCanvas();
    ScenePainter(_page(root), const {}).paint(canvas);

    expect(canvas.drawPaths, hasLength(2));
    expect(canvas.drawPaths[0].path.getBounds().left, 10);
    expect(canvas.drawPaths[1].path.getBounds().left, 50);
  });

  test('rotação: -90° em (100,200) leva (110,200) a (100,190)', () {
    final root = _node(
      children: [
        _node(
          rotate: SceneRotate(angle: -90, origin: const Offset(100, 200)),
          children: [_fillRect(100)],
        ),
      ],
    );
    final canvas = RecordingCanvas();
    ScenePainter(_page(root), const {}).paint(canvas);

    expect(canvas.drawPaths, hasLength(1));
    final call = canvas.drawPaths.single;
    final pivot = call.map(100, 200);
    expect(pivot.dx, closeTo(100.0, 1e-9));
    expect(pivot.dy, closeTo(200.0, 1e-9));
    final turned = call.map(110, 200);
    expect(turned.dx, closeTo(100.0, 1e-9));
    expect(turned.dy, closeTo(190.0, 1e-9));
    // save/restore balanceados.
    expect(canvas.getSaveCount(), 1);
  });

  test('ordem: 5 formas saem na ordem de children', () {
    final root = _node(
      children: [
        _fillRect(10),
        _fillRect(20),
        _fillRect(30),
        _fillRect(40),
        _fillRect(50),
      ],
    );
    final canvas = RecordingCanvas();
    ScenePainter(_page(root), const {}).paint(canvas);

    expect(canvas.drawPaths, hasLength(5));
    for (var k = 0; k < 5; k++) {
      expect(canvas.drawPaths[k].path.getBounds().left, 10.0 * (k + 1));
    }
  });

  test(
    'página real: drawPath == formas com fill != none (percurso próprio)',
    () {
      final bytes = File('test/fixtures/erik-satie.vsb').readAsBytesSync();
      final doc = VsbDocument.fromBytes(bytes);
      final page = doc.pages.first;

      final canvas = RecordingCanvas();
      ScenePainter(page, doc.glyphs).paint(canvas);

      expect(canvas.drawPaths.length, _countFills(page.root));
      expect(canvas.drawPaths, isNotEmpty);
    },
  );
}

/// Conta `p`/`r`/`e` com `fill != none`, pulando subárvores `hidden` —
/// percurso independente do pintor (glifos e texto não contam: R02b os
/// ignora).
int _countFills(SceneNode node) {
  if (node.hidden) {
    return 0;
  }
  var count = 0;
  for (final child in node.children) {
    if (child is SceneNode) {
      count += _countFills(child);
    } else if (child is ScenePath ||
        child is SceneRect ||
        child is SceneEllipse) {
      final fill = (child as SceneShape).fill;
      if (!identical(fill, ScenePaint.none)) {
        count += 1;
      }
    }
    // SceneGlyphUse e SceneText: o pintor os ignora neste passo (R03/R04).
  }
  return count;
}
