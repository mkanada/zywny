// Modelo imutável do formato `.vsb` (Verovio Score Bridge).
//
// Corresponde a docs/formato/especificacao-v1.md. Os nomes de campo e a
// estrutura de classes seguem a especificação seção a seção; os comentários
// citam a seção correspondente onde a regra não é óbvia pelo nome do campo.
library;

import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'glyph_cache.dart';
import 'parser.dart' as parser;

/// Exceção lançada quando um documento `.vsb`/JSON está malformado.
///
/// [path] é o caminho do campo culpado no documento, no mesmo estilo que um
/// erro de `JSON.parse` aponta uma linha: por exemplo
/// `pages[2].children[17].v`.
class VsbFormatException implements Exception {
  final String path;
  final String message;

  const VsbFormatException(this.path, this.message);

  @override
  String toString() => 'VsbFormatException: $path: $message';
}

/// Lançada quando `manifest.version` é maior que a versão suportada por este
/// leitor. Nunca se tenta renderizar um documento com versão desconhecida.
class UnsupportedVsbVersionException implements Exception {
  final int version;

  const UnsupportedVsbVersionException(this.version);

  String get message =>
      'versão de formato .vsb não suportada: $version (esperado 1)';

  @override
  String toString() => 'UnsupportedVsbVersionException: $message';
}

/// `manifest.json` (§2.1).
class VsbManifest {
  final String format;
  final int version;
  final String generator;
  final int pageCount;
  final VsbManifestFiles files;

  const VsbManifest({
    required this.format,
    required this.version,
    required this.generator,
    required this.pageCount,
    required this.files,
  });
}

class VsbManifestFiles {
  final String scene;
  final String glyphs;
  final String? timemap;

  const VsbManifestFiles({
    required this.scene,
    required this.glyphs,
    this.timemap,
  });
}

/// Documento completo: manifest + dicionário de glifos + páginas + timemap
/// opcional (§2.2).
class VsbDocument {
  final VsbManifest manifest;
  final Map<String, GlyphDef> glyphs;
  final List<ScenePage> pages;
  final List<TimemapEntry>? timemap;

  VsbDocument({
    required this.manifest,
    required this.glyphs,
    required this.pages,
    this.timemap,
  });

  /// Cache de contornos de glifo (R03a): uma instância por documento,
  /// compartilhada por todas as páginas e painters.
  late final GlyphCache glyphCache = GlyphCache(glyphs);

  /// Faz o parse de um `.vsb` (zip) ou de um JSON único (`-t vsb-json`),
  /// detectando o formato pela assinatura `PK` do zip (§2).
  factory VsbDocument.fromBytes(Uint8List bytes) =>
      parser.parseVsbDocumentBytes(bytes);

  /// Faz o parse da raiz de um JSON único já decodificado (§2.2).
  factory VsbDocument.fromJson(Map<String, dynamic> json) =>
      parser.parseVsbDocumentJson(json);
}

/// Uma entrada de `glyphs.json` (§4).
class GlyphDef {
  final String font;
  final String codepoint;
  final int unitsPerEm;
  final double horizAdvX;
  final GlyphBBox bbox;
  final List<BezierPath> paths;

  const GlyphDef({
    required this.font,
    required this.codepoint,
    required this.unitsPerEm,
    required this.horizAdvX,
    required this.bbox,
    required this.paths,
  });
}

/// Bbox de metadados de um glifo (§4).
///
/// O JSON usa `[x, y, width, height]` na escala guardada por
/// `Glyph::SetBoundingBox`: 10 vezes a escala dos contornos e com o eixo Y
/// apontando para cima. Use [toContourRect] para obter a bbox no sistema dos
/// contornos, já dividida por 10 e com Y apontando para baixo.
class GlyphBBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const GlyphBBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Rect toContourRect() {
    return Rect.fromLTRB(
      x / 10.0,
      -(y + height) / 10.0,
      (x + width) / 10.0,
      -y / 10.0,
    );
  }
}

