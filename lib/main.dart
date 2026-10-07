import 'dart:async';

import 'render/score_size_log.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';

import 'package:zywny_audio/sound_engine.dart';

import 'audio/sound_engine_debug_panel.dart';
import 'course/built_in_course.dart';
import 'render/layout_options.dart';
import 'app/layout_panel.dart';

import 'package:zywny_library/piece.dart';
import 'package:zywny_library/library_package.dart' show LibraryTerm;

import 'app/library_screen.dart';
import 'app/playback_controller.dart';
import 'app/score_render_session.dart';
import 'app/sound_output_controller.dart';
import 'app/trail_runner.dart';

import 'package:zywny_library/library_term_scope.dart';

import 'package:zywny_midi/midi_device_manager.dart';

import 'midi/midi_device_picker.dart';

import 'package:zywny_midi/midi_input_service.dart';
import 'package:zywny_midi/midi_monitor.dart';

import 'midi/midi_monitor_panel.dart';

import 'package:zywny_midi/midi_out_sound_engine.dart';

import 'practice/transpose_check.dart';

import 'package:zywny_music/pitch_frame.dart';

import 'package:zywny_audio/performance_track.dart';

import 'package:zywny_music/tone_choices.dart';

import 'practice/count_in_overlay.dart';
import 'practice/hand.dart';
import 'practice/practice_colors.dart';
import 'practice/practice_controller.dart';
import 'practice/shift_banner.dart';
import 'practice/shift_detector.dart';
import 'practice/practice_report.dart';
import 'practice/practice_tools.dart';
import 'practice/study_mode.dart';
import 'settings/app_settings.dart';
import 'settings/effective_transposition.dart';
import 'app/general_settings_panel.dart';
import 'settings/piece_settings.dart';
import 'app/splash_screen.dart';
import 'trail/stage_result.dart' show kTrailPassAccuracy;
import 'trail/trail_progress.dart';
import 'trail/trail_stage.dart' show kTrailMinMeasures;
import 'trail/trail_widgets.dart';
import 'ui/page_pager.dart';
import 'ui/phone_chrome.dart';
import 'ui/practice_legend.dart';
import 'ui/side_panel.dart';
import 'ui/theme.dart';
import 'ui/transpose_widgets.dart';

import 'package:zywny_diag/diag_log.dart';

import 'render/score_renderer.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await DiagLog.init();
  // Liberation Serif (the `t` runs of the scene, §5.4) ships inside
  // score_bridge and has to be registered before the first paint —
  // otherwise the engine falls back to a system serif without warning.
  await loadScoreFonts();
  runApp(
    MyApp(
      debugMode: args.contains('--debug'),
      splash: true,
      initialDraftPath: _cursoArg(args),
    ),
  );
}

/// `just curso <pasta>` (I12): abre o app direto no rascunho da pasta.
String? _cursoArg(List<String> args) {
  final i = args.indexOf('--curso');
  if (i < 0 || i + 1 >= args.length) return null;
  final path = args[i + 1].trim();
  return path.isEmpty ? null : path;
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.debugMode = false,
    this.splash = false,
    this.loadCatalog,
    this.initialDraftPath,
  });

  final bool debugMode;

  /// Splash de abertura (`lib/app/splash_screen.dart`); os testes ficam sem ela.
  final bool splash;

  /// De onde vêm as músicas da biblioteca; sem isto, a biblioteca instalada
  /// e em uso. Os testes trocam por uma lista própria.
  final Future<PieceCatalog> Function()? loadCatalog;

  /// I12: abre direto no rascunho da pasta (`just curso <pasta>`).
  final String? initialDraftPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zywny',
      theme: buildAppTheme(),
      // A tela inicial é a biblioteca de hinos embutidos; a partitura
      // (ScoreHomePage) abre por cima dela, um hino por vez.
      home: SplashOverlay(
        enabled: splash,
        child: LibraryScreen(
          loadCatalog: loadCatalog,
          loadCourses: loadBuiltInCourses,
          initialDraftPath: initialDraftPath,
          scoreBuilder: (context, opened) => LibraryTermScope(
            term: opened.term,
            numbered: opened.numbered,
            child: ScoreHomePage(debugMode: debugMode, opened: opened),
          ),
        ),
      ),
    );
  }
}

class ScoreHomePage extends StatefulWidget {
  const ScoreHomePage({
    super.key,
    required this.opened,
    this.debugMode = false,
    this.renderer,
  });

  /// Quem grava a partitura. Só os testes passam o seu; o app usa o da
  /// plataforma ([createScoreRenderer]).
  @visibleForTesting
  final ScoreRenderer? renderer;

  /// O hino que a biblioteca abriu, com os recursos que ela compartilha
  /// (configurações, trilha, MIDI): são dela, e é ela quem os descarta. Os
  /// testes passam um feito de fakes (`test/support/score_page_fakes.dart`).
  final OpenedPiece opened;

  /// `--debug` on the command line: asks Verovio to also embed the
  /// effective options and source document inside the rendered `.vsb`
  /// (`vsbDebug`, score_bridge's own debug mode), so a render can be
  /// reproduced from the `.vsb` alone.
  final bool debugMode;

  @override
  State<ScoreHomePage> createState() => _ScoreHomePageState();
}

/// Range of the on-screen zoom. It scales the drawn page only — see
/// [_ScoreHomePageState._view] — so it has no bearing on the engraving.
const double kZoomMin = 0.5;
const double kZoomMax = 8.0;

class _ScoreHomePageState extends State<ScoreHomePage> {
  /// Como a biblioteca chama a música.
  LibraryTerm get _term => widget.opened.term;

  Piece get _piece => widget.opened.piece;

  late final String _scoreName = _piece.number == null
      ? _piece.title
      : '${_piece.number} · ${_piece.title}';

  /// A gravura (R09): render, fila, caixa, layout e tom deste hino. A cada
  /// documento novo chama [_onDocument], que monta o player.
  late final ScoreRenderSession _session;

  /// Configurações gerais (som, MIDI, cores…): as da biblioteca, já lidas
  /// por ela. Ver [_onSettingsChanged].
  late final AppSettings _settings = widget.opened.appSettings;

  /// O que este hino tinha guardado ao abrir (layout, andamento, mão).
  late final PieceSettings _stored = widget.opened.pieceSettings;

  /// Painel "Layout deste hino" e painel "Configurações gerais" — um de
  /// cada vez.
  bool _panelOpen = false;
  bool _generalOpen = false;

  /// Layout de celular (`kPhoneLayoutMaxWidth`): gaveta "Opções de estudo"
  /// aberta (botão ⋯ da barra lateral).
  bool _optionsOpen = false;

  /// On-screen zoom and pan of the drawn page.
  ///
  /// This lives above the score: it transforms the finished drawing and is
  /// never part of the render request, so changing it neither reflows the
  /// piece nor triggers a render. What does change the engraving is the
  /// `unit` option, in the panel.
  final TransformationController _view = TransformationController();
  Size _viewport = Size.zero;

  /// Note highlights. Repaints the page through its own listenable, so
  /// playback never rebuilds this widget.
  final ScoreController _controller = ScoreController();
  final GhostController _ghosts = GhostController();

  /// Page navigation and page-turn animation (sweep bar) of the [ScoreView].
  final ScoreViewController _viewController = ScoreViewController();

  /// Por onde sai o som (R08): os dois motores, a saída em uso, o `.sf2` e
  /// o monitor MIDI. Sobrevive a novas gravuras (só o agendador é
  /// recriado, um por `.vsb`).
  late final SoundOutputController _sound;

  /// Tocar a partitura (R10): player, agendador, contagem, loop, metrônomo
  /// e andamento. Um player por gravura ([_onDocument]).
  late final PlaybackController _playback;

  /// A trilha de estudo (fase J) e o treino em curso (R11): a etapa, o
  /// ouvir, o treino livre e as marcas na pauta.
  late final TrailRunner _runner;

  /// Modo treino (T02): armado pelo usuário, só passa a valer no Play
  /// ("Praticar") quando também há um teclado MIDI conectado — ver
  /// [_canTrain].
  bool _trainingMode = false;
  late Hand _hand = _stored.hand ?? _kDefaultHand;
  static const _kDefaultHand = Hand.direita;

  /// Espera (o tempo para até o aluno tocar), ou tempo real (T03) —
  /// configuração geral.
  PracticeMode get _practiceMode => _settings.practiceMode;
  set _practiceMode(PracticeMode value) => _settings.practiceMode = value;

  /// O progresso das trilhas é o da biblioteca (a linha do hino atualiza ao
  /// voltar sem reabrir nada — J09).
  late final TrailProgressStore _trailStore = widget.opened.trailProgress;

  /// Gaveta da trilha aberta (J06).
  bool _trailDrawerOpen = false;

  /// Program Change (M03) — configuração geral.
  bool get _useScoreInstruments => _settings.useScoreInstruments;

  /// Entrada MIDI (M01): lista/conecta dispositivos e reconecta sozinho ao
  /// último escolhido; converte mensagens em [PlayedNote] para o monitor.
  /// Relógio de carimbo: o motor de áudio se já estiver ligado (mesmo
  /// instante que o áudio usa), senão este `Stopwatch`, que roda desde a
  /// abertura do app.
  final Stopwatch _appClock = Stopwatch()..start();

