// R11: o andamento da trilha de estudo — montar a trilha, armar a etapa,
// contar, ouvir, avaliar, avançar, encerrar — e o treino livre, que divide
// com ela o mesmo `PracticeController`. Saiu de `_ScoreHomePageState`
// (achado 5 da revisão): a lógica pura da trilha é o [TrailController]; o
// que mora aqui é a cola entre ela, o player ([PlaybackController]), a
// prática e as marcas de erro na partitura. Os resumos e a conclusão são
// diálogos: a tela os mostra por [TrailRunnerHost].

// Os parâmetros são públicos e os campos, privados (como no R08).
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:score_bridge/score_bridge.dart';

import 'package:zywny_audio/score_audio_scheduler.dart';

import 'package:zywny_library/library_keys.dart' show progressIdFor;
import 'package:zywny_library/library_package.dart' show LibraryTerm;
import 'package:zywny_library/piece.dart';

import 'package:zywny_midi/midi_device_manager.dart';
import 'package:zywny_midi/midi_input_service.dart';

import 'package:zywny_audio/performance_track.dart';

import '../practice/app_hand.dart';
import '../practice/hand.dart';
import '../practice/input_latency.dart';
import '../practice/practice_colors.dart';
import '../practice/practice_controller.dart';
import '../practice/practice_report.dart';
import '../practice/shift_detector.dart';
import '../settings/app_settings.dart';
import '../trail/stage_result.dart' show StagePass, StageResult;
import '../trail/trail_controller.dart';
import '../trail/trail_path.dart';
import '../trail/trail_plan.dart';
import '../trail/trail_progress.dart';
import '../trail/trail_stage.dart' show TrailPhase, TrailStage;
import '../trail/trail_widgets.dart'
    show StageSummaryAction, TrailConclusionAction, trailStripTextFor;
import '../ui/transpose_widgets.dart' show alsoStudiedText;
import 'playback_controller.dart';
import 'score_render_session.dart';
import 'sound_output_controller.dart';

/// O resumo de uma etapa (ou de um bloco de reforço) que a tela mostra:
/// [blockCount] é o número de blocos de reforço que a reprovação abriu.
typedef StageSummaryDialog = Future<StageSummaryAction?> Function({
  required String stageRef,
  required StageResult result,
  required List<int> badLogical,
  required bool isLast,
  int? blockCount,
});

/// O que o runner pede à tela: os diálogos e a volta à biblioteca.
class TrailRunnerHost {
  const TrailRunnerHost({
    required this.stageSummary,
    required this.conclusion,
    required this.backToLibrary,
    required this.practiceReport,
    this.pieceNChanged,
  });

  final StageSummaryDialog stageSummary;

  /// A trilha foi concluída (J07): biblioteca, treino livre ou ficar.
  final Future<TrailConclusionAction?> Function() conclusion;
  final VoidCallback backToLibrary;

  /// O treino livre com tempo acabou com algo avaliado (T03): a pontuação
  /// e o resumo.
  final void Function(PracticeReport report) practiceReport;

  /// O N deste hino mudou ([TrailRunner.setPieceN]): guardar.
  final void Function(int? n)? pieceNChanged;
}

/// A trilha do hino aberto e o treino (da etapa ou livre) em curso.
///
/// Quem cria descarta: [dispose] para o treino e solta a trilha. O store
/// do progresso é de fora (da biblioteca).
class TrailRunner extends ChangeNotifier {
  TrailRunner({
    required TrailProgressStore store,
    required PlaybackController playback,
    required ScoreRenderSession session,
    required SoundOutputController sound,
    required AppSettings settings,
    required MidiDeviceManager devices,
    required MidiInputService midiInput,
    required Piece piece,
    required LibraryTerm term,
    required this.scores,
    required this.ghosts,
    required this.shiftDetector,
    required this.onShift,
    required this.writtenFromReceived,
    required this.host,
    int? pieceN,
    Future<double> Function()? inputLatency,
  }) : _store = store,
       _playback = playback,
       _session = session,
       _sound = sound,
       _settings = settings,
       _devices = devices,
       _midiInput = midiInput,
       _piece = piece,
       _term = term,
       _pieceN = pieceN,
       _inputLatency =
           inputLatency ??
           (() => calibratedInputLatency(devices, sound.output)) {
    _settings.addListener(_onSettingsChanged);
  }

