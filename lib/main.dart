import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:score_bridge/score_bridge.dart';

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

class _ScoreHomePageState extends State<ScoreHomePage> {
  String? _scoreName;
  String? _inputPath;
  VsbDocument? _document;
  int _pageIndex = 0;
  String _status = 'abra uma partitura (.mei, .musicxml, .mxml)';
  bool _busy = false;

  /// Size of the score box in device pixels, from the [LayoutBuilder] in
  /// [_buildScoreArea]. The page is engraved for exactly this box, so there
  /// is nothing to render before the first layout.
  Size? _boxDevicePx;
  Timer? _resizeDebounce;

  /// Zoom, as a multiplier on how large the notation is displayed. The page
  /// is [_boxDevicePx] divided by this, so 2x asks for a page half the size
  /// in millimetres: fewer systems on it, each one twice as large on screen,
  /// and more pages for the piece.
  double _zoom = 1.0;

  int get _pageCount => _document?.pages.length ?? 0;

  /// Paper size, in tenths of a millimetre, that makes one device pixel one
  /// unit — i.e. the page is engraved at 254 dpi and drawn 1:1, which is the
  /// configuration `compare` measured against the reference SVG. Anything
  /// larger would show the notation shrunk, pushing stroke widths below a
  /// pixel (a 0.13 mm staff line needs ~7.7 px/mm to survive).
  int get _pageWidth => (_boxDevicePx!.width / _zoom)
      .round()
      .clamp(kVerovioMinPageWidth, kVerovioMaxPageWidth);

  int get _pageHeight => (_boxDevicePx!.height / _zoom)
      .round()
      .clamp(kVerovioMinPageHeight, kVerovioMaxPageHeight);

  @override
  void dispose() {
    _resizeDebounce?.cancel();
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
      // First layout: the tuning panel was built before the box was known,
      // so it is still showing no page size. Nothing to re-render yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    if (_inputPath == null) return;
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

    setState(() {
      _inputPath = file.path;
      _scoreName = file.name;
      _pageIndex = 0;
    });
    await _renderAndShow();
  }

  /// Renders [_inputPath] with the current tuning values and displays it.
  Future<void> _renderAndShow() async {
    final inputPath = _inputPath;
    if (inputPath == null || _busy || _boxDevicePx == null) return;
    if (!mounted) return;

    final pageWidth = _pageWidth;
    final pageHeight = _pageHeight;

    setState(() {
      _busy = true;
      _status = 'gerando .vsb…';
      _document = null;
    });

    try {
      final tmpDir = await Directory.systemTemp.createTemp('zywny');
      final outPath = '${tmpDir.path}/score.vsb';
      final name = _scoreName ?? '';

      setState(
        () => _status = 'renderizando $name ($pageWidth×$pageHeight)…',
      );

      final document = await renderScoreToVsb(
        VsbRenderRequest(
          inputPath: inputPath,
          outputPath: outPath,
          libraryPath: findVerovioLibrary(),
          resourcePath: await verovioResourcePath(),
          pageWidth: pageWidth,
          pageHeight: pageHeight,
        ),
      );

      if (!mounted) return;
      setState(() {
        _document = document;
        // A new page size reflows the score: the page we were on may not
        // exist any more.
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

  /// One tuning slider row. The value label updates live while dragging;
  /// the file re-renders once on release ([Slider.onChangeEnd]), guarded
  /// by [_renderAndShow] (no file loaded or render in flight → no-op).
  Widget _tuningSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String suffix = '',
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: (_) => _renderAndShow(),
          ),
        ),
        SizedBox(
          width: 88,
          child: Text(
            '${value.toStringAsFixed(1)}$suffix',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreArea() {
    // The page is engraved for this box, so its size has to be known before
    // the first render — hence measuring here rather than off the window.
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        _onBoxSize(constraints.biggest * dpr);

        if (_busy) return const Center(child: CircularProgressIndicator());
        final document = _document;
        if (document == null || document.pages.isEmpty) {
          return const Center(
            child: Icon(Icons.music_note, size: 64, color: Colors.grey),
          );
        }
        return VsbPageView(
          document: document,
          pageIndex: _pageIndex.clamp(0, document.pages.length - 1),
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
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ajustes de render'),
              subtitle: Text(
                _boxDevicePx == null
                    ? 'zoom ${_zoom.toStringAsFixed(1)}×'
                    : 'zoom ${_zoom.toStringAsFixed(1)}× • '
                        'página $_pageWidth×$_pageHeight '
                        '(${(_pageWidth / 10).round()}×'
                        '${(_pageHeight / 10).round()} mm)',
              ),
              children: [
                _tuningSlider(
                  label: 'Zoom',
                  value: _zoom,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  onChanged: (v) => setState(() => _zoom = v),
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
                  _pageCount == 0
                      ? '—'
                      : '${_pageIndex + 1} / $_pageCount',
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
