// I09 — tela do exercício (paisagem no celular): barra com título,
// "rodada N", meta e sair; o corpo da rodada com a partitura; no fim, o
// painel de resultado na linguagem do U12 com Outra rodada / Voltar.
//
// Nesta etapa só roda `ScoreRound` (`play-notes`, modo espera — I03); os
// tipos por pergunta (I07) e com tempo (I08) plugam o corpo aqui por um
// `switch` no tipo (ponto de extensão em `_RoundBody`).

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';

import '../../audio/audio_playback_clock.dart';
import '../../audio/engine_opener.dart';
import '../exercise/exercise_kind.dart';
import '../exercise/exercise_round.dart';
import '../exercise/pass_check.dart';
import '../exercise/score_round_runner.dart';
import '../../midi/midi_device_manager.dart';
import '../../midi/midi_device_picker.dart';
import '../../practice/app_hand.dart';
import '../../ui/theme.dart';
import 'exercise_card.dart' show exerciseGoal, exerciseNeedsMidi;
import '../format/course_model.dart';
import '../loaded_course.dart';
import 'course_flow.dart';

/// Costura de teste: avisa quando a rodada começa (o aluno simulado toca a
/// partir daqui). `null` no app.
typedef ExerciseRoundHook =
    void Function(ScoreRoundRunner runner, Future<RoundResult?> result);

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({
    super.key,
    required this.loaded,
    required this.lesson,
    required this.spec,
    required this.deps,
    this.rng,
    this.onRound,
  });

  final LoadedCourse loaded;
  final Lesson lesson;
  final ExerciseSpec spec;
  final CourseScreenDeps deps;

  /// Semente das rodadas (o app sorteia de verdade).
  final Random? rng;

  /// Costura de teste (ver `ExerciseRoundHook`).
  final ExerciseRoundHook? onRound;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late final Random _rng = widget.rng ?? Random();
  ScoreRoundRunner? _runner;
  ScorePlayer? _player;
  ScoreViewController? _viewController;
  bool _loading = true;
  String? _error;
  bool _running = false;
  int _roundNumber = 0;
  final List<RoundResult> _history = [];
  RoundResult? _result;
  PassVerdict? _verdict;
  Set<String> _badMeasureIds = const {};
  double? _loadWidthPx;
  bool _startedRound = false;

  static bool get _isPhone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _needsMidi => exerciseNeedsMidi(widget.spec);

  @override
  void initState() {
    super.initState();
    if (_isPhone) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    widget.deps.deviceManager.connected.addListener(_onKeyboardChanged);
    if (!_needsMidi || widget.deps.deviceManager.connected.value != null) {
      _startedRound = true;
    }
  }

  void _onKeyboardChanged() {
    if (!mounted || _startedRound) return;
    if (!_needsMidi || widget.deps.deviceManager.connected.value != null) {
      setState(() => _startedRound = true);
      // A largura pode já ser conhecida (porta de teclado aberta depois da
      // primeira medição): aí a rodada começa sem esperar outro layout.
      final widthPx = _loadWidthPx;
      if (widthPx != null) unawaited(_newRound(widthPx));
    }
  }

  @override
  void dispose() {
    if (_isPhone) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    widget.deps.deviceManager.connected.removeListener(_onKeyboardChanged);
    _releaseRound();
    super.dispose();
  }

  void _releaseRound() {
    _runner?.dispose();
    _runner = null;
    _player?.dispose();
    _player = null;
    _viewController?.dispose();
    _viewController = null;
  }

  /// Renderiza e começa uma rodada nova ([widthPx] da caixa da partitura).
  Future<void> _newRound(double widthPx) async {
    _releaseRound();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _verdict = null;
      _badMeasureIds = const {};
    });
    try {
      // Ponto de extensão (I07/I08): cada família de tipos monta seu corpo
      // aqui; sem implementação, o `generateRound` lança `UnimplementedError`.
      final round = await generateRound(
        widget.spec,
        widget.loaded.files,
        _rng,
      );
      if (!mounted) return;
      if (round is! ScoreRound) {
        setState(() {
          _loading = false;
          _error = 'Este tipo de exercício chega no I07/I08.';
        });
        return;
      }
      final engine = await widget.deps.ensureEngine();
      if (!mounted) return;
      if (engine == null) {
        setState(() {
          _loading = false;
          _error = 'Não deu para abrir o som.';
        });
        return;
      }
      final settings = widget.deps.settings;
      final runner = ScoreRoundRunner(
        midiInput: widget.deps.midiInput,
        engine: engine,
        renderer: widget.deps.rendererFactory(),
        inputLatencyMs: await calibratedInputLatency(
          widget.deps.deviceManager,
          settings.output,
        ),
        rhythmToleranceMs: settings.rhythmToleranceMs,
        correctColor: settings.highlightColor,
        wrongColor: settings.practiceWrongColor,
        pendingColor: settings.practicePendingColor,
        onWaitTarget: (ms) => _player?.waitTarget = ms,
      );
      await runner.load(round, widthPx: widthPx);
      if (!mounted) {
        runner.dispose();
        return;
      }
      final viewController = ScoreViewController();
      final player = ScorePlayer(
        document: runner.document,
        controller: runner.controller,
        view: viewController,
        highlightColor: settings.practicePendingColor,
        mergeTies: true,
      );
      // No modo espera as notas do aluno são do treino; o player só vira
      // páginas (como `_paintForPractice` em `main.dart`).
      final track = runner.track;
      final studentNotes = {
        for (final id in studentHandNoteIds(track, round.hand)) ...[
          id,
          runner.document.sceneIdOf(id) ?? id,
        ],
      };
      player.skipHighlight = studentNotes.contains;
      player.clock = AudioPlaybackClock(runner.scheduler);
      setState(() {
        _runner = runner;
        _player = player;
        _viewController = viewController;
        _loading = false;
        _running = true;
        _roundNumber++;
      });
      final pending = runner.start();
      widget.onRound?.call(runner, pending);
      final result = await pending;
      if (!mounted) return;
      if (result == null) return; // cancelada (sair no meio): sem registro.
      await _finishRound(result);
    } on UnimplementedError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _finishRound(RoundResult result) async {
    final verdict = PassCheck.evaluate(widget.spec, [..._history, result]);
    await widget.deps.progress.recordAttempt(
      widget.loaded.id,
      widget.spec,
      result,
    );
    if (!mounted) return;
    final badMeasures = _runner?.practice.stageResult?.badMeasures ?? const {};
    final measures = _runner?.timeline.measures ?? const [];
    setState(() {
      _history.add(result);
      _result = result;
      _verdict = verdict;
      _running = false;
      _badMeasureIds = {
        for (final i in badMeasures)
          if (i >= 0 && i < measures.length) measures[i].id,
      };
    });
  }

  void _exit() {
    _runner?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kPanelSideBg,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Sair do exercício',
          onPressed: _exit,
          icon: const Icon(Icons.close),
        ),
        title: Text(
          widget.spec.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: serifDisplay(fontSize: 19),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'rodada $_roundNumber',
                style: const TextStyle(fontSize: 13, color: kInkCaption),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                exerciseGoal(widget.spec),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kInkCaption),
              ),
            ),
          ),
        ],
      ),
      body: _needsMidi &&
              widget.deps.deviceManager.connected.value == null
          ? _KeyboardGate(deviceManager: widget.deps.deviceManager)
          : _RoundBody(
              loading: _loading,
              error: _error,
              runner: _runner,
              player: _player,
              viewController: _viewController,
              badMeasureIds: _badMeasureIds,
              onWidth: (widthPx) {
                if (_loadWidthPx == widthPx || _running || _result != null) {
                  return;
                }
                _loadWidthPx = widthPx;
                if (_startedRound) unawaited(_newRound(widthPx));
              },
              resultPanel: _result != null && _verdict != null
                  ? _ResultPanel(
                      result: _result!,
                      verdict: _verdict!,
                      onRetry: _loadWidthPx == null
                          ? null
                          : () => unawaited(_newRound(_loadWidthPx!)),
                      onBack: _exit,
                    )
                  : null,
            ),
    );
  }
}