  final TrailProgressStore _store;
  final PlaybackController _playback;
  final ScoreRenderSession _session;
  final SoundOutputController _sound;
  final AppSettings _settings;
  final MidiDeviceManager _devices;
  final MidiInputService _midiInput;
  final Piece _piece;
  final LibraryTerm _term;
  final ScoreController scores;
  final GhostController ghosts;
  final ShiftDetector shiftDetector;
  final void Function(int d) onShift;

  /// A altura escrita para a nota que chegou do teclado (fase Q).
  final int Function(int received) writtenFromReceived;
  final TrailRunnerHost host;
  final Future<double> Function() _inputLatency;

  bool _disposed = false;

  TrailController? _trail;
  String? _unavailable;
  String? _alsoStudied;
  int? _pieceN;
  PracticeController? _practice;
  bool _listening = false;
  Timer? _listenTimer;
  double _inputLatencyMs = 0;

  /// Etapas e andamentos com que o plano da trilha foi montado: mudou nas
  /// configurações, a trilha é remontada.
  List<TrailPhase> _planPhases = const [];
  Set<double> _planSpeeds = const {};

  /// Compassos (ids da cena) com erro na última passagem, marcados na pauta
  /// até o próximo play, a troca de etapa ou a saída (U12).
  Set<String> _errorMeasureIds = const {};
  String? _errorStageId;

  /// Notas erradas do último treino, guardadas para a revisão na partitura
  /// (a mesma vida das marcas de erro: até o próximo treino, a troca de
  /// etapa ou a nova gravura) e se a revisão está aberta.
  List<WrongMark> _wrongMarks = const [];
  bool _reviewing = false;

  /// Id da etapa para a qual a partitura já foi levada (U02).
  String? _armedStageId;

  String? _markedStageId;
  List<String> _markedIds = const [];
  Set<String> _markedSet = const {};

  /// Trilha de estudo (fase J): plano do hino, progresso e etapa
  /// selecionada. `null` sem trilha (caminho com saltos, ou partitura sem
  /// número de hino) — aí a tela fica no treino livre.
  TrailController? get trail => _trail;

  /// Por que não há trilha (explicação no lugar da faixa); `null` com trilha
  /// ou sem partitura.
  String? get unavailable => _unavailable;

  /// "Também estudada: original, 3 de 8 etapas" (Q04/Q08): os outros tons
  /// em que este hino tem trilha. Lido a cada trilha montada.
  String? get alsoStudied => _alsoStudied;

  /// N da trilha deste hino (`null` = o geral).
  int? get pieceN => _pieceN;

  /// A trilha no comando (faixa), e não o treino livre.
  bool get trailMode => _trail != null && !_trail!.freeMode;

  /// O treino em curso (de uma etapa ou livre); `null` fora dele.
  PracticeController? get practice => _practice;

  /// Ouvindo o trecho da etapa (U03).
  bool get listening => _listening;

  /// Latência de entrada+saída calibrada para o teclado/saída correntes.
  double get inputLatencyMs => _inputLatencyMs;

  /// Compassos com erro na última passagem (ids da cena).
  Set<String> get errorMeasureIds => _errorMeasureIds;

  /// As notas erradas do último treino que terminou; vazio se não houve
  /// nenhuma, ou depois de [discardWrongMarks].
  List<WrongMark> get wrongMarks => _wrongMarks;

  /// A revisão está aberta: as notas erradas fixas na partitura.
  bool get reviewing => _reviewing;

  /// Compassos do trecho da etapa selecionada, para marcar na pauta (U02).
  /// Vazio no treino livre, sem trilha e na fase final.
  List<String> markedIds() {
    final trail = _trail;
    final player = _playback.player;
    final stage = trail?.selected;
    if (trail == null || trail.freeMode || player == null || stage == null) {
      return const [];
    }
    if (_markedStageId != stage.id) {
      _markedStageId = stage.id;
      _markedIds = trailStageMeasureIds(trail.path, stage, player.measures);
      _markedSet = _markedIds.toSet();
    }
    return _markedIds;
  }

