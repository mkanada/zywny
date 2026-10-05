import 'dart:async';
import 'dart:ui' show Color;

import 'package:score_bridge/score_bridge.dart';

import '../../audio/score_audio_scheduler.dart';
import '../../audio/sound_engine.dart';
import '../../midi/midi_input_service.dart';
import '../../music/performance_track.dart';
import '../../practice/practice_colors.dart';
import '../../practice/practice_controller.dart';
import '../../render/score_renderer.dart';
import '../format/course_model.dart';
import '../score/lesson_score.dart';
import 'exercise_round.dart';

/// O executor, sem tela, de uma [ScoreRound]: renderiza a partitura, monta o
/// treino de **passagem única** (a mesma que a trilha usa, J04) sobre a
/// partitura inteira e entrega o [RoundResult] quando o aluno termina.
///
/// Não conhece `BuildContext` nem widgets: recebe o teclado, o som e o
/// renderizador por parâmetro. A tela do exercício (I09) desenha o
/// [document] com o [controller] e escuta o [practice]; este arquivo só
/// conduz a rodada.
///
/// Ciclo de vida: [load] (renderiza e monta tudo) → [start] (devolve o
/// resultado, ou `null` se [cancel]ou) → [dispose].
class ScoreRoundRunner {
  ScoreRoundRunner({
    required this.midiInput,
    required this.engine,
    required this.renderer,
    this.inputLatencyMs = 0,
    this.rhythmToleranceMs = kDefaultRhythmToleranceMs,
    this.correctColor = kPracticeCorrectColor,
    this.wrongColor = kPracticeWrongColor,
    this.pendingColor = kPracticePendingColor,
    this.autoTick = true,
    this.onWaitTarget,
  });

  final MidiInputService midiInput;
  final SoundEngine engine;
  final ScoreRenderer renderer;

  /// Os mesmos campos que o `_startTrailStage` lê de `AppSettings`.
  final double inputLatencyMs;
  final double rhythmToleranceMs;
  final Color correctColor;
  final Color wrongColor;
  final Color pendingColor;

  /// `false` nos testes: quem anda o relógio chama `scheduler.pump()`.
  final bool autoTick;

  /// Modo espera: instante (ms musicais) da nota pendente, ou `null` — a
  /// tela repassa ao `ScorePlayer.waitTarget` para virar a página.
  final void Function(double? onMs)? onWaitTarget;

  ScoreRound? _round;
  VsbDocument? _document;
  ScoreController? _controller;
  PerformanceTrack? _track;
  ScoreTimeline? _timeline;
  ScoreAudioScheduler? _scheduler;
  PracticeController? _practice;
  Completer<RoundResult?>? _done;
  bool _disposed = false;

  ScoreRound get round => _round!;

  /// A partitura renderizada (para a tela desenhar).
  VsbDocument get document => _document!;
  ScoreController get controller => _controller!;
  PerformanceTrack get track => _track!;
  ScoreTimeline get timeline => _timeline!;
  ScoreAudioScheduler get scheduler => _scheduler!;
  PracticeController get practice => _practice!;

  bool get isLoaded => _practice != null;

  /// Renderiza [round] e monta o treino, sem começar a tocar. [widthPx] é a
  /// largura da caixa da partitura em pixels do dispositivo
  /// (`lessonScoreLayout`).
  Future<void> load(ScoreRound round, {double widthPx = 1800}) async {
    _release();
    final layout = lessonScoreLayout(widthPx);
    final rendered = await renderer.render(
      ScoreRenderRequest(
        source: round.bytes,
        fileName: round.fileName,
        pageWidth: layout.pageWidth,
        pageHeight: layout.pageHeight,
        options: layout.options,
      ),
    );
    if (_disposed) return;
    final document = rendered.document;
    final timeline = ScoreTimeline(document);
    if (timeline.measures.isEmpty) {
      throw StateError('a partitura da rodada não tem compassos');
    }
    final track = PerformanceTrack.fromDocument(document);
    final controller = ScoreController(document: document);
    final scheduler = ScoreAudioScheduler(
      engine: engine,
      track: track,
      autoTick: autoTick,
    );
    if (round.mode == PlayMode.realtime) scheduler.setSpeed(round.speed);

    final done = Completer<RoundResult?>();
    final practice = PracticeController(
      midiInput: midiInput,
      track: track,
      scheduler: scheduler,
      controller: controller,
      hand: round.hand,
      inputLatencyMs: inputLatencyMs,
      mode: round.mode == PlayMode.wait
          ? PracticeMode.wait
          : PracticeMode.realtime,
      measureIndexAt: timeline.measureIndexAt,
      passOf: (i) => timeline.measures[i].pass,
      // A partitura inteira, uma vez só.
      range: (
        startMs: timeline.measures.first.startMs.toDouble(),
        endMs: timeline.measures.last.endMs.toDouble(),
      ),
      // No modo espera o aviso chega de dentro da notificação do passo
      // (`WaitModeSession.current`), e encerrar a rodada descarta esse mesmo
      // notificador: o encerramento espera a notificação acabar.
      onRangeDone: () => scheduleMicrotask(_finish),
      onWaitTarget: onWaitTarget,
      correctColor: correctColor,
      wrongColor: wrongColor,
      pendingColor: pendingColor,
      rhythmToleranceMs: rhythmToleranceMs,
    );

    _round = round;
    _document = document;
    _timeline = timeline;
    _track = track;
    _controller = controller;
    _scheduler = scheduler;
    _practice = practice;
    _done = done;
  }

  /// Começa a rodada e devolve o resultado quando o aluno chega ao fim da
  /// partitura; `null` se [cancel] antes disso.
  Future<RoundResult?> start() {
    final practice = _practice;
    final done = _done;
    if (practice == null || done == null) {
      throw StateError('chame load() antes de start()');
    }
    practice.start();
    return done.future;
  }

  void _finish() {
    final done = _done;
    final practice = _practice;
    if (done == null || done.isCompleted || practice == null) return;
    final result = practice.stageResult;
    done.complete(
      RoundResult(
        hits: result?.hits ?? 0,
        total: result?.total ?? 0,
        speed: _round?.speed ?? 1.0,
      ),
    );
  }

  /// Abandona a rodada: nenhum resultado (o [start] termina com `null`).
  void cancel() {
    final done = _done;
    if (done == null || done.isCompleted) return;
    _practice?.stop();
    done.complete(null);
  }

  void _release() {
    cancel();
    _practice?.dispose();
    _scheduler?.dispose();
    _controller?.dispose();
    _practice = null;
    _scheduler = null;
    _controller = null;
    _track = null;
    _timeline = null;
    _document = null;
    _round = null;
    _done = null;
  }

  void dispose() {
    _disposed = true;
    _release();
  }
}