/// Sem teclado conectado: "Conecte o teclado" com o botão do U15 — e nada
/// mais. Conectou, a tela segue sozinha (ouvindo `connected`).
class _KeyboardGate extends StatelessWidget {
  const _KeyboardGate({required this.deviceManager});

  final MidiDeviceManager deviceManager;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.piano_off, size: 48, color: kInkCaption),
            const SizedBox(height: 12),
            const Text(
              'Conecte o teclado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Este exercício se toca no teclado MIDI.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: kInkCaption),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => unawaited(
                showMidiDevicePicker(context, deviceManager),
              ),
              icon: const Icon(Icons.piano),
              label: const Text('Conectar teclado'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundBody extends StatelessWidget {
  const _RoundBody({
    required this.loading,
    required this.error,
    required this.runner,
    required this.player,
    required this.viewController,
    required this.badMeasureIds,
    required this.onWidth,
    required this.resultPanel,
  });

  final bool loading;
  final String? error;
  final ScoreRoundRunner? runner;
  final ScorePlayer? player;
  final ScoreViewController? viewController;
  final Set<String> badMeasureIds;
  final ValueChanged<double> onWidth;
  final Widget? resultPanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthPx = constraints.maxWidth.isFinite
            ? constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)
            : 1800.0;
        WidgetsBinding.instance.addPostFrameCallback((_) => onWidth(widthPx));
        final document = runner?.document;
        final Widget score;
        if (loading) {
          score = const Center(child: CircularProgressIndicator());
        } else if (error != null || document == null) {
          score = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error ?? 'Não deu para montar a rodada.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: kInkCaption),
              ),
            ),
          );
        } else {
          score = ScoreView(
            document: document,
            controller: runner!.controller,
            viewController: viewController,
            curtain: player?.curtain,
            overlayIds: badMeasureIds.isEmpty
                ? const []
                : [for (final m in player!.measures) m.id],
            overlayBuilder: (context, id, rect) =>
                badMeasureIds.contains(id)
                ? IgnorePointer(
                    child: ColoredBox(
                      color: kBadColor.withValues(alpha: 0.12),
                    ),
                  )
                : null,
            overlayUniformHeight: true,
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: score),
            if (resultPanel case final panel?)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: panel,
              ),
          ],
        );
      },
    );
  }
}

