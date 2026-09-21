// Coordenadas e hit-test (A04a): da bbox exportada para a posição no widget, e
// de um toque para o `xml:id` do elemento.
//
// DUAS CONVERSÕES, SEPARADAS de propósito:
//   1. **página** ([pageRectToPagePx], [pagePxToPageRect]): unidades de viewBox
//      (o referencial de conteúdo, *antes* do `translate(origin)`) → pixels da
//      página (`widthPx × heightPx`). É a fórmula do plano:
//      `(v + origin) * fit.scale + fit.t`. Vive só aqui; o `ScoreView`
//      (A03b/A03c) e o player (A05b) chamam estas funções.
//   2. **widget**: pixels da página → pixels lógicos do widget, uma
//      multiplicação por `pageWidth / widthPx` (o `ScorePageView` escala o
//      desenho para ocupar a largura que recebe). A posição da página na
//      trilha/rolagem (câmera) é somada por quem a conhece, não aqui.
//
// REGRAS DE `idAt`:
//   * as bboxes se sobrepõem por construção (nota ⊂ acorde ⊂ camada ⊂
//     compasso): ganha a de **menor área**, a mais específica;
//   * entradas com bbox de área zero (nós com `id` sem conteúdo desenhável,
//     `[0,0,0,0]` no formato) são descartadas na indexação e **nunca**
//     ganham;
//   * `classes` filtra por classe (`{'note'}` → "quero a nota, não o
//     compasso");
//   * a varredura é linear (~1 000 entradas por página): sem R-tree antes de
//     medir.
library;

import 'dart:ui' as ui;

import 'model.dart';

/// Converte [bbox] (unidades de viewBox, referencial de conteúdo) para pixels
/// da página, `widthPx × heightPx` de [page].
ui.Rect pageRectToPagePx(ui.Rect bbox, ScenePage page) {
  final fit = page.fit;
  final o = page.origin;
  return ui.Rect.fromLTRB(
    (bbox.left + o.dx) * fit.scale + fit.tx,
    (bbox.top + o.dy) * fit.scale + fit.ty,
    (bbox.right + o.dx) * fit.scale + fit.tx,
    (bbox.bottom + o.dy) * fit.scale + fit.ty,
  );
}

/// Inversa de [pageRectToPagePx]: pixels da página → unidades de viewBox.
ui.Rect pagePxToPageRect(ui.Rect px, ScenePage page) {
  final fit = page.fit;
  final o = page.origin;
  return ui.Rect.fromLTRB(
    (px.left - fit.tx) / fit.scale - o.dx,
    (px.top - fit.ty) / fit.scale - o.dy,
    (px.right - fit.tx) / fit.scale - o.dx,
    (px.bottom - fit.ty) / fit.scale - o.dy,
  );
}

/// Coordenada x de viewBox (referencial de conteúdo) → x em pixels da página.
double xToPagePx(double x, ScenePage page) =>
    (x + page.origin.dx) * page.fit.scale + page.fit.tx;

/// Inversa de [xToPagePx].
double xFromPagePx(double px, ScenePage page) =>
    (px - page.fit.tx) / page.fit.scale - page.origin.dx;

/// Um elemento endereçável e onde ele está.
class ElementRef {
  const ElementRef({
    required this.id,
    required this.className,
    required this.page,
    required this.bbox,
  });

  final String id;
  final String className;

  /// Índice da página no documento.
  final int page;

  /// Bbox em unidades de viewBox (referencial de conteúdo).
  final ui.Rect bbox;

  double get _area => bbox.width * bbox.height;
}

/// Mapa `id → (página, bbox, classe)` de um documento, montado **uma vez**, e
/// as consultas de coordenada e hit-test em cima dele.
///
/// Todas as consultas em "pixels do widget" recebem a [pageWidth] com que a
/// página está desenhada (o `ScorePageView` escala o desenho até ela); sem
/// ela, a página está em tamanho natural (`widthPx`).
class ScoreGeometry {
  ScoreGeometry(this.document) {
    for (final page in document.pages) {
      final list = <ElementRef>[];
      for (final e in page.elements) {
        if (e.bbox.width <= 0 || e.bbox.height <= 0) {
          continue; // degenerada: nunca ganha o hit-test
        }
        final ref = ElementRef(
          id: e.id,
          className: e.className,
          page: page.index,
          bbox: e.bbox,
        );
        list.add(ref);
        // Um id repetido em duas páginas (raro) fica com a primeira.
        _byId.putIfAbsent(e.id, () => ref);
      }
      _byPage.add(list);
    }
  }