  /// [id] é de um compasso do trecho da etapa ([markedIds]).
  bool isMarked(String id) => markedIds().isNotEmpty && _markedSet.contains(id);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// As configurações mudaram: a trilha é remontada se o corte ou as etapas
  /// mudaram, e as cores do treino seguem as novas.
  void _onSettingsChanged() {
    // O N geral mudou e o hino usa o padrão: o corte muda junto (a trilha
    // antiga cai ao abrir, em [setup]).
    final trail = _trail;
    if (trail != null && !trail.running) {
      final effective = effectiveTrailMeasures(
        general: _settings.trailMeasures,
        piece: _pieceN,
      );
      if (effective != trail.plan.n ||
          !listEquals(_planPhases, _settings.trailPlanPhases) ||
          !setEquals(_planSpeeds, _settings.trailSpeeds)) {
        unawaited(setup());
      }
    }
    // No treino o player destaca na cor de "esperado agora"; a cor da
    // reprodução volta em [endPractice].
    _playback.player?.highlightColor = _practice == null
        ? _settings.highlightColor
        : _settings.practicePendingColor;
    _practice
      ?..correctColor = _settings.highlightColor
      ..wrongColor = _settings.practiceWrongColor
      ..pendingColor = _settings.practicePendingColor;
  }

  /// Uma gravura nova: o treino da anterior acaba, o player é trocado e a
  /// trilha é montada de novo.
  void attachDocument(VsbDocument document, PerformanceTrack track) {
    _practice?.dispose();
    _practice = null;
    _trail?.setRunning(false);
    _playback.attach(document, track);
    unawaited(setup());
  }

  /// Monta a trilha depois de cada gravura: caminho sem repetições (J01),
  /// plano de etapas (J03) e progresso do hino. Sem plano (saltos) ou sem
  /// número de hino, explica e fica no livre.
  Future<void> setup() async {
    final document = _session.document;
    final track = _session.track;
    final player = _playback.player;
    _trail?.removeListener(_onTrailChanged);
    _trail?.dispose();
    _trail = null;
    _unavailable = null;
    clearErrorMarks();
    if (_disposed) return;
    if (document == null || track == null || player == null) return;
    // A trilha é do tom que está na tela (fase Q): cada tom tem a sua, e o
    // original guarda a de antes, sob o id da música.
    final pieceId = progressIdFor(_piece.id, _session.renderedTransposition);
    unawaited(_refreshAlsoStudied());
    final n = effectiveTrailMeasures(
      general: _settings.trailMeasures,
      piece: _pieceN,
    );
    final path = TrailPath.fromTimeline(player.timeline);
    _planPhases = _settings.trailPlanPhases;
    _planSpeeds = _settings.trailSpeeds;
    final plan = TrailPlan.build(
      path,
      track,
      n: n,
      includeFinal: true,
      phases: _planPhases,
      speeds: _planSpeeds,
    );
    if (plan.isEmpty) {
      _unavailable =
          'Trilha indisponível ${_term.neste} ${_term.singular} — treino '
          'livre';
      _changed();
      return;
    }
    var progress = await _store.ensureLoaded(pieceId);
    if (_disposed || !identical(_session.document, document)) return;
    // O N efetivo mudou desde o guardado (pelo geral): a trilha antiga é
    // de outro corte e é descartada ao abrir (J06).
    if (progress.total > 0 && progress.n != n) {
      await _store.reset(pieceId);
      progress = TrailProgress(n: n, total: plan.stages.length);
    } else if (progress.total > 0 && progress.total != plan.stages.length) {
      // Outras etapas escolhidas nas configurações: o mesmo progresso, com
      // o total do plano de agora (para a biblioteca).
      progress = TrailProgress(
        n: progress.n,
        total: plan.stages.length,
        records: progress.records,
        resume: progress.resume,
      );
    }
    final trail = TrailController(
      path: path,
      plan: plan,
      progress: progress,
      store: _store,
      pieceId: pieceId,
    );
    trail.addListener(_onTrailChanged);
    _armedStageId = null;
    _trail = trail;
    _changed();
    _armStage();
  }