  ///
  /// O gerenciador de dispositivos é o da biblioteca (o teclado conectado
  /// lá continua conectado aqui).
  late final MidiDeviceManager _midiDeviceManager =
      widget.opened.midiDeviceManager;
  late final MidiInputService _midiInput = FlutterMidiInputService(
    nowSeconds: () =>
        _sound.engine?.nowSeconds ?? _appClock.elapsedMicroseconds / 1e6,
  );
  bool _midiPanelOpen = false;

  /// Appearance, from the general settings — pure paint-time, none of them
  /// reach Verovio or reflow the score.
  double get _haloWidth => _settings.haloWidth;
  Color get _barColor => _settings.barColor;

  // Haste fina: meia cabeça de nota (o padrão do `ScoreView` são duas). O
  // player e a vista precisam do mesmo valor.
  double _barWidthOf(VsbDocument document) {
    if (!identical(document, _barWidthDocument)) {
      _barWidthDocument = document;
      _barWidth = defaultBarWidth(document) / 4;
    }
    return _barWidth;
  }

  VsbDocument? _barWidthDocument;
  double _barWidth = 0;

  bool get _canPlay =>
      (_session.document?.timemap?.isNotEmpty ?? false) && !_session.busy;

  /// O Play vira "Praticar" (T02) só com modo treino armado **e** teclado
  /// MIDI conectado — sem dispositivo não há como o aluno tocar.
  bool get _canTrain =>
      _canPlay && _trainingMode && _midiDeviceManager.connected.value != null;