/// Fim da rodada, na linguagem do U12: "11 de 12 de primeira · 91%", o
/// `reason` do `PassCheck`, e Outra rodada / Voltar à lição (aprovou: o
/// painel diz e o botão principal vira Voltar).
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.verdict,
    required this.onRetry,
    required this.onBack,
  });

  final RoundResult result;
  final PassVerdict verdict;
  final VoidCallback? onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final approved = verdict.exercisePassed;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorderPanel)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${result.percent}%',
            style: serifDisplay(fontSize: 36),
          ),
          Text(
            '${result.hits} de ${result.total} de primeira',
            style: const TextStyle(fontSize: 15, color: kInk),
          ),
          const SizedBox(height: 2),
          Text(
            approved ? 'Exercício aprovado!' : verdict.reason,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: approved ? kGoodColor : kBadColor,
            ),
          ),
          const SizedBox(height: 12),
          if (approved) ...[
            FilledButton(
              onPressed: onBack,
              child: const Text('Voltar à lição'),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Outra rodada'),
            ),
          ] else ...[
            FilledButton(
              onPressed: onRetry,
              child: const Text('Outra rodada'),
            ),
            TextButton(
              onPressed: onBack,
              child: const Text('Voltar à lição'),
            ),
          ],
        ],
      ),
    );
  }
}