  /// Lê os outros tons em que este hino tem trilha ([alsoStudied]).
  Future<void> _refreshAlsoStudied() async {
    final tones = await _store.studiedTones(_piece.id);
    if (_disposed) return;
    final text = alsoStudiedText(
      tones,
      current: _session.renderedTransposition,
      fifths: _piece.fifths,
      naming: _settings.noteNaming,
    );
    if (text == _alsoStudied) return;
    _alsoStudied = text;
    _changed();
  }

  /// Reinicia a trilha do hino (gaveta, J06): zera o progresso e remonta.
  Future<void> restartTrail() async {
    if (_trail?.running ?? false) abandonStage();
    final id = _trail?.pieceId;
    if (id != null) await _store.reset(id);
    unawaited(setup());
  }

  /// Troca o N do hino (`null` = padrão geral). Mudar o N efetivo com
  /// progresso pede [confirm] e zera a trilha do hino (J06).
  Future<void> setPieceN(
    int? value, {
    required Future<bool> Function() confirm,
  }) async {
    final oldEffective = effectiveTrailMeasures(
      general: _settings.trailMeasures,
      piece: _pieceN,
    );
    final newEffective = effectiveTrailMeasures(
      general: _settings.trailMeasures,
      piece: value,
    );
    if (newEffective != oldEffective &&
        _trail != null &&
        _trail!.progress.done > 0) {
      if (!await confirm()) return;
      await _store.reset(
        progressIdFor(_piece.id, _session.renderedTransposition),
      );
    }
    if (_disposed) return;
    _pieceN = value;
    host.pieceNChanged?.call(value);
    _changed();
    if (newEffective != oldEffective) unawaited(setup());
  }

  void _onTrailChanged() {
    if (_disposed) return;
    // Trocou de etapa: as marcas de erro eram da anterior.
    if ((_errorMeasureIds.isNotEmpty || _wrongMarks.isNotEmpty) &&
        _trail?.selected?.id != _errorStageId) {
      clearErrorMarks();
    }
    _changed();
    _armStage();
  }

  /// Marca na pauta os compassos (ocorrências) com erro.
  void markErrors(Iterable<int> occurrences) {
    final player = _playback.player;
    if (player == null) return;
    _errorMeasureIds = {
      for (final i in occurrences)
        if (i >= 0 && i < player.measures.length) player.measures[i].id,
    };
    _errorStageId = _trail?.selected?.id;
    _changed();
  }

  void clearErrorMarks() {
    if (_errorMeasureIds.isEmpty && _wrongMarks.isEmpty) return;
    _errorMeasureIds = const {};
    _errorStageId = null;
    _dropWrongMarks();
    _changed();
  }

  /// Guarda as notas erradas de um treino que acabou, para o aluno poder
  /// revê-las na partitura. Sem nenhuma, não oferece nada.
  void _keepWrongMarks(List<WrongMark> marks) {
    _dropWrongMarks();
    if (marks.isEmpty || _disposed) return;
    _wrongMarks = marks;
    _errorStageId = _trail?.selected?.id;
    _changed();
  }

  void _dropWrongMarks() {
    _wrongMarks = const [];
    _reviewing = false;
    ghosts.clearReview();
  }

  /// "Revisar": fixa na partitura as notas erradas do último treino — as
  /// tocadas antes do tempo à esquerda da nota, as depois à direita.
  void startReview() {
    if (_wrongMarks.isEmpty || _practice != null || _disposed) return;
    ghosts.setReview([for (final m in _wrongMarks) m.ghostRequest]);
    _reviewing = true;
    _changed();
  }

  /// Fecha a revisão (ou a oferta dela) e esquece as notas erradas.
  void discardWrongMarks() {
    if (_wrongMarks.isEmpty && !_reviewing) return;
    _dropWrongMarks();
    _changed();
  }

