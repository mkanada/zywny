import 'dart:async';
import 'dart:ui' show Color;

import 'package:score_bridge/score_bridge.dart';

import '../../audio/metronome.dart';
import '../../audio/score_audio_scheduler.dart';
import '../../audio/sound_engine.dart';
import '../../midi/midi_input_service.dart';
import '../../music/performance_track.dart';
import '../../practice/hand.dart';
import '../../practice/practice_colors.dart';
import '../../practice/practice_controller.dart';
import '../../render/score_renderer.dart';
import '../../trail/trail_path.dart';
import '../format/course_model.dart';
import '../score/lesson_score.dart';
import 'exercise_round.dart';

/// Intervalo de passagem única para [measures] (compassos **escritos**,
/// base 1, inclusivos) em [timeline]: primeira ocorrência de cada um, com
/// os saltos do caminho como vãos (J01/J08). `null` é a partitura toda.
({
  ({double startMs, double endMs}) range,
  List<({double startMs, double endMs})> jumps,
})
exerciseRange(ScoreTimeline timeline, MeasureRange? measures) {
  if (measures == null) {
    return (
      range: (
        startMs: timeline.measures.first.startMs.toDouble(),
        endMs: timeline.measures.last.endMs.toDouble(),
      ),
      jumps: const [],
    );
  }
  final path = TrailPath.fromTimeline(timeline);
  final count = path.measureCount;
  if (measures.from < 1 || measures.to < measures.from || measures.to > count) {
    throw StateError(
      'compassos ${measures.from}-${measures.to} fora da partitura '
      '(a peça tem $count compassos)',
    );
  }
  final first = measures.from - 1;
  final last = measures.to - 1;
  final range = (
    startMs: path.logical[first].startMs,
    endMs: path.logical[last].endMs,
  );
  final jumps = <({double startMs, double endMs})>[];
  for (final jump in path.jumps) {
    if (jump > first && jump <= last) {
      jumps.add((
        startMs: path.logical[jump - 1].endMs,
        endMs: path.logical[jump].startMs,
      ));
    }
  }
  return (range: range, jumps: jumps);
}

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
    this.metronomeOn,
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

  /// Metrônomo da rodada com tempo (`rhythm` sempre ligado; `play-score`
  /// em tempo real, o das configurações). `null`: ligado só com tempo real.
  final bool? metronomeOn;

  /// Modo espera: instante (ms musicais) da nota pendente, ou `null` — a
  /// tela repassa ao `ScorePlayer.waitTarget` para virar a página.
  final void Function(double? onMs)? onWaitTarget;

  /// A nota errada desenhada na pauta, como no treino dos hinos. Fica mais
  /// tempo na tela que lá: no exercício o aluno precisa ver o que tocou,
  /// mesmo soltando a tecla logo.
  final GhostController ghosts = GhostController(
    minVisible: const Duration(milliseconds: 1500),
    fade: const Duration(milliseconds: 300),
  );

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
    final realtime = round.mode == PlayMode.realtime;
    if (realtime) {
      // Contagem e metrônomo precisam das batidas (T04); o `play-score` em
      // tempo real usa o das configurações, o `rhythm` sempre ligado.
      scheduler.beats = metronomeBeats(timeline);
      scheduler.metronomeOn = metronomeOn ?? true;
      // `bpm` do `play-score`: a velocidade 1,0 passa a ser esse `bpm` —
      // converte para a velocidade relativa ao andamento do arquivo
      // (o primeiro `tempo` do timemap; 120 sem ele).
      final override = round.bpm;
      if (override != null) {
        double? fileTempo;
        for (final entry in timeline.entries) {
          if (entry.tempo != null) {
            fileTempo = entry.tempo;
            break;
          }
        }
        final base = fileTempo ?? 120.0;
        scheduler.setSpeed(round.speed * override / base);
      } else {
        scheduler.setSpeed(round.speed);
      }
    } else {
      scheduler.metronomeOn = metronomeOn ?? false;
    }

    final resolved = exerciseRange(timeline, round.measures);
    // Partitura de uma pauta só ignora a mão (`play-score` com `hand`):
    // a pauta é do aluno.
    final Hand hand = track.staves.length <= 1 ? Hand.direita : round.hand;

    final done = Completer<RoundResult?>();
    final practice = PracticeController(
      midiInput: midiInput,
      track: track,
      scheduler: scheduler,
      controller: controller,
      hand: hand,
      ghosts: ghosts,
      inputLatencyMs: inputLatencyMs,
      mode: realtime ? PracticeMode.realtime : PracticeMode.wait,
      measureIndexAt: timeline.measureIndexAt,
      passOf: (i) => timeline.measures[i].pass,
      // Passagem única: a partitura toda ou os compassos do `measures`.
      range: resolved.range,
      rangeJumps: resolved.jumps,
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
  /// partitura; `null` se [cancel] antes disso. Com tempo real, com um
  /// compasso de contagem (como a trilha com tempo).
  Future<RoundResult?> start() {
    final practice = _practice;
    final done = _done;
    if (practice == null || done == null) {
      throw StateError('chame load() antes de start()');
    }
    practice.start(countIn: practice.mode == PracticeMode.realtime);
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
    ghosts.clear();
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
    ghosts.dispose();
  }
}
