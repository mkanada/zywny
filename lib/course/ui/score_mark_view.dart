// I05 — `zywny-score`: partitura pequena com toque para ouvir.
//
// Renderiza os bytes do I02 com `lessonScoreLayout(largura)`, mostra com o
// `ScoreView` do `score_bridge`, `highlight` pinta as notas daquelas alturas
// (cor de destaque das configurações) e a legenda vai embaixo. Toque = ouvir
// do começo (o sintetizador do app, mesmo caminho do "ouvir o trecho", U03:
// `ScoreAudioScheduler` com o `PerformanceTrack`); tocar de novo para.
// Respeita a saída de som escolhida: quem chama resolve o `SoundEngine`
// (app ou teclado MIDI) a partir de `AppSettings` e passa pronto.

import 'package:flutter/material.dart';
import 'package:score_bridge/score_bridge.dart';

import '../../audio/score_audio_scheduler.dart';
import '../../audio/sound_engine.dart';
import '../../music/performance_track.dart';
import '../../render/score_renderer.dart';
import '../../ui/theme.dart';
import '../format/course_files.dart';
import '../format/course_model.dart';
import '../score/lesson_score.dart';
import 'course_chrome.dart';

/// Partitura pequena de uma marca `zywny-score`.
class ScoreMarkView extends StatefulWidget {
  const ScoreMarkView({
    super.key,
    required this.mark,
    required this.files,
    required this.highlightColor,
    this.engine,
    this.renderer,
    this.widthPx,
  });

  final ScoreMark mark;
  final CourseFiles files;

  /// Cor de destaque das configurações (`AppSettings.highlightColor`).
  final Color highlightColor;

  /// Motor já resolvido para a saída escolhida (`AppSettings.output`); `null`
  /// mostra a partitura muda (o toque não faz nada).
  final SoundEngine? engine;

  /// Para teste: renderizador falso em vez do Verovio real.
  final ScoreRenderer? renderer;

  /// Para teste: largura em pixels do dispositivo (sem ela, a da caixa).
  final double? widthPx;

  @override
  State<ScoreMarkView> createState() => _ScoreMarkViewState();
}

class _ScoreMarkViewState extends State<ScoreMarkView> {
  bool _loading = true;
  String? _error;
  VsbDocument? _document;
  PerformanceTrack? _track;
  ScoreController? _controller;
  ScoreViewController? _viewController;
  ScoreAudioScheduler? _scheduler;
  bool _playing = false;
  double? _lastWidth;

  @override
  void initState() {
    super.initState();
    if (widget.widthPx != null) {
      _lastWidth = widget.widthPx;
      _load(widget.widthPx!);
    }
  }

