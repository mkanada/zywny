// `ScorePageView`: uma página da partitura como widget de produção (A01b).
//
// Camadas: os segmentos estáticos de A01a viram `ui.Picture` gravados uma vez
// (ver `PageLayers`) e os dinâmicos são pintados ao vivo com as cores do
// `ScoreController`. `RepaintBoundary` em volta do `CustomPaint`, e o
// `repaint:` do painter ligado ao controller: uma mudança de cor repinta sem
// `setState`, sem reconstruir widget e sem refazer layout.
//
// TAMANHO: o widget tem a proporção da página (`widthPx : heightPx`) e escala
// o desenho para ocupar a largura que recebe. Os `Picture` são gravados em
// unidades de viewBox, então redimensionar não recompila nada.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'model.dart';
import 'page_layers.dart';
import 'score_controller.dart';
import 'segmentation.dart';

class ScorePageView extends StatefulWidget {
  const ScorePageView({
    super.key,
    required this.document,
    required this.pageIndex,
    this.controller,
    this.animatableIds,
    this.backgroundColor = const Color(0xFFFFFFFF),
  });

  final VsbDocument document;
  final int pageIndex;

  /// Cor por id e destaques. Sem controller a página só mostra o repouso.
  final ScoreController? controller;

  /// Ids que podem mudar de cor sem recompilar a página. `null` é o padrão:
  /// os ids `on`/`off` do timemap do documento (vazio, se não há timemap).
  /// Um id que o controller colore e que não está aqui é promovido a
  /// dinâmico, ao custo de recompilar os `Picture` da página.
  final Set<String>? animatableIds;

  /// Fundo da página; `null` deixa transparente.
  final Color? backgroundColor;

  @override
  State<ScorePageView> createState() => ScorePageViewState();
}

class ScorePageViewState extends State<ScorePageView> {
  final PictureStats _stats = PictureStats();
  PageLayers? _layers;
  Set<String> _animatableIds = const {};

  // Ids promovidos a dinâmicos porque o controller os colore (ver
  // `_collectPromotions`); zerado quando muda documento/página.
  final Set<String> _promoted = {};

  ScenePage get _page => widget.document.pages[widget.pageIndex];

  @override
  void initState() {
    super.initState();
    widget.controller?.attachDocument(widget.document);
    widget.controller?.addListener(_onControllerChanged);
    _collectPromotions();
    _rebuildLayers();
  }

  @override
  void didUpdateWidget(ScorePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = widget.controller;
    if (oldWidget.controller != controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      controller?.addListener(_onControllerChanged);
    }
    controller?.attachDocument(widget.document);
    final structural =
        oldWidget.document != widget.document ||
        oldWidget.pageIndex != widget.pageIndex ||
        !setEquals(oldWidget.animatableIds, widget.animatableIds);
    if (structural) {
      _promoted.clear();
    }
    if (structural || _collectPromotions()) {
      _rebuildLayers();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _layers?.dispose();
    super.dispose();
  }

  /// Recria as camadas: a única situação em que os `Picture` são recompilados
  /// (documento, página ou conjunto de ids dinâmicos mudou — nunca cor).
  void _rebuildLayers() {
    final old = _layers;
    _animatableIds = {
      ...(widget.animatableIds ??
          animatableIdsFromTimemap(widget.document.timemap)),
      ..._promoted,
    };
    _layers = PageLayers(
      _page,
      widget.document.glyphs,
      animatableIds: _animatableIds,
      glyphCache: widget.document.glyphCache,
      stats: _stats,
    );
    old?.dispose();
  }

  void _onControllerChanged() {
    if (_collectPromotions()) {
      setState(_rebuildLayers);
    }
  }

  /// Se o controller tem cor para um id que existe nesta página mas está num
  /// `Picture` estático, marca o id para promoção a dinâmico. Devolve se
  /// houve promoção nova (e as camadas precisam ser recriadas).
  bool _collectPromotions() {
    final controller = widget.controller;
    if (controller == null || controller.colors.isEmpty) {
      return false;
    }
    final byId = _page.byId;
    var added = false;
    for (final id in controller.colors.keys) {
      if (!_animatableIds.contains(id) &&
          !_promoted.contains(id) &&
          byId.containsKey(id)) {
        _promoted.add(id);
        added = true;
      }
    }
    return added;
  }

  /// Quantos `Picture` estáticos já foram gravados por este widget (todas as
  /// gerações de cache somadas). Não muda quando uma cor muda.
  @visibleForTesting
  int get pictureBuilds => _stats.builds;

  /// Quantos `Picture` estáticos já foram descartados.
  @visibleForTesting
  int get pictureDisposals => _stats.disposals;

  @visibleForTesting
  PictureStats get pictureStats => _stats;

  @visibleForTesting
  PageLayers get layers => _layers!;

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return AspectRatio(
      aspectRatio: page.widthPx / page.heightPx,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PagePainter(
            _layers!,
            widget.controller,
            widget.backgroundColor,
          ),
        ),
      ),
    );
  }
}

class _PagePainter extends CustomPainter {
  _PagePainter(this.layers, this.controller, this.backgroundColor)
    : super(repaint: controller);

  final PageLayers layers;
  final ScoreController? controller;
  final Color? backgroundColor;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final page = layers.page;
    if (backgroundColor != null) {
      canvas.drawRect(
        ui.Offset.zero & size,
        ui.Paint()..color = backgroundColor!,
      );
    }
    final scale = size.width / page.widthPx;
    canvas.save();
    if (scale != 1.0) {
      canvas.scale(scale);
    }
    layers.applyPageTransform(canvas);
    layers.paint(canvas, controller?.colors ?? const {});
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PagePainter oldDelegate) =>
      !identical(oldDelegate.layers, layers) ||
      oldDelegate.backgroundColor != backgroundColor;
}