  final VsbDocument document;
  final Map<String, ElementRef> _byId = {};
  final List<List<ElementRef>> _byPage = [];

  /// Quantos elementos com bbox utilizável há no documento.
  int get length => _byId.length;

  /// O elemento [id], ou `null` se ele não existe na cena (ids do timemap com
  /// sufixo `-rend2`) ou não tem bbox desenhável.
  ElementRef? elementOf(String id) => _byId[id];

  /// Índice da página de [id], ou `null`.
  int? pageOf(String id) => _byId[id]?.page;

  /// Fator de escala pixels-da-página → pixels-do-widget.
  double _scaleOf(int pageIndex, double? pageWidth) =>
      pageWidth == null ? 1.0 : pageWidth / document.pages[pageIndex].widthPx;

  /// Retângulo de [id] em pixels lógicos **da página** desenhada com
  /// [pageWidth] (a origem é o canto superior esquerdo da página), ou `null`.
  ui.Rect? rectForId(String id, {double? pageWidth}) {
    final ref = _byId[id];
    if (ref == null) {
      return null;
    }
    return rectOf(ref, pageWidth: pageWidth);
  }

  /// [rectForId] para um [ElementRef] já resolvido.
  ui.Rect rectOf(ElementRef ref, {double? pageWidth}) {
    final px = pageRectToPagePx(ref.bbox, document.pages[ref.page]);
    final s = _scaleOf(ref.page, pageWidth);
    return s == 1.0
        ? px
        : ui.Rect.fromLTRB(
            px.left * s,
            px.top * s,
            px.right * s,
            px.bottom * s,
          );
  }

  /// O id do elemento **mais específico** (menor área) sob [localPosition],
  /// dada em pixels da página [pageIndex] desenhada com [pageWidth]; `null`
  /// numa área vazia.
  String? idAt(
    int pageIndex,
    ui.Offset localPosition, {
    double? pageWidth,
    Set<String>? classes,
  }) {
    final page = document.pages[pageIndex];
    final s = _scaleOf(pageIndex, pageWidth);
    // Ponto em unidades de viewBox: compara com as bboxes sem converter cada
    // uma.
    final p = ui.Offset(
      xFromPagePx(localPosition.dx / s, page),
      (localPosition.dy / s - page.fit.ty) / page.fit.scale - page.origin.dy,
    );
    ElementRef? best;
    var bestArea = double.infinity;
    for (final ref in _byPage[pageIndex]) {
      if (classes != null && !classes.contains(ref.className)) {
        continue;
      }
      if (!ref.bbox.contains(p)) {
        continue;
      }
      final area = ref._area;
      if (area < bestArea) {
        best = ref;
        bestArea = area;
      }
    }
    return best?.id;
  }

  /// Ids cuja bbox **intersecta** [localRect] (pixels da página
  /// [pageIndex] desenhada com [pageWidth]), em ordem de documento.
  Iterable<String> idsIn(
    int pageIndex,
    ui.Rect localRect, {
    double? pageWidth,
    Set<String>? classes,
  }) sync* {
    final page = document.pages[pageIndex];
    final s = _scaleOf(pageIndex, pageWidth);
    final r = pagePxToPageRect(
      ui.Rect.fromLTRB(
        localRect.left / s,
        localRect.top / s,
        localRect.right / s,
        localRect.bottom / s,
      ),
      page,
    );
    for (final ref in _byPage[pageIndex]) {
      if (classes != null && !classes.contains(ref.className)) {
        continue;
      }
      if (ref.bbox.overlaps(r)) {
        yield ref.id;
      }
    }
  }
}