  /// Com a etapa parada, a partitura mostra o primeiro compasso do trecho:
  /// ao abrir o hino e a cada troca de etapa. Não mexe com a etapa rodando,
  /// com treino em curso nem com a música tocando.
  void _armStage() {
    final trail = _trail;
    final player = _playback.player;
    if (trail == null || trail.freeMode || player == null) return;
    final stage = trail.selected;
    if (stage == null || stage.id == _armedStageId) return;
    if (trail.running ||
        _practice != null ||
        _playback.playing ||
        _session.busy) {
      return;
    }
    _armedStageId = stage.id;
    player.seek(Duration(microseconds: (stage.startMs * 1000).round()));
    // Parado: o seek acende a nota da partida na cor de reprodução (verde),
    // como se já tivesse sido tocada. Só a etapa em curso destaca notas.
    scores.clearHighlights();
    _playback.scheduler?.seek(stage.startMs);
  }

  /// Lê a latência calibrada do teclado/saída de agora.
  Future<void> loadInputLatency() async {
    final ms = await _inputLatency();
    if (_disposed) return;
    _inputLatencyMs = ms;
    _changed();
  }

  /// A calibração acabou de medir [ms].
  void setInputLatency(double ms) {
    _inputLatencyMs = ms;
    _changed();
  }

  /// Um treino novo: o agendador sobre o motor (que abre se preciso),
  /// `null` se não houver como.
  Future<ScoreAudioScheduler?> _ensureScheduler() async {
    final engine = await _sound.ensureEngine();
    if (engine == null || _disposed) return null;
    if (_playback.scheduler == null || !_sound.soundOn) {
      _playback.attachAudio(engine);
    }
    return _playback.scheduler;
  }

  /// Começa (ou para, se já está rodando) a etapa selecionada da trilha. A
  /// etapa manda nos controles enquanto roda — modo, mão, andamento,
  /// intervalo, contagem e metrônomo nas etapas com tempo — sem gravar nada:
  /// ao sair valem de novo os valores do aluno.
  Future<void> startStage() async {
    final trail = _trail;
    final track = _session.track;
    final player = _playback.player;
    if (trail == null || track == null || player == null) return;
    if (trail.running) {
      abandonStage();
      return;
    }
    final stage = trail.selected;
    if (stage == null) return;
    // Sem teclado quem chama é o ouvir ([listenStage]).
    if (_devices.connected.value == null) return;
    clearErrorMarks();
    stopListening();
    final scheduler = await _ensureScheduler();
    if (scheduler == null || _disposed) return;
    // O andamento da etapa vale só nela (sem gravar no hino).
    if ((stage.speed ?? _playback.speed) != scheduler.speed) {
      scheduler.setSpeed(stage.speed ?? _playback.speed);
    }
    scores.clearAll();
    // O instante de partida já acende na cor de "esperada" (e a mão do app
    // em cinza), não na da reprodução (U08).
    _paintForPractice(player, track, stage.phase.hand, stage.phase.mode);
    player.seek(Duration(microseconds: (stage.startMs * 1000).round()));
    await loadInputLatency();
    if (_disposed) return;
    final timed = stage.speed != null;
    final gaps = trailStageGaps(trail.path, stage);
    shiftDetector.rearm();
    final practice = PracticeController(
      midiInput: _midiInput,
      track: track,
      scheduler: scheduler,
      controller: scores,
      hand: stage.phase.hand,
      ghosts: ghosts,
      inputLatencyMs: _inputLatencyMs,
      writtenFromReceived: writtenFromReceived,
      shiftDetector: shiftDetector,
      onShift: onShift,
      mode: stage.phase.mode,
      measureIndexAt: player.timeline.measureIndexAt,
      passOf: (i) => player.measures[i].pass,
      range: (startMs: stage.startMs, endMs: stage.endMs),
      rangeJumps: gaps,
      // No modo espera o aviso chega de dentro da notificação do passo
      // (`WaitModeSession.current`), e encerrar a etapa descarta esse mesmo
      // notificador: descartá-lo ali estoura (asserção no debug, RangeError
      // fora dele). O encerramento espera a notificação acabar.
      onRangeDone: () => scheduleMicrotask(() {
        final current = _practice;
        if (current != null) _onStageDone(current, stage);
      }),
      onRangeJump: (ms) =>
          player.seek(Duration(microseconds: (ms * 1000).round())),
      onWaitTarget: (ms) => player.waitTarget = ms,
      correctColor: _settings.highlightColor,
      wrongColor: _settings.practiceWrongColor,
      pendingColor: _settings.practicePendingColor,
      rhythmToleranceMs: _settings.rhythmToleranceMs,
    );
    if (timed) scheduler.metronomeOn = true;
    practice.start(countIn: timed);
    _playback.playPlayerAfterCount(stage.startMs);
    // No treino, o "esperado agora" acende na cor própria, como no modo
    // livre.
    player.highlightColor = _settings.practicePendingColor;
    trail.setRunning(true);
    trail.clearResult();
    _sound.markSoundOn();
    _practice = practice;
    _changed();
    _playback.setPlaying(true);
  }

