// I09 — tela do exercício (paisagem no celular): barra com título,
// "rodada N", meta e sair; o corpo da rodada com a partitura; no fim, o
// painel de resultado na linguagem do U12 com Outra rodada / Voltar.
//
// I07 (perguntas) e I08 (com tempo) plugam o corpo por um `switch` no tipo:
// `ScoreRound` (`play-notes`, `rhythm`, `play-score`) usa o treino de
// passagem única; `QuestionRound` (`find-key`, `name-note`, `count-beats`,
// `choice`) usa o `QuestionBody`.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../audio/audio_playback_clock.dart';
import '../../audio/engine_opener.dart';
import '../../audio/score_audio_scheduler.dart';
import '../../practice/count_in_overlay.dart';
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
import 'course_chrome.dart';
import 'course_flow.dart';
import '../../ui/orientation.dart';
import 'question_body.dart';

/// Costura de teste: avisa quando a rodada começa (o aluno simulado toca a
/// partir daqui). `null` no app.
typedef ExerciseRoundHook = void Function(
  ScoreRoundRunner runner,
  Future<RoundResult?> result,
);

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
  QuestionRound? _questionRound;
  bool _loading = true;
  String? _error;
  bool _running = false;
  int _roundNumber = 0;
  final List<RoundResult> _history = [];
  RoundResult? _result;
  PassVerdict? _verdict;

  /// Teclas erradas da rodada que acabou (`null` nas perguntas) e o melhor %
  /// guardado antes dela, para o painel comparar.
  int? _errors;
  int? _previousBest;
  Set<String> _badMeasureIds = const {};
  double? _loadWidthPx;
  bool _startedRound = false;

  /// Andamento escolhido (I08, tempo real): 1,0 = o escrito. Começa no
  /// `pass.speed` (ou 100%).
  double? _chosenSpeed;

  /// Ouvindo antes (I08): o trecho sem avaliar.
  bool _listening = false;
  ScoreAudioScheduler? _listenScheduler;
  Timer? _listenTimer;

  static bool get _isPhone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _needsMidi => exerciseNeedsMidi(widget.spec);

  bool get _isQuestion =>
      widget.spec.type == ExerciseType.findKey ||
      widget.spec.type == ExerciseType.nameNote ||
      widget.spec.type == ExerciseType.countBeats ||
      widget.spec.type == ExerciseType.choice;

  bool get _isRealtimeScore =>
      _runner?.round.mode == PlayMode.realtime ||
      (widget.spec is RhythmSpec) ||
      (widget.spec is PlayScoreSpec &&
          (widget.spec as PlayScoreSpec).mode == PlayMode.realtime);

  /// Tela acesa enquanto o exercício está aberto: as mãos ficam no teclado,
  /// não na tela, e o celular escurecia no meio da rodada. (O hino segura
  /// só enquanto toca; aqui a espera pela nota certa também é exercício.)
  static void _keepScreenOn(bool on) {
    unawaited(
      (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError(
        (Object e) => debugPrint('exercício: tela acesa falhou ($e)'),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _keepScreenOn(true);
    if (_isPhone) {
      unawaited(
        SystemChrome.setPreferredOrientations(kFollowDeviceOrientations),
      );
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    widget.deps.deviceManager.connected.addListener(_onKeyboardChanged);
    if (!_needsMidi || widget.deps.deviceManager.connected.value != null) {
      _startedRound = true;
      // Perguntas não precisam da largura da partitura para sortear.
      if (_isQuestion) unawaited(_newRound(1800));
    }
  }

  void _onKeyboardChanged() {
    if (!mounted || _startedRound) return;
    if (!_needsMidi || widget.deps.deviceManager.connected.value != null) {
      setState(() => _startedRound = true);
      if (_isQuestion) {
        unawaited(_newRound(1800));
        return;
      }
      // A largura pode já ser conhecida (porta de teclado aberta depois da
      // primeira medição): aí a rodada começa sem esperar outro layout.
      final widthPx = _loadWidthPx;
      if (widthPx != null) unawaited(_newRound(widthPx));
    }
  }

  @override
  void dispose() {
    _keepScreenOn(false);
    if (_isPhone) {
      unawaited(
        SystemChrome.setPreferredOrientations(kFollowDeviceOrientations),
      );
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    widget.deps.deviceManager.connected.removeListener(_onKeyboardChanged);
    _releaseRound();
    _stopListening();
    super.dispose();
  }

  void _releaseRound() {
    _runner?.dispose();
    _runner = null;
    _player?.dispose();
    _player = null;
    _viewController?.dispose();
    _viewController = null;
    _questionRound = null;
  }

  void _stopListening() {
    _listenTimer?.cancel();
    _listenTimer = null;
    _listenScheduler?.dispose();
    _listenScheduler = null;
    if (_listening) setState(() => _listening = false);
  }

  /// Renderiza e começa uma rodada nova ([widthPx] da caixa da partitura).
  Future<void> _newRound(double widthPx) async {
    _releaseRound();
    _stopListening();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _verdict = null;
      _badMeasureIds = const {};
      _questionRound = null;
    });
    try {
      final round = await generateRound(widget.spec, widget.loaded.files, _rng);
      if (!mounted) return;
      if (round is QuestionRound) {
        setState(() {
          _questionRound = round;
          _loading = false;
          _running = true;
          _roundNumber++;
        });
        return;
      }
      if (round is! ScoreRound) {
        setState(() {
          _loading = false;
          _error = 'Tipo de exercício desconhecido.';
        });
        return;
      }
      var scoreRound = round;
      // I08: o andamento escolhido vale na rodada com tempo (começa no
      // `pass.speed`). No modo espera não vale.
      if (scoreRound.mode == PlayMode.realtime) {
        _chosenSpeed ??= widget.spec.pass.speed / 100.0;
        final chosen = _chosenSpeed!.clamp(0.25, 2.0);
        if ((chosen - scoreRound.speed).abs() > 1e-9) {
          scoreRound = scoreRound.copyWith(speed: chosen);
        }
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
      // I08: `rhythm` sempre com metrônomo; `play-score` em tempo real, o
      // das configurações; espera, sem.
      final bool metronomeOn = widget.spec is RhythmSpec
          ? true
          : (scoreRound.mode == PlayMode.realtime
                ? settings.metronomeOn
                : false);
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
        metronomeOn: metronomeOn,
      );
      await runner.load(scoreRound, widthPx: widthPx);
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
        for (final id in studentHandNoteIds(track, scoreRound.hand)) ...[
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
    final previousBest = widget
        .deps
        .progress[widget.loaded.id]
        .records[widget.spec.id]
        ?.bestPercent;
    final runner = _runner;
    final errors = runner != null && runner.isLoaded
        ? runner.practice.wrongCount.value
        : null;
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
      _errors = errors;
      _previousBest = previousBest;
      _running = false;
      _badMeasureIds = {
        for (final i in badMeasures)
          if (i >= 0 && i < measures.length) measures[i].id,
      };
    });
  }

  void _exit() {
    _runner?.cancel();
    _stopListening();
    Navigator.of(context).pop();
  }

  /// Recomeça a rodada (o play/stop da I08): abandona sem registrar e sorteia
  /// de novo na mesma largura.
  void _restart() {
    final widthPx = _loadWidthPx;
    if (widthPx == null) return;
    _runner?.cancel();
    _stopListening();
    unawaited(_newRound(widthPx));
  }

  /// Ouve o trecho sem avaliar (I08, o mesmo "ouvir o trecho" do U03):
  /// abandona a rodada atual sem registrar, toca as duas mãos no andamento
  /// escolhido e recomeça uma rodada nova ao parar.
  Future<void> _toggleListen() async {
    if (_listening) {
      _stopListening();
      final widthPx = _loadWidthPx;
      if (widthPx != null && mounted) unawaited(_newRound(widthPx));
      return;
    }
    final runner = _runner;
    if (runner == null) return;
    _runner?.cancel();
    final engine = await widget.deps.ensureEngine();
    if (!mounted || engine == null) return;
    try {
      await engine.start();
    } on Object {
      // Motor falso ou já aberto: segue para o play mesmo assim.
    }
    final listen = ScoreAudioScheduler(
      engine: engine,
      track: runner.track,
      autoTick: true,
    );
    final speed = runner.round.mode == PlayMode.realtime
        ? (_chosenSpeed ?? runner.round.speed)
        : 1.0;
    listen.setSpeed(speed);
    final range = exerciseRange(runner.timeline, runner.round.measures).range;
    setState(() {
      _listenScheduler = listen;
      _listening = true;
      _running = false;
    });
    listen.play(range.startMs);
    final ms = ((range.endMs - range.startMs) / speed).ceil() + 500;
    _listenTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      _stopListening();
      final widthPx = _loadWidthPx;
      if (widthPx != null) unawaited(_newRound(widthPx));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kPanelSideBg,
        surfaceTintColor: Colors.transparent,
        // Deitado, o cabeçalho fica baixo: a partitura precisa da altura.
        toolbarHeight: courseToolbarHeight(context),
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
      body: CourseTextScale(
        settings: widget.deps.settings,
        child: _needsMidi && widget.deps.deviceManager.connected.value == null
            ? _KeyboardGate(deviceManager: widget.deps.deviceManager)
            : _isQuestion
            ? _questionFlow()
            : _scoreFlow(),
      ),
    );
  }

  Widget _questionFlow() {
    if (_loading && _questionRound == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: kInkCaption),
          ),
        ),
      );
    }
    if (_result != null && _verdict != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _ResultPanel(
            result: _result!,
            verdict: _verdict!,
            errors: _errors,
            previousBest: _previousBest,
            onRetry: () => unawaited(_newRound(1800)),
            onBack: _exit,
          ),
        ),
      );
    }
    final round = _questionRound;
    if (round == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return QuestionBody(
      key: ValueKey('q$_roundNumber'),
      spec: widget.spec,
      round: round,
      files: widget.loaded.files,
      settings: widget.deps.settings,
      midiInput: widget.deps.midiInput,
      rendererFactory: widget.deps.rendererFactory,
      onDone: (result) => unawaited(_finishRound(result)),
    );
  }

  Widget _scoreFlow() {
    final showControls =
        _runner != null && _result == null && !_loading && _error == null;
    final realtime = _isRealtimeScore;
    return Column(
      children: [
        if (showControls && (realtime || true))
          _ScoreControls(
            realtime: realtime,
            speed: _chosenSpeed ?? widget.spec.pass.speed / 100.0,
            listening: _listening,
            running: _running,
            onSpeed: (value) {
              setState(() => _chosenSpeed = value);
              final widthPx = _loadWidthPx;
              if (widthPx != null) unawaited(_newRound(widthPx));
            },
            onRestart: _loadWidthPx == null ? null : _restart,
            onListen: _toggleListen,
          ),
        Expanded(
          child: _RoundBody(
            loading: _loading,
            error: _error,
            runner: _runner,
            player: _player,
            viewController: _viewController,
            badMeasureIds: _badMeasureIds,
            scheduler: _runner?.scheduler,
            phone: _isPhone,
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
                    errors: _errors,
                    previousBest: _previousBest,
                    onRetry: _loadWidthPx == null
                        ? null
                        : () => unawaited(_newRound(_loadWidthPx!)),
                    onBack: _exit,
                  )
                : null,
          ),
        ),
      ],
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
              onPressed: () =>
                  unawaited(showMidiDevicePicker(context, deviceManager)),
              icon: const Icon(Icons.piano),
              label: const Text('Conectar teclado'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreControls extends StatelessWidget {
  const _ScoreControls({
    required this.realtime,
    required this.speed,
    required this.listening,
    required this.running,
    required this.onSpeed,
    required this.onRestart,
    required this.onListen,
  });

  final bool realtime;
  final double speed;
  final bool listening;
  final bool running;
  final ValueChanged<double> onSpeed;
  final VoidCallback? onRestart;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: kPanelSideBg,
        border: Border(bottom: BorderSide(color: kBorderPanel)),
      ),
      child: Row(
        children: [
          if (realtime) ...[
            const Icon(Icons.speed, size: 18, color: kInkCaption),
            Expanded(
              child: Slider(
                value: (speed * 100).clamp(25.0, 200.0),
                min: 25,
                max: 200,
                divisions: 35,
                label: '${(speed * 100).round()}%',
                onChanged: (value) => onSpeed(value / 100.0),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${(speed * 100).round()}%',
                style: const TextStyle(fontSize: 13, color: kInkCaption),
              ),
            ),
          ] else
            const Expanded(
              child: Text(
                'Toque no seu tempo.',
                style: TextStyle(fontSize: 13, color: kInkCaption),
              ),
            ),
          IconButton(
            tooltip: listening ? 'Parar de ouvir' : 'Ouvir antes (sem avaliar)',
            onPressed: onListen,
            icon: Icon(listening ? Icons.stop : Icons.hearing),
          ),
          IconButton(
            tooltip: 'Recomeçar a rodada',
            onPressed: running ? onRestart : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
    this.scheduler,
    this.phone = false,
  });

  final bool loading;
  final String? error;
  final ScoreRoundRunner? runner;
  final ScorePlayer? player;
  final ScoreViewController? viewController;
  final Set<String> badMeasureIds;
  final ValueChanged<double> onWidth;
  final Widget? resultPanel;
  final ScoreAudioScheduler? scheduler;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthPx = constraints.maxWidth.isFinite
            ? lessonScorePaperPx(context, constraints.maxWidth)
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
            ghosts: runner!.ghosts,
            overlayIds: badMeasureIds.isEmpty
                ? const []
                : [for (final m in player!.measures) m.id],
            overlayBuilder: (context, id, rect) => badMeasureIds.contains(id)
                ? IgnorePointer(
                    child: ColoredBox(color: kBadColor.withValues(alpha: 0.12)),
                  )
                : null,
            overlayUniformHeight: true,
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: score),
            // Contagem inicial (I08, U09): número grande na metade direita.
            if (scheduler != null)
              Positioned.fill(
                child: CountInOverlay(
                  active: !loading && error == null,
                  read: () => scheduler?.countInTick,
                  phone: phone,
                ),
              ),
            // Erros da rodada, ao vivo: o modo espera deixa tentar até
            // acertar, e o número é o que se quer ver diminuir.
            if (runner case final r?
                when r.isLoaded &&
                    !loading &&
                    error == null &&
                    resultPanel == null)
              Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: r.practice.wrongCount,
                    builder: (context, n, _) => _ErrorChip(count: n),
                  ),
                ),
              ),
            if (resultPanel case final panel?)
              Positioned(left: 0, right: 0, bottom: 0, child: panel),
          ],
        );
      },
    );
  }
}

