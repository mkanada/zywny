// `ScenePainter`: ajuste de página, percurso da árvore e cor herdada (R02b),
// mais traço, opacidade, pontas/junções e tracejado (R02c).
//
// Desenha formas `p`/`r`/`e` com preenchimento e traço (§5.2/§6). Glifos (R03)
// e texto (R04) ficam para os passos seguintes.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'dash.dart';
import 'geometry.dart';
import 'model.dart';

/// Pinta uma página da cena num [Canvas] (§3/§5.1/§6).
///
/// Aplica a transformação de página uma vez ([PageFit] + `origin` vindos
/// prontos do arquivo), percorre `children` em ordem de documento mantendo
/// a cor corrente por parâmetro, respeita `hidden` e `rotate`.
class ScenePainter {
  ScenePainter(this.page, this.glyphs, {this.colorOverrides = const {}});

  final ScenePage page;
  final Map<String, GlyphDef> glyphs;
  final Map<String, ui.Color> colorOverrides;

  void paint(ui.Canvas canvas) {
    canvas.translate(page.fit.tx, page.fit.ty);
    canvas.scale(page.fit.scale);
    canvas.translate(page.origin.dx, page.origin.dy);
    // Pilha de cor começa em preto opaco: o `color="black"` do
    // `<svg class="definition-scale">` (§6).
    _paintNode(canvas, page.root, const ui.Color(0xFF000000));
  }

  void _paintNode(ui.Canvas canvas, SceneNode node, ui.Color current) {
    if (node.hidden) {
      return;
    }
    // Uma conversão `#rrggbb` -> `Color` por nó, não por forma.
    ui.Color color = current;
    final override = node.id == null ? null : colorOverrides[node.id];
    if (override != null) {
      color = override;
    } else if (node.color != null) {
      color = _parseCssColor(node.color!);
    }
    if (node.rotate != null) {
      final r = node.rotate!;
      canvas.save();
      canvas.translate(r.origin.dx, r.origin.dy);
      canvas.rotate(r.angle * math.pi / 180.0);
      canvas.translate(-r.origin.dx, -r.origin.dy);
      for (final child in node.children) {
        _paintChild(canvas, child, color);
      }
      canvas.restore();
    } else {
      for (final child in node.children) {
        _paintChild(canvas, child, color);
      }
    }
  }

  void _paintChild(ui.Canvas canvas, SceneChild child, ui.Color current) {
    switch (child) {
      case SceneNode():
        _paintNode(canvas, child, current);
      case ScenePath():
        _drawShape(canvas, child, child.path, current);
      case SceneRect():
        _drawShape(canvas, child, child.path, current);
      case SceneEllipse():
        _drawShape(canvas, child, child.path, current);
      case SceneGlyphUse():
        break; // R03.
      case SceneText():
        break; // R04.
    }
  }

  /// Pinta uma forma `p`/`r`/`e`: preenchimento primeiro, traço depois (é a
  /// ordem do SVG), com duas `Paint` separadas (§5.2).
  ///
  /// `strokeWidth` ausente vira `1.0` (padrão IR para `p`/`r`/`e`; no corpus
  /// atual o campo nunca falta). O caminho do traço leva o tracejado quando
  /// `dash` está presente; o do preenchimento nunca (semântica do SVG:
  /// `stroke-dasharray` só afeta o traço). `strokeWidth` fica em unidades de
  /// viewBox: a escala da página é do `Canvas`, nunca da `Paint`.
  void _drawShape(
    ui.Canvas canvas,
    SceneShape shape,
    ui.Path basePath,
    ui.Color current,
  ) {
    final fill = _resolveChannelColor(shape.fill, current, shape.fillOpacity);
    if (fill != null) {
      canvas.drawPath(
        basePath,
        ui.Paint()
          ..color = fill
          ..style = ui.PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
    final stroke = _resolveChannelColor(
      shape.stroke,
      current,
      shape.strokeOpacity,
    );
    if (stroke != null) {
      final strokePath = shape.dash == null
          ? basePath
          : applyDash(basePath, shape.dash!);
      canvas.drawPath(
        strokePath,
        ui.Paint()
          ..color = stroke
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = shape.strokeWidth ?? 1.0
          ..strokeCap = _toStrokeCap(shape.lineCap)
          ..strokeJoin = _toStrokeJoin(shape.lineJoin)
          ..isAntiAlias = true,
      );
    }
  }
}

/// Resolve a cor de um canal (`fill`/`stroke`): `none` vira `null` (não
/// pinta), `inherit` usa a cor corrente, cor explícita usa o hex. O alfa
/// final é `alfaDaCor × opacity`, com arredondamento metade para cima na
/// hora de quantizar para 8 bits (`0.5 sobre #ff0000` dá alfa 128: 127.5
/// arredonda para cima).
ui.Color? _resolveChannelColor(
  ScenePaint paint,
  ui.Color current,
  double opacity,
) {
  if (identical(paint, ScenePaint.none)) {
    return null;
  }
  final ui.Color base = paint is ColorPaint
      ? _parseCssColor(paint.hex)
      : current;
  if (opacity >= 1.0) {
    return base;
  }
  return base.withValues(alpha: (base.a * opacity).clamp(0.0, 1.0));
}

/// `default` = "o exportador não pediu nada" → default do SVG quando o
/// atributo está ausente (`butt`, é o que o `resvg` aplica).
ui.StrokeCap _toStrokeCap(SceneLineCap cap) {
  switch (cap) {
    case SceneLineCap.defaultCap:
      return ui.StrokeCap.butt;
    case SceneLineCap.butt:
      return ui.StrokeCap.butt;
    case SceneLineCap.round:
      return ui.StrokeCap.round;
    case SceneLineCap.square:
      return ui.StrokeCap.square;
  }
}

/// `default` → `miter` (default do SVG). `arcs` e `miter-clip` não existem no
/// Flutter e são mapeados para `miter`; nenhum dos dois ocorre no corpus
/// (só `default`/`round`/`miter`/`bevel` aparecem nas formas — e `arcs`/
/// `miter-clip` em zero ocorrências).
ui.StrokeJoin _toStrokeJoin(SceneLineJoin join) {
  switch (join) {
    case SceneLineJoin.defaultJoin:
      return ui.StrokeJoin.miter;
    case SceneLineJoin.arcs:
      return ui.StrokeJoin.miter;
    case SceneLineJoin.bevel:
      return ui.StrokeJoin.bevel;
    case SceneLineJoin.miter:
      return ui.StrokeJoin.miter;
    case SceneLineJoin.miterClip:
      return ui.StrokeJoin.miter;
    case SceneLineJoin.round:
      return ui.StrokeJoin.round;
  }
}

/// Converte `#rrggbb` (minúsculo, conforme §7) em [ui.Color] opaca.
ui.Color _parseCssColor(String hex) {
  return ui.Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