  /// Ouvir o trecho da etapa (U03): as duas mãos, com som, no andamento da
  /// etapa (100% no modo espera), sem avaliar nada nem tocar no progresso.
  /// Para sozinho no fim e volta ao início do trecho.
  Future<void> listenStage() async {
    final trail = _trail;
    final player = _playback.player;
    if (trail == null || _session.track == null || player == null) return;
    if (_listening) {
      stopListening();
      return;
    }
    final stage = trail.selected;
    if (stage == null) return;
    if (trail.running) abandonStage();
    clearErrorMarks();
    final scheduler = await _ensureScheduler();
    if (scheduler == null || _disposed || _listening) return;
    _playback.cancelSilentCountIn();
    scores.clearAll();
    scheduler.setStaves(null);
    scheduler.setSpeed(stage.speed ?? 1.0);
    scheduler.metronomeOn = false;
    scheduler.setStopAt(stage.endMs - kRangeBoundaryToleranceMs);
    scheduler.setJumps(trailStageGaps(trail.path, stage));
    scheduler.onJump = (ms) =>
        player.seek(Duration(microseconds: (ms * 1000).round()));
    player.seek(Duration(microseconds: (stage.startMs * 1000).round()));
    player.play();
    scheduler.play(stage.startMs);
    _listenTimer?.cancel();
    _listenTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (player.position.inMicroseconds / 1000 >= stage.endMs) {
        stopListening();
      }
    });
    _sound.markSoundOn();
    _listening = true;
    _changed();
    _playback.setPlaying(true);
  }

  /// Fecha o ouvir: devolve ao agendador o que era do aluno e volta ao
  /// início do trecho. Sem efeito se não está ouvindo.
  void stopListening() {
    if (!_listening) return;
    _listenTimer?.cancel();
    _listenTimer = null;
    _listening = false;
    final scheduler = _playback.scheduler;
    if (scheduler != null) {
      scheduler.clearStopAt();
      scheduler.clearJumps();
      scheduler.onJump = null;
      scheduler.setSpeed(_playback.speed);
      scheduler.metronomeOn = _settings.metronomeOn;
      scheduler.pause();
    }
    _playback.player?.pause();
    scores.releaseAll();
    final start = _trail?.selected?.startMs;
    if (start != null) {
      _playback.player?.seek(Duration(microseconds: (start * 1000).round()));
      scheduler?.seek(start);
    }
    if (!_disposed) _playback.setPlaying(false);
  }

  /// O intervalo terminou por conta própria: grava, limpa e mostra o resumo
  /// da etapa (ou do bloco de reforço). Parar no meio não passa por aqui
  /// (abandono, sem registro).
  void _onStageDone(PracticeController practice, TrailStage stage) {
    if (_disposed || !identical(_practice, practice)) return;
    final trail = _trail;
    final result = practice.stageResult;
    final wrongMarks = practice.wrongMarks;
    _endRun();
    if (trail == null || result == null || _disposed) return;
    final blockIndex = trail.blockIndexOf(stage);
    unawaited(() async {
      if (blockIndex != null) {
        await _onBlockDone(trail, blockIndex, stage, result, wrongMarks);
        return;
      }
      await trail.recordDone(result);
      if (_disposed) return;
      markErrors(result.badMeasures);
      _keepWrongMarks(wrongMarks);
      // Aprovou a final.100: concluiu a trilha (tela própria, J07).
      if (result.passed && stage.id == 'final.100') {
        final action = await host.conclusion();
        if (_disposed) return;
        switch (action) {
          case TrailConclusionAction.library:
            host.backToLibrary();
          case TrailConclusionAction.free:
            trail.setFreeMode(true);
          case null:
            break;
        }
        return;
      }
      // Reprovou a final com reforço útil: treinar os blocos em vez de
      // tentar de novo.
      int? blocks;
      if (!result.passed &&
          stage.segment == null &&
          trail.startReinforcement(result)) {
        blocks = trail.blockViews.length;
      }
      final action = await host.stageSummary(
        stageRef: trailStripTextFor(
          trail.plan.segmentCount,
          stage.segment,
          stage.label,
        ),
        result: result,
        badLogical: _badLogical(trail, result),
        isLast: trail.progress.current(trail.plan) == null,
        blockCount: blocks,
      );
      if (_disposed) return;
      switch (action) {
        case StageSummaryAction.next:
          trail.next();
        case StageSummaryAction.retry:
          trail.repeat(stage);
          unawaited(startStage());
        case StageSummaryAction.skip:
          await trail.skipSelected();
          trail.next();
        case StageSummaryAction.train:
          trail.next();
        case null:
          break;
      }
    }());
  }

  /// Resultado de um bloco de reforço: guarda (sem tocar no plano) e mostra
  /// o resumo do bloco.
  Future<void> _onBlockDone(
    TrailController trail,
    int blockIndex,
    TrailStage stage,
    StageResult result,
    List<WrongMark> wrongMarks,
  ) async {
    trail.recordBlockDone(blockIndex, result);
    if (_disposed) return;
    markErrors(result.badMeasures);
    _keepWrongMarks(wrongMarks);
    final action = await host.stageSummary(
      stageRef: stage.label,
      result: result,
      badLogical: _badLogical(trail, result),
      isLast: false,
    );
    if (_disposed) return;
    switch (action) {
      case StageSummaryAction.next:
      case StageSummaryAction.train:
        break;
      case StageSummaryAction.retry:
        trail.repeat(stage);
        unawaited(startStage());
      case StageSummaryAction.skip:
        trail.skipBlock(blockIndex);
        break;
      case null:
        break;
    }
  }

  /// Compassos lógicos com erro para o resumo.
  List<int> _badLogical(TrailController trail, StageResult result) {
    final numbers = <int>{};
    for (final occurrence in result.badMeasures) {
      final logical = trail.path.logicalOf(occurrence);
      if (logical != null) numbers.add(trail.path.logical[logical].number);
    }
    return numbers.toList()..sort();
  }

  /// Para a etapa no meio: sem registro e sem resumo.
  void abandonStage() {
    if (_practice == null || _trail == null) return;
    _endRun();
  }

  /// Solta o que a etapa prendeu e devolve os controles do aluno (andamento
  /// do agendador, metrônomo, cor de destaque).
  void _endRun() {
    final practice = _practice;
    if (practice == null) return;
    _releasePlayer();
    practice.stop();
    practice.dispose();
    _practice = null;
    _playback.scheduler?.setSpeed(_playback.speed);
    _playback.scheduler?.metronomeOn = _settings.metronomeOn;
    _playback.player?.pause();
    _trail?.setRunning(false);
    _changed();
    if (!_disposed) _playback.setPlaying(false);
  }

  /// Devolve a cor de destaque configurada (o treino usa o azul de
  /// "esperado agora") e desiste de soltar o player depois da contagem.
  void _releasePlayer() {
    final player = _playback.player;
    player?.highlightColor = _settings.highlightColor;
    player?.highlightColorOf = null;
    player?.skipHighlight = null;
    _playback.cancelPlayAfterCount();
  }

  /// "Praticar" (T02): o treino livre, com [hand] para o aluno e o app
  /// tocando a outra mão, a partir do loop (se houver). Precisa de som — o
  /// agendador que toca a mão do app é o mesmo do interruptor "som" — e
  /// abre o motor/pede um `.sf2` na primeira vez. Com treino em curso, para.
  Future<void> togglePractice({
    required Hand hand,
    required PracticeMode mode,
  }) async {
    if (_practice != null) {
      stopPractice();
      return;
    }
    final track = _session.track;
    final player = _playback.player;
    if (track == null || player == null) return;
    clearErrorMarks();
    final scheduler = await _ensureScheduler();
    if (scheduler == null) return;

    scores.clearAll();
    final range = _playback.loopRangeMs;
    final fromMs = range?.startMs ?? 0;
    _paintForPractice(player, track, hand, mode);
    player.seek(Duration(microseconds: (fromMs * 1000).round()));
    await loadInputLatency();
    if (_disposed) return;
    shiftDetector.rearm();
    final practice = PracticeController(
      midiInput: _midiInput,
      track: track,
      scheduler: scheduler,
      controller: scores,
      hand: hand,
      ghosts: ghosts,
      inputLatencyMs: _inputLatencyMs,
      writtenFromReceived: writtenFromReceived,
      shiftDetector: shiftDetector,
      onShift: onShift,
      mode: mode,
      measureIndexAt: player.timeline.measureIndexAt,
      passOf: (i) => player.measures[i].pass,
      onLoopRestart: (ms) =>
          player.seek(Duration(microseconds: (ms * 1000).round())),
      onWaitTarget: (ms) => player.waitTarget = ms,
      correctColor: _settings.highlightColor,
      wrongColor: _settings.practiceWrongColor,
      pendingColor: _settings.practicePendingColor,
      rhythmToleranceMs: _settings.rhythmToleranceMs,
    );
    practice.start(fromMs: fromMs, countIn: mode != PracticeMode.wait);
    if (range != null) practice.setLoop(range.startMs, range.endMs);
    _playback.playPlayerAfterCount(fromMs);
    // No treino, o "esperado agora" acende na cor própria (azul por
    // padrão): o vermelho padrão do player confundia pendente com errada.
    player.highlightColor = _settings.practicePendingColor;
    _sound.markSoundOn();
    _practice = practice;
    _changed();
    _playback.setPlaying(true);
  }

  /// Cores do destaque durante o treino (U08), antes do `seek` que acende o
  /// instante de partida: "esperada" para as notas do aluno e cinza para as
  /// da mão que o app toca. No modo espera as notas do aluno são do
  /// `PracticeController` (esperada/certa em camadas): o player não as acende.
  void _paintForPractice(
    ScorePlayer player,
    PerformanceTrack track,
    Hand hand,
    PracticeMode mode,
  ) {
    player.highlightColor = _settings.practicePendingColor;
    final appNotes = appHandNoteIds(track, hand);
    player.highlightColorOf = appNotes.isEmpty
        ? null
        : (id) => appNotes.contains(id) ? kPracticeAppHandColor : null;
    if (mode == PracticeMode.wait) {
      final doc = player.document;
      final studentNotes = {
        for (final id in studentHandNoteIds(track, hand)) ...[
          id,
          doc.sceneIdOf(id) ?? id,
        ],
      };
      player.skipHighlight = studentNotes.contains;
    } else {
      player.skipHighlight = null;
    }
  }

  /// Encerra o treino: solta freio/filtro/destaques, descarta o controlador
  /// e — no tempo real, se algo foi avaliado — marca os compassos com erro
  /// e passa o relatório a [TrailRunnerHost.practiceReport] (T03).
  void endPractice() {
    final practice = _practice;
    if (practice == null) return;
    PracticeReport? report;
    _releasePlayer();
    if (practice.mode != PracticeMode.wait && practice.hasVerdicts) {
      practice.finish();
      report = practice.report;
    }
    final wrongMarks = practice.wrongMarks;
    practice.stop();
    practice.dispose();
    _practice = null;
    _changed();
    if (_disposed) return;
    if (report != null) {
      markErrors([
        for (final m in report.measures)
          if (m.errors + m.imprecise > 0) m.index,
      ]);
    }
    _keepWrongMarks(wrongMarks);
    if (report != null) host.practiceReport(report);
  }

  /// Para o treino em curso e volta ao estado pausado normal —
  /// [PracticeController.stop] já solta o freio/filtro do agendador e os
  /// destaques.
  void stopPractice() {
    if (_practice == null) return;
    endPractice();
    _playback.player?.pause();
    if (!_disposed) _playback.setPlaying(false);
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(_onSettingsChanged);
    _listenTimer?.cancel();
    _practice?.dispose();
    _trail?.removeListener(_onTrailChanged);
    _trail?.dispose();
    super.dispose();
  }
}
