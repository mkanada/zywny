import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';

import 'layout_options.dart';
import 'layout_panel.dart';
import 'native_paths.dart';
import 'verovio_render.dart';
import 'verovio_resources.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Liberation Serif (the `t` runs of the scene, §5.4) ships inside
  // score_bridge and has to be registered before the first paint —
  // otherwise the engine falls back to a system serif without warning.
  await loadScoreFonts();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zywny • partitura → .vsb',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const ScoreHomePage(),
    );
  }
}

class ScoreHomePage extends StatefulWidget {
  const ScoreHomePage({super.key});

  @override
  State<ScoreHomePage> createState() => _ScoreHomePageState();
}

/// Range of the on-screen zoom. It scales the drawn page only — see
/// [_ScoreHomePageState._view] — so it has no bearing on the engraving.
const double kZoomMin = 0.5;
const double kZoomMax = 8.0;

class _ScoreHomePageState extends State<ScoreHomePage> {
  String? _scoreName;
  String? _inputPath;
  VsbDocument? _document;
  int _pageIndex = 0;
  String _status = 'abra uma partitura (.mei, .musicxml, .mxml)';
  bool _busy = false;

  /// A render was asked for while another was running; it starts as soon as
  /// that one ends, with whatever the options are by then.
  bool _renderQueued = false;

  /// Size of the score box in device pixels, from the [LayoutBuilder] in
  /// [_buildScoreArea]. The page is engraved for exactly this box, so there
  /// is nothing to render before the first layout.
  Size? _boxDevicePx;
  Timer? _resizeDebounce;

  /// Verovio options being tried, by name (see `layout_options.dart`).
  Map<String, Object> _layout = initialLayoutValues();

  /// Whether the page is sized from the score box ([_pageWidth] /
  /// [_pageHeight]) or from the `pageWidth`/`pageHeight` options.
  bool _pageFitsBox = true;
  bool _panelOpen = false;

  /// On-screen zoom and pan of the drawn page.
  ///
  /// This lives above the score: it transforms the finished drawing and is
  /// never part of the render request, so changing it neither reflows the
  /// piece nor triggers a render. What does change the engraving is the
  /// `unit` option, in the panel.
  final TransformationController _view = TransformationController();
  Size _viewport = Size.zero;

  int get _pageCount => _document?.pages.length ?? 0;

  /// Paper size, in tenths of a millimetre, that makes one device pixel one
  /// unit — i.e. the page is engraved at 254 dpi and drawn 1:1, which is the
  /// configuration `compare` measured against the reference SVG. Anything
  /// larger would show the notation shrunk, pushing stroke widths below a
  /// pixel (a 0.13 mm staff line needs ~7.7 px/mm to survive).
  Size? get _fittedPage {
    final box = _boxDevicePx;
    if (box == null) return null;
    return Size(
      box.width
          .round()
          .clamp(kVerovioMinPageWidth, kVerovioMaxPageWidth)
          .toDouble(),
      box.height
          .round()
          .clamp(kVerovioMinPageHeight, kVerovioMaxPageHeight)
          .toDouble(),
    );
  }

  int get _pageWidth =>
      _pageFitsBox ? _fittedPage!.width.round() : _layout['pageWidth'] as int;

