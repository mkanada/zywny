// `ScenePainter`: ajuste de página, percurso da árvore e cor herdada (R02b),
// mais traço, opacidade, pontas/junções e tracejado (R02c), mais instâncias
// de glifo `u` (R03b) e runs de texto `t` (R04b, só `left`; `center`/`right`
// em R04c).
//
// Desenha formas `p`/`r`/`e` com preenchimento e traço (§5.2/§6), usos de
// glifo `u` (§5.3) via `GlyphCache` (R03a) e texto comum (§5.4) via
// `painterForRun` (R04a/R04b).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'dash.dart';
import 'geometry.dart';
import 'glyph_cache.dart';
import 'model.dart';
import 'text_run.dart';

/// Pinta uma página da cena num [Canvas] (§3/§5.1/§6).
///
/// Aplica a transformação de página uma vez ([PageFit] + `origin` vindos
/// prontos do arquivo), percorre `children` em ordem de documento mantendo
/// a cor corrente por parâmetro, respeita `hidden` e `rotate`.
class ScenePainter {
  ScenePainter(
    this.page,
    Map<String, GlyphDef> glyphs, {
    this.colorOverrides = const {},
    GlyphCache? glyphCache,
  }) : glyphs = glyphs,
       _glyphCache = glyphCache ?? GlyphCache(glyphs);

  final ScenePage page;
  final Map<String, GlyphDef> glyphs;

  /// Contornos de glifo memoizados (R03a). Por defeito é construído a partir
  /// de [glyphs]; o chamador pode injetar o `document.glyphCache` para
  /// compartilhar entre páginas/painters.
  final GlyphCache _glyphCache;
  final Map<String, ui.Color> colorOverrides;

  /// Contornos memoizados compartilháveis (R03a). Expõe o cache injetado
  /// ou o interno para que o teste de contagem confira `builtCount`.
  GlyphCache get glyphCache => _glyphCache;

  // Reuso de `Paint` entre usos consecutivos com a mesma cor (R03b §4): uma
  // página do Nocturne tem 2 665 usos, alocar 2 `Paint` por uso é evitável.
  ui.Paint? _cachedGlyphFill;
  ui.Color? _cachedGlyphFillColor;
  ui.Paint? _cachedGlyphStroke;
  ui.Color? _cachedGlyphStrokeColor;
  double? _cachedGlyphStrokeWidth;
  SceneLineCap? _cachedGlyphStrokeCap;
  SceneLineJoin? _cachedGlyphStrokeJoin;

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
        _drawGlyphUse(canvas, child, current);
      case SceneText():
        _drawText(canvas, child, current);
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

  /// Pinta um uso de glifo `u` (§5.3, R03b): o mesmo `ui.Path` do dicionário
  /// sob `translate(x, y) scale(sx, sy)`, preenchido **e** traçado com a cor
  /// herdada (é o `<use>` de `DrawMusicText` em `svgdevicecontext.cpp`).
  ///
  /// O `<path>` referenciado cai sob a regra CSS global
  /// `ellipse, path, ... {stroke:currentColor}`: sem o traço os glifos saem
  /// visivelmente mais finos (divergência de alguns por cento no diff).
  /// `strokeWidth: 1.0` **dentro** do `save/scale` equivale a `sy` em
  /// unidades de viewBox — que é exatamente o que §5.3 documenta. Não fazer
  /// a conta à mão fora do `scale`: é a mesma coisa e uma fonte a menos
  /// de erro.
  ///
  /// Quando `strokeWidth` explícito está presente (nunca no corpus), o valor
  /// vem em unidades de viewBox e é convertido para o espaço do glifo com
  /// `strokeWidth / sy` antes de usar dentro do `scale`.
  /// `dash` em `u` não tem ocorrência no corpus e é ignorado aqui.
  void _drawGlyphUse(ui.Canvas canvas, SceneGlyphUse use, ui.Color current) {
    final glyphPath = _glyphCache.pathFor(use.glyphId);
    final fill = _resolveChannelColor(use.fill, current, use.fillOpacity);
    final stroke = _resolveChannelColor(use.stroke, current, use.strokeOpacity);
    if (fill == null && stroke == null) {
      return;
    }
    canvas.save();
    canvas.translate(use.x, use.y);
    // `sx` e `sy` separados: iguais em todo o corpus, mas o formato permite
    // diferirem (`widthToHeightRatio`).
    canvas.scale(use.sx, use.sy);
    if (fill != null) {
      canvas.drawPath(glyphPath, _glyphFillPaint(fill));
    }
    if (stroke != null) {
      final double widthInGlyphSpace = use.strokeWidth == null
          ? 1.0
          : use.strokeWidth! / use.sy;
      canvas.drawPath(
        glyphPath,
        _glyphStrokePaint(stroke, widthInGlyphSpace, use.lineCap, use.lineJoin),
      );
    }
    canvas.restore();
  }

  /// `Paint` de preenchimento de glifo com reuso entre usos consecutivos da
  /// mesma cor final (R03b §4).
  ui.Paint _glyphFillPaint(ui.Color color) {
    final cached = _cachedGlyphFill;
    if (cached != null && _cachedGlyphFillColor == color) {
      return cached;
    }
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill
      ..isAntiAlias = true;
    _cachedGlyphFill = paint;
    _cachedGlyphFillColor = color;
    return paint;
  }

  /// `Paint` de traço de glifo com reuso por (cor, largura, cap, join).
  ui.Paint _glyphStrokePaint(
    ui.Color color,
    double widthInGlyphSpace,
    SceneLineCap cap,
    SceneLineJoin join,
  ) {
    final cached = _cachedGlyphStroke;
    if (cached != null &&
        _cachedGlyphStrokeColor == color &&
        _cachedGlyphStrokeWidth == widthInGlyphSpace &&
        _cachedGlyphStrokeCap == cap &&
        _cachedGlyphStrokeJoin == join) {
      return cached;
    }
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = widthInGlyphSpace
      ..strokeCap = _toStrokeCap(cap)
      ..strokeJoin = _toStrokeJoin(join)
      ..isAntiAlias = true;
    _cachedGlyphStroke = paint;
    _cachedGlyphStrokeColor = color;
    _cachedGlyphStrokeWidth = widthInGlyphSpace;
    _cachedGlyphStrokeCap = cap;
    _cachedGlyphStrokeJoin = join;
    return paint;
  }

  /// Pinta um run de texto comum `t` (§5.4, R04b).
  ///
  /// `x`/`y` do formato são a âncora da **linha de base** (como no SVG:
  /// `StartText`/`MoveTextTo`); o `TextPainter` pinta a partir do **topo**,
  /// daí `run.y - dy`. Neste passo só `left` está implementado (âncora =
  /// `x`); `center`/`right` pintam provisoriamente como `left` — ver
  /// TODO(R04c) abaixo, nunca uma conta errada silenciosa.
  void _drawText(ui.Canvas canvas, SceneText run, ui.Color current) {
    final color = run.color == null ? current : _parseCssColor(run.color!);
    final painter = painterForRun(run, color);
    final dy = painter.computeDistanceToActualBaseline(
      ui.TextBaseline.alphabetic,
    );
    var x = run.x;
    switch (run.align) {
      case SceneTextAlign.left:
        break;
      // TODO(R04c): deslocar x pela metade/largura total do run para
      // `center`/`right` (e aplicar `letterSpacing`); hoje caem como `left`.
      case SceneTextAlign.center:
      case SceneTextAlign.right:
        break;
    }
    painter.paint(canvas, ui.Offset(x, run.y - dy));
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