/// "2 erros" no canto da partitura durante a rodada.
class _ErrorChip extends StatelessWidget {
  const _ErrorChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final bad = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bad ? kBadColor.withValues(alpha: 0.12) : kChipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count == 1 ? '1 erro' : '$count erros',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: bad ? kBadColor : kInkCaption,
        ),
      ),
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
    this.errors,
    this.previousBest,
  });

  final RoundResult result;
  final PassVerdict verdict;

  /// Teclas erradas na rodada (exercícios no teclado; `null` nas perguntas).
  final int? errors;

  /// O melhor % antes desta rodada (`null`: primeira vez).
  final int? previousBest;
  final VoidCallback? onRetry;
  final VoidCallback onBack;

  /// "2 erros · seu melhor: 83%" — ou "novo recorde" quando passou dele.
  String? _progressLine() {
    final parts = <String>[
      if (errors case final n?)
        switch (n) {
          0 => 'nenhum erro',
          1 => '1 erro',
          _ => '$n erros',
        },
      if (previousBest case final best?)
        result.percent > best
            ? 'novo recorde (antes: $best%)'
            : 'seu melhor: $best%',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

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
          Text('${result.percent}%', style: serifDisplay(fontSize: 36)),
          Text(
            '${result.hits} de ${result.total} de primeira',
            style: const TextStyle(fontSize: 15, color: kInk),
          ),
          if (_progressLine() case final line?)
            Text(
              line,
              style: const TextStyle(fontSize: 14, color: kInkCaption),
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
            TextButton(onPressed: onRetry, child: const Text('Outra rodada')),
          ] else ...[
            FilledButton(onPressed: onRetry, child: const Text('Outra rodada')),
            TextButton(onPressed: onBack, child: const Text('Voltar à lição')),
          ],
        ],
      ),
    );
  }
}
