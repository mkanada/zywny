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

import 'package:zywny_audio/audio_playback_clock.dart';
import 'package:zywny_audio/score_audio_scheduler.dart';

import '../../practice/count_in_overlay.dart';
import '../../practice/input_latency.dart';
import '../../render/score_size_log.dart';
import '../exercise/exercise_round.dart';
import '../exercise/score_round_runner.dart';
import '../score/lesson_score.dart' show kLessonPageHeight;

import 'package:zywny_midi/midi_device_manager.dart';

import '../../midi/midi_device_picker.dart';
import '../../practice/app_hand.dart';
import '../../practice/hand.dart';
import '../../practice/practice_colors.dart' show kPracticeAppHandColor;
import '../../ui/phone_chrome.dart';
import '../../ui/side_panel.dart';
import '../../ui/theme.dart';

import 'package:zywny_course_format/course_model.dart';

import 'course_chrome.dart';
import '../exercise/pass_check.dart' show PassVerdict;
import '../loaded_course.dart';
import 'course_flow.dart';
import 'exercise_source.dart';
import '../../ui/orientation.dart';
import 'question_body.dart';

/// Costura de teste: avisa quando a rodada começa (o aluno simulado toca a
/// partir daqui). `null` no app.
typedef ExerciseRoundHook = void Function(
  ScoreRoundRunner runner,
  Future<RoundResult?> result,
);

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen.source({
    super.key,
    required this.source,
    required this.deps,
    this.rng,
    this.onRound,
  });

  /// Um exercício da lição do curso (`CourseExerciseSource`).
  factory ExerciseScreen.course({
    Key? key,
    required LoadedCourse loaded,
    required ExerciseSpec spec,
    required CourseScreenDeps deps,
    Random? rng,
    ExerciseRoundHook? onRound,
  }) => ExerciseScreen.source(
    key: key,
    source: CourseExerciseSource(
      loaded: loaded,
      spec: spec,
      progress: deps.progress,
    ),
    deps: deps,
    rng: rng,
    onRound: onRound,
  );

  /// De onde vêm as rodadas, o título e a passagem (ver `ExerciseSource`).
  final ExerciseSource source;

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
  double? _loadWidthPx;

  /// Altura da caixa da partitura, na medida de [_loadWidthPx]: a página
  /// não passa dela, e o resto da música vai para as páginas seguintes.
  double? _loadHeightPx;

  /// Conta as rodadas pedidas: só a última vale (ver [_newRound]).
  int _roundToken = 0;

  /// Solta o player quando a contagem inicial acaba.
  Timer? _followTimer;
  bool _startedRound = false;

  /// Andamento escolhido (I08, tempo real): 1,0 = o escrito. Começa no
  /// `pass.speed` (ou 100%).
  double? _chosenSpeed;

  /// Metrônomo da rodada com tempo: ligado por padrão, na rodada inteira (não
  /// só na contagem). O aluno desliga na barra.
  bool _metronomeOn = true;

  /// Gaveta "Opções de estudo" aberta (celular, como no hino).
  bool _optionsOpen = false;

  /// Ouvindo antes (I08): o trecho sem avaliar.
  bool _listening = false;
  ScoreAudioScheduler? _listenScheduler;
  Timer? _listenTimer;

  /// Celular ou tablet (Android/iOS): tela cheia e orientação livre no
  /// exercício.
  static bool get _isPhone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _needsMidi => widget.source.needsMidi;

  /// Uma rodada de perguntas (o treino de leitura tem uma, a de ouvido).
  bool get _isQuestion => widget.source.isQuestion || _questionRound != null;

  bool get _isRealtimeScore =>
      _runner?.round.mode == PlayMode.realtime || widget.source.isRealtime;

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
    _followTimer?.cancel();
    _followTimer = null;
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

  /// Renderiza e começa uma rodada nova ([widthPx] da caixa da partitura). Com
  /// [repeat], refaz a última, igual (ver `ExerciseSource.repeatRound`).
  Future<void> _newRound(double widthPx, {bool repeat = false}) async {
    // Uma rodada pedida por cima de outra que ainda carrega (a caixa mudou
    // de tamanho ao esconder as barras do sistema, ao girar) deixa a antiga
    // velha: ela desiste a cada espera e descarta o que já montou — senão
    // as duas tocavam juntas (metrônomo e acompanhamento dobrados).
    final token = ++_roundToken;
    bool stale() => !mounted || token != _roundToken;
    _releaseRound();
    _stopListening();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _verdict = null;
      _questionRound = null;
    });
    try {
      final round = repeat
          ? await widget.source.repeatRound()
          : await widget.source.nextRound(_rng);
      if (stale()) return;
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
        _chosenSpeed ??= widget.source.startSpeed;
        final chosen = _chosenSpeed!.clamp(0.25, 2.0);
        if ((chosen - scoreRound.speed).abs() > 1e-9) {
          scoreRound = scoreRound.copyWith(speed: chosen);
        }
      }
      final engine = await widget.deps.ensureEngine();
      if (stale()) return;
      if (engine == null) {
        setState(() {
          _loading = false;
          _error = 'Não deu para abrir o som.';
        });
        return;
      }
      final settings = widget.deps.settings;
      // Com tempo real, o metrônomo é o da barra (ligado por padrão); espera,
      // sem.
      final bool metronomeOn =
          scoreRound.mode == PlayMode.realtime && _metronomeOn;
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
      await runner.load(scoreRound, widthPx: widthPx, heightPx: _loadHeightPx);
      if (stale()) {
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
      // Como `_paintForPractice` em `main.dart`: a mão do app em cinza; no
      // modo espera as notas do aluno são do treino e o player só vira
      // páginas.
      final track = runner.track;
      final hand = runner.practice.hand;
      final appNotes = appHandNoteIds(track, hand);
      player.highlightColorOf = appNotes.isEmpty
          ? null
          : (id) => appNotes.contains(id) ? kPracticeAppHandColor : null;
      if (scoreRound.mode == PlayMode.wait) {
        final studentNotes = {
          for (final id in studentHandNoteIds(track, hand)) ...[
            id,
            runner.document.sceneIdOf(id) ?? id,
          ],
        };
        player.skipHighlight = studentNotes.contains;
      }
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
      _follow(
        player,
        runner,
        exerciseRange(runner.timeline, scoreRound.measures).range.startMs,
      );
      widget.onRound?.call(runner, pending);
      final result = await pending;
      if (stale()) return;
      if (result == null) return; // cancelada (sair no meio): sem registro.
      await _finishRound(result);
    } on UnimplementedError catch (e) {
      if (stale()) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    } on Object catch (e) {
      if (stale()) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// O player acompanha a rodada pelo relógio do áudio e vira as páginas
  /// (sem ele a partitura ficava parada na primeira). Com contagem inicial,
  /// nada fica aceso até o primeiro tempo — como `_playPlayerAfterCount` em
  /// `main.dart`.
  void _follow(ScorePlayer player, ScoreRoundRunner runner, double startMs) {
    _followTimer?.cancel();
    _followTimer = null;
    void go() => player
      ..seek(Duration(microseconds: (startMs * 1000).round()))
      ..play();
    final scheduler = runner.scheduler;
    if (!scheduler.isCountingIn) {
      go();
      return;
    }
    player.seek(Duration(microseconds: (startMs * 1000).round()));
    runner.controller.clearHighlights();
    _followTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (scheduler.isCountingIn) return;
      timer.cancel();
      _followTimer = null;
      if (!mounted || !identical(player, _player)) return;
      go();
    });
  }

  Future<void> _finishRound(RoundResult result) async {
    _followTimer?.cancel();
    _followTimer = null;
    _player?.pause();
    _player?.cancelTurn();
    final verdict = widget.source.verdict([..._history, result]);
    final previousBest = widget.source.bestPercent;
    final runner = _runner;
    final errors = runner != null && runner.isLoaded
        ? runner.practice.wrongCount.value
        : null;
    // Lido antes de gravar, para dizer respeito à rodada que acabou.
    final chain = widget.source.chainsNextRound;
    await widget.source.recordRound(result);
    if (!mounted) return;
    _history.add(result);
    if (chain) {
      // A pergunta de ouvido emenda na próxima leitura, sem painel.
      unawaited(_newRound(_loadWidthPx ?? 1800));
      return;
    }
    setState(() {
      _result = result;
      _verdict = verdict;
      _errors = errors;
      _previousBest = previousBest;
      _running = false;
    });
    _showErrorsAtEnd();
  }

  /// Fim da rodada: as notas erradas ficam fixas na partitura, como na
  /// revisão do treino, e a primeira página com erro abre por baixo do painel.
  void _showErrorsAtEnd() {
    final runner = _runner;
    if (runner == null) return;
    runner.showReview();
    final pages = {for (final g in runner.ghosts.review) g.page.index}.toList()
      ..sort();
    if (pages.isNotEmpty) _viewController?.goToPage(pages.first);
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

  /// Liga ou desliga o metrônomo na hora: a rodada e o "ouvir antes" que
  /// estiverem soando mudam junto, sem recomeçar.
  void _toggleMetronome() {
    setState(() => _metronomeOn = !_metronomeOn);
    _runner?.scheduler.metronomeOn = _metronomeOn;
    _listenScheduler?.metronomeOn = _metronomeOn;
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
    // Igual à rodada: o mesmo andamento (já com o `bpm` do exercício e a
    // velocidade escolhida) e o mesmo metrônomo — ouvir sem ele tirava a
    // referência que o aluno vai ter ao tocar.
    final realtime = runner.round.mode == PlayMode.realtime;
    final speed = realtime ? runner.scheduler.speed : 1.0;
    listen.setSpeed(speed);
    listen.beats = runner.scheduler.beats;
    listen.metronomeOn = runner.scheduler.metronomeOn;
    final range = exerciseRange(runner.timeline, runner.round.measures).range;
    setState(() {
      _listenScheduler = listen;
      _listening = true;
      _running = false;
    });
    listen.play(range.startMs);
    // A partitura acompanha o que se ouve (e vira as páginas).
    if (_player case final player?) {
      _followTimer?.cancel();
      _followTimer = null;
      player
        ..clock = AudioPlaybackClock(listen)
        ..skipHighlight = null
        ..seek(Duration(microseconds: (range.startMs * 1000).round()))
        ..play();
    }
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
    final appBar = AppBar(
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
        widget.source.title,
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
              widget.source.goal,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: kInkCaption),
            ),
          ),
        ),
      ],
    );
    final flow = CourseTextScale(
      settings: widget.deps.settings,
      child: _needsMidi && widget.deps.deviceManager.connected.value == null
          ? _KeyboardGate(deviceManager: widget.deps.deviceManager)
          : _isQuestion
          ? _questionFlow()
          : _scoreFlow(),
    );
    if (!_isPhone) {
      return Scaffold(
        backgroundColor: kSurface,
        appBar: appBar,
        // Como no hino: o corpo fica na área segura (o recorte da câmera não
        // corta a partitura). O topo já é do cabeçalho.
        body: SafeArea(child: flow),
      );
    }
    // No celular, a barra lateral da rodada vai de alto a baixo, como no
    // hino; o cabeçalho ocupa só a largura da partitura. Tudo dentro da área
    // segura, longe do recorte da câmera.
    final gate =
        _needsMidi && widget.deps.deviceManager.connected.value == null;
    final railShown =
        !gate && !_isQuestion && _result == null && _error == null;
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  right: railShown ? kPhoneRailWidth : 0,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: courseToolbarHeight(context),
                      child: appBar,
                    ),
                    Expanded(child: flow),
                  ],
                ),
              ),
            ),
            if (railShown)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: kPhoneRailWidth,
                child: _scoreRail(),
              ),
            if (railShown && _optionsOpen) _scoreOptions(),
          ],
        ),
      ),
    );
  }

  Widget _questionFlow() {
    // Sem spec nem arquivos, a origem não tem perguntas (a caixa fica vazia).
    final source = widget.source;
    final spec = source.questionSpec;
    final files = source.questionFiles;
    if (spec == null || files == null) return const SizedBox.shrink();
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
            retryLabel: source.nextRoundLabel,
            onRetry: () => unawaited(_newRound(1800)),
            onRepeat: widget.source.canRepeatRound
                ? () => unawaited(_newRound(1800, repeat: true))
                : null,
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
      spec: spec,
      round: round,
      files: files,
      settings: widget.deps.settings,
      midiInput: widget.deps.midiInput,
      rendererFactory: widget.deps.rendererFactory,
      ensureEngine: widget.deps.ensureEngine,
      onDone: (result) => unawaited(_finishRound(result)),
    );
  }

  Widget _scoreFlow() {
    // A barra aparece já no carregamento (desligada): se surgisse só com a
    // rodada pronta, a caixa da partitura encolheria depois de a página ter
    // sido medida por ela.
    final showControls = _result == null && _error == null;
    final ready = _runner != null && !_loading;
    final realtime = _isRealtimeScore;
    final body = Expanded(
      child: _RoundBody(
        loading: _loading,
        error: _error,
        runner: _runner,
        player: _player,
        viewController: _viewController,
        scheduler: _runner?.scheduler,
        phone: _isPhone,
        sidePanel: courseCompactHeader(context),
        label: widget.source.id,
        onPaper: (widthPx, heightPx) {
          if ((_loadWidthPx == widthPx && _loadHeightPx == heightPx) ||
              _running ||
              _listening ||
              _result != null) {
            return;
          }
          _loadWidthPx = widthPx;
          _loadHeightPx = heightPx;
          if (_startedRound) unawaited(_newRound(widthPx));
        },
        resultPanel: _result != null && _verdict != null
            ? _ResultPanel(
                result: _result!,
                verdict: _verdict!,
                errors: _errors,
                previousBest: _previousBest,
                retryLabel: widget.source.nextRoundLabel,
                onRetry: _loadWidthPx == null
                    ? null
                    : () => unawaited(_newRound(_loadWidthPx!)),
                onRepeat: _loadWidthPx == null || !widget.source.canRepeatRound
                    ? null
                    : () => unawaited(_newRound(_loadWidthPx!, repeat: true)),
                onBack: _exit,
                side: courseCompactHeader(context),
              )
            : null,
      ),
    );
    // No celular, os controles ficam na barra lateral da direita, como nos
    // hinos; nos outros aparelhos, na faixa de cima.
    return Column(
      children: [
        if (showControls && !_isPhone)
          _ScoreControls(
            realtime: realtime,
            speed: _chosenSpeed ?? widget.source.startSpeed,
            metronome: _metronomeOn,
            listening: _listening,
            running: _running,
            playing: _playing,
            onPlayPause: _running ? _togglePause : null,
            onSpeed: ready ? _setSpeed : null,
            onMetronome: ready ? _toggleMetronome : null,
            onRestart: _loadWidthPx == null ? null : _restart,
            onListen: ready ? _toggleListen : null,
          ),
        body,
      ],
    );
  }

  /// Rodada tocando (não pausada): o botão mostra "Pausar".
  bool get _playing => _running && !(_runner?.paused ?? false);

  /// Pausa ou retoma a rodada com tempo real; a partitura para ou segue junto.
  void _togglePause() {
    final runner = _runner;
    if (runner == null || !_running) return;
    if (runner.paused) {
      runner.resume();
      _player?.play();
    } else {
      runner.pause();
      _player?.pause();
    }
    setState(() {});
  }

  /// Andamento escolhido: a rodada recomeça com ele na mesma largura.
  void _setSpeed(double value) {
    setState(() => _chosenSpeed = value);
    final widthPx = _loadWidthPx;
    if (widthPx != null) unawaited(_newRound(widthPx));
  }

  /// A barra lateral da rodada no celular: o mesmo desenho do hino
  /// (`PhoneRail`). O compasso acompanha a partitura.
  Widget _scoreRail() {
    final runner = _runner;
    final player = _player;
    final playing = _playing;
    final speed = _chosenSpeed ?? widget.source.startSpeed;
    Widget rail(int? measure, int? total) => PhoneRail(
      playing: playing,
      onPlayPause: _running ? _togglePause : null,
      measure: measure,
      totalMeasures: total,
      tempoPercent: (speed * 100).round(),
      handLabel: runner?.round.hand.shortLabel ?? '',
      onOptions: () => setState(() => _optionsOpen = true),
      onRestart: _loadWidthPx == null ? null : _restart,
      onListen: runner != null && !_loading ? _toggleListen : null,
      listening: _listening,
    );
    if (player == null) return rail(null, null);
    return ValueListenableBuilder<int>(
      valueListenable: player.currentMeasureIndex,
      builder: (context, index, _) => rail(index + 1, player.measures.length),
    );
  }

  /// A gaveta "Opções de estudo" da rodada, como a do hino: andamento e
  /// metrônomo, o que a faixa de cima mostra no computador.
  Widget _scoreOptions() {
    final realtime = _isRealtimeScore;
    final percent = ((_chosenSpeed ?? widget.source.startSpeed) * 100).round();
    return Positioned.fill(
      child: PhoneSidePanel(
        title: 'Opções de estudo',
        onClose: () => setState(() => _optionsOpen = false),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (realtime) ...[
                Text(
                  'Andamento $percent%',
                  style: const TextStyle(fontSize: 15),
                ),
                Slider(
                  value: percent.clamp(25, 200).toDouble(),
                  min: 25,
                  max: 200,
                  divisions: 35,
                  label: '$percent%',
                  onChanged: (value) => _setSpeed(value / 100),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Metrônomo'),
                  value: _metronomeOn,
                  onChanged: (_) => _toggleMetronome(),
                ),
              ] else
                const Text(
                  'Toque no seu tempo.',
                  style: TextStyle(fontSize: 14, color: kInkCaption),
                ),
            ],
          ),
        ),
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
    required this.metronome,
    required this.listening,
    required this.running,
    required this.playing,
    required this.onPlayPause,
    required this.onSpeed,
    required this.onMetronome,
    required this.onRestart,
    required this.onListen,
  });

  final bool realtime;
  final double speed;
  final bool metronome;
  final bool listening;
  final bool running;
  final bool playing;
  final VoidCallback? onPlayPause;
  final ValueChanged<double>? onSpeed;
  final VoidCallback? onMetronome;
  final VoidCallback? onRestart;
  final VoidCallback? onListen;

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
          IconButton(
            tooltip: playing ? 'Pausar' : 'Tocar',
            onPressed: onPlayPause,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          if (realtime) ...[
            const Icon(Icons.speed, size: 18, color: kInkCaption),
            Expanded(
              child: Slider(
                value: (speed * 100).clamp(25.0, 200.0),
                min: 25,
                max: 200,
                divisions: 35,
                label: '${(speed * 100).round()}%',
                onChanged: onSpeed == null
                    ? null
                    : (value) => onSpeed!(value / 100.0),
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
          if (realtime)
            IconButton(
              tooltip: metronome ? 'Desligar metrônomo' : 'Ligar metrônomo',
              onPressed: onMetronome,
              icon: Icon(metronome ? Icons.av_timer : Icons.timer_off_outlined),
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
    required this.onPaper,
    required this.resultPanel,
    this.label = '',
    this.scheduler,
    this.phone = false,
    this.sidePanel = false,
  });

  final bool loading;
  final String? error;
  final ScoreRoundRunner? runner;
  final ScorePlayer? player;
  final ScoreViewController? viewController;

  /// Largura e altura da caixa em medida de papel (`lessonScorePaperPx`).
  final void Function(double widthPx, double heightPx) onPaper;
  final Widget? resultPanel;
  final ScoreAudioScheduler? scheduler;
  final bool phone;

  /// Celular deitado: o [resultPanel] entra pela direita, sobre a partitura,
  /// que mantém o tamanho (encolher a pauta a redesenhava menor; embaixo, o
  /// painel cobriria a pauta quase toda).
  final bool sidePanel;

  /// Id do exercício, para o log de tamanho (`ScoreSizeLog`).
  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthPx = constraints.maxWidth.isFinite
            ? lessonScorePaperPx(context, constraints.maxWidth)
            : 1800.0;
        final heightPx = constraints.maxHeight.isFinite
            ? lessonScorePaperPx(context, constraints.maxHeight)
            : kLessonPageHeight.toDouble();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => onPaper(widthPx, heightPx),
        );
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
          score = ScoreSizeLog(
            label: 'exercício $label',
            document: document,
            child: ScoreView(
              document: document,
              controller: runner!.controller,
              viewController: viewController,
              curtain: player?.curtain,
              ghosts: runner!.ghosts,
            ),
          );
        }
        final side = sidePanel && resultPanel != null;
        final stack = Stack(
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
            if (resultPanel case final panel? when !side)
              Positioned(left: 0, right: 0, bottom: 0, child: panel),
            // Celular deitado: o resumo entra pela direita sobre a partitura,
            // sem mudar o tamanho dela (como o resumo do hino).
            if (resultPanel case final panel? when side)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: min(constraints.maxWidth * 0.6, kPhoneSidePanelWidth),
                child: Material(
                  color: kSurface,
                  elevation: 8,
                  child: SafeArea(
                    left: false,
                    child: Center(child: SingleChildScrollView(child: panel)),
                  ),
                ),
              ),
          ],
        );
        return stack;
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
    required this.retryLabel,
    this.onRepeat,
    this.errors,
    this.previousBest,
    this.side = false,
  });

  final RoundResult result;
  final PassVerdict verdict;

  /// Celular deitado: o painel fica na lateral, ao lado da partitura, e não
  /// embaixo dela.
  final bool side;

  /// Teclas erradas na rodada (exercícios no teclado; `null` nas perguntas).
  final int? errors;

  /// O melhor % antes desta rodada (`null`: primeira vez).
  final int? previousBest;

  /// O texto do botão que pede a próxima rodada (`nextRoundLabel` da origem).
  final String retryLabel;
  final VoidCallback? onRetry;

  /// Refaz a mesma rodada ("Tocar de novo"); `null` quando a fonte não repete.
  final VoidCallback? onRepeat;
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
      decoration: BoxDecoration(
        color: kSurface,
        border: side
            ? const Border(left: BorderSide(color: kBorderPanel))
            : const Border(top: BorderSide(color: kBorderPanel)),
        borderRadius: side
            ? null
            : const BorderRadius.vertical(top: Radius.circular(16)),
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
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ] else ...[
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
            if (onRepeat != null)
              TextButton(
                onPressed: onRepeat,
                child: const Text('Tocar de novo'),
              ),
            TextButton(onPressed: onBack, child: const Text('Voltar à lição')),
          ],
        ],
      ),
    );
  }
}
