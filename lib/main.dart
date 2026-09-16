import 'dart:io';

import 'package:dotlottie_flutter/dotlottie_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:verovio_viewer/verovio_viewer.dart';

import 'native_paths.dart';
import 'verovio_render.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zywny • partitura → dotLottie',
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
  final GlobalKey<ScoreViewerState> _viewerKey = GlobalKey();
  DotLottieViewController? _controller;

  String? _scoreName;
  String? _inputPath;
  String? _lottiePath;
  String _status = 'abra uma partitura (.mei, .musicxml, .mxml)';
  bool _busy = false;
  double _velocidade = 1.0;

  /// Render tuning (see the "Ajustes de render" panel). Values persist
  /// across files so the best size for this screen is tuned once.
  /// Defaults: 3700×1350 (see [kDefaultPageWidth]/[kDefaultPageHeight]).
  double _pageWidth = kDefaultPageWidth.toDouble();
  double _pageHeight = kDefaultPageHeight.toDouble();

  int get _pageCount => _viewerKey.currentState?.pageCount ?? 1;
  int get _currentPage => _viewerKey.currentState?.currentPage ?? 0;

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
    });
    await _renderAndShow();
  }

  /// Renders [_inputPath] with the current tuning values and displays it.
  Future<void> _renderAndShow() async {
    final inputPath = _inputPath;
    if (inputPath == null || _busy) return;
    if (!mounted) return;

    final pageWidth = _pageWidth.toInt();
    final pageHeight = _pageHeight.toInt();

    setState(() {
      _busy = true;
      _status = 'gerando dotLottie…';
      _controller = null;
    });

    try {
      final tmpDir = await Directory.systemTemp.createTemp('zywny');
      final outPath = '${tmpDir.path}/score.lottie';
      final name = _scoreName ?? '';

      setState(() => _status =
          'renderizando $name ($pageWidth×$pageHeight)…');

      await renderScoreToDotLottie(
        VerovioRenderRequest(
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
        // Novo caminho => Key nova (ver [ScoreViewer]) => o player recarrega.
        _lottiePath = outPath;
        _status = 'carregando ($pageWidth×$pageHeight)…';
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

  void _onScoreViewerReady() {
    if (!mounted) return;
    setState(() {
      _status = _pageCount > 1
          ? 'página ${_currentPage + 1} de $_pageCount'
          : 'carregada ✓';
    });
  }

  Future<void> _goToPage(int page) async {
    await _viewerKey.currentState?.goToPage(page);
    if (!mounted) return;
    setState(() {
      _status = _pageCount > 1
          ? 'página ${_currentPage + 1} de $_pageCount'
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
            '${value.toInt()}$suffix',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('zywny • partitura → dotLottie'),
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
                '${_pageWidth.toInt()}×${_pageHeight.toInt()}',
              ),
              children: [
                _tuningSlider(
                  label: 'Largura',
                  value: _pageWidth,
                  min: kVerovioMinPageWidth.toDouble(),
                  max: kVerovioMaxPageWidth.toDouble(),
                  divisions: 95,
                  onChanged: (v) => setState(() => _pageWidth = v),
                ),
                _tuningSlider(
                  label: 'Altura',
                  value: _pageHeight,
                  min: kVerovioMinPageHeight.toDouble(),
                  max: kVerovioMaxPageHeight.toDouble(),
                  divisions: 114,
                  onChanged: (v) => setState(() => _pageHeight = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Score view locked to the page aspect: the fitted box always
            // matches the rendered page exactly, so the display scale stays
            // constant (no letterbox bands, no cropping) whatever the
            // window size. The plugin itself only offers fit modes
            // (contain/cover/… via setLayout) — constancy comes from the
            // matched aspects, not from a player flag.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pageAspect = _pageWidth / _pageHeight;
                  var w = constraints.maxWidth;
                  var h = w / pageAspect;
                  if (h > constraints.maxHeight) {
                    h = constraints.maxHeight;
                    w = h * pageAspect;
                  }
                  return Center(
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.deepPurple.shade100),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _busy
                        ? const Center(child: CircularProgressIndicator())
                        : _lottiePath == null
                            ? const Center(
                                child: Icon(
                                  Icons.music_note,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              )
                            : ScoreViewer(
                                key: _viewerKey,
                                lottiePath: _lottiePath!,
                                // Page aspect matches this box by
                                // construction, so contain fills it exactly.
                                fit: BoxFit.contain,
                                speed: _velocidade,
                                onControllerReady: (c) => _controller = c,
                                onReady: _onScoreViewerReady,
                                onError: (e) => setState(
                                  () => _status = 'erro ao carregar ✗',
                                ),
                                onPlay: () =>
                                    setState(() => _status = 'tocando ▶'),
                                onPause: () =>
                                    setState(() => _status = 'pausada ⏸'),
                                onStop: () =>
                                    setState(() => _status = 'parada ⏹'),
                                onComplete: () =>
                                    setState(() => _status = 'concluída ✓'),
                              ),
                      ),
                    ),
                  );
                },
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
                  onPressed: _pageCount > 1 && !_busy
                      ? () => _goToPage(_currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton.filledTonal(
                  tooltip: 'Próxima página',
                  onPressed: _pageCount > 1 && !_busy
                      ? () => _goToPage(_currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                FilledButton.icon(
                  onPressed: () => _controller?.play(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _controller?.pause(),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _controller?.stop(),
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                const SizedBox(width: 8),
                const Text('Velocidade: '),
                DropdownButton<double>(
                  value: _velocidade,
                  items: const [0.5, 1.0, 1.5, 2.0]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text('${v}x'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _velocidade = v);
                    await _controller?.setSpeed(v);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