  int get _pageHeight =>
      _pageFitsBox ? _fittedPage!.height.round() : _layout['pageHeight'] as int;

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    _view.dispose();
    super.dispose();
  }

  /// Records the score box and re-engraves when it really changed.
  ///
  /// Called from `build`, so it must never call `setState` synchronously;
  /// the re-render goes through a debounce both for that and because a
  /// window drag emits a size per frame, each one an FFI render away.
  void _onBoxSize(Size devicePx) {
    final previous = _boxDevicePx;
    if (previous == devicePx) return;
    _boxDevicePx = devicePx;
    if (previous == null) {
      // First layout: the panel was built before the box was known, so it
      // is still showing no page size. Nothing to re-render yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    // A fixed page size does not depend on the box, so a resize has nothing
    // to re-engrave.
    if (_inputPath == null || !_pageFitsBox) return;
    // 2% of slack: a one-pixel wobble is not worth re-engraving the piece.
    final changed =
        (previous.width - devicePx.width).abs() / previous.width > 0.02 ||
        (previous.height - devicePx.height).abs() / previous.height > 0.02;
    if (!changed) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 400), _renderAndShow);
  }

  Future<void> _abrirPartitura() async {
    if (_busy) return;
    const typeGroup = XTypeGroup(
      label: 'partituras',
      extensions: ['mei', 'musicxml', 'mxml', 'xml'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    if (!mounted) return;

    _view.value = Matrix4.identity();
    setState(() {
      _inputPath = file.path;
      _scoreName = file.name;
      _pageIndex = 0;
    });
    await _renderAndShow();
  }

  /// Every option that reaches Verovio for the current state: the page size
  /// plus whatever differs from Verovio's defaults.
  Map<String, Object> _effectiveOptions() => {
    'pageWidth': _pageWidth,
    'pageHeight': _pageHeight,
    ...layoutOptionsToSend(_layout),
  };

  /// Renders [_inputPath] with the current options and displays it. The
  /// previous page stays on screen meanwhile, so the effect of an option can
  /// be compared at the same zoom and pan.
  Future<void> _renderAndShow() async {
    final inputPath = _inputPath;
    if (inputPath == null || _boxDevicePx == null || !mounted) return;
    if (_busy) {
      _renderQueued = true;
      return;
    }

    final pageWidth = _pageWidth;
    final pageHeight = _pageHeight;
    final options = layoutOptionsToSend(_layout);

    setState(() {
      _busy = true;
      _status = 'gerando .vsb…';
    });

    Directory? tmpDir;
    try {
      tmpDir = await Directory.systemTemp.createTemp('zywny');
      final outPath = '${tmpDir.path}/score.vsb';
      final name = _scoreName ?? '';

      setState(() => _status = 'renderizando $name ($pageWidth×$pageHeight)…');

      final document = await renderScoreToVsb(
        VsbRenderRequest(
          inputPath: inputPath,
          outputPath: outPath,
          libraryPath: findVerovioLibrary(),
          resourcePath: await verovioResourcePath(),
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          options: options,
        ),
      );

      if (!mounted) return;
      setState(() {
        _document = document;
        // New options reflow the score: the page we were on may not exist
        // any more.
        _pageIndex = _pageIndex.clamp(0, document.pages.length - 1);
        _status = document.pages.length > 1
            ? 'página ${_pageIndex + 1} de ${document.pages.length}'
            : 'carregada ✓';
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'erro: $e';
        _busy = false;
      });
    } finally {
      // The .vsb is fully in memory by now; one temp dir per render adds up
      // fast when trying options.
      unawaited(tmpDir?.delete(recursive: true).then((_) {}, onError: (_) {}));
    }

    if (mounted && _renderQueued) {
      _renderQueued = false;
      unawaited(_renderAndShow());
    }
  }

  void _goToPage(int page) {
    if (_pageCount == 0) return;
    final target = page.clamp(0, _pageCount - 1);
    setState(() {
      _pageIndex = target;
      _status = _pageCount > 1
          ? 'página ${target + 1} de $_pageCount'
          : 'pronto ✓';
    });
  }

  void _setLayoutValue(String key, Object value) =>
      setState(() => _layout = {..._layout, key: value});

  void _resetLayout() {
    setState(() {
      _layout = initialLayoutValues();
      _pageFitsBox = true;
    });
    _renderAndShow();
  }

  Future<void> _copyOptions() async {
    final json = const JsonEncoder.withIndent('  ')
        .convert(_effectiveOptions());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Opções copiadas (JSON)')));
  }

  /// Multiplies the on-screen zoom by [factor]. Reads the live value, not
  /// the one the buttons were built with, so taps between frames add up.
  void _zoomBy(double factor) =>
      _zoomTo(_view.value.getMaxScaleOnAxis() * factor);

  /// Sets the on-screen zoom to [target], keeping the centre of the view
  /// where it is.
  void _zoomTo(double target) {
    final current = _view.value.getMaxScaleOnAxis();
    final factor = target.clamp(kZoomMin, kZoomMax) / current;
    final cx = _viewport.width / 2;
    final cy = _viewport.height / 2;
    // All three axes, like InteractiveViewer does: getMaxScaleOnAxis() reads
    // the largest of them, so a Z left at 1 would pin the zoom at >= 100%.
    _view.value =
        Matrix4.translationValues(cx, cy, 0) *
        Matrix4.diagonal3Values(factor, factor, factor) *
        Matrix4.translationValues(-cx, -cy, 0) *
        _view.value;
  }

  /// Zoom control floating over the score. It sits in the [Stack] of
  /// [_buildScoreArea], so it takes no room from the page.
  Widget _zoomControls() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      child: ValueListenableBuilder<Matrix4>(
        valueListenable: _view,
        builder: (context, matrix, _) {
          final scale = matrix.getMaxScaleOnAxis();
          final untouched = matrix.isIdentity();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Diminuir zoom',
                onPressed: scale > kZoomMin ? () => _zoomBy(1 / 1.25) : null,
                icon: const Icon(Icons.remove),
              ),
              // Logarithmic: equal steps are equal ratios, so 50%→100% takes
              // as much travel as 400%→800%.
              SizedBox(
                width: 150,
                child: Slider(
                  min: math.log(kZoomMin) / math.ln2,
                  max: math.log(kZoomMax) / math.ln2,
                  value: (math.log(scale) / math.ln2).clamp(
                    math.log(kZoomMin) / math.ln2,
                    math.log(kZoomMax) / math.ln2,
                  ),
                  onChanged: (v) => _zoomTo(math.pow(2, v).toDouble()),
                ),
              ),
              IconButton(
                tooltip: 'Aumentar zoom',
                onPressed: scale < kZoomMax ? () => _zoomBy(1.25) : null,
                icon: const Icon(Icons.add),
              ),
              Tooltip(
                message: 'Voltar a 100%',
                child: TextButton(
                  onPressed: untouched
                      ? null
                      : () => _view.value = Matrix4.identity(),
                  child: SizedBox(
                    width: 44,
                    child: Text(
                      '${(scale * 100).round()}%',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScoreArea() {
    // The page is engraved for this box, so its size has to be known before
    // the first render — hence measuring here rather than off the window.
    // Everything drawn over the score (zoom, panel) is a Stack child, so it
    // never changes this box and never re-engraves the piece.
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        _onBoxSize(constraints.biggest * dpr);
        _viewport = constraints.biggest;

        final document = _document;
        final hasPage = document != null && document.pages.isNotEmpty;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _view,
                minScale: kZoomMin,
                maxScale: kZoomMax,
                boundaryMargin: EdgeInsets.all(
                  math.min(constraints.maxWidth, constraints.maxHeight) / 2,
                ),
                child: hasPage
                    ? VsbPageView(
                        document: document,
                        pageIndex: _pageIndex.clamp(
                          0,
                          document.pages.length - 1,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.music_note,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            if (_busy)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
            Positioned(left: 12, bottom: 12, child: _zoomControls()),
            if (_panelOpen)
              Positioned(
                top: 8,
                right: 8,
                bottom: 8,
                width: math.min(360, constraints.maxWidth - 16),
                child: LayoutPanel(
                  values: _layout,
                  pageFitsBox: _pageFitsBox,
                  fittedPage: _fittedPage,
                  onChanged: _setLayoutValue,
                  onCommit: _renderAndShow,
                  onFitChanged: (v) {
                    setState(() => _pageFitsBox = v);
                    _renderAndShow();
                  },
                  onReset: _resetLayout,
                  onCopy: _copyOptions,
                  onClose: () => setState(() => _panelOpen = false),
                ),
              )
            else
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Parâmetros do Verovio',
                  onPressed: () => setState(() => _panelOpen = true),
                  icon: const Icon(Icons.tune),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('zywny • partitura → .vsb'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _abrirPartitura,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir partitura'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _scoreName ?? 'nenhuma partitura',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildScoreArea(),
              ),
            ),
            const SizedBox(height: 8),
            Text('status: $_status'),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Página anterior',
                  onPressed: _pageIndex > 0 && !_busy
                      ? () => _goToPage(_pageIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  _pageCount == 0 ? '—' : '${_pageIndex + 1} / $_pageCount',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                IconButton.filledTonal(
                  tooltip: 'Próxima página',
                  onPressed: _pageIndex < _pageCount - 1 && !_busy
                      ? () => _goToPage(_pageIndex + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws one page of a parsed `.vsb` with [ScenePainter], keeping the page
/// aspect and centring it in whatever box the parent gives.
///
/// Named `VsbPageView`, not `ScorePageView`: the plan's phase A gives
/// `score_bridge` a `ScorePageView` of its own (layered `CustomPaint` plus a
/// `ScoreController`), and an unqualified import of both would clash. When
/// that lands, this widget is what it replaces.
///
/// The page is a fixed-size drawing ([ScenePage.widthPx]/[ScenePage.heightPx]
/// are the dimensions of the Verovio `<svg>` root); the painter already
/// applies the page fit, so all that is left here is a uniform scale from
/// those pixels to the widget box.
class VsbPageView extends StatelessWidget {
  const VsbPageView({
    super.key,
    required this.document,
    required this.pageIndex,
  });

  final VsbDocument document;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final page = document.pages[pageIndex];
    return Center(
      child: AspectRatio(
        aspectRatio: page.widthPx / page.heightPx,
        child: ColoredBox(
          color: Colors.white,
          child: CustomPaint(
            painter: _ScenePageCustomPainter(document, page),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _ScenePageCustomPainter extends CustomPainter {
  _ScenePageCustomPainter(this.document, this.page);

  final VsbDocument document;
  final ScenePage page;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // AspectRatio keeps both factors equal; computing them separately just
    // avoids depending on that for correctness.
    canvas.scale(size.width / page.widthPx, size.height / page.heightPx);
    // The glyph outline cache lives on the document, so flipping pages back
    // and forth never rebuilds a `ui.Path`.
    ScenePainter(
      page,
      document.glyphs,
      glyphCache: document.glyphCache,
    ).paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePageCustomPainter oldDelegate) =>
      !identical(oldDelegate.page, page) ||
      !identical(oldDelegate.document, document);
}