/// Um subpath dentro de `paths` (glifo ou forma `p`), §4/§4.1.
///
/// `v`/`i`/`o` são arrays **planos** de pares x,y (não convertidos para
/// `Offset`) para manter o parse rápido e a memória baixa — são os arrays com
/// maior volume de números no formato.
class BezierPath {
  final bool closed;
  final Float64List v;
  final Float64List i;
  final Float64List o;

  const BezierPath({
    required this.closed,
    required this.v,
    required this.i,
    required this.o,
  });
}

/// Ajuste de página pré-computado (§3): `translate(tx, ty)`, `scale(scale)`.
class PageFit {
  final double scale;
  final double tx;
  final double ty;

  const PageFit({required this.scale, required this.tx, required this.ty});
}

/// Entrada de `pages[].elements` (§5.5).
class IndexEntry {
  final String id;
  final String className;
  final int nodePath;
  final Rect bbox;

  const IndexEntry({
    required this.id,
    required this.className,
    required this.nodePath,
    required this.bbox,
  });
}

/// Uma página de `scene.json` (§5).
class ScenePage {
  final int index;
  final int width;
  final int height;
  final int contentHeight;
  final double viewBoxFactor;
  final Rect viewBox;
  final int baseWidth;
  final int baseHeight;
  final double userScaleX;
  final double userScaleY;
  final int widthPx;
  final int heightPx;
  final PageFit fit;
  final Offset origin;
  final SceneNode root;
  final List<IndexEntry> elements;

  /// Índice `xml:id` → nó, construído numa única passada de percurso da
  /// árvore durante o parse (não vem do JSON).
  final Map<String, SceneNode> byId;

  const ScenePage({
    required this.index,
    required this.width,
    required this.height,
    required this.contentHeight,
    required this.viewBoxFactor,
    required this.viewBox,
    required this.baseWidth,
    required this.baseHeight,
    required this.userScaleX,
    required this.userScaleY,
    required this.widthPx,
    required this.heightPx,
    required this.fit,
    required this.origin,
    required this.root,
    required this.elements,
    required this.byId,
  });
}

/// Cor de preenchimento/traço (§5.2): herdar do ancestral, não pintar, ou uma
/// cor explícita `#rrggbb`.
sealed class ScenePaint {
  const ScenePaint();

  static const ScenePaint inherit = _InheritPaint();
  static const ScenePaint none = _NonePaint();
}

class _InheritPaint extends ScenePaint {
  const _InheritPaint();
}

class _NonePaint extends ScenePaint {
  const _NonePaint();
}

class ColorPaint extends ScenePaint {
  final String hex;

  const ColorPaint(this.hex);
}

enum SceneLineCap { defaultCap, butt, round, square }

enum SceneLineJoin { defaultJoin, arcs, bevel, miter, miterClip, round }

/// `dash` de uma forma (§5.2): `[dashLength, gapLength]`.
class SceneDash {
  final double length;
  final double gap;

  const SceneDash(this.length, this.gap);
}

enum SceneTextAlign { left, center, right }

/// `rotate` de um nó (§5.1).
class SceneRotate {
  final double angle;
  final Offset origin;

  const SceneRotate({required this.angle, required this.origin});
}

/// Um item de `children[]` (§8, `BridgeChild`): nó, forma, uso de glifo ou
/// run de texto.
sealed class SceneChild {
  const SceneChild();
}

/// Um nó de grupo (`t: "g"`, §5.1).
class SceneNode extends SceneChild {
  final String? id;
  final String className;
  final String? color;
  final bool hidden;
  final SceneRotate? rotate;
  final Rect? bbox;
  final List<SceneChild> children;

  const SceneNode({
    this.id,
    required this.className,
    this.color,
    required this.hidden,
    this.rotate,
    this.bbox,
    required this.children,
  });
}

