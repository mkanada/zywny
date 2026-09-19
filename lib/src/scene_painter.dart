// Esqueleto do `ScenePainter`: ajuste de página, percurso da árvore e cor
// herdada (R02b).
//
// Desenha somente o preenchimento de `ScenePath`/`SceneRect`/`SceneEllipse`.
// Traço e opacidade (R02c), glifos (R03) e texto (R04) ficam para os passos
// seguintes.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

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
        _drawFill(canvas, child.path, child.fill, current);
      case SceneRect():
        _drawFill(canvas, child.path, child.fill, current);
      case SceneEllipse():
        _drawFill(canvas, child.path, child.fill, current);
      case SceneGlyphUse():
        break; // R03.
      case SceneText():
        break; // R04.
    }
  }

  void _drawFill(
    ui.Canvas canvas,
    ui.Path path,
    ScenePaint fill,
    ui.Color current,
  ) {
    if (identical(fill, ScenePaint.none)) {
      return;
    }
    final ui.Color color = fill is ColorPaint
        ? _parseCssColor(fill.hex)
        : current;
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.fill,
    );
  }
}

/// Converte `#rrggbb` (minúsculo, conforme §7) em [ui.Color] opaca.
ui.Color _parseCssColor(String hex) {
  return ui.Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
