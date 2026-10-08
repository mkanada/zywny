// Tutorial de primeiro uso: um passeio que escurece a tela, recorta o botão
// de cada passo e explica o que ele faz.
//
// O motor não conhece tela nenhuma: cada passo traz um texto e as
// `GlobalKey`s dos widgets a destacar (a tela as põe nos botões). Passo sem
// alvo é um cartão no meio da tela (boas-vindas, despedida). Passo cujo alvo
// não está na tela (por exemplo, o "Continuar" numa biblioteca vazia) é
// pulado, em vez de apontar para o nada.
//
// O passeio é uma rota por cima das outras (`showGeneralDialog`), então o
// "voltar" do aparelho e a tecla Esc o encerram, e o que está embaixo
// continua montado e medível.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/theme.dart';

/// Um passo do passeio.
@immutable
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    this.targets = const [],
  });

  final String title;
  final String body;

  /// O que destacar: o recorte cobre a caixa que envolve todos os alvos que
  /// estiverem na tela. Vazio: cartão centralizado, sem recorte.
  final List<GlobalKey> targets;

  /// Há algo a destacar (ou o passo nem pede alvo).
  bool get available => targets.isEmpty || targets.any(_isMounted);
}

/// Como o passeio terminou.
enum TourEnd { finished, skipped }

bool _isMounted(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  return box is RenderBox && box.attached && box.hasSize;
}

/// Mostra o passeio e devolve como terminou, ou `null` se não havia nada
/// a mostrar (nenhum passo com alvo na tela).
///
/// Quais passos têm alvo na tela é conferido a cada passo, e não só aqui: um
/// botão que monta um instante depois do começo (o chip da trilha) entra no
/// passeio quando chega a vez dele.
Future<TourEnd?> showTour(BuildContext context, List<TourStep> steps) async {
  if (!steps.any((step) => step.targets.isNotEmpty && step.available)) {
    return null;
  }
  final end = await showGeneralDialog<TourEnd>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Tutorial',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, _, _) => TourOverlay(steps: steps),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  // Fechar pelo "voltar" do aparelho devolve `null`: é pular.
  return end ?? TourEnd.skipped;
}

/// A película, o recorte e o cartão. Público para os testes.
class TourOverlay extends StatefulWidget {
  const TourOverlay({
    super.key,
    required this.steps,
    this.remeasureEvery = const Duration(milliseconds: 250),
  });

  final List<TourStep> steps;