/// Campos de estilo comuns a todas as formas (§5.2): `fill`, `fillOpacity`,
/// `stroke`, `strokeWidth`, `strokeOpacity`, `lineCap`, `lineJoin`, `dash`.
///
/// `strokeWidth` é mantido cru (`null` quando ausente do JSON) porque o valor
/// efetivo padrão depende do tipo de forma — `1.0` para `p`/`r`/`e`, `sy` para
/// `u` (§5.3/§8) — e essa é uma decisão de pintura, fora do escopo deste
/// pacote (R02/R03).
sealed class SceneShape extends SceneChild {
  final ScenePaint fill;
  final double fillOpacity;
  final ScenePaint stroke;
  final double? strokeWidth;
  final double strokeOpacity;
  final SceneLineCap lineCap;
  final SceneLineJoin lineJoin;
  final SceneDash? dash;

  const SceneShape({
    required this.fill,
    required this.fillOpacity,
    required this.stroke,
    required this.strokeWidth,
    required this.strokeOpacity,
    required this.lineCap,
    required this.lineJoin,
    required this.dash,
  });
}

/// Forma de caminho (`t: "p"`, §5.2). `paths` são subpaths que compartilham o
/// mesmo preenchimento.
class ScenePath extends SceneShape {
  final List<BezierPath> paths;

  const ScenePath({
    required this.paths,
    required super.fill,
    required super.fillOpacity,
    required super.stroke,
    required super.strokeWidth,
    required super.strokeOpacity,
    required super.lineCap,
    required super.lineJoin,
    required super.dash,
  });
}

/// Retângulo (`t: "r"`, §5.2). `x`/`y` é o canto superior esquerdo.
class SceneRect extends SceneShape {
  final double x;
  final double y;
  final double w;
  final double h;
  final double rx;

  const SceneRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.rx,
    required super.fill,
    required super.fillOpacity,
    required super.stroke,
    required super.strokeWidth,
    required super.strokeOpacity,
    required super.lineCap,
    required super.lineJoin,
    required super.dash,
  });
}

/// Elipse (`t: "e"`, §5.2).
class SceneEllipse extends SceneShape {
  final double cx;
  final double cy;
  final double rx;
  final double ry;

  const SceneEllipse({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required super.fill,
    required super.fillOpacity,
    required super.stroke,
    required super.strokeWidth,
    required super.strokeOpacity,
    required super.lineCap,
    required super.lineJoin,
    required super.dash,
  });
}

/// Uso de glifo (`t: "u"`, §5.3). `glyphId` é a chave em
/// `VsbDocument.glyphs`.
class SceneGlyphUse extends SceneShape {
  final String glyphId;
  final double x;
  final double y;
  final double sx;
  final double sy;

  const SceneGlyphUse({
    required this.glyphId,
    required this.x,
    required this.y,
    required this.sx,
    required this.sy,
    required super.fill,
    required super.fillOpacity,
    required super.stroke,
    required super.strokeWidth,
    required super.strokeOpacity,
    required super.lineCap,
    required super.lineJoin,
    required super.dash,
  });
}

/// Run de texto comum (`t: "t"`, §5.4).
class SceneText extends SceneChild {
  final String text;
  final double x;
  final double y;
  final double size;
  final SceneTextAlign align;
  final double letterSpacing;
  final bool bold;
  final bool italic;
  final String family;
  final String? color;

  const SceneText({
    required this.text,
    required this.x,
    required this.y,
    required this.size,
    required this.align,
    required this.letterSpacing,
    required this.bold,
    required this.italic,
    required this.family,
    this.color,
  });
}

/// Uma entrada de `timemap.json` (§2, formato herdado do `Toolkit`).
class TimemapEntry {
  final double? qstamp;
  final List<int>? qfrac;
  final double tstamp;
  final List<String> on;
  final List<String> off;
  final List<String> restsOn;
  final List<String> restsOff;
  final double? tempo;
  final String? measureOn;

  const TimemapEntry({
    this.qstamp,
    this.qfrac,
    required this.tstamp,
    required this.on,
    required this.off,
    required this.restsOn,
    required this.restsOff,
    this.tempo,
    this.measureOn,
  });
}