  @override
  void didUpdateWidget(covariant ScoreMarkView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mark != widget.mark) {
      _releaseSound();
      if (_lastWidth != null) {
        setState(() {
          _loading = true;
          _error = null;
        });
        _load(_lastWidth!);
      }
    }
    if (oldWidget.highlightColor != widget.highlightColor && _track != null) {
      _applyHighlight();
    }
  }

  Future<void> _load(double widthPx) async {
    try {
      final source = await scoreSourceFor(
        widget.mark.source,
        widget.files,
        clef: widget.mark.clef,
        key: widget.mark.key,
        time: widget.mark.time,
      );
      final layout = lessonScoreLayout(widthPx);
      final renderer = widget.renderer ?? createScoreRenderer();
      final rendered = await renderer.render(
        ScoreRenderRequest(
          source: source.bytes,
          fileName: source.fileName,
          pageWidth: layout.pageWidth,
          pageHeight: layout.pageHeight,
          options: layout.options,
        ),
      );
      if (!mounted) return;
      final controller = ScoreController()..attachDocument(rendered.document);
      final track = PerformanceTrack.fromDocument(rendered.document);
      ScoreAudioScheduler? scheduler;
      final engine = widget.engine;
      if (engine != null) {
        scheduler = ScoreAudioScheduler(
          engine: engine,
          track: track,
          autoTick: true,
        );
      }
      if (widthPx != _lastWidth) {
        // Já pediram outra largura: esta renderização ficou velha.
        controller.dispose();
        return;
      }
      _disposeLater();
      setState(() {
        _document = rendered.document;
        _track = track;
        _controller = controller;
        _viewController = ScoreViewController();
        _scheduler = scheduler;
        _loading = false;
        _error = null;
      });
      _applyHighlight();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _applyHighlight() {
    final track = _track;
    final controller = _controller;
    if (track == null || controller == null) return;
    final wanted = {for (final p in widget.mark.highlight) p.midi};
    if (wanted.isEmpty) return;
    final ids = <String>{};
    for (final event in track.events) {
      if (wanted.contains(event.pitch)) {
        ids.add(event.id);
        ids.addAll(event.tied);
      }
    }
    controller.setColors({for (final id in ids) id: widget.highlightColor});
  }

  Future<void> _toggle() async {
    final scheduler = _scheduler;
    final engine = widget.engine;
    if (scheduler == null || engine == null) return;
    if (_playing) {
      scheduler.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await engine.start();
    } on Object {
      // Motor falso ou já aberto: segue para o play mesmo assim.
    }
    // Tocar de novo para: a parada é manual (sem temporizador próprio — um
    // `Future.delayed` aqui travaria o `tap` do teste no relógio falso).
    scheduler.play(0);
    if (mounted) setState(() => _playing = true);
  }

  /// Solta o que a partitura anterior usava depois do quadro em que a nova
  /// entra (o `ScoreView` ainda segura os controladores velhos até lá).
  void _disposeLater() {
    final scheduler = _scheduler;
    final controller = _controller;
    final viewController = _viewController;
    if (scheduler == null && controller == null && viewController == null) {
      return;
    }
    scheduler?.stop();
    _playing = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduler?.dispose();
      controller?.dispose();
      viewController?.dispose();
    });
  }

  void _releaseSound() {
    _scheduler?.dispose();
    _scheduler = null;
    _controller?.dispose();
    _controller = null;
    _viewController?.dispose();
    _viewController = null;
    _document = null;
    _track = null;
    _playing = false;
  }

  @override
  void dispose() {
    _releaseSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final widthPx =
                  widget.widthPx ??
                  lessonScorePaperPx(
                    context,
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 640,
                  );
              if (!_loading && _lastWidth != null && widthPx != _lastWidth) {
                // O "Aa" ou o giro mudou o papel: redesenha, mostrando a
                // anterior até a nova ficar pronta.
                _lastWidth = widthPx;
                _load(widthPx);
              }
              if (_loading && _lastWidth == null) {
                // Espaço reservado com altura estimada, sem pular a rolagem.
                _lastWidth = widthPx;
                _load(widthPx);
                return Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: kChipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              if (_loading) {
                return Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: kChipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              if (_error != null) {
                return _renderError();
              }
              final document = _document;
              final controller = _controller;
              final viewController = _viewController;
              if (document == null ||
                  controller == null ||
                  viewController == null) {
                return _renderError();
              }
              // Altura limitada: a `LessonView` é uma coluna rolável (altura
              // ilimitada) e o `ScoreView` contínuo é uma lista — sem caixa
              // com altura, a lista não monta. A altura sai da largura da
              // caixa e da proporção das páginas gravadas (todas as páginas,
              // sem teto: a rolagem é a da lição).
              final boxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 640.0;
              var total = 0.0;
              for (final page in document.pages) {
                if (page.widthPx > 0) {
                  total += boxWidth * page.heightPx / page.widthPx;
                }
              }
              final height = total < 120.0 ? 120.0 : total;
              // Sem rolagem própria: a lista interna com a mesma direção da
              // coluna da lição roubaria o gesto e confundiria o
              // `ensureVisible` dos testes — a rolagem é só a da lição.
              final score = ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(
                  physics: const NeverScrollableScrollPhysics(),
                ),
                child: SizedBox(
                  height: height,
                  child: ScoreView(
                    // Redesenho (outra largura) = documento novo: estado novo.
                    key: ObjectKey(document),
                    document: document,
                    controller: controller,
                    viewController: viewController,
                    mode: ScorePageMode.continuousScroll,
                  ),
                ),
              );
              return GestureDetector(
                onTap: widget.engine == null ? null : _toggle,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: kBorderSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: score,
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kInk.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _playing ? Icons.stop : Icons.play_arrow,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _playing ? 'parar' : 'ouvir',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.mark.caption != null && widget.mark.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.mark.caption!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kInkCaption),
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderError() {
    final source = widget.mark.source;
    final file = switch (source) {
      AbcSource() => 'abc em linha',
      FileSource() => source.path,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Não consegui desenhar esta partitura ($file, linha ${widget.mark.line}).',
        style: const TextStyle(fontSize: 14, color: kInkCaption),
      ),
    );
  }
}