  /// A tela de baixo pode se mexer (a partitura termina de carregar, a lista
  /// rola): de tempos em tempos o recorte confere onde o alvo está.
  final Duration remeasureEvery;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> with WidgetsBindingObserver {
  late int _index = _neighbourFrom(-1, 1);
  Rect? _hole;
  Timer? _timer;

  TourStep get _step => widget.steps[_index];
  bool get _last => _lastAvailableAfter(_index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.remeasureEvery, (_) => _measure());
    _enter();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _measureAfterFrame();

  /// Chegou a um passo: traz o alvo para a vista (rola a lista, se for o
  /// caso) e mede onde ele ficou.
  void _enter() {
    for (final key in _step.targets) {
      final target = key.currentContext;
      if (target != null && target.mounted) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0.3,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ).catchError((Object _) {}),
        );
      }
    }
    _measureAfterFrame();
  }

  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final overlay = context.findRenderObject();
    if (overlay is! RenderBox || !overlay.attached || !overlay.hasSize) return;
    Rect? hole;
    for (final key in _step.targets) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
      hole = hole == null ? rect : hole.expandToInclude(rect);
    }
    if (_sameRect(hole, _hole)) return;
    setState(() => _hole = hole);
  }

  static bool _sameRect(Rect? a, Rect? b) {
    if (a == null || b == null) return a == b;
    return (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.right - b.right).abs() < 0.5 &&
        (a.bottom - b.bottom).abs() < 0.5;
  }

  bool _lastAvailableAfter(int index) {
    for (var i = index + 1; i < widget.steps.length; i++) {
      if (widget.steps[i].available) return false;
    }
    return true;
  }

  /// O próximo passo na direção [delta] que ainda tem alvo na tela, ou `-1`.
  int _neighbour(int delta) => _neighbourFrom(_index, delta);

  int _neighbourFrom(int from, int delta) {
    for (var i = from + delta; i >= 0 && i < widget.steps.length; i += delta) {
      if (widget.steps[i].available) return i;
    }
    return -1;
  }

  void _go(int delta) {
    final next = _neighbour(delta);
    if (next < 0) {
      if (delta > 0) _close(TourEnd.finished);
      return;
    }
    setState(() {
      _index = next;
      _hole = null;
    });
    _enter();
  }

  void _close(TourEnd end) =>
      Navigator.of(context, rootNavigator: true).pop(end);

  /// Quantos passos o aluno vai ver, para o "3 de 9" (os pulados não contam).
  ({int position, int total}) get _progress {
    var total = 0;
    var position = 0;
    for (var i = 0; i < widget.steps.length; i++) {
      if (!widget.steps[i].available) continue;
      total++;
      if (i <= _index) position = total;
    }
    return (position: position, total: total);
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final progress = _progress;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _close(TourEnd.skipped),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // A película come os toques: o aluno só mexe no cartão.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(
                    key: kTourScrimKey,
                    painter: TourScrimPainter(hole: _hole),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: TourCardLayout(
                    hole: _hole,
                    insets: MediaQuery.paddingOf(context),
                  ),
                  child: _TourCard(
                    key: ValueKey(_index),
                    step: step,
                    position: progress.position,
                    total: progress.total,
                    first: _neighbour(-1) < 0,
                    last: _last,
                    onNext: () => _go(1),
                    onBack: () => _go(-1),
                    onSkip: () => _close(TourEnd.skipped),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chave do título do cartão, para os testes lerem em que passo estão.
@visibleForTesting
const kTourTitleKey = ValueKey<String>('tour-title');

/// A chave da película, para os testes lerem o que ela recorta.
@visibleForTesting
const kTourScrimKey = ValueKey<String>('tour-scrim');

/// A folga entre o alvo e a borda do recorte.
const double kTourHolePadding = 6;
const double _kHoleRadius = 12;

/// A película escura com o recorte em volta do alvo. [hole] é o retângulo do
/// alvo (sem a folga); `null` não recorta nada.
class TourScrimPainter extends CustomPainter {
  const TourScrimPainter({required this.hole});

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    RRect? rrect;
    if (hole != null) {
      rrect = RRect.fromRectAndRadius(
        hole.inflate(kTourHolePadding),
        const Radius.circular(_kHoleRadius),
      );
      path
        ..addRRect(rrect)
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = const Color(0xB31C1D22));
    if (rrect != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(TourScrimPainter oldDelegate) => oldDelegate.hole != hole;
}

/// Onde o cartão fica: do lado do alvo que tiver espaço (embaixo, em cima,
/// à direita, à esquerda — nessa ordem), sem passar da área útil. Sem alvo,
/// no meio; se o alvo for grande demais para sobrar lado, o cartão fica por
/// cima dele, na metade da tela que o alvo não ocupa.
class TourCardLayout extends SingleChildLayoutDelegate {
  const TourCardLayout({required this.hole, required this.insets});

  final Rect? hole;
  final EdgeInsets insets;

  static const double maxWidth = 360;
  static const double _margin = 12;
  static const double _gap = 14;

  Rect _safe(Size size) => Rect.fromLTRB(
    insets.left + _margin,
    insets.top + _margin,
    size.width - insets.right - _margin,
    size.height - insets.bottom - _margin,
  );

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final safe = _safe(constraints.biggest);
    return BoxConstraints(
      maxWidth: math.min(maxWidth, safe.width),
      maxHeight: safe.height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final safe = _safe(size);
    final hole = this.hole?.inflate(kTourHolePadding);
    double clampX(double x) =>
        x.clamp(safe.left, math.max(safe.left, safe.right - childSize.width));
    double clampY(double y) =>
        y.clamp(safe.top, math.max(safe.top, safe.bottom - childSize.height));
    if (hole == null) {
      return Offset(
        clampX(safe.center.dx - childSize.width / 2),
        clampY(safe.center.dy - childSize.height / 2),
      );
    }
    final below = hole.bottom + _gap;
    if (below + childSize.height <= safe.bottom) {
      return Offset(clampX(hole.center.dx - childSize.width / 2), below);
    }
    final above = hole.top - _gap - childSize.height;
    if (above >= safe.top) {
      return Offset(clampX(hole.center.dx - childSize.width / 2), above);
    }
    final right = hole.right + _gap;
    if (right + childSize.width <= safe.right) {
      return Offset(right, clampY(hole.center.dy - childSize.height / 2));
    }
    final left = hole.left - _gap - childSize.width;
    if (left >= safe.left) {
      return Offset(left, clampY(hole.center.dy - childSize.height / 2));
    }
    // Nenhum lado cabe (o alvo toma a tela, como a partitura inteira): por
    // cima dele, embaixo — a música começa no alto e a página costuma ter
    // folga no pé. Só vai para o alto se o alvo estiver colado embaixo.
    final onTop = hole.center.dy > safe.top + safe.height * 0.75;
    return Offset(
      clampX(safe.center.dx - childSize.width / 2),
      onTop ? safe.top : safe.bottom - childSize.height,
    );
  }

  @override
  bool shouldRelayout(TourCardLayout oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.insets != insets;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.position,
    required this.total,
    required this.first,
    required this.last,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final TourStep step;
  final int position;
  final int total;
  final bool first;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: kSurface,
        elevation: 10,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (total > 1)
                        Text(
                          '$position de $total',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: kInkCaption,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        step.title,
                        key: kTourTitleKey,
                        style: serifDisplay(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: kInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!last)
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(foregroundColor: kInkCaption),
                      child: const Text('Pular'),
                    ),
                  // Em fonte grande os botões não cabem lado a lado: o
                  // `Wrap` passa o que sobra para a linha de baixo.
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        if (!first)
                          TextButton(
                            onPressed: onBack,
                            child: const Text('Voltar'),
                          ),
                        FilledButton(
                          autofocus: true,
                          onPressed: onNext,
                          child: Text(
                            last ? 'Entendi' : (first ? 'Começar' : 'Próximo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