  @override
  void initState() {
    super.initState();
    _session = ScoreRenderSession(
      renderer: widget.renderer ?? createScoreRenderer(),
      scoreXml: widget.opened.scoreXml,
      piece: _piece,
      settings: _settings,
      stored: _stored,
      name: _scoreName,
      phone: _isPhone,
      debugMode: widget.debugMode,
      onDocument: _onDocument,
    )..addListener(_onSessionChanged);
    _sound = SoundOutputController(
      settings: _settings,
      devices: _midiDeviceManager,
      input: _midiInput,
      monitorPitch: (r, {required midiKeyboard}) =>
          _pitchFrame.engineFromReceived(r, midiKeyboard: midiKeyboard),
      playback: SoundOutputPlayback(
        hasTrack: () => _playback.track != null,
        attach: (engine, {required always}) =>
            _playback.attachSound(engine, always: always),
        detach: () => _playback.detachSound(),
        endPractice: () => _runner.endPractice(),
      ),
      onMessage: _showMessage,
    )..addListener(_onSoundChanged);
    _playback = PlaybackController(
      sound: _sound,
      settings: _settings,
      controller: _controller,
      view: _viewController,
      speed: _stored.speed ?? 1.0,
      barWidthOf: _barWidthOf,
      pitchOf: _enginePitchOf,
      onEnded: () => _runner.endPractice(),
      onLoopChanged: (range) => range == null
          ? _runner.practice?.clearLoop()
          : _runner.practice?.setLoop(range.startMs, range.endMs),
    )..addListener(_onPlaybackChanged);
    _runner = TrailRunner(
      store: _trailStore,
      playback: _playback,
      session: _session,
      sound: _sound,
      settings: _settings,
      devices: _midiDeviceManager,
      midiInput: _midiInput,
      piece: _piece,
      term: _term,
      scores: _controller,
      ghosts: _ghosts,
      shiftDetector: _shiftDetector,
      onShift: _onShiftDetected,
      writtenFromReceived: (r) => _pitchFrame.writtenFromReceived(r),
      pieceN: _stored.trailMeasures,
      host: TrailRunnerHost(
        stageSummary:
            ({
              required stageRef,
              required result,
              required badLogical,
              required isLast,
              blockCount,
            }) async {
              final action = await showStageSummary(
                context,
                stageRef: stageRef,
                result: result,
                badLogical: badLogical,
                isLast: isLast,
                blockCount: blockCount,
                reviewCount: _runner.wrongMarks.length,
                reviewHasSides: _runner.wrongMarks.any((m) => m.side != 0),
                sidePanel: _phoneLayout,
              );
              if (action == StageSummaryAction.review && mounted) {
                _startReview();
              }
              return action;
            },
        conclusion: () => showTrailConclusion(context, sidePanel: _phoneLayout),
        backToLibrary: _backToLibrary,
        practiceReport: _onPracticeReport,
        pieceNChanged: (n) => widget.opened.onPieceSettingsChanged(
          _pieceSettingsWith(trailMeasures: n),
        ),
      ),
    )..addListener(_onRunnerChanged);
    _midiDeviceManager.connected.addListener(_maybeCheckTranspose);
    _settings.addListener(_onSettingsChanged);
    // A partitura é para ler em paisagem no celular (a biblioteca, em
    // retrato, volta a travar a orientação dela quando esta tela fecha); no
    // desktop isto não vale nada.
    if (_isPhone) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      // Modo imersivo (U10): a barra de status sai e a página é gravada,
      // desde a primeira vez, para a caixa inteira (pedido aqui para não
      // mudar a caixa e regravar o hino depois).
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  /// As configurações gerais mudaram — pelo painel desta tela ou por
  /// qualquer outro caminho: os controllers aplicam o que é deles; aqui só
  /// redesenha.
  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  /// Guarda o que é deste hino (layout, andamento, mão). Com um respiro: um
  /// slider arrastado chama isto a cada passo.
  void _savePieceSettings() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 400),
      _flushPieceSettings,
    );
  }

  Timer? _saveDebounce;

  PieceSettings _pieceSettingsWith({int? trailMeasures}) => PieceSettings(
    layout: PieceSettings.layoutOverrides(
      _session.layout,
      _session.layoutDefaults,
    ),
    pageFitsBox: _session.pageFitsBox,
    speed: _playback.speed == 1.0 ? null : _playback.speed,
    hand: _hand == _kDefaultHand ? null : _hand,
    trailMeasures: trailMeasures,
    transpose: _session.transposeChoice,
  );

  void _flushPieceSettings() {
    if (_saveDebounce == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    widget.opened.onPieceSettingsChanged(
      _pieceSettingsWith(trailMeasures: _runner.pieceN),
    );
  }

  /// Maior N que o controle do hino oferece: 20, ou os compassos lógicos.
  int get _trailMaxN {
    final measures = _runner.trail?.path.measureCount ?? 20;
    if (measures < kTrailMinMeasures) return kTrailMinMeasures;
    return measures < 20 ? measures : 20;
  }

  /// Mudar o N efetivo com progresso reinicia a trilha do hino (J06).
  Future<bool> _confirmNewCut() => confirmTrailReset(
    context,
    title: 'Trocar o corte?',
    message: 'Isto reinicia a trilha ${_term.deste} ${_term.singular}.',
    confirmLabel: 'Trocar',
  );

  @override
  void dispose() {
    if (_isPhone) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    _flushPieceSettings();
    _settings.removeListener(_onSettingsChanged);
    _shiftNotice.dispose();
    _runner
      ..removeListener(_onRunnerChanged)
      ..dispose();
    _midiDeviceManager.connected.removeListener(_maybeCheckTranspose);
    _playback
      ..removeListener(_onPlaybackChanged)
      ..dispose();
    _sound
      ..removeListener(_onSoundChanged)
      ..dispose();
    _midiInput.dispose();
    _viewController.dispose();
    _controller.dispose();
    _ghosts.dispose();
    _view.dispose();
    super.dispose();
  }

  /// Fecha a partitura e volta à biblioteca (o `dispose` para o que
  /// estiver tocando).
  void _backToLibrary() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  /// Troca o tom deste hino ("Transpor", Q08): [choice] é [kTransposeNone]
  /// ou um intervalo. Com trilha começada no tom de agora e nenhuma no novo,
  /// pergunta antes (Q04); guarda a escolha e grava a partitura de novo.
  Future<void> _chooseTranspose(String choice) async {
    final opened = widget.opened;
    final from = _session.transposition;
    final to = _session.transpositionFor(choice);
    if (to != from &&
        await _trailStore.toneChangeStartsOver(opened.piece.id, from, to)) {
      if (!mounted) return;
      final ok = await confirmTrailReset(
        context,
        title: 'Trocar de tom?',
        message: toneChangeMessage(
          opened.piece.fifths ?? 0,
          from: from,
          to: to,
          naming: _settings.noteNaming,
        ),
        confirmLabel: 'Trocar',
      );
      if (!ok || !mounted) return;
    }
    if (!_session.chooseTranspose(choice)) return;
    setState(() => _optionsOpen = false);
    opened.onPieceSettingsChanged(
      _pieceSettingsWith(trailMeasures: _runner.pieceN),
    );
  }

  /// "Escolher…": a lista dos 12 tons.
  Future<void> _pickTone() async {
    final fifths = _piece.fifths;
    if (fifths == null) return;
    final range = _session.originalRange;
    final current = _session.transposition;
    final choice = await showToneList(
      context,
      choices: toneChoices(
        fifths,
        lowest: range?.lowest ?? kCatalogLowestMidi,
        highest: range?.highest ?? kCatalogHighestMidi,
        naming: _settings.noteNaming,
      ),
      currentFifths: fifths + (current?.fifthsDelta ?? 0),
    );
    if (choice == null || !mounted) return;
    await _chooseTranspose(choice.transposition?.interval ?? kTransposeNone);
  }

  /// O item "Transpor" (gaveta e diálogo do desktop); [before] roda antes da
  /// ação — o diálogo fecha a si mesmo. `null` sem armadura conhecida.
  Widget? _transposeSection({VoidCallback? before}) {
    final fifths = _piece.fifths;
    if (fifths == null) return null;
    final current = _session.transposition;
    final none = _session.noAccidentals;
    return TransposeSection(
      fifths: fifths,
      mode: transposeModeOf(current, none),
      noAccidentals: none,
      currentTone: current,
      alsoStudied: _runner.alsoStudied,
      onNone: () {
        before?.call();
        unawaited(_chooseTranspose(kTransposeNone));
      },
      onNoAccidentals: () {
        before?.call();
        if (none != null) unawaited(_chooseTranspose(none.interval));
      },
      onPick: () {
        before?.call();
        unawaited(_pickTone());
      },
    );
  }

  /// Desktop: o mesmo item num diálogo (o celular o tem na gaveta).
  Future<void> _openTransposeDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Transpor'),
        content: SizedBox(
          width: 360,
          child: _transposeSection(before: () => Navigator.pop(dialog)),
        ),
      ),
    );
  }

  /// O selo da partitura transposta: "Mi♭ → Dó · teclado +3". Mostra o tom da
  /// gravura que está na tela. `null` no tom original.
  Widget? _transposeSeal() {
    final transposition = _session.renderedTransposition;
    if (transposition == null) return null;
    final fifths = _piece.fifths;
    return TransposeSeal(
      text: fifths == null
          ? 'Transposta · teclado ${transposition.keyboardLabel}'
          : transposeSealText(
              fifths,
              transposition,
              appIsSound: _sound.midiMonitorOn,
              naming: _settings.noteNaming,
            ),
      onTap: _onSealTap,
    );
  }

  /// Tocar no selo abre a conferência do teclado (Q06); sem teclado ou com o
  /// som só do app não há o que conferir, e a pessoa fica sabendo por quê.
  void _onSealTap() {
    final message = _midiDeviceManager.connected.value == null
        ? 'Conecte o teclado para conferir o TRANSPOSE.'
        : _sound.midiMonitorOn
        ? 'O som sai pelo app, no tom original: não há o que ajustar no '
              'teclado.'
        : null;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    unawaited(_openTransposeCheck());
  }

  /// As alturas da música aberta (fase Q): o que se lê, o que se ouve e o que
  /// chega do teclado. Montado a cada uso — o tom da gravura que está na tela,
  /// o que se sabe do teclado conectado e se o som é do app — então quem o usa
  /// por função (casador, agendador, monitor) sempre vê o estado de agora.
  PitchFrame get _pitchFrame {
    // O tom da gravura na tela (não o pedido, que ainda pode estar sendo
    // gravado): as alturas do `midi.json` são as dele.
    final k = _session.renderedTransposition?.semitones ?? 0;
    if (k == 0) return PitchFrame.identity;
    final behavior = _settings.keyboardTransposeOf(
      _midiDeviceManager.connected.value?.name,
    );
    return PitchFrame(
      k,
      keyboardShiftsOut: behavior.shiftsOut ?? false,
      keyboardShiftsIn: behavior.shiftsIn ?? false,
      appIsSound: _sound.midiMonitorOn,
    );
  }

  /// A altura que o [engine] deve receber para a nota escrita: o teclado MIDI
  /// lê o que mandamos pela regra dele; o sintetizador do app toca a soada.
  int Function(int) _enginePitchOf(SoundEngine engine) {
    final midiKeyboard = engine is MidiOutSoundEngine;
    return (w) => _pitchFrame.engineFromWritten(w, midiKeyboard: midiKeyboard);
  }

  /// Uma gravura nova ([ScoreRenderSession.onDocument]): os ids (e talvez as
  /// páginas) mudaram, então o que tocava a anterior é desmontado e montado
  /// de novo sobre ela.
  void _onDocument(VsbDocument document, PerformanceTrack track) {
    if (!mounted) return;
    _runner.attachDocument(document, track);
    _sound.restoreSound();
    _maybeCheckTranspose();
    _maybeRemindTransposeReset();
  }

  /// Todos os compassos da música, para o véu dos que não são do trecho.
  Iterable<String> _allMeasureIds(ScorePlayer player) => {
    for (final m in player.measures) m.id,
  };

  Widget? _markMeasure(BuildContext context, String id, Rect rect) {
    // Erros da última passagem: um fundo vermelho leve sobre o compasso.
    if (_runner.errorMeasureIds.contains(id)) {
      return IgnorePointer(
        child: ColoredBox(color: kBadColor.withValues(alpha: 0.12)),
      );
    }
    if (_runner.markedIds().isEmpty) return null;
    if (!_runner.isMarked(id)) {
      return IgnorePointer(
        child: ColoredBox(color: kSurface.withValues(alpha: 0.55)),
      );
    }
    if (_runner.trail?.running ?? false) return null;
    // Compassos do trecho: fundo azul leve, sem barra na base.
    return IgnorePointer(
      child: ColoredBox(color: kAccent.withValues(alpha: 0.10)),
    );
  }

  void _togglePlay() {
    _runner.clearErrorMarks();
    _playback.togglePlay();
  }

  /// Stops playback and rewinds to the start.
  void _stop() {
    if (_runner.trail?.running == true) {
      _runner.abandonStage();
      return;
    }
    // `ScoreAudioScheduler.stop` reancora em 0 mas não solta o freio nem o
    // filtro de pauta do modo treino (T02) — sem isto, o próximo Play
    // ficaria preso no freio antigo.
    _runner.endPractice();
    _playback.stop();
  }

  /// Reiniciar: volta ao começo e segue como estava — tocando, recomeça de
  /// lá; parado, fica parado no começo. "Começo" é o da etapa na trilha, o
  /// do trecho em repetição no modo livre, ou o da música.
  Future<void> _restart() async {
    final player = _playback.player;
    if (player == null) return;
    if (_runner.trailMode) {
      final trail = _runner.trail!;
      if (trail.running) {
        _runner.abandonStage();
        await _runner.startStage();
        return;
      }
      final stage = trail.selected;
      if (stage != null) _playback.seekTo(stage.startMs);
      return;
    }
    if (_runner.practice != null) {
      _runner.stopPractice();
      await _runner.togglePractice(hand: _hand, mode: _practiceMode);
      return;
    }
    if (_playback.playing) _runner.clearErrorMarks();
    _playback.restart();
  }

  /// Arma/desarma o modo treino (T02) — só decide se o Play vira
  /// "Praticar" ([_canTrain] também exige um teclado MIDI conectado).
  /// Desarmar com uma sessão em andamento também a para.
  void _toggleTrainingMode() {
    if (_trainingMode && _runner.practice != null) _runner.stopPractice();
    setState(() => _trainingMode = !_trainingMode);
  }

  /// Troca a mão do aluno (T02) — o seletor só aparece armado e sem sessão
  /// em andamento ([_runner.practice] existindo esconde o seletor).
  void _setHand(Hand hand) {
    setState(() => _hand = hand);
    _savePieceSettings();
  }

  /// O treino livre com tempo acabou com algo avaliado (T03): a biblioteca
  /// guarda a melhor precisão do hino ("Pontuação") e o resumo abre.
  void _onPracticeReport(PracticeReport report) {
    widget.opened.onPracticeScore(
      (report.accuracy * 100).round(),
      _session.renderedTransposition,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showSummary(report));
    });
  }

  Future<void> _showSummary(PracticeReport report) => showPracticeSummary(
    context,
    report,
    legend: _practiceLegend(),
    sidePanel: _phoneLayout,
    onRepeatWorst: _repeatWorst,
    wrongCount: _runner.wrongMarks.length,
    reviewHasSides: _runner.wrongMarks.any((m) => m.side != 0),
    onReview: _runner.wrongMarks.isEmpty ? null : _startReview,
  );

  /// "Revisar" (fim do treino): as notas erradas ficam fixas na partitura e
  /// a primeira página com erro abre.
  void _startReview() {
    _runner.startReview();
    final pages = _reviewPages();
    if (pages.isNotEmpty) _viewController.goToPage(pages.first);
  }

  /// Páginas (índices) que têm nota errada fixa, em ordem.
  List<int> _reviewPages() =>
      ({for (final g in _ghosts.review) g.page.index}.toList()..sort());

  /// "Repetir os compassos com mais erros" (T03 + loop do T04): o intervalo
  /// que cobre os piores compassos se forem próximos (até 4 compassos);
  /// senão, só o pior.
  void _repeatWorst(List<MeasureStats> worst) {
    if (worst.isEmpty) return;
    var a = worst.map((m) => m.index).reduce(math.min);
    var b = worst.map((m) => m.index).reduce(math.max);
    if (b - a > 3) {
      a = b = worst.first.index;
    }
    _setLoop(a, b);
  }

  /// Tocar numa nota (E02c) move o player e o agendador.
  void _onScoreTap(String id) => _playback.seekToElement(id);

  void _setSpeed(double value) {
    _playback.setSpeed(value);
    _savePieceSettings();
  }

  /// Ícone dos botões "som" e "monitor MIDI": giro de carregamento enquanto
  /// [SoundOutputController.ensureEngine] pede o `.sf2` (motor compartilhado
  /// pelos dois).
  Widget _engineButtonIcon(IconData icon) => _sound.loadingSoundFont
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon);

  Future<void> _openLoopSheet() async {
    final player = _playback.player;
    if (player == null || player.measures.isEmpty) return;
    final chosen = await showLoopSheet(
      context,
      total: player.measures.length,
      current: player.currentMeasureIndex.value,
      initial: _playback.loop,
      sidePanel: _phoneLayout,
      onClear: _playback.clearLoop,
    );
    if (chosen == null || !mounted || !identical(player, _playback.player)) {
      return;
    }
    _setLoop(chosen.a, chosen.b);
  }

  /// "Repetir um trecho" e "repetir os piores compassos" (T03): liga o loop
  /// nos compassos `a..b` (ocorrências, 0-based) e vai ao início do trecho.
  void _setLoop(int a, int b) => _playback.setLoop(a, b);

  String get _outputKey =>
      _sound.output == SoundOutput.midiKeyboard ? 'midi' : 'app';

  Future<void> _openCalibration() async {
    final device = _midiDeviceManager.connected.value;
    if (device == null) return;
    final engine = await _sound.ensureEngine();
    if (engine == null || !mounted) return;
    final ms = await showCalibrationDialog(
      context,
      engine: engine,
      input: _midiInput,
      deviceName: device.name,
    );
    if (ms == null) return;
    await _midiDeviceManager.setInputLatencyMs(device.id, _outputKey, ms);
    if (mounted) _runner.setInputLatency(ms);
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  void _onRunnerChanged() {
    if (mounted) setState(() {});
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Teclados para os quais a conferência do TRANSPOSE (Q06) já foi oferecida
  /// nesta tela: quem a fechou não é incomodado a cada regravação.
  final Set<String> _transposeCheckAsked = {};
  bool _transposeCheckOpen = false;

  /// Q07: o aviso da faixa no topo da partitura (detector de deslocamento ou
  /// lembrete de voltar o TRANSPOSE a 0) e o detector, que vigia só onde o
  /// TRANSPOSE errado muda o número que chega: teclado que transpõe a saída
  /// (ou ainda não conferido) e som que sai do teclado, não do app.
  final ValueNotifier<ShiftNotice?> _shiftNotice = ValueNotifier(null);
  late final ShiftDetector _shiftDetector = ShiftDetector(
    enabled: () =>
        !_sound.midiMonitorOn &&
        _settings
                .keyboardTransposeOf(_midiDeviceManager.connected.value?.name)
                .shiftsOut !=
            false,
  );

  /// O detector disparou com a distância [d]: diz à pessoa o que ajustar e, num
  /// teclado ainda não conferido, guarda que ele transpõe a saída (só quem
  /// transpõe manda o número deslocado). Se o teclado já estava no valor
  /// pedido, só fica sabendo disso — não há o que avisar.
  void _onShiftDetected(int d) {
    if (!mounted) return;
    final frame = _pitchFrame;
    final frameShiftsOut = frame.keyboardShiftsOut && !frame.appIsSound;
    final name = _midiDeviceManager.connected.value?.name;
    final behavior = _settings.keyboardTransposeOf(name);
    if (name != null && !behavior.isChecked) {
      _settings.setKeyboardTranspose(
        name,
        KeyboardTransposeBehavior(shiftsOut: true, shiftsIn: behavior.shiftsIn),
      );
    }
    if (shiftIsAlreadyRight(d: d, k: frame.k, frameShiftsOut: frameShiftsOut)) {
      return;
    }
    _shiftNotice.value = shiftNoticeFor(
      d: d,
      k: frame.k,
      frameShiftsOut: frameShiftsOut,
    );
  }

  /// Lembra de voltar o TRANSPOSE a 0 ao passar de uma música transposta (nesta
  /// execução do app) a uma sem transposição, num teclado que não transpõe a
  /// saída: nele o detector não vê nada. Sair do app com a transposta aberta
  /// não avisa: no celular não há um momento confiável para isso.
  void _maybeRemindTransposeReset() {
    final now = (_session.renderedTransposition?.semitones ?? 0) != 0;
    final previous = _settings.lastPieceTransposed;
    _settings.lastPieceTransposed = now;
    final name = _midiDeviceManager.connected.value?.name;
    if (shouldRemindTransposeReset(
      previousWasTransposed: previous,
      nowTransposed: now,
      hasKeyboard: name != null,
      keyboardShiftsOut: _settings.keyboardTransposeOf(name).shiftsOut,
      appIsSound: _sound.midiMonitorOn,
    )) {
      _shiftNotice.value = const ShiftNotice(
        kShiftReminderMessage,
        hideOnPlay: false,
      );
    }
  }

  /// Oferece a conferência sozinha quando há transposição, um teclado
  /// conectado e ainda não conferido ([shouldAutoCheckTranspose]).
  void _maybeCheckTranspose() {
    if (!mounted || _transposeCheckOpen) return;
    final name = _midiDeviceManager.connected.value?.name;
    if (!shouldAutoCheckTranspose(
      transposition: _session.renderedTransposition,
      deviceName: name,
      behavior: _settings.keyboardTransposeOf(name),
      appIsSound: _sound.midiMonitorOn,
      alreadyAsked: _transposeCheckAsked.contains(name),
    )) {
      return;
    }
    _transposeCheckAsked.add(name!);
    unawaited(_openTransposeCheck());
  }

  /// A conferência do TRANSPOSE (Q06): também é o que o selo da partitura
  /// abre (Q08). Sem teclado, sem transposição na tela ou com o som só do app
  /// não há o que ajustar, e não abre. O que se descobre fica guardado pelo
  /// nome do teclado.
  Future<void> _openTransposeCheck() async {
    final transposition = _session.renderedTransposition;
    final device = _midiDeviceManager.connected.value;
    if (transposition == null ||
        device == null ||
        _sound.midiMonitorOn ||
        _transposeCheckOpen ||
        !mounted) {
      return;
    }
    _transposeCheckOpen = true;
    try {
      final behavior = await showTransposeCheck(
        context,
        transposition: transposition,
        deviceName: device.name,
        input: _midiInput,
        previous: _settings.keyboardTransposeOf(device.name),
        naming: _settings.noteNaming,
        playOwnSound: _playOwnTone,
        playOnKeyboard: _sound.output == SoundOutput.midiKeyboard
            ? _playKeyboardTone
            : null,
      );
      if (behavior != null) {
        _settings.setKeyboardTranspose(device.name, behavior);
      }
    } finally {
      _transposeCheckOpen = false;
    }
  }

  /// Toca [pitch] pelo sintetizador do app, para o teste de ouvido da
  /// conferência; `false` se ele não está aberto (então vale a palavra da
  /// pessoa). Pelo canal do monitor, que a partitura não usa.
  Future<bool> _playOwnTone(int pitch) async {
    final engine = _sound.appEngine;
    if (engine == null) return false;
    await _beep(engine, pitch, channel: kMidiMonitorChannel);
    return true;
  }

  /// Manda [pitch] cru ao teclado (M03), sem conversão: é o que a conferência
  /// da entrada compara.
  Future<void> _playKeyboardTone(int pitch) async {
    final engine = _sound.ensureMidiOutEngine();
    // Canal 1: alguns teclados só respondem nele.
    if (engine != null) await _beep(engine, pitch, channel: 0);
  }

  Future<void> _beep(
    SoundEngine engine,
    int pitch, {
    required int channel,
  }) async {
    engine.send([0x90 | channel, pitch, 100]);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    engine.send([0x80 | channel, pitch, 0]);
  }

  /// Só quem está ouvindo ou treinando vê a página virar com animação (a
  /// haste varre a pauta no compasso da música). Para só olhar, a página
  /// muda de uma vez.
  bool get _pageTurnAnimated => _playback.playing || _runner.practice != null;

  /// Os botões de página à vista: a pessoa não está tocando nem treinando e
  /// a música tem mais de uma página.
  bool get _pagerVisible => !_pageTurnAnimated && _session.pageCount > 1;

  bool get _canPageBack => _session.pageIndex > 0 && !_session.busy;
  bool get _canPageForward =>
      _session.pageIndex < _session.pageCount - 1 && !_session.busy;

  void _previousPage() {
    _viewController.previousPage(animate: _pageTurnAnimated);
  }

  void _nextPage() {
    _viewController.nextPage(animate: _pageTurnAnimated);
  }

  void _onPageChanged(int target) {
    if (mounted) _session.setPage(target);
  }

  /// A layout option of this piece settled (slider released, toggle
  /// flipped): keep it for the piece and re-engrave.
  void _commitLayout() {
    _savePieceSettings();
    unawaited(_session.render());
  }

  /// Back to the app's default layout — for this piece only.
  void _resetLayout() {
    _session.resetLayout();
    _commitLayout();
  }

  Future<void> _copyOptions() async {
    final json = const JsonEncoder.withIndent('  ')
        .convert(_session.effectiveOptions);
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Opções copiadas (JSON)')));
  }

  /// Multiplies the on-screen zoom by [factor]. Reads the live value, not
  /// the one the buttons were built with, so taps between frames add up.
  void _zoomBy(double factor) =>
      _zoomTo(_view.value.getMaxScaleOnAxis() * factor);

  /// Sets the on-screen zoom to [target], keeping the centre of the view
  /// where it is.
  void _zoomTo(double target) {
    final current = _view.value.getMaxScaleOnAxis();
    final factor = target.clamp(kZoomMin, kZoomMax) / current;
    final cx = _viewport.width / 2;
    final cy = _viewport.height / 2;
    // All three axes, like InteractiveViewer does: getMaxScaleOnAxis() reads
    // the largest of them, so a Z left at 1 would pin the zoom at >= 100%.
    _view.value =
        Matrix4.translationValues(cx, cy, 0) *
        Matrix4.diagonal3Values(factor, factor, factor) *
        Matrix4.translationValues(-cx, -cy, 0) *
        _view.value;
  }

  /// Zoom control embedded in [LayoutPanel] (the "Opções" panel) — it used
  /// to float over the score, but that hid the score under it on a small
  /// window, so it moved in with the rest of the controls.
  Widget _zoomControls() {
    return ValueListenableBuilder<Matrix4>(
      valueListenable: _view,
      builder: (context, matrix, _) {
        final scale = matrix.getMaxScaleOnAxis();
        final untouched = matrix.isIdentity();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Diminuir zoom',
              onPressed: scale > kZoomMin ? () => _zoomBy(1 / 1.25) : null,
              icon: const Icon(Icons.remove),
            ),
            // Logarithmic: equal steps are equal ratios, so 50%→100% takes
            // as much travel as 400%→800%.
            Expanded(
              child: Slider(
                min: math.log(kZoomMin) / math.ln2,
                max: math.log(kZoomMax) / math.ln2,
                value: (math.log(scale) / math.ln2).clamp(
                  math.log(kZoomMin) / math.ln2,
                  math.log(kZoomMax) / math.ln2,
                ),
                onChanged: (v) => _zoomTo(math.pow(2, v).toDouble()),
              ),
            ),
            IconButton(
              tooltip: 'Aumentar zoom',
              onPressed: scale < kZoomMax ? () => _zoomBy(1.25) : null,
              icon: const Icon(Icons.add),
            ),
            Tooltip(
              message: 'Voltar a 100%',
              child: TextButton(
                onPressed: untouched
                    ? null
                    : () => _view.value = Matrix4.identity(),
                child: SizedBox(
                  width: 44,
                  child: Text(
                    '${(scale * 100).round()}%',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Modo da gaveta: `false` = Ouvir, `true` = Espera (modo treino, T02).
  /// Como no artefato, entrar em Espera pede uma mão só (Direita) e
  /// andamento 80%; voltar a Ouvir devolve Ambas e 100%.
  void _setTrainingFromDrawer(bool training) {
    if (training == _trainingMode) return;
    if (!training && _runner.practice != null) _runner.stopPractice();
    setState(() {
      _trainingMode = training;
      _hand = training
          ? (_hand == Hand.ambas ? Hand.direita : _hand)
          : Hand.ambas;
    });
    _setSpeed(training ? 0.8 : 1.0);
  }

  /// Escolha do seletor único de modos (U11). Entre os três modos de treino
  /// só troca o modo; de e para Ouvir valem os efeitos de carona de
  /// [_setTrainingFromDrawer] (mão e andamento).
  void _setStudyMode(StudyMode next) {
    final current = StudyMode.of(training: _trainingMode, mode: _practiceMode);
    if (next == current) return;
    final practiceMode = next.practiceMode;
    if (practiceMode != null) _practiceMode = practiceMode;
    if (next.isTraining == current.isTraining) {
      setState(() {});
    } else {
      _setTrainingFromDrawer(next.isTraining);
    }
  }

  /// Compasso (base 1) e total para a barra lateral; `null` sem partitura.
  int? get _measureCount {
    final n = _playback.player?.timeline.measureCount ?? 0;
    return n == 0 ? null : n;
  }

  /// A tela da partitura está no layout de celular (`build`): resumos e
  /// seletores entram pela lateral, não como folha inferior (U18).
  bool get _phoneLayout =>
      MediaQuery.sizeOf(context).width < kPhoneLayoutMaxWidth;

  Future<void> _openMeasureJump() async {
    final player = _playback.player;
    // Na trilha o compasso fala a numeração do caminho (a da gaveta e do
    // resumo), não a das ocorrências da música expandida (U07).
    final trail = _runner.trailMode ? _runner.trail : null;
    final path = trail != null && trail.path.measureCount > 0
        ? trail.path
        : null;
    final total = path?.measureCount ?? _measureCount;
    if (player == null || total == null) return;
    final current = player.currentMeasureIndex.value;
    var target = path != null ? (path.numberOf(current) ?? 1) : current + 1;
    final sidePanel = _phoneLayout;
    final result = await showSheetOrSidePanel<int>(
      context,
      sidePanel: sidePanel,
      title: 'Ir para o compasso',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => sheetBody(
          sidePanel: sidePanel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ir para o compasso $target de $total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Slider(
                value: target.toDouble(),
                min: 1,
                max: total.toDouble(),
                divisions: total > 1 ? total - 1 : null,
                onChanged: (v) => setSheetState(() => target = v.round()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, target),
                child: const Text('Ir'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted || !identical(player, _playback.player)) {
      return;
    }
    final ms =
        path?.startMsOfNumber(result) ??
        player.timeline.measures[result - 1].startMs;
    player.seek(Duration(milliseconds: ms.round()));
    _playback.scheduler?.seek(ms.toDouble());
  }

  /// Selo do canto superior: modo (espera ou tempo real) e mão.
  String get _trainingPillText {
    final hand = _hand.shortLabel.toLowerCase();
    final realtime = _practiceMode == PracticeMode.realtime;
    if (_runner.practice != null) {
      return realtime ? 'Tempo real · mão $hand' : 'Esperando · mão $hand';
    }
    if (_midiDeviceManager.connected.value == null) {
      return 'Conecte o teclado MIDI';
    }
    return realtime ? 'Tempo real · mão $hand' : 'Espera · mão $hand';
  }

  /// Corpo no celular — `CelularEstudo` / `CelularTreino` / `CelularPainel` /
  /// `CelularGrande`: a partitura ocupa tudo, com a barra lateral de 84 px à
  /// direita; o resto (andamento, mão, modo, tamanho, som…) fica na gaveta ⋯.
  /// Faixa do topo no celular: voltar, número e título do hino e, no
  /// treino, os selos de modo/mão e de acertos e erros.
  Widget _buildPhoneTitleBar() {
    final piece = _piece;
    return PhoneTitleBar(
      number: piece.number,
      title: piece.title,
      onBack: _backToLibrary,
      center: _trailChip(),
      trailing: [
        _phoneSoundButton(),
        ?_transposeSeal(),
        if (_runner.trailMode)
          ValueListenableBuilder(
            valueListenable: _midiDeviceManager.connected,
            builder: (context, device, _) => device != null
                ? const SizedBox.shrink()
                : PhoneKeyboardNotice(
                    onTap: () => unawaited(
                      showMidiDevicePicker(context, _midiDeviceManager),
                    ),
                  ),
          ),
        if (_trainingMode) PhoneStatusPill(text: _trainingPillText),
        if (_runner.practice case final practice?)
          practice.mode == PracticeMode.wait && practice.range == null
              // Modo espera livre não tem resultado: os dois contadores.
              ? ListenableBuilder(
                  listenable: Listenable.merge([
                    practice.correctCount,
                    practice.wrongCount,
                  ]),
                  builder: (context, _) => PhoneCountersPill(
                    correct: practice.correctCount.value,
                    mistakes: practice.wrongCount.value,
                  ),
                )
              // Com resultado (trilha ou tempo real livre): a
              // porcentagem do resumo, com a meta na trilha (U05).
              : ValueListenableBuilder(
                  valueListenable: practice.liveScore,
                  builder: (context, score, _) => PhoneScorePill(
                    hits: score.hits,
                    total: score.total,
                    goalPercent: practice.range != null
                        ? (kTrailPassAccuracy * 100).round()
                        : null,
                  ),
                ),
      ],
    );
  }

  /// Alto-falante da barra do título (U04): mostra o som de agora; o toque
  /// muda também a preferência. Saída no teclado MIDI sem teclado: explica e
  /// leva ao seletor. Desabilitado com o treino rodando (desligar o som o
  /// encerraria).
  Widget _phoneSoundButton() => ValueListenableBuilder(
    valueListenable: _midiDeviceManager.connected,
    builder: (context, device, _) {
      final noKeyboard =
          _sound.output == SoundOutput.midiKeyboard && device == null;
      if (noKeyboard) {
        return PhoneSoundButton(
          on: false,
          tooltip: 'Som no teclado: nenhum conectado',
          onPressed: () =>
              unawaited(showMidiDevicePicker(context, _midiDeviceManager)),
        );
      }
      return PhoneSoundButton(
        on: _sound.soundOn,
        loading: _sound.loadingSoundFont,
        tooltip: _sound.soundOn ? 'Som ligado' : 'Som desligado',
        onPressed: _runner.practice != null
            ? null
            : () => unawaited(_sound.userToggleSound()),
      );
    },
  );

  /// A trilha na barra do título do celular (U01): no lugar da faixa, que
  /// cobria o topo da pauta. No treino livre com trilha, "Treino livre" e um
  /// toque volta à trilha.
  Widget? _trailChip() {
    if (_playback.player == null) return null;
    final unavailable = _runner.unavailable;
    if (unavailable != null && _runner.trail == null) {
      return TrailTitleChip(text: unavailable);
    }
    final trail = _runner.trail;
    if (trail == null) return null;
    if (trail.freeMode) {
      return TrailTitleChip(
        text: 'Treino livre',
        onTap: () => setState(() => trail.setFreeMode(false)),
      );
    }
    final stage = trail.selected;
    if (stage == null) return const TrailTitleChip(text: 'Fase final em breve');
    return TrailTitleChip(
      text: stage.isReinforcement
          ? stage.label
          : trailStripTextFor(
              trail.plan.segmentCount,
              stage.segment,
              stage.label,
            ),
      stateText: stage.isReinforcement
          ? ''
          : trailStateText(trail.progress, stage.id),
      onTap: () => setState(() => _trailDrawerOpen = true),
    );
  }

  /// Faixa da trilha sobre a partitura (J05): altura fixa, fora da caixa de
  /// layout da partitura — não muda a área gravada e não dispara re-render.
  /// `null` no modo livre, sem partitura ou sem trilha montada; com trilha
  /// indisponível ou concluída (fase final até o J07), uma linha explicando.
  Widget? _trailStrip() {
    if (_playback.player == null) return null;
    final unavailable = _runner.unavailable;
    if (unavailable != null && _runner.trail == null) {
      return _trailMessage(unavailable);
    }
    final trail = _runner.trail;
    if (trail == null || trail.freeMode) return null;
    final stage = trail.selected;
    if (stage == null) {
      return _trailMessage('Fase final em breve');
    }
    return TrailStrip(
      text: stage.isReinforcement
          ? stage.label
          : trailStripTextFor(
              trail.plan.segmentCount,
              stage.segment,
              stage.label,
            ),
      stateText: stage.isReinforcement
          ? ''
          : trailStateText(trail.progress, stage.id),
      running: trail.running,
      onStart: () => unawaited(_runner.startStage()),
      onStop: _runner.abandonStage,
      onTap: () => setState(() => _trailDrawerOpen = true),
    );
  }

  /// Legenda das cores do treino, com as do aluno (U08).
  Widget _practiceLegend() => PracticeLegend(
    pending: _settings.practicePendingColor,
    correct: _settings.highlightColor,
    offBeat: kPracticeOffBeatColor,
    wrong: _settings.practiceWrongColor,
    missed: kPracticeMissedColor,
  );

  /// Gaveta da trilha (J06): lista de etapas, pular, refazer e reiniciar.
  /// Os retornos falam com o `_runner.trail` corrente (não o da construção), pois
  /// reiniciar troca o controlador com a gaveta aberta.
  Widget _buildTrailDrawer() {
    final trail = _runner.trail;
    if (trail == null) return const SizedBox.shrink();
    return TrailDrawer(
      plan: trail.plan,
      progress: trail.progress,
      selectedId: trail.selected?.id,
      currentId: trail.progress.current(trail.plan)?.id,
      blocks: trail.blockViews,
      footer: _practiceLegend(),
      alsoStudied: _runner.alsoStudied,
      onClose: () => setState(() => _trailDrawerOpen = false),
      onSelectStage: (id) {
        // Etapa rodando: escolher outra encerra a que roda (sem registro),
        // senão a faixa mostraria a nova com o treino ainda na antiga.
        if (_runner.trail?.running ?? false) _runner.abandonStage();
        _runner.trail?.select(id);
        setState(() => _trailDrawerOpen = false);
      },
      onRepeatStage: trail.running
          ? null
          : (id) {
              _runner.trail?.select(id);
              setState(() => _trailDrawerOpen = false);
              unawaited(_runner.startStage());
            },
      onSkipCurrent: () async {
        final current = _runner.trail;
        if (current == null) return;
        if (current.running) _runner.abandonStage();
        await current.skipSelected();
        current.next();
      },
      onRestartTrail: _runner.restartTrail,
    );
  }

  Widget _trailMessage(String text) => Container(
    height: kTrailStripHeight,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: const BoxDecoration(
      color: kPanelSideBg,
      border: Border(bottom: BorderSide(color: kBorderPanel)),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: kInkCaption),
    ),
  );

  Widget _buildPhoneBody() {
    final player = _playback.player;
    return Stack(
      children: [
        SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ColoredBox(
                  color: kSurface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPhoneTitleBar(),
                      Expanded(child: _buildScoreArea(phone: true)),
                    ],
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([
                  player?.currentMeasureIndex ?? _noMeasure,
                  _midiDeviceManager.connected,
                ]),
                builder: (context, _) {
                  final index =
                      (player?.currentMeasureIndex ?? _noMeasure).value;
                  final trail = _runner.trailMode ? _runner.trail : null;
                  final keyboard = _midiDeviceManager.connected.value != null;
                  return PhoneRail(
                    playing: _playback.playing,
                    onListen: trail != null && !trail.running
                        ? () => unawaited(_runner.listenStage())
                        : null,
                    listening: _runner.listening,
                    onPlayPause: trail != null
                        ? (keyboard
                              ? () => unawaited(_runner.startStage())
                              : () => unawaited(_runner.listenStage()))
                        : (_canTrain
                              ? () => unawaited(
                                  _runner.togglePractice(
                                    hand: _hand,
                                    mode: _practiceMode,
                                  ),
                                )
                              : (_canPlay ? _togglePlay : null)),
                    playTooltip: trail != null
                        ? (trail.running
                              ? 'Parar etapa'
                              : (keyboard
                                    ? 'Começar etapa'
                                    : (_runner.listening
                                          ? 'Parar de ouvir'
                                          : 'Ouvir o trecho')))
                        : (_canTrain
                              ? (_runner.practice != null
                                    ? 'Pausar'
                                    : 'Praticar')
                              : null),
                    playIcon: trail != null
                        ? (trail.running
                              ? null
                              : Icon(
                                  _runner.listening
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                  size: 24,
                                ))
                        : (_canTrain && _runner.practice == null
                              ? const Icon(Icons.play_arrow, size: 24)
                              : null),
                    onRestart: _canPlay ? () => unawaited(_restart()) : null,
                    measure: _measureCount == null
                        ? null
                        : (trail?.path.numberOf(index) ?? index + 1),
                    totalMeasures: trail != null && trail.path.measureCount > 0
                        ? trail.path.measureCount
                        : _measureCount,
                    onMeasureTap: _measureCount == null
                        ? null
                        : _openMeasureJump,
                    stageTempo: trail == null
                        ? null
                        : switch (trail.selected?.speed) {
                            final speed? => '${(speed * 100).round()}%',
                            null => 'livre',
                          },
                    stageTempoCaption: trail?.selected?.speed == null
                        ? 'sem tempo'
                        : 'da etapa',
                    stageHand: trail?.selected?.phase.hand.shortLabel,
                    onStageTap: trail == null
                        ? null
                        : () => setState(() => _trailDrawerOpen = true),
                    tempoPercent: (_playback.speed * 100).round(),
                    handLabel: _hand.shortLabel,
                    onOptions: () => setState(() => _optionsOpen = true),
                  );
                },
              ),
            ],
          ),
        ),
        if (_optionsOpen) _buildOptionsDrawer(),
        if (_trailDrawerOpen) _buildTrailDrawer(),
      ],
    );
  }

  final ValueNotifier<int> _noMeasure = ValueNotifier(0);

  /// Celular de verdade (não só janela estreita): começa com [kPhoneUnit].
  static final bool _isPhone =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Widget _buildOptionsDrawer() {
    final trailActive = _runner.trailMode;
    return PhoneOptionsDrawer(
      mode: StudyMode.of(training: _trainingMode, mode: _practiceMode),
      onModeChanged: _runner.practice != null ? null : _setStudyMode,
      trailMode: trailActive,
      hand: _hand,
      onHandChanged: _setHand,
      tempoPercent: (_playback.speed * 100).round(),
      onTempoChanged: (v) => _setSpeed(v / 100),
      onClose: () => setState(() => _optionsOpen = false),
      // A trilha vem primeiro: na trilha a gaveta abre por ela, e no treino
      // livre "Voltar à trilha" fica no topo, à vista (U11).
      top: [
        if (_runner.trail != null) ...[
          const PhoneSectionLabel('TRILHA'),
          PhoneActionRow(
            icon: trailActive ? Icons.school_outlined : Icons.route,
            label: trailActive ? 'Treino livre' : 'Voltar à trilha',
            onTap: () {
              final trail = _runner.trail;
              if (trail == null) return;
              setState(() {
                trail.setFreeMode(!trail.freeMode);
                _optionsOpen = false;
              });
            },
          ),
        ],
      ],
      children: [
        // Na trilha a etapa manda no modo, no metrônomo e no trecho.
        if (!trailActive) ...[
          const PhoneSectionLabel('TREINO'),
          PhoneToggleRow(
            label: 'Metrônomo (com som)',
            value: _settings.metronomeOn,
            onChanged: (_) => _playback.toggleMetronome(),
          ),
          PhoneActionRow(
            icon: Icons.repeat,
            label: _playback.loop == null
                ? 'Repetir um trecho'
                : 'Trecho: compassos ${_playback.loop!.a + 1}–${_playback.loop!.b + 1} — mudar',
            onTap: _playback.player == null
                ? null
                : () {
                    setState(() => _optionsOpen = false);
                    unawaited(_openLoopSheet());
                  },
          ),
        ],
        ?_transposeSection(),
        // O que é só deste hino: cada um guarda o seu tamanho e layout.
        PhoneSectionLabel('${_term.este} ${_term.singular}'.toUpperCase()),
        PhoneToggleRow(
          label: 'Trechos de ${_settings.trailMeasures} compassos (padrão)',
          value: _runner.pieceN == null,
          onChanged: (v) => unawaited(
            _runner.setPieceN(
              v ? null : _settings.trailMeasures,
              confirm: _confirmNewCut,
            ),
          ),
        ),
        if (_runner.pieceN case final pieceN?)
          TrailNSelector(
            value: pieceN,
            max: _trailMaxN,
            onChanged: (v) =>
                unawaited(_runner.setPieceN(v, confirm: _confirmNewCut)),
          ),
        PhoneSliderRow(
          label: 'TAMANHO DA NOTAÇÃO',
          value: (_session.layout['unit']! as num).toDouble(),
          min: 4.5,
          max: 12,
          divisions: 15,
          formatValue: (v) => v.toStringAsFixed(1),
          onChanged: (v) => _session.setLayoutValue('unit', v),
          onChangeEnd: (_) => _commitLayout(),
        ),
        PhoneActionRow(
          icon: Icons.tune,
          label: 'Ajustes da partitura (avançado)',
          onTap: () => setState(() {
            _optionsOpen = false;
            _generalOpen = false;
            _panelOpen = true;
          }),
        ),
        PhoneActionRow(
          icon: Icons.chevron_left,
          label: 'Página anterior',
          onTap: _session.pageIndex > 0 && !_session.busy
              ? _previousPage
              : null,
          trailing: Text(
            _session.pageCount == 0
                ? '—'
                : '${_session.pageIndex + 1} / ${_session.pageCount}',
            style: const TextStyle(fontSize: 13, color: kInkCaption),
          ),
        ),
        PhoneActionRow(
          icon: Icons.chevron_right,
          label: 'Próxima página',
          onTap: _session.pageIndex < _session.pageCount - 1 && !_session.busy
              ? _nextPage
              : null,
        ),
        // O que vale para todos os hinos fica num painel só.
        const PhoneSectionLabel('GERAL'),
        PhoneActionRow(
          icon: Icons.settings_outlined,
          label: 'Configurações gerais',
          trailing: const Text(
            'som, MIDI, cores',
            style: TextStyle(fontSize: 13, color: kInkCaption),
          ),
          onTap: () => setState(() {
            _optionsOpen = false;
            _panelOpen = false;
            _generalOpen = true;
          }),
        ),
      ],
    );
  }

  /// Um cartão flutuante da partitura (layout, configurações gerais, monitor
  /// MIDI). No celular ele entra pela direita, na mesma casca das gavetas —
  /// o monitor também, que antes abria à esquerda (U18); no layout largo,
  /// como sempre: um cartão solto, à esquerda ([left]) ou à direita.
  Widget _scorePanel({
    required bool phone,
    required BoxConstraints constraints,
    required Widget child,
    bool left = false,
  }) {
    if (!phone) {
      return Positioned(
        top: 8,
        left: left ? 8 : null,
        right: left ? null : 8,
        bottom: 8,
        width: math.min(360, constraints.maxWidth - 16),
        child: child,
      );
    }
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: math.min(kPhoneSidePanelWidth, constraints.maxWidth * 0.6),
      child: Material(
        color: kSurface,
        elevation: 8,
        child: SafeArea(left: false, child: ClipRect(child: child)),
      ),
    );
  }

  /// Treino com a música andando (tempo real, livre ou na trilha).
  bool get _timedPractice => _runner.practice?.mode == PracticeMode.realtime;

  Widget _buildScoreArea({bool phone = false}) {
    // The page is engraved for this box, so its size has to be known before
    // the first render — hence measuring here rather than off the window.
    // Everything drawn over the score (zoom, panel) is a Stack child, so it
    // never changes this box and never re-engraves the piece.
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        if (_session.setBox(constraints.biggest * dpr)) {
          // A primeira caixa: o painel, montado antes dela, ainda não mostra
          // o tamanho da página.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        _viewport = constraints.biggest;

        final document = _session.document;
        final hasPage = document != null && document.pages.isNotEmpty;
        final Widget content = hasPage
            // InteractiveViewer gives its child unbounded room, so the
            // view is pinned to the score box.
            ? SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: ScoreSizeLog(
                  label: 'hino ${_piece.id}',
                  document: document,
                  child: ScoreView(
                    document: document,
                    controller: _controller,
                    viewController: _viewController,
                    curtain: _playback.player?.curtain,
                    mode: ScorePageMode.pagedSweep,
                    initialPage: _session.pageIndex.clamp(
                      0,
                      document.pages.length - 1,
                    ),
                    onPageChanged: _onPageChanged,
                    onElementTap: _onScoreTap,
                    ghosts: _ghosts,
                    overlayIds:
                        (_runner.markedIds().isEmpty &&
                                _runner.errorMeasureIds.isEmpty) ||
                            _playback.player == null
                        ? const []
                        : _allMeasureIds(_playback.player!),
                    overlayBuilder: _markMeasure,
                    overlayUniformHeight: true,
                    haloSigmaScale: _haloWidth,
                    barColor: _barColor,
                    barWidth: _barWidthOf(document),
                    // A página nova fica ilegível até a haste começar a sair:
                    // o foco é o fim da página que ainda toca. No treino com
                    // tempo não: o aluno precisa ler o que vem antes de tocar,
                    // e a virada é curta (300 ms de parede, em qualquer
                    // andamento — o teto é em ms musicais).
                    revealBlurSigma: _timedPractice
                        ? 0
                        : _barWidthOf(document) * 4,
                    maxSweepDuration: _timedPractice
                        ? Duration(
                            milliseconds:
                                (300 * (_playback.scheduler?.speed ?? 1))
                                    .round(),
                          )
                        : kDefaultMaxSweepDuration,
                  ),
                ),
              )
            : phone
            // Enquanto o hino é gravado (a barra de progresso corre em
            // cima); se a gravação falhar, o motivo fica à vista.
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: Text(
                    switch (_session.error) {
                      final error? =>
                        'Não deu para abrir ${_term.o} ${_term.singular}: $error',
                      null => _scoreName,
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: kInkCaption),
                  ),
                ),
              )
            : const Center(
                child: Icon(Icons.music_note, size: 64, color: Colors.grey),
              );
        return Stack(
          children: [
            Positioned.fill(
              // No celular a partitura é fixa: sem arrastar nem ampliar (o
              // tamanho vem do `unit`). O zoom só existe no banco de testes.
              child: phone
                  ? content
                  : InteractiveViewer(
                      transformationController: _view,
                      minScale: kZoomMin,
                      maxScale: kZoomMax,
                      boundaryMargin: EdgeInsets.all(
                        math.min(constraints.maxWidth, constraints.maxHeight) /
                            2,
                      ),
                      child: content,
                    ),
            ),
            Positioned.fill(
              child: CountInOverlay(
                phone: phone,
                active: _playback.playing,
                read: _playback.countIn,
              ),
            ),
            if (_session.busy)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
            // No layout largo a barra de baixo já tem os botões de página.
            if (phone && _pagerVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PagePager(
                  onPrevious: _canPageBack ? _previousPage : null,
                  onNext: _canPageForward ? _nextPage : null,
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ShiftBanner(notice: _shiftNotice, notes: _midiInput.notes),
            ),
            if (_midiPanelOpen)
              _scorePanel(
                phone: phone,
                constraints: constraints,
                left: true,
                child: MidiMonitorPanel(
                  deviceManager: _midiDeviceManager,
                  input: _midiInput,
                  onClose: () => setState(() => _midiPanelOpen = false),
                  wrong: _runner.practice?.wrongPitches,
                  heldPitchOf: (r) => _pitchFrame.writtenFromReceived(r),
                ),
              )
            else if (!phone)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Ver as teclas que chegam',
                  onPressed: () => setState(() => _midiPanelOpen = true),
                  icon: const Icon(Icons.piano),
                ),
              ),
            if (_panelOpen)
              _scorePanel(
                phone: phone,
                constraints: constraints,
                child: LayoutPanel(
                  subtitle: _scoreName,
                  values: _session.layout,
                  pageFitsBox: _session.pageFitsBox,
                  fittedPage: _session.fittedPage,
                  onChanged: _session.setLayoutValue,
                  onCommit: _commitLayout,
                  onFitChanged: (v) {
                    _session.setPageFitsBox(v);
                    _commitLayout();
                  },
                  onReset: _resetLayout,
                  onCopy: _copyOptions,
                  onClose: () => setState(() => _panelOpen = false),
                  // No celular a partitura não tem zoom (o tamanho é o
                  // `unit`).
                  zoomSection: phone ? null : _zoomControls(),
                ),
              )
            else if (_generalOpen)
              _scorePanel(
                phone: phone,
                constraints: constraints,
                child: GeneralSettingsPanel(
                  settings: _settings,
                  midiDeviceManager: _midiDeviceManager,
                  customSoundFont: _sound.customSoundFont,
                  onChooseSoundFont: () => unawaited(_sound.chooseSoundFont()),
                  onResetSoundFont: () => unawaited(_sound.resetSoundFont()),
                  onClose: () => setState(() => _generalOpen = false),
                  live: LiveSettingsActions(
                    busy: _sound.loadingSoundFont,
                    monitorOn: _sound.midiMonitorOn,
                    onMonitorChanged: (_) =>
                        unawaited(_sound.toggleMidiMonitor()),
                    inputLatencyMs: _runner.inputLatencyMs,
                    onCalibrate: () {
                      setState(() => _generalOpen = false);
                      unawaited(_openCalibration());
                    },
                    onOpenMidiPanel: () => setState(() {
                      _generalOpen = false;
                      _midiPanelOpen = true;
                    }),
                  ),
                ),
              )
            else if (!phone)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Configurações gerais',
                      onPressed: () => setState(() => _generalOpen = true),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Ajustes da partitura',
                      onPressed: () => setState(() => _panelOpen = true),
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < kPhoneLayoutMaxWidth) {
      // O "voltar" do aparelho fecha primeiro a gaveta de opções; só com
      // ela fechada é que sai da partitura para a biblioteca.
      return PopScope(
        canPop:
            !_optionsOpen &&
            !_panelOpen &&
            !_generalOpen &&
            !_midiPanelOpen &&
            !_trailDrawerOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() {
            _optionsOpen = false;
            _panelOpen = false;
            _generalOpen = false;
            _midiPanelOpen = false;
            _trailDrawerOpen = false;
          });
        },
        child: Scaffold(backgroundColor: kSurface, body: _buildPhoneBody()),
      );
    }
    return Scaffold(
      // A barra de `Main.dc.html`: "‹ Biblioteca" à esquerda, o título do
      // hino no centro (com o número e o compositor por baixo) e o teclado
      // MIDI à direita.
      appBar: AppBar(
        backgroundColor: kPanelSideBg,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: kBorderPanel)),
        automaticallyImplyLeading: false,
        leadingWidth: 150,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              onPressed: _backToLibrary,
              style: TextButton.styleFrom(foregroundColor: kInk),
              icon: const Icon(Icons.chevron_left, size: 22),
              label: const Text(
                'Biblioteca',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: ScoreTitle(
          title: _piece.title,
          caption: _piece.number == null
              ? _piece.composer
              : '${_term.singularCapitalized} ${_piece.number} · ${_piece.composer}',
        ),
        actions: [
          ?_transposeSeal(),
          if (_piece.fifths != null)
            IconButton(
              tooltip: 'Transpor',
              onPressed: _openTransposeDialog,
              icon: const Icon(Icons.swap_vert),
            ),
          MidiDevicePickerButton(
            deviceManager: _midiDeviceManager,
            onCalibrate: () => unawaited(_openCalibration()),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.deepPurple.shade100),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildScoreArea(),
                      ),
                      if (_trailStrip() case final strip?)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: strip,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // `maxLines: 1` matters beyond truncating long text: this Text is
                // a Column sibling of the (Expanded) score area, not wrapped in
                // one itself, so its height comes out of the score area's share
                // of the fixed Column height. Left unbounded, a status message
                // long enough to wrap on a narrow (phone) width shrinks the
                // score box just past `ScoreRenderSession.setBox`'s 2% threshold, which
                // schedules a re-render — whose *own* status text then differs
                // in length from this one, flipping the wrap back and forth
                // forever. Desktop windows are wide enough that no status
                // string wraps, so this never showed up before a real phone.
                Text(
                  'status: ${_session.status}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_runner.trail != null)
                      IconButton.filledTonal(
                        tooltip: _runner.trailMode
                            ? 'Treino livre'
                            : 'Voltar à trilha',
                        onPressed: () {
                          final trail = _runner.trail;
                          if (trail != null) {
                            setState(() => trail.setFreeMode(!trail.freeMode));
                          }
                        },
                        icon: Icon(
                          _runner.trailMode
                              ? Icons.school_outlined
                              : Icons.route,
                        ),
                      ),
                    IconButton.filled(
                      tooltip: _runner.trailMode
                          ? ((_runner.trail?.running ?? false)
                                ? 'Parar etapa'
                                : 'Começar etapa')
                          : (_canTrain
                                ? (_runner.practice != null
                                      ? 'Parar prática'
                                      : 'Praticar (modo espera)')
                                : (_playback.playing
                                      ? 'Pausar'
                                      : 'Tocar (destacar notas)')),
                      onPressed: _runner.trailMode
                          ? () => unawaited(_runner.startStage())
                          : (_canTrain
                                ? () => unawaited(
                                    _runner.togglePractice(
                                      hand: _hand,
                                      mode: _practiceMode,
                                    ),
                                  )
                                : (_canPlay ? _togglePlay : null)),
                      icon: Icon(
                        _runner.trailMode
                            ? ((_runner.trail?.running ?? false)
                                  ? Icons.pause
                                  : Icons.school)
                            : (_canTrain
                                  ? (_runner.practice != null
                                        ? Icons.pause
                                        : Icons.school)
                                  : (_playback.playing
                                        ? Icons.pause
                                        : Icons.play_arrow)),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Reiniciar',
                      onPressed: _canPlay ? () => unawaited(_restart()) : null,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Parar',
                      onPressed:
                          _canPlay &&
                              (_playback.playing ||
                                  (_playback.player?.position ??
                                          Duration.zero) >
                                      Duration.zero)
                          ? _stop
                          : null,
                      icon: const Icon(Icons.stop),
                    ),
                    IconButton.filledTonal(
                      tooltip: _trainingMode
                          ? 'Desarmar modo treino (T02)'
                          : 'Armar modo treino (T02): Play vira Praticar com '
                                'teclado MIDI conectado',
                      onPressed: _toggleTrainingMode,
                      icon: Icon(
                        _trainingMode ? Icons.school : Icons.school_outlined,
                      ),
                    ),
                    if (_trainingMode && _runner.practice == null)
                      IconButton.filledTonal(
                        tooltip: switch (_practiceMode) {
                          PracticeMode.wait =>
                            'Modo espera — trocar para tempo real',
                          PracticeMode.realtime =>
                            'Tempo real — trocar para modo espera',
                        },
                        onPressed: () => setState(
                          () => _practiceMode = switch (_practiceMode) {
                            PracticeMode.wait => PracticeMode.realtime,
                            PracticeMode.realtime => PracticeMode.wait,
                          },
                        ),
                        icon: Icon(switch (_practiceMode) {
                          PracticeMode.wait => Icons.hourglass_bottom,
                          PracticeMode.realtime => Icons.speed,
                        }),
                      ),
                    if (_trainingMode && _runner.practice == null)
                      PopupMenuButton<Hand>(
                        tooltip: 'Mão do aluno',
                        initialValue: _hand,
                        onSelected: _setHand,
                        icon: const Icon(Icons.back_hand),
                        itemBuilder: (context) => [
                          for (final h in Hand.values)
                            PopupMenuItem(value: h, child: Text(h.label)),
                        ],
                      ),
                    IconButton.filledTonal(
                      tooltip: _settings.metronomeOn
                          ? 'Desligar metrônomo'
                          : 'Ligar metrônomo (com som do app)',
                      onPressed: _playback.toggleMetronome,
                      icon: Icon(
                        _settings.metronomeOn
                            ? Icons.av_timer
                            : Icons.timer_outlined,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: _playback.loop == null
                          ? 'Repetir um trecho (loop A-B)'
                          : 'Loop: compassos ${_playback.loop!.a + 1}–${_playback.loop!.b + 1}',
                      onPressed: _playback.player == null
                          ? null
                          : () => unawaited(_openLoopSheet()),
                      icon: Icon(
                        _playback.loop == null ? Icons.repeat : Icons.repeat_on,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: _sound.soundOn
                          ? 'Desligar som'
                          : _sound.output == SoundOutput.midiKeyboard
                          ? 'Ligar som (teclado MIDI conectado)'
                          : 'Ligar som (escolhe um .sf2)',
                      onPressed: _sound.loadingSoundFont
                          ? null
                          : _sound.userToggleSound,
                      icon: _engineButtonIcon(
                        _sound.soundOn ? Icons.volume_up : Icons.volume_off,
                      ),
                    ),
                    PopupMenuButton<SoundOutput>(
                      tooltip: 'Saída de som',
                      initialValue: _sound.output,
                      onSelected: (value) => _settings.output = value,
                      icon: Icon(
                        _sound.output == SoundOutput.midiKeyboard
                            ? Icons.piano
                            : Icons.graphic_eq,
                      ),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: SoundOutput.appSynth,
                          child: Text('Sintetizador do app'),
                        ),
                        PopupMenuItem(
                          value: SoundOutput.midiKeyboard,
                          child: Text('Teclado MIDI'),
                        ),
                      ],
                    ),
                    if (_sound.output == SoundOutput.midiKeyboard)
                      IconButton.filledTonal(
                        tooltip: _useScoreInstruments
                            ? 'Voltar ao timbre do teclado'
                            : 'Trocar o timbre do teclado (usa o instrumento '
                                  'da partitura)',
                        onPressed: () => _sound.setUseScoreInstruments(
                          !_useScoreInstruments,
                        ),
                        icon: Icon(
                          _useScoreInstruments
                              ? Icons.music_note
                              : Icons.music_off,
                        ),
                      ),
                    IconButton.filledTonal(
                      tooltip: _sound.midiMonitorOn
                          ? 'Desligar monitor MIDI'
                          : 'Ligar monitor MIDI (teclado sem som próprio)',
                      onPressed: _sound.loadingSoundFont
                          ? null
                          : _sound.toggleMidiMonitor,
                      icon: _engineButtonIcon(
                        _sound.midiMonitorOn
                            ? Icons.piano
                            : Icons.piano_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.speed, size: 18),
                          Expanded(
                            child: Slider(
                              min: 0.5,
                              max: 1.5,
                              divisions: 10,
                              label: '${_playback.speed.toStringAsFixed(2)}×',
                              value: _playback.speed,
                              onChanged: _canPlay ? _setSpeed : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Página anterior',
                      onPressed: _session.pageIndex > 0 && !_session.busy
                          ? _previousPage
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      _session.pageCount == 0
                          ? '—'
                          : '${_session.pageIndex + 1} / ${_session.pageCount}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Próxima página',
                      onPressed:
                          _session.pageIndex < _session.pageCount - 1 &&
                              !_session.busy
                          ? _nextPage
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (widget.debugMode) ...[
                  const SizedBox(height: 8),
                  const SoundEngineDebugPanel(),
                ],
              ],
            ),
          ),
          if (_trailDrawerOpen) _buildTrailDrawer(),
        ],
      ),
    );
  }
}
