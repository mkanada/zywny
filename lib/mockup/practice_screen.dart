import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'options_panel.dart';
import 'practice_state.dart';
import 'practice_wide.dart';
import 'theme.dart';

/// Tela de estudo, em paisagem — cobre os quatro artboards `Celular*` que
/// não são a biblioteca (`Estudo`, `Grande`, `Painel`, `Treino`): são o
/// mesmo layout em estados diferentes (modo, mão, tamanho, painel
/// aberto/fechado), não telas separadas.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.args,
    this.startWithPanelOpen = false,
  });

  final PracticeArgs args;

  /// Abre a tela já com o painel de opções aberto — usado pela rota
  /// `/painel` (deep link de captura de tela, `lib/main_mockup.dart`) para
  /// reproduzir `CelularPainel.dc.html` diretamente.
  final bool startWithPanelOpen;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late PracticeMode _mode;
  late Hand _hand;
  late int _tempo;
  late int _measure;
  late int _totalMeasures;
  ScoreSize _size = ScoreSize.padrao;
  bool _playing = false;
  bool _panelOpen = false;
  bool _repeatAB = false;
  bool _metronome = true;

  int _correct = 23;
  int _reminders = 3;
  int _mistakes = 1;
  Timer? _liveTicker;

  @override
  void initState() {
    super.initState();
    _mode = widget.args.mode;
    _hand = widget.args.hand;
    _tempo = widget.args.tempoPercent;
    _measure = widget.args.measure;
    _totalMeasures = widget.args.totalMeasures;
    _size = widget.args.size;
    _panelOpen = widget.startWithPanelOpen;
    if (_mode == PracticeMode.ouvir) {
      _correct = 0;
      _reminders = 0;
      _mistakes = 0;
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  bool get _isPracticing => _mode != PracticeMode.ouvir;

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _liveTicker?.cancel();
    if (_playing && _isPracticing) {
      // Só de enfeite: dá vida à tela quando demonstrada no aparelho, sem
      // MIDI real por trás (ver docs/plano — o motor de som/MIDI é a fase
      // K/M, ainda pendente).
      _liveTicker = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted) return;
        setState(() {
          _correct++;
          if (_measure < _totalMeasures) _measure++;
        });
      });
    }
  }

  void _setMode(PracticeMode next) {
    setState(() {
      final enteringPractice =
          _mode == PracticeMode.ouvir && next != PracticeMode.ouvir;
      final leavingPractice =
          _mode != PracticeMode.ouvir && next == PracticeMode.ouvir;
      _mode = next;
      if (enteringPractice) {
        _tempo = 80;
        if (_hand == Hand.ambas) _hand = Hand.direita;
      } else if (leavingPractice) {
        _tempo = 100;
        _hand = Hand.ambas;
        _correct = 0;
        _reminders = 0;
        _mistakes = 0;
      }
    });
  }

  Future<void> _openMeasureJump() async {
    var target = _measure;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: kSurface,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ir para o compasso $target de $_totalMeasures',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: target.toDouble(),
                      min: 1,
                      max: _totalMeasures.toDouble(),
                      divisions: _totalMeasures - 1,
                      activeColor: kAccent,
                      onChanged: (v) =>
                          setSheetState(() => target = v.round()),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, target),
                      child: const Text('Ir'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) setState(() => _measure = result);
  }

  /// "Parar" da barra larga — pausa e volta ao início, diferente de
  /// "Pausar" (retoma de onde estava). O celular não tem botão Parar
  /// próprio (só Play/Pausar), como no artboard.
  void _stop() {
    _liveTicker?.cancel();
    setState(() {
      _playing = false;
      _measure = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= kWidePracticeBreakpoint;
            return Stack(
              children: [
                wide
                    ? _wideLayout()
                    : Row(
                        children: [
                          Expanded(child: _scoreArea()),
                          _sideRail(),
                        ],
                      ),
                if (_panelOpen) _panelOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Layout largo (tablet/desktop) — `Main.dc.html` / `Treino.dc.html` /
  /// `TabletEstudo.dc.html`: barra de topo com título, faixa de status do
  /// treino (só fora do modo Ouvir) e barra de transporte com tudo à
  /// vista, em vez da barra lateral + painel escondido do celular.
  Widget _wideLayout() {
    return Column(
      children: [
        WideTopBar(
          title: widget.args.title,
          composer: widget.args.composer,
          midiConnected: true,
          onBack: () => Navigator.of(context).pop(),
          onSettings: () => setState(() => _panelOpen = true),
        ),
        if (_isPracticing)
          WideStatusBar(
            mode: _mode,
            hand: _hand,
            correct: _correct,
            reminders: _reminders,
            mistakes: _mistakes,
          ),
        Expanded(child: _wideScoreArea()),
        WideTransportBar(
          playing: _playing,
          onPlayPause: _togglePlay,
          onStop: _stop,
          measure: _measure,
          totalMeasures: _totalMeasures,
          onMeasureTap: _openMeasureJump,
          tempoPercent: _tempo,
          onTempoStep: (d) =>
              setState(() => _tempo = (_tempo + d).clamp(25, 150)),
          hand: _hand,
          onHandChanged: (h) => setState(() => _hand = h),
          mode: _mode,
          onModeChanged: _setMode,
          repeatAB: _repeatAB,
          onRepeatABChanged: (v) => setState(() => _repeatAB = v),
          metronome: _metronome,
          onMetronomeChanged: (v) => setState(() => _metronome = v),
        ),
      ],
    );
  }

  Widget _wideScoreArea() {
    final asset = _size == ScoreSize.grande
        ? 'assets/mockup/partitura_grande.png'
        : 'assets/mockup/partitura_padrao.png';
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          left: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: WidePageArrow(
              icon: Icons.chevron_left,
              label: 'Página anterior',
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: WidePageArrow(
              icon: Icons.chevron_right,
              label: 'Próxima página',
            ),
          ),
        ),
      ],
    );
  }

  Widget _scoreArea() {
    final asset = _size == ScoreSize.grande
        ? 'assets/mockup/partitura_grande.png'
        : 'assets/mockup/partitura_padrao.png';
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 4,
          child: IconButton(
            tooltip: 'Voltar à biblioteca',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left, size: 28, color: kInkCaption),
          ),
        ),
        if (_isPracticing)
          Positioned(
            left: 54,
            right: 12,
            top: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusPill(text: '${_mode.statusVerb} · mão ${_hand.shortLabel.toLowerCase()}'),
                _CountersPill(
                  correct: _correct,
                  reminders: _reminders,
                  mistakes: _mistakes,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sideRail() {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: kPanelSideBg,
        border: Border(left: BorderSide(color: kBorderPanel)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filled(
            tooltip: _playing ? 'Pausar' : 'Tocar',
            onPressed: _togglePlay,
            style: IconButton.styleFrom(
              backgroundColor: kAccent,
              minimumSize: const Size(52, 52),
            ),
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          ),
          _RailButton(
            top: '$_measure',
            bottom: 'de $_totalMeasures',
            tooltip: 'Ir para compasso',
            onTap: _openMeasureJump,
          ),
          _RailButton(
            top: '$_tempo%',
            bottom: 'andamento',
            tooltip: 'Andamento',
            onTap: () => setState(() => _panelOpen = true),
          ),
          _RailButton(
            top: _hand.shortLabel,
            bottom: 'mão',
            tooltip: 'Mão',
            onTap: () => setState(() => _panelOpen = true),
          ),
          IconButton(
            tooltip: 'Mais opções',
            onPressed: () => setState(() => _panelOpen = true),
            icon: const Icon(Icons.more_horiz, color: kInkCaption),
          ),
        ],
      ),
    );
  }

  Widget _panelOverlay() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _panelOpen = false),
            child: Container(color: kScrim),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 340,
          child: OptionsPanel(
            mode: _mode,
            onModeChanged: _setMode,
            hand: _hand,
            onHandChanged: (h) => setState(() => _hand = h),
            size: _size,
            onSizeChanged: (s) => setState(() => _size = s),
            tempoPercent: _tempo,
            onTempoChanged: (t) => setState(() => _tempo = t),
            repeatAB: _repeatAB,
            onRepeatABChanged: (v) => setState(() => _repeatAB = v),
            metronome: _metronome,
            onMetronomeChanged: (v) => setState(() => _metronome = v),
            onClose: () => setState(() => _panelOpen = false),
          ),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.top,
    required this.bottom,
    required this.tooltip,
    required this.onTap,
  });

  final String top;
  final String bottom;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                top,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: kInk,
                ),
              ),
              Text(
                bottom,
                style: const TextStyle(fontSize: 10.5, color: kInkCaption),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kAccentSoftBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: kAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kAccentDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountersPill extends StatelessWidget {
  const _CountersPill({
    required this.correct,
    required this.reminders,
    required this.mistakes,
  });

  final int correct;
  final int reminders;
  final int mistakes;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kLibraryCardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: kGoodColor, count: correct),
          const SizedBox(width: 12),
          _Dot(color: kOkColor, count: reminders),
          const SizedBox(width: 12),
          Text(
            '×',
            style: TextStyle(
              color: kBadColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$mistakes',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }
}
