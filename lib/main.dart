import 'dart:async';

import 'render/score_size_log.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio/audio_playback_clock.dart';
import 'audio/engine_opener.dart';
import 'audio/metronome.dart';
import 'audio/score_audio_scheduler.dart';
import 'audio/sound_engine.dart';
import 'audio/sound_engine_debug_panel.dart';
import 'audio/soundfont_store.dart';
import 'course/built_in_course.dart';
import 'layout_options.dart';
import 'layout_panel.dart';
import 'library/piece.dart';
import 'library/library_package.dart' show LibraryTerm;
import 'library/library_screen.dart';
import 'library/library_term_scope.dart';
import 'midi/midi_device_manager.dart';
import 'midi/midi_device_picker.dart';
import 'midi/midi_input_service.dart';
import 'midi/midi_monitor.dart';
import 'midi/midi_monitor_panel.dart';
import 'midi/midi_out_sound_engine.dart';
import 'music/performance_track.dart';
import 'practice/app_hand.dart';
import 'practice/count_in_overlay.dart';
import 'practice/hand.dart';
import 'practice/practice_colors.dart';
import 'practice/practice_controller.dart';
import 'practice/practice_report.dart';
import 'practice/practice_tools.dart';
import 'practice/study_mode.dart';
import 'settings/app_settings.dart';
import 'settings/general_settings_panel.dart';
import 'settings/piece_settings.dart';
import 'splash_screen.dart';
import 'trail/stage_result.dart' show StageResult, kTrailPassAccuracy;
import 'trail/trail_controller.dart';
import 'trail/trail_path.dart';
import 'trail/trail_plan.dart';
import 'trail/trail_progress.dart';
import 'trail/trail_stage.dart' show TrailPhase, TrailStage, kTrailMinMeasures;
import 'trail/trail_widgets.dart';
import 'ui/phone_chrome.dart';
import 'ui/practice_legend.dart';
import 'ui/side_panel.dart';
import 'ui/theme.dart';
import 'diag_log.dart';
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

  /// Splash de abertura (`lib/splash_screen.dart`); os testes ficam sem ela.
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
  const ScoreHomePage({super.key, this.debugMode = false, this.opened});

  /// O hino que a biblioteca abriu. `null` só nos testes de widget, que
  /// exercitam a tela sem partitura (nada nativo é tocado).
  final OpenedPiece? opened;

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
  /// Como a biblioteca chama a música (o hinário, sem partitura aberta).
  LibraryTerm get _term => widget.opened?.term ?? LibraryTerm.hymn;

  late final String? _scoreName = switch (widget.opened?.piece) {
    final piece? =>
      piece.number == null ? piece.title : '${piece.number} · ${piece.title}',
    null => null,
  };
  late final Uint8List? _scoreXml = widget.opened?.scoreXml;
  final ScoreRenderer _renderer = createScoreRenderer();
  VsbDocument? _document;
  int _pageIndex = 0;
  String _status = 'nenhuma partitura';

  /// A última gravação falhou — o celular não tem linha de status, então
  /// o motivo aparece no lugar da partitura.
  String? _renderError;
  bool _busy = false;

  /// A render was asked for while another was running; it starts as soon as
  /// that one ends, with whatever the options are by then.
  bool _renderQueued = false;

  /// Size of the score box in device pixels, from the [LayoutBuilder] in
  /// [_buildScoreArea]. The page is engraved for exactly this box, so there
  /// is nothing to render before the first layout.
  Size? _boxDevicePx;
  Timer? _resizeDebounce;

  /// Configurações gerais (som, MIDI, cores…): as da biblioteca quando ela
  /// abriu o hino; só são desta tela — e lidas e descartadas por ela —
  /// quando não vieram de fora. Ver [_onSettingsChanged].
  late final AppSettings _settings =
      widget.opened?.appSettings ?? AppSettings();

  /// O que este hino tinha guardado ao abrir (layout, andamento, mão).
  late final PieceSettings _stored =
      widget.opened?.pieceSettings ?? const PieceSettings();

  /// O layout de um hino em que nada foi mexido.
  static Map<String, Object> get _layoutDefaults =>
      initialLayoutValues(phone: _isPhone);

  /// Verovio options of this piece, by name (see `layout_options.dart`):
  /// the app's defaults with whatever was changed for it.
  late Map<String, Object> _layout = _stored.layoutOver(_layoutDefaults);

  /// Whether the page is sized from the score box ([_pageWidth] /
  /// [_pageHeight]) or from the `pageWidth`/`pageHeight` options.
  late bool _pageFitsBox = _stored.pageFitsBox;

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

  int get _pageCount => _document?.pages.length ?? 0;

  /// Note highlights. Repaints the page through its own listenable, so
  /// playback never rebuilds this widget.
  final ScoreController _controller = ScoreController();
  final GhostController _ghosts = GhostController();

  /// Page navigation and page-turn animation (sweep bar) of the [ScoreView].
  final ScoreViewController _viewController = ScoreViewController();

  /// Playback: walks the timemap, highlights notes through [_controller] and
  /// drives the page-turn sweep. Rebuilt for every new engraving.
  ScorePlayer? _player;
  bool _playing = false;

  /// Notas tocáveis da peça corrente (N03), reconstruída a cada nova
  /// gravura junto com [_player] — o que [ScoreAudioScheduler] agenda.
  PerformanceTrack? _track;

  /// Motor de áudio (K03): criado sob demanda no primeiro "ligar som", não
  /// no início do app — mudo por padrão, como antes de K04. Sobrevive a
  /// novas gravuras (só [_scheduler] é recriado, um por `.vsb`).
  ///
  /// Um motor por [SoundOutput] (M03): trocar de saída não descarta o
  /// sintetizador do app (com `.sf2` já carregado) nem o motor MIDI (que é
  /// recriado se o dispositivo conectado mudar — ver [_onMidiDeviceChanged]).
  SoundEngine? _appEngine;
  MidiOutSoundEngine? _midiOutEngine;
  SoundEngine? get _engine =>
      _output == SoundOutput.midiKeyboard ? _midiOutEngine : _appEngine;
  ScoreAudioScheduler? _scheduler;
  AudioPlaybackClock? _audioClock;

  /// Modo treino (T02): armado pelo usuário, só passa a valer no Play
  /// ("Praticar") quando também há um teclado MIDI conectado — ver
  /// [_canTrain]. [_practice] existe só enquanto a sessão de modo espera
  /// está de fato tocando.
  bool _trainingMode = false;
  late Hand _hand = _stored.hand ?? _kDefaultHand;
  static const _kDefaultHand = Hand.direita;

  /// Espera (o tempo para até o aluno tocar), ou tempo real (T03) —
  /// configuração geral.
  PracticeMode get _practiceMode => _settings.practiceMode;
  set _practiceMode(PracticeMode value) => _settings.practiceMode = value;
  PracticeController? _practice;

  /// Trilha de estudo (fase J): plano do hino, progresso e etapa selecionada.
  /// `null` sem trilha (caminho com saltos até o J08, ou partitura sem
  /// número de hino) — aí a tela abre direto no modo livre. Detalhes em
  /// `lib/trail/`.
  ///
  /// O store é o da biblioteca (a linha do hino atualiza ao voltar sem
  /// reabrir nada — J09); só é desta tela quando não veio de fora.
  late final TrailProgressStore _trailStore =
      widget.opened?.trailProgress ?? TrailProgressStore();
  TrailController? _trail;

  /// Por que não há trilha (explicação no lugar da faixa); `null` com trilha
  /// ou sem partitura.
  String? _trailUnavailable;

  /// N da trilha deste hino (`null` = o geral); começa no guardado e muda
  /// pela gaveta de opções (J06).
  int? _trailPieceN;

  /// Gaveta da trilha aberta (J06).
  bool _trailDrawerOpen = false;

  /// Acessórios de treino (T04). O loop guarda **ocorrências** de compasso
  /// (índices em `ScorePlayer.measures`, ordem de execução); metrônomo e
  /// contagem só soam com o som do app ligado (o agendador é quem clica).
  /// O metrônomo é configuração geral ([_settings]); a contagem não é
  /// escolha: tudo o que anda no tempo (play, tempo real) começa com
  /// 1 compasso dela, e o modo espera — em que o tempo espera o aluno — não.
  bool get _metronomeOn => _settings.metronomeOn;
  set _metronomeOn(bool value) => _settings.metronomeOn = value;
  ({int a, int b})? _loop;

  /// Contagem do play com o som desligado: sem agendador para contar, a
  /// tela segura o player e conta sozinha — o número e, com o sintetizador
  /// do app aberto, os cliques (a música segue muda). `null` fora dela.
  Timer? _silentCountInTimer;
  CountInTick? Function()? _silentCountIn;
  SoundEngine? _silentCountInEngine;

  /// Latência de entrada+saída calibrada para o teclado/saída correntes.
  double _inputLatencyMs = 0;

  /// Saída **em uso** (M03). A escolhida mora em [_settings]; quando ela
  /// muda, [_onSettingsChanged] troca o motor e só então atualiza esta.
  SoundOutput _output = SoundOutput.appSynth;

  /// Program Change (M03) — configuração geral.
  bool get _useScoreInstruments => _settings.useScoreInstruments;

  /// Interruptor "som" (K04): liga o agendador de áudio sobre [_player];
  /// desligado, o player volta ao próprio relógio interno (`speed`), o
  /// modo mudo de sempre.
  ///
  /// É o estado **de agora**; o que o usuário quer ao abrir um hino é
  /// `_settings.soundOn` ([_soundSetting] guarda o último valor visto, para
  /// distinguir "o usuário mexeu" de "o treino ligou o som por conta").
  bool _soundOn = false;
  bool _soundSetting = false;
  bool _autoSoundDone = false;
  bool _loadingSoundFont = false;
  final SoundFontStore _soundFonts = const SoundFontStore();

  /// O usuário escolheu um `.sf2` próprio (senão vale o TimGM6mb embutido).
  bool _customSoundFont = false;

  /// Entrada MIDI (M01): lista/conecta dispositivos e reconecta sozinho ao
  /// último escolhido; converte mensagens em [PlayedNote] para o monitor.
  /// Relógio de carimbo: o motor de áudio se já estiver ligado (mesmo
  /// instante que o áudio usa), senão este `Stopwatch`, que roda desde a
  /// abertura do app.
  final Stopwatch _appClock = Stopwatch()..start();

  ///
  /// O gerenciador de dispositivos é o da biblioteca quando ela abriu o
  /// hino (o teclado conectado lá continua conectado aqui); só é desta tela
  /// — e descartado com ela — quando não veio de fora.
  late final MidiDeviceManager _midiDeviceManager =
      widget.opened?.midiDeviceManager ?? MidiDeviceManager();
  late final MidiInputService _midiInput = FlutterMidiInputService(
    nowSeconds: () =>
        _engine?.nowSeconds ?? _appClock.elapsedMicroseconds / 1e6,
  );
  bool _midiPanelOpen = false;

  /// Monitor MIDI pelo sintetizador do app (M02): o que chega em
  /// [_midiInput] sai por [_engine] num canal reservado, para teclados
  /// controladores sem som próprio. Mesmo motor de [_toggleSound] (K04) —
  /// [_ensureEngine] pede um `.sf2` só na primeira vez, para qualquer um
  /// dos dois. Preferência guardada por dispositivo em
  /// [MidiDeviceManager].
  MidiMonitor? _midiMonitor;
  bool _midiMonitorOn = false;

  /// 0,5×–1,5×; alimenta [_scheduler] com som ligado, ou `ScorePlayer.speed`
  /// mudo (C01: o relógio externo ignora `speed`).
  late double _speed = _stored.speed ?? 1.0;

  /// Appearance, from the general settings — pure paint-time, none of them
  /// reach Verovio or reflow the score.
  Color get _highlightColor => _settings.highlightColor;
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

  bool get _canPlay => (_document?.timemap?.isNotEmpty ?? false) && !_busy;

  /// O Play vira "Praticar" (T02) só com modo treino armado **e** teclado
  /// MIDI conectado — sem dispositivo não há como o aluno tocar.
  bool get _canTrain =>
      _canPlay && _trainingMode && _midiDeviceManager.connected.value != null;

  /// Paper size, in tenths of a millimetre, that makes one device pixel one
  /// unit — i.e. the page is engraved at 254 dpi and drawn 1:1, which is the
  /// configuration `compare` measured against the reference SVG. Anything
  /// larger would show the notation shrunk, pushing stroke widths below a
  /// pixel (a 0.13 mm staff line needs ~7.7 px/mm to survive).
  Size? get _fittedPage {
    final box = _boxDevicePx;
    if (box == null) return null;
    return Size(
      box.width
          .round()
          .clamp(kVerovioMinPageWidth, kVerovioMaxPageWidth)
          .toDouble(),
      box.height
          .round()
          .clamp(kVerovioMinPageHeight, kVerovioMaxPageHeight)
          .toDouble(),
    );
  }

  int get _pageWidth =>
      _pageFitsBox ? _fittedPage!.width.round() : _layout['pageWidth'] as int;

  int get _pageHeight =>
      _pageFitsBox ? _fittedPage!.height.round() : _layout['pageHeight'] as int;

  @override
  void initState() {
    super.initState();
    _midiDeviceManager.connected.addListener(_onMidiDeviceChanged);
    // Lidos já aqui (e não na primeira vez que forem usados): é contra
    // eles que [_onSettingsChanged] compara para saber o que mudou.
    _output = _settings.output;
    _soundSetting = _settings.soundOn;
    _trailPieceN = _stored.trailMeasures;
    _settings.addListener(_onSettingsChanged);
    if (widget.opened == null) unawaited(_settings.load());
    unawaited(
      _soundFonts.hasCustom().then((v) {
        if (mounted) setState(() => _customSoundFont = v);
      }),
    );
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
  /// qualquer outro caminho: aplica ao que está vivo aqui (motor de saída,
  /// agendador, player) e redesenha.
  void _onSettingsChanged() {
    if (!mounted) return;
    if (_settings.output != _output) unawaited(_applyOutput(_settings.output));
    _midiOutEngine?.useScoreInstruments = _settings.useScoreInstruments;
    _scheduler?.metronomeOn = _settings.metronomeOn;
    // O N geral mudou e o hino usa o padrão: o corte muda junto (a trilha
    // antiga cai ao abrir, em `_setupTrail`).
    final trail = _trail;
    if (trail != null && !trail.running) {
      final effective = effectiveTrailMeasures(
        general: _settings.trailMeasures,
        piece: _trailPieceN,
      );
      if (effective != trail.plan.n ||
          !listEquals(_planPhases, _settings.trailPlanPhases) ||
          !setEquals(_planSpeeds, _settings.trailSpeeds)) {
        unawaited(_setupTrail());
      }
    }
    // No treino o player destaca na cor de "esperado agora"; a cor da
    // reprodução volta em [_endPractice].
    _player?.highlightColor = _practice == null
        ? _settings.highlightColor
        : _settings.practicePendingColor;
    _practice
      ?..correctColor = _settings.highlightColor
      ..wrongColor = _settings.practiceWrongColor
      ..pendingColor = _settings.practicePendingColor;
    if (_settings.soundOn != _soundSetting) {
      _soundSetting = _settings.soundOn;
      if (_soundSetting != _soundOn && !_loadingSoundFont) {
        unawaited(_toggleSound());
      }
    }
    setState(() {});
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
    layout: PieceSettings.layoutOverrides(_layout, _layoutDefaults),
    pageFitsBox: _pageFitsBox,
    speed: _speed == 1.0 ? null : _speed,
    hand: _hand == _kDefaultHand ? null : _hand,
    trailMeasures: trailMeasures,
  );

  void _flushPieceSettings() {
    if (_saveDebounce == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    widget.opened?.onPieceSettingsChanged(
      _pieceSettingsWith(trailMeasures: _trailPieceN),
    );
  }

  /// Maior N que o controle do hino oferece: 20, ou os compassos lógicos.
  int get _trailMaxN {
    final measures = _trail?.path.measureCount ?? 20;
    if (measures < kTrailMinMeasures) return kTrailMinMeasures;
    return measures < 20 ? measures : 20;
  }

  /// Troca o N do hino (`null` = padrão geral). Mudar o N efetivo com
  /// progresso pede confirmação e zera a trilha do hino (J06).
  Future<void> _setPieceTrailN(int? value) async {
    final opened = widget.opened;
    if (opened == null) return;
    final oldEffective = effectiveTrailMeasures(
      general: _settings.trailMeasures,
      piece: _trailPieceN,
    );
    final newEffective = effectiveTrailMeasures(
      general: _settings.trailMeasures,
      piece: value,
    );
    if (newEffective != oldEffective &&
        _trail != null &&
        _trail!.progress.done > 0 &&
        mounted) {
      final ok = await confirmTrailReset(
        context,
        title: 'Trocar o corte?',
        message: 'Isto reinicia a trilha ${_term.deste} ${_term.singular}.',
        confirmLabel: 'Trocar',
      );
      if (!ok) return;
      await _trailStore.reset(opened.piece.id);
    }
    opened.onPieceSettingsChanged(_pieceSettingsWith(trailMeasures: value));
    if (!mounted) return;
    setState(() => _trailPieceN = value);
    if (newEffective != oldEffective) unawaited(_setupTrail());
  }

  @override
  void dispose() {
    if (_isPhone) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    _listenTimer?.cancel();
    _countInPlayTimer?.cancel();
    if (_playing) unawaited(WakelockPlus.disable());
    _resizeDebounce?.cancel();
    _flushPieceSettings();
    _settings.removeListener(_onSettingsChanged);
    if (widget.opened == null) _settings.dispose();
    _silentCountInTimer?.cancel();
    _practice?.dispose();
    _trail?.removeListener(_onTrailChanged);
    _trail?.dispose();
    if (widget.opened == null) _trailStore.dispose();
    _midiDeviceManager.connected.removeListener(_onMidiDeviceChanged);
    _midiMonitor?.dispose();
    _midiInput.dispose();
    if (widget.opened == null) _midiDeviceManager.dispose();
    _scheduler?.dispose();
    unawaited(_appEngine?.dispose());
    unawaited(_midiOutEngine?.dispose());
    _player?.dispose();
    _viewController.dispose();
    _controller.dispose();
    _ghosts.dispose();
    _view.dispose();
    super.dispose();
  }

  /// Records the score box and re-engraves when it really changed.
  ///
  /// Called from `build`, so it must never call `setState` synchronously;
  /// the re-render goes through a debounce both for that and because a
  /// window drag emits a size per frame, each one an FFI render away.
  void _onBoxSize(Size devicePx) {
    final previous = _boxDevicePx;
    if (previous == devicePx) return;
    _boxDevicePx = devicePx;
    if (previous == null) {
      // First layout: the panel was built before the box was known, so it
      // is still showing no page size.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    if (_scoreXml == null) return;
    // No celular esta tela é travada em paisagem, mas abre a partir da
    // biblioteca em retrato: uma caixa mais alta que larga é só o aparelho
    // ainda girando, e gravar a partitura para ela seria trabalho jogado
    // fora (a caixa em paisagem chega logo depois).
    if (_isPhone && devicePx.height > devicePx.width) return;
    if (_document == null && !_busy) {
      // Nothing engraved yet: the piece the library opened gets its first
      // render as soon as there is a box to engrave it for.
      _resizeDebounce?.cancel();
      _resizeDebounce = Timer(Duration.zero, _renderAndShow);
      return;
    }
    // A fixed page size does not depend on the box, so a resize has nothing
    // to re-engrave.
    if (previous == null || !_pageFitsBox) return;
    // 2% of slack: a one-pixel wobble is not worth re-engraving the piece.
    final changed =
        (previous.width - devicePx.width).abs() / previous.width > 0.02 ||
        (previous.height - devicePx.height).abs() / previous.height > 0.02;
    if (!changed) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 400), _renderAndShow);
  }

  /// Fecha a partitura e volta à biblioteca (o `dispose` para o que
  /// estiver tocando).
  void _backToLibrary() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  /// Every option that reaches Verovio for the current state: the page size
  /// plus whatever differs from Verovio's defaults.
  Map<String, Object> _effectiveOptions() => {
    'pageWidth': _pageWidth,
    'pageHeight': _pageHeight,
    ...layoutOptionsToSend(_layout),
    if (widget.debugMode) 'vsbDebug': true,
  };

  /// Renders [_scoreXml] with the current options and displays it. The
  /// previous page stays on screen meanwhile, so the effect of an option can
  /// be compared at the same zoom and pan.
  Future<void> _renderAndShow() async {
    final scoreXml = _scoreXml;
    if (scoreXml == null || _boxDevicePx == null || !mounted) return;
    if (_busy) {
      _renderQueued = true;
      return;
    }

    final pageWidth = _pageWidth;
    final pageHeight = _pageHeight;
    final options = {
      ...layoutOptionsToSend(_layout),
      if (widget.debugMode) 'vsbDebug': true,
    };

    setState(() {
      _busy = true;
      _renderError = null;
      _status = 'gerando .vsb…';
    });

    try {
      final name = _scoreName ?? '';

      setState(() => _status = 'renderizando $name ($pageWidth×$pageHeight)…');

      final renderStopwatch = Stopwatch()..start();
      final rendered = await _renderer.render(
        ScoreRenderRequest(
          source: scoreXml,
          fileName: '${widget.opened?.piece.id ?? 'score'}.musicxml',
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          options: options,
        ),
      );
      final document = rendered.document;
      final debugCopyPath = rendered.debugCopyPath;
      debugPrint(
        '_renderAndShow: render($name) levou '
        '${renderStopwatch.elapsedMilliseconds}ms',
      );

      if (!mounted) return;
      // A new engraving has new ids (and possibly new pages): drop the
      // playback that belonged to the old one.
      _practice?.dispose();
      _practice = null;
      _trail?.setRunning(false);
      _cancelSilentCountIn();
      _player?.dispose();
      _player = null;
      _setPlaying(false);
      _scheduler?.dispose();
      _scheduler = null;
      _audioClock = null;
      _controller.clearAll();
      _controller.attachDocument(document);
      final hasTimemap = document.timemap?.isNotEmpty ?? false;
      final track = PerformanceTrack.fromDocument(document);
      setState(() {
        _track = track;
        _player = hasTimemap
            ? ScorePlayer(
                document: document,
                controller: _controller,
                view: _viewController,
                onEntry: _onEntry,
                barWidth: _barWidthOf(document),
                highlightColor: _highlightColor,
                // Ligadura é uma tecla só: a cadeia acende junta.
                mergeTies: true,
              )
            : null;
        final engine = _engine;
        if (_player != null && _soundOn && engine != null) {
          _attachAudio(engine, track);
        }
        _document = document;
        // New options reflow the score: the page we were on may not exist
        // any more.
        _pageIndex = _pageIndex.clamp(0, document.pages.length - 1);
        _status = document.pages.length > 1
            ? 'página ${_pageIndex + 1} de ${document.pages.length}'
            : 'carregada ✓';
        if (debugCopyPath != null) {
          _status = '$_status — .vsb salvo em $debugCopyPath';
        }
        _busy = false;
      });
      unawaited(_setupTrail());
      _restoreSound();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'erro: $e';
        _renderError = '$e';
        _busy = false;
      });
    }

    if (mounted && _renderQueued) {
      _renderQueued = false;
      unawaited(_renderAndShow());
    }
  }

  /// Monta a trilha depois de cada gravura: caminho sem repetições (J01),
  /// plano de etapas (J03, sem fase final até o J07) e progresso do hino.
  /// Sem plano (saltos) ou sem número de hino, explica e fica no livre.
  Future<void> _setupTrail() async {
    final document = _document;
    final track = _track;
    final player = _player;
    _trail?.removeListener(_onTrailChanged);
    _trail?.dispose();
    _trail = null;
    _trailUnavailable = null;
    _clearErrorMarks();
    if (!mounted) return;
    if (document == null || track == null || player == null) return;
    final pieceId = widget.opened?.piece.id;
    if (pieceId == null) {
      setState(
        () => _trailUnavailable =
            'Trilha indisponível sem uma música aberta — treino livre',
      );
      return;
    }
    final n = effectiveTrailMeasures(
      general: _settings.trailMeasures,
      piece: _trailPieceN,
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
      setState(
        () => _trailUnavailable =
            'Trilha indisponível ${_term.neste} ${_term.singular} — treino '
            'livre',
      );
      return;
    }
    var progress = await _trailStore.ensureLoaded(pieceId);
    if (!mounted || !identical(_document, document)) return;
    // O N efetivo mudou desde o guardado (pelo geral): a trilha antiga é
    // de outro corte e é descartada ao abrir (J06).
    if (progress.total > 0 && progress.n != n) {
      await _trailStore.reset(pieceId);
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
      store: _trailStore,
      pieceId: pieceId,
    );
    trail.addListener(_onTrailChanged);
    _armedStageId = null;
    setState(() => _trail = trail);
    _armTrailStage();
  }

  /// Etapas e andamentos com que o plano da trilha foi montado: mudou nas
  /// configurações, a trilha é remontada.
  List<TrailPhase> _planPhases = const [];
  Set<double> _planSpeeds = const {};

  void _onTrailChanged() {
    if (!mounted) return;
    // Trocou de etapa: as marcas de erro eram da anterior.
    if (_errorMeasureIds.isNotEmpty && _trail?.selected?.id != _errorStageId) {
      _clearErrorMarks();
    }
    setState(() {});
    _armTrailStage();
  }

  /// Compassos (ids da cena) com erro na última passagem, marcados na pauta
  /// até o próximo play, a troca de etapa ou a saída (U12).
  Set<String> _errorMeasureIds = const {};
  String? _errorStageId;

  void _markErrors(Iterable<int> occurrences) {
    final player = _player;
    if (player == null) return;
    _errorMeasureIds = {
      for (final i in occurrences)
        if (i >= 0 && i < player.measures.length) player.measures[i].id,
    };
    _errorStageId = _trail?.selected?.id;
  }

  void _clearErrorMarks() {
    if (_errorMeasureIds.isEmpty) return;
    _errorMeasureIds = const {};
    _errorStageId = null;
  }

  /// Id da etapa para a qual a partitura já foi levada (U02).
  String? _armedStageId;

  /// Com a etapa parada, a partitura mostra o primeiro compasso do trecho:
  /// ao abrir o hino e a cada troca de etapa. Não mexe com a etapa rodando,
  /// com treino em curso nem com a música tocando.
  void _armTrailStage() {
    final trail = _trail;
    final player = _player;
    if (trail == null || trail.freeMode || player == null) return;
    final stage = trail.selected;
    if (stage == null || stage.id == _armedStageId) return;
    if (trail.running || _practice != null || _playing || _busy) return;
    _armedStageId = stage.id;
    player.seek(Duration(microseconds: (stage.startMs * 1000).round()));
    // Parado: o seek acende a nota da partida na cor de reprodução (verde),
    // como se já tivesse sido tocada. Só a etapa em curso destaca notas.
    _controller.clearHighlights();
    _scheduler?.seek(stage.startMs);
  }

  String? _markedStageId;
  List<String> _markedIds = const [];
  Set<String> _markedSet = const {};

  /// Compassos do trecho da etapa selecionada, para marcar na pauta (U02).
  /// Vazio no treino livre, sem trilha e na fase final.
  List<String> _trailMarkedIds() {
    final trail = _trail;
    final player = _player;
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

  /// Todos os compassos da música, para o véu dos que não são do trecho.
  Iterable<String> _allMeasureIds(ScorePlayer player) => {
    for (final m in player.measures) m.id,
  };

  Widget? _markMeasure(BuildContext context, String id, Rect rect) {
    // Erros da última passagem: um fundo vermelho leve sobre o compasso.
    if (_errorMeasureIds.contains(id)) {
      return IgnorePointer(
        child: ColoredBox(color: kBadColor.withValues(alpha: 0.12)),
      );
    }
    if (_trailMarkedIds().isEmpty) return null;
    if (!_markedSet.contains(id)) {
      return IgnorePointer(
        child: ColoredBox(color: kSurface.withValues(alpha: 0.55)),
      );
    }
    if (_trail?.running ?? false) return null;
    // Compassos do trecho: fundo azul leve, sem barra na base.
    return IgnorePointer(
      child: ColoredBox(color: kAccent.withValues(alpha: 0.10)),
    );
  }

  /// Começa (ou para, se já está rodando) a etapa selecionada da trilha. A
  /// etapa manda nos controles enquanto roda — modo, mão, andamento,
  /// intervalo, contagem e metrônomo nas etapas com tempo — sem gravar nada:
  /// ao sair valem de novo os valores do aluno.
  Future<void> _startTrailStage() async {
    final trail = _trail;
    final track = _track;
    final player = _player;
    if (trail == null || track == null || player == null) return;
    if (trail.running) {
      _abandonTrailStage();
      return;
    }
    final stage = trail.selected;
    if (stage == null) return;
    // Sem teclado quem chama é o ouvir (`_listenTrailStage`).
    if (_midiDeviceManager.connected.value == null) return;
    _clearErrorMarks();
    _stopListening();
    final engine = await _ensureEngine();
    if (engine == null || !mounted) return;
    if (_scheduler == null || !_soundOn) {
      _attachAudio(engine, track);
    }
    final scheduler = _scheduler;
    if (scheduler == null || !mounted) return;
    // O andamento da etapa vale só nela (sem gravar no hino).
    if ((stage.speed ?? _speed) != scheduler.speed) {
      scheduler.setSpeed(stage.speed ?? _speed);
    }
    _controller.clearAll();
    // O instante de partida já acende na cor de "esperada" (e a mão do app
    // em cinza), não na da reprodução (U08).
    _paintForPractice(player, track, stage.phase.hand, stage.phase.mode);
    player.seek(Duration(microseconds: (stage.startMs * 1000).round()));
    await _loadInputLatency();
    if (!mounted) return;
    final timed = stage.speed != null;
    final gaps = trailStageGaps(trail.path, stage);
    final practice = PracticeController(
      midiInput: _midiInput,
      track: track,
      scheduler: scheduler,
      controller: _controller,
      hand: stage.phase.hand,
      ghosts: _ghosts,
      inputLatencyMs: _inputLatencyMs,
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
        if (current != null) _onTrailStageDone(current, stage);
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
    _playPlayerAfterCount(player, stage.startMs);
    // No treino, o "esperado agora" acende na cor própria, como no modo
    // livre.
    player.highlightColor = _settings.practicePendingColor;
    trail.setRunning(true);
    trail.clearResult();
    setState(() {
      _practice = practice;
      _soundOn = true;
      _setPlaying(true);
    });
  }

  bool _listening = false;
  Timer? _listenTimer;

  /// Ouvir o trecho da etapa (U03): as duas mãos, com som, no andamento da
  /// etapa (100% no modo espera), sem avaliar nada nem tocar no progresso.
  /// Para sozinho no fim e volta ao início do trecho.
  Future<void> _listenTrailStage() async {
    final trail = _trail;
    final track = _track;
    final player = _player;
    if (trail == null || track == null || player == null) return;
    if (_listening) {
      _stopListening();
      return;
    }
    final stage = trail.selected;
    if (stage == null) return;
    if (trail.running) _abandonTrailStage();
    _clearErrorMarks();
    final engine = await _ensureEngine();
    if (engine == null || !mounted || _listening) return;
    if (_scheduler == null || !_soundOn) _attachAudio(engine, track);
    final scheduler = _scheduler;
    if (scheduler == null || !mounted) return;
    _cancelSilentCountIn();
    _controller.clearAll();
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
        _stopListening();
      }
    });
    setState(() {
      _listening = true;
      _soundOn = true;
      _setPlaying(true);
    });
  }

  /// Fecha o ouvir: devolve ao agendador o que era do aluno e volta ao
  /// início do trecho. Sem efeito se não está ouvindo.
  void _stopListening() {
    if (!_listening) return;
    _listenTimer?.cancel();
    _listenTimer = null;
    _listening = false;
    final scheduler = _scheduler;
    if (scheduler != null) {
      scheduler.clearStopAt();
      scheduler.clearJumps();
      scheduler.onJump = null;
      scheduler.setSpeed(_speed);
      scheduler.metronomeOn = _settings.metronomeOn;
      scheduler.pause();
    }
    _player?.pause();
    _controller.releaseAll();
    final start = _trail?.selected?.startMs;
    if (start != null) {
      _player?.seek(Duration(microseconds: (start * 1000).round()));
      scheduler?.seek(start);
    }
    if (mounted) setState(() => _setPlaying(false));
  }

  /// O intervalo terminou por conta própria: grava, limpa e mostra o resumo
  /// da etapa (ou do bloco de reforço). Parar no meio não passa por aqui
  /// (abandono, sem registro).
  void _onTrailStageDone(PracticeController practice, TrailStage stage) {
    if (!mounted || !identical(_practice, practice)) return;
    final trail = _trail;
    final result = practice.stageResult;
    _endTrailRun();
    if (trail == null || result == null || !mounted) return;
    final blockIndex = trail.blockIndexOf(stage);
    unawaited(() async {
      if (blockIndex != null) {
        await _onTrailBlockDone(trail, blockIndex, stage, result);
        return;
      }
      await trail.recordDone(result);
      if (!mounted) return;
      setState(() => _markErrors(result.badMeasures));
      // Aprovou a final.100: concluiu a trilha (tela própria, J07).
      if (result.passed && stage.id == 'final.100') {
        final action = await showTrailConclusion(
          context,
          sidePanel: _phoneLayout,
        );
        if (!mounted) return;
        switch (action) {
          case TrailConclusionAction.library:
            _backToLibrary();
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
      final numbers = _trailBadLogical(trail, result);
      final action = await showStageSummary(
        context,
        stageRef: trailStripTextFor(
          trail.plan.segmentCount,
          stage.segment,
          stage.label,
        ),
        result: result,
        badLogical: numbers,
        isLast: trail.progress.current(trail.plan) == null,
        blockCount: blocks,
        sidePanel: _phoneLayout,
      );
      if (!mounted) return;
      switch (action) {
        case StageSummaryAction.next:
          trail.next();
        case StageSummaryAction.retry:
          trail.repeat(stage);
          unawaited(_startTrailStage());
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
  Future<void> _onTrailBlockDone(
    TrailController trail,
    int blockIndex,
    TrailStage stage,
    StageResult result,
  ) async {
    trail.recordBlockDone(blockIndex, result);
    if (!mounted) return;
    setState(() => _markErrors(result.badMeasures));
    final action = await showStageSummary(
      context,
      stageRef: stage.label,
      result: result,
      badLogical: _trailBadLogical(trail, result),
      isLast: false,
      sidePanel: _phoneLayout,
    );
    if (!mounted) return;
    switch (action) {
      case StageSummaryAction.next:
      case StageSummaryAction.train:
        break;
      case StageSummaryAction.retry:
        trail.repeat(stage);
        unawaited(_startTrailStage());
      case StageSummaryAction.skip:
        trail.skipBlock(blockIndex);
        break;
      case null:
        break;
    }
  }

  /// Compassos lógicos com erro para o resumo.
  List<int> _trailBadLogical(TrailController trail, StageResult result) {
    final numbers = <int>{};
    for (final occurrence in result.badMeasures) {
      final logical = trail.path.logicalOf(occurrence);
      if (logical != null) numbers.add(trail.path.logical[logical].number);
    }
    return numbers.toList()..sort();
  }

  /// Para a etapa no meio: sem registro e sem resumo.
  void _abandonTrailStage() {
    if (_practice == null || _trail == null) return;
    _endTrailRun();
  }

  /// Solta o que a etapa prendeu e devolve os controles do aluno (andamento
  /// do agendador, metrônomo, cor de destaque).
  void _endTrailRun() {
    final practice = _practice;
    if (practice == null) return;
    _player?.highlightColor = _highlightColor;
    _player?.highlightColorOf = null;
    _player?.skipHighlight = null;
    _countInPlayTimer?.cancel();
    _countInPlayTimer = null;
    practice.stop();
    practice.dispose();
    _practice = null;
    _scheduler?.setSpeed(_speed);
    if (_scheduler != null) _scheduler!.metronomeOn = _settings.metronomeOn;
    _player?.pause();
    _trail?.setRunning(false);
    if (mounted) setState(() => _setPlaying(false));
  }

  /// Every write to [_playing] goes through here so the screen wakelock
  /// (X01: found the phone falling asleep mid-playback) never falls out of
  /// sync with one of the several places that flip the flag.
  void _setPlaying(bool value) {
    _playing = value;
    unawaited(value ? WakelockPlus.enable() : WakelockPlus.disable());
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    _clearErrorMarks();
    if (_playing) {
      _cancelSilentCountIn();
      player.pause();
      _scheduler?.pause();
      _controller.releaseAll();
      setState(() => _setPlaying(false));
      return;
    }
    // Posição fora do loop (ou depois do fim): começa pelo trecho.
    final range = _loopRangeMs;
    if (range != null) {
      final ms = player.position.inMicroseconds / 1000;
      if (ms < range.startMs || ms >= range.endMs) {
        player.seek(Duration(microseconds: (range.startMs * 1000).round()));
      }
    }
    // Do fim, o play recomeça a música: a contagem é a do 1º compasso.
    if (player.position >= player.duration) player.seek(Duration.zero);
    if (_soundOn) {
      final fromMs = player.position.inMicroseconds / 1000;
      final scheduler = _scheduler;
      if (scheduler == null) {
        player.play();
      } else {
        scheduler.play(fromMs, speed: _speed, countIn: true);
        _playPlayerAfterCount(player, fromMs);
      }
    } else {
      _startSilentCountIn(player);
    }
    setState(() => _setPlaying(true));
  }

  /// Play sem som: faz a contagem na tela e só então solta [player] (que,
  /// mudo, anda pelo relógio próprio). Os cliques soam mesmo assim, pelo
  /// sintetizador do app, se ele já estiver aberto — e aí o número segue o
  /// relógio do áudio, para acender junto com o clique que se ouve.
  void _startSilentCountIn(ScorePlayer player) {
    final fromMs = player.position.inMicroseconds / 1000;
    final clicks = countInBeats(metronomeBeats(player.timeline), fromMs);
    if (clicks.isEmpty) {
      player.play();
      return;
    }
    final firstMs = clicks.first.ms;
    final speed = _speed;
    // Segundos desde o 1º clique (negativo enquanto ele não soa).
    double Function() elapsed;
    final engine = _appEngine;
    if (engine != null) {
      final t0 = engine.earliestScheduleSeconds;
      engine.schedule([
        for (final c in clicks) ...[
          ScheduledMidi(
            t0 + (c.ms - firstMs) / 1000 / speed,
            0x90 | kMetronomeChannel,
            c.accent ? kMetronomeAccentNote : kMetronomeNote,
            100,
          ),
          ScheduledMidi(
            t0 + (c.ms - firstMs) / 1000 / speed + 0.05,
            0x80 | kMetronomeChannel,
            c.accent ? kMetronomeAccentNote : kMetronomeNote,
            0,
          ),
        ],
      ]);
      _silentCountInEngine = engine;
      elapsed = () => engine.nowSeconds - t0;
    } else {
      final watch = Stopwatch()..start();
      elapsed = () => watch.elapsedMicroseconds / 1e6;
    }
    _silentCountIn = () =>
        countInTickAt(clicks, fromMs, firstMs + elapsed() * 1000 * speed);
    final leftSeconds = (fromMs - firstMs) / 1000 / speed - elapsed();
    _silentCountInTimer = Timer(
      Duration(microseconds: (leftSeconds * 1e6).round()),
      () {
        _silentCountInTimer = null;
        _silentCountIn = null;
        _silentCountInEngine = null;
        player.play();
      },
    );
  }

  Timer? _countInPlayTimer;

  /// Solta o player no ponto [startMs]. Com contagem inicial em curso nada
  /// fica aceso na pauta até o primeiro tempo (U09): apaga o destaque do
  /// instante de partida e o devolve, com o `seek`, quando a contagem acaba.
  void _playPlayerAfterCount(ScorePlayer player, double startMs) {
    _countInPlayTimer?.cancel();
    _countInPlayTimer = null;
    final scheduler = _scheduler;
    if (scheduler == null || !scheduler.isCountingIn) {
      player.play();
      return;
    }
    _controller.clearHighlights();
    _countInPlayTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (scheduler.isCountingIn) return;
      timer.cancel();
      _countInPlayTimer = null;
      if (!mounted || !identical(player, _player) || !_playing) return;
      player.seek(Duration(microseconds: (startMs * 1000).round()));
      player.play();
    });
  }

  /// Desiste da contagem sem som em curso (e dos cliques que ainda não
  /// soaram); devolve se havia uma (o player ainda não tinha sido solto).
  bool _cancelSilentCountIn() {
    _countInPlayTimer?.cancel();
    _countInPlayTimer = null;
    final timer = _silentCountInTimer;
    if (timer == null) return false;
    timer.cancel();
    _silentCountInEngine?.clearScheduled();
    _silentCountInTimer = null;
    _silentCountIn = null;
    _silentCountInEngine = null;
    return true;
  }

  /// Stops playback and rewinds to the start.
  void _stop() {
    if (_trail?.running == true) {
      _abandonTrailStage();
      return;
    }
    final player = _player;
    if (player == null) return;
    // `ScoreAudioScheduler.stop` reancora em 0 mas não solta o freio nem o
    // filtro de pauta do modo treino (T02) — sem isto, o próximo Play
    // ficaria preso no freio antigo.
    _endPractice();
    _cancelSilentCountIn();
    player.pause();
    player.seek(Duration.zero);
    _scheduler?.stop();
    _controller.clearAll();
    if (_playing && mounted) setState(() => _setPlaying(false));
  }

  /// Reiniciar: volta ao começo e segue como estava — tocando, recomeça de
  /// lá; parado, fica parado no começo. "Começo" é o da etapa na trilha, o
  /// do trecho em repetição no modo livre, ou o da música.
  Future<void> _restart() async {
    final player = _player;
    if (player == null) return;
    if (_trailMode) {
      final trail = _trail!;
      if (trail.running) {
        _abandonTrailStage();
        await _startTrailStage();
        return;
      }
      final stage = trail.selected;
      if (stage != null) _seekTo(stage.startMs);
      return;
    }
    if (_practice != null) {
      _stopPractice();
      await _togglePractice();
      return;
    }
    final wasPlaying = _playing;
    if (wasPlaying) _togglePlay();
    _controller.clearAll();
    _seekTo(_loopRangeMs?.startMs ?? 0);
    if (wasPlaying) _togglePlay();
  }

  /// Leva o player e o agendador de áudio (se houver) para [ms].
  void _seekTo(double ms) {
    _player?.seek(Duration(microseconds: (ms * 1000).round()));
    _scheduler?.seek(ms);
  }

  /// Arma/desarma o modo treino (T02) — só decide se o Play vira
  /// "Praticar" ([_canTrain] também exige um teclado MIDI conectado).
  /// Desarmar com uma sessão em andamento também a para.
  void _toggleTrainingMode() {
    if (_trainingMode && _practice != null) _stopPractice();
    setState(() => _trainingMode = !_trainingMode);
  }

  /// Troca a mão do aluno (T02) — o seletor só aparece armado e sem sessão
  /// em andamento ([_practice] existindo esconde o seletor).
  void _setHand(Hand hand) {
    setState(() => _hand = hand);
    _savePieceSettings();
  }

  /// "Praticar" (T02): modo espera com o app tocando a outra mão. Precisa
  /// de som ligado — o agendador que toca a mão do app é o mesmo do
  /// interruptor "som" — e abre o motor/pede um `.sf2` na primeira vez,
  /// como [_toggleSound]/[_toggleMidiMonitor] já fazem.
  Future<void> _togglePractice() async {
    if (_practice != null) {
      _stopPractice();
      return;
    }
    final track = _track;
    final player = _player;
    if (track == null || player == null) return;
    _clearErrorMarks();
    final engine = await _ensureEngine();
    if (engine == null || !mounted) return;
    if (_scheduler == null || !_soundOn) {
      _attachAudio(engine, track);
    }
    final scheduler = _scheduler;
    if (scheduler == null) return;

    _controller.clearAll();
    final range = _loopRangeMs;
    final fromMs = range?.startMs ?? 0;
    _paintForPractice(player, track, _hand, _practiceMode);
    player.seek(Duration(microseconds: (fromMs * 1000).round()));
    await _loadInputLatency();
    if (!mounted) return;
    final practice = PracticeController(
      midiInput: _midiInput,
      track: track,
      scheduler: scheduler,
      controller: _controller,
      hand: _hand,
      ghosts: _ghosts,
      inputLatencyMs: _inputLatencyMs,
      mode: _practiceMode,
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
    practice.start(fromMs: fromMs, countIn: _practiceMode != PracticeMode.wait);
    if (range != null) practice.setLoop(range.startMs, range.endMs);
    _playPlayerAfterCount(player, fromMs);
    // No treino, o "esperado agora" acende na cor própria (azul por
    // padrão): o vermelho padrão do player confundia pendente com errada.
    player.highlightColor = _settings.practicePendingColor;
    setState(() {
      _practice = practice;
      _soundOn = true;
      _setPlaying(true);
    });
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

  /// Encerra a sessão de treino: solta freio/filtro/destaques, descarta o
  /// controlador e — no tempo real, se algo foi avaliado — abre o resumo (T03).
  void _endPractice() {
    final practice = _practice;
    if (practice == null) return;
    PracticeReport? report;
    // Devolve a cor de destaque configurada (o treino usa o azul de
    // "esperado agora", ver _togglePractice).
    _player?.highlightColor = _highlightColor;
    _player?.highlightColorOf = null;
    _player?.skipHighlight = null;
    _countInPlayTimer?.cancel();
    _countInPlayTimer = null;
    if (practice.mode != PracticeMode.wait && practice.hasVerdicts) {
      practice.finish();
      report = practice.report;
    }
    practice.stop();
    practice.dispose();
    _practice = null;
    if (report != null) {
      final r = report;
      // A biblioteca guarda a melhor precisão do hino ("Pontuação").
      widget.opened?.onPracticeScore((r.accuracy * 100).round());
      if (mounted) {
        setState(
          () => _markErrors([
            for (final m in r.measures)
              if (m.errors + m.imprecise > 0) m.index,
          ]),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showSummary(r));
      });
    }
  }

  Future<void> _showSummary(PracticeReport report) => showPracticeSummary(
    context,
    report,
    legend: _practiceLegend(),
    sidePanel: _phoneLayout,
    onRepeatWorst: _repeatWorst,
  );

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

  /// Para a sessão de treino em curso e volta ao estado pausado normal —
  /// [PracticeController.stop] já solta o freio/filtro do agendador e os
  /// destaques.
  void _stopPractice() {
    if (_practice == null) return;
    _endPractice();
    _player?.pause();
    if (mounted) setState(() => _setPlaying(false));
  }

  /// The player pauses itself at the end of the piece; follow that here.
  void _onEntry(TimemapEntry entry) {
    final player = _player;
    if (player == null || !_playing) return;
    if (player.position >= player.duration) {
      _endPractice();
      _scheduler?.pause();
      _controller.releaseAll();
      if (mounted) setState(() => _setPlaying(false));
    }
  }

  /// Tocar numa nota (E02c) move o player; K04 reflete o mesmo instante no
  /// agendador de áudio, senão os dois relógios divergem.
  void _onScoreTap(String id) {
    final player = _player;
    if (player == null) return;
    if (!player.seekToElement(id)) return;
    _scheduler?.seek(player.position.inMicroseconds / 1000);
  }

  /// 0,5×–1,5×: alimenta o que estiver tocando de verdade agora — o
  /// agendador de áudio com som ligado, ou `ScorePlayer.speed` mudo.
  void _setSpeed(double value) {
    setState(() => _speed = value);
    _savePieceSettings();
    if (_soundOn) {
      _scheduler?.setSpeed(value);
    } else {
      _player?.speed = value;
    }
  }

  /// Ícone dos botões "som" e "monitor MIDI": giro de carregamento enquanto
  /// [_ensureEngine] pede o `.sf2` (motor compartilhado pelos dois).
  Widget _engineButtonIcon(IconData icon) => _loadingSoundFont
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon);

  /// Liga [_scheduler] sobre [engine]/[track] e passa o relógio de áudio ao
  /// player — chamado ao ligar o som e de novo a cada nova gravura enquanto
  /// ele já estiver ligado.
  void _attachAudio(SoundEngine engine, PerformanceTrack track) {
    // O som chegou no meio da contagem muda: daqui em diante quem manda no
    // tempo é o agendador, então o player é solto já.
    if (_cancelSilentCountIn()) _player?.play();
    final scheduler = ScoreAudioScheduler(engine: engine, track: track);
    _scheduler = scheduler;
    _audioClock = AudioPlaybackClock(scheduler);
    _player?.clock = _audioClock;
    final player = _player;
    if (player != null) scheduler.beats = metronomeBeats(player.timeline);
    scheduler.metronomeOn = _metronomeOn;
    _applyLoop();
  }

  // -------------------------------------------------------------------------
  // T04: metrônomo, contagem, loop A-B, calibração
  // -------------------------------------------------------------------------

  void _toggleMetronome() {
    setState(() => _metronomeOn = !_metronomeOn);
    _scheduler?.metronomeOn = _metronomeOn;
  }

  /// `[startMs, endMs)` do loop atual, ou `null`.
  ({double startMs, double endMs})? get _loopRangeMs {
    final loop = _loop;
    final player = _player;
    if (loop == null || player == null) return null;
    final m = player.measures;
    if (loop.b >= m.length) return null;
    return (
      startMs: m[loop.a].startMs.toDouble(),
      endMs: m[loop.b].endMs.toDouble(),
    );
  }

  /// Empurra o loop para o agendador e a sessão de treino (se existirem).
  void _applyLoop() {
    final range = _loopRangeMs;
    if (range == null) {
      _scheduler?.clearLoop();
      _practice?.clearLoop();
      return;
    }
    _scheduler?.setLoop(range.startMs, range.endMs);
    _practice?.setLoop(range.startMs, range.endMs);
  }

  Future<void> _openLoopSheet() async {
    final player = _player;
    if (player == null || player.measures.isEmpty) return;
    final chosen = await showLoopSheet(
      context,
      total: player.measures.length,
      current: player.currentMeasureIndex.value,
      initial: _loop,
      sidePanel: _phoneLayout,
      onClear: () {
        setState(() => _loop = null);
        _applyLoop();
      },
    );
    if (chosen == null || !mounted || !identical(player, _player)) return;
    _setLoop(chosen.a, chosen.b);
  }

  /// Liga o loop nos compassos `a..b` (ocorrências, 0-based) e vai ao início
  /// do trecho. Também é o que o "repetir os piores compassos" do resumo do
  /// treino (T03) chama.
  void _setLoop(int a, int b) {
    final player = _player;
    if (player == null) return;
    setState(() => _loop = (a: a, b: b));
    _applyLoop();
    final start = _loopRangeMs?.startMs ?? 0;
    player.seek(Duration(microseconds: (start * 1000).round()));
    _scheduler?.seek(start);
  }

  String get _outputKey => _output == SoundOutput.midiKeyboard ? 'midi' : 'app';

  Future<void> _loadInputLatency() async {
    final ms = await calibratedInputLatency(_midiDeviceManager, _output);
    if (mounted) setState(() => _inputLatencyMs = ms);
  }

  Future<void> _openCalibration() async {
    final device = _midiDeviceManager.connected.value;
    if (device == null) return;
    final engine = await _ensureEngine();
    if (engine == null || !mounted) return;
    final ms = await showCalibrationDialog(
      context,
      engine: engine,
      input: _midiInput,
      deviceName: device.name,
    );
    if (ms == null) return;
    await _midiDeviceManager.setInputLatencyMs(device.id, _outputKey, ms);
    if (mounted) setState(() => _inputLatencyMs = ms);
  }

  /// Interruptor "som" (K04). Desligar volta ao modo mudo de sempre
  /// (relógio interno do player); ligar abre o motor (K03) e — só na
  /// primeira vez, D-SF ainda em aberto — pede um `.sf2` ao usuário.
  Future<void> _toggleSound() async {
    if (_soundOn) {
      // Modo treino (T02) depende do agendador de som para o freio e a mão
      // do app — sem som, não há como continuar.
      _endPractice();
      _scheduler?.pause();
      _engine?.allNotesOff();
      _player?.clock = null;
      _player?.speed = _speed;
      setState(() => _soundOn = false);
      return;
    }
    final track = _track;
    if (track == null) return;
    final engine = await _ensureEngine();
    if (engine == null) return;
    _attachAudio(engine, track);
    // Já estava tocando (mudo) quando o som foi ligado: sem isto o
    // agendador ficaria parado na âncora 0 e o próximo tick do player veria
    // o relógio de áudio "voltar" para o início e daria um seek indevido.
    final player = _player;
    if (_playing && player != null) {
      _scheduler!.play(player.position.inMicroseconds / 1000, speed: _speed);
    }
    setState(() => _soundOn = true);
  }

  /// O usuário mexeu no interruptor de som desta tela: além de ligar ou
  /// desligar agora, vira a preferência geral (o próximo hino abre igual).
  Future<void> _userToggleSound() async {
    await _toggleSound();
    _soundSetting = _soundOn;
    _settings.soundOn = _soundOn;
  }

  /// Uma vez por hino, depois da primeira gravura: religa o som se ele
  /// estava ligado da última vez. Com saída no teclado MIDI e nenhum
  /// conectado, deixa quieto em vez de reclamar a cada hino aberto.
  void _restoreSound() {
    if (_autoSoundDone) return;
    _autoSoundDone = true;
    if (_soundOn) return;
    if (!_settings.soundOn) {
      // Som desligado: mesmo assim deixa o motor do app armado (dispositivo
      // aberto, `.sf2` carregado) enquanto o aluno ainda olha a partitura —
      // senão o primeiro play espera por isso. O play continua mudo até
      // alguém ligar o som. O motor MIDI não custa nada para abrir e
      // reclamaria da falta de teclado, então fica para quando for usado.
      if (_output == SoundOutput.appSynth) unawaited(_ensureEngine());
      return;
    }
    if (_output == SoundOutput.midiKeyboard &&
        _midiDeviceManager.connected.value == null) {
      return;
    }
    unawaited(_toggleSound());
  }

  /// Abre [_engine] se ainda não existir — pedindo um `.sf2` ao usuário só
  /// na primeira vez (D-SF) — e o devolve; `null` se o motor não abriu ou o
  /// usuário cancelou o `.sf2`. Compartilhado por [_toggleSound] e
  /// [_toggleMidiMonitor] (M02): é o mesmo motor que toca a partitura e o
  /// monitor.
  Future<SoundEngine?> _ensureEngine() async {
    final existing = _engine;
    if (existing != null) return existing;
    if (_output == SoundOutput.midiKeyboard) return _ensureMidiOutEngine();
    // Já abrindo (armado na entrada, ou dois pedidos seguidos): quem chega
    // depois espera a mesma abertura em vez de desistir.
    return _engineOpening ??= _openAppEngine().whenComplete(
      () => _engineOpening = null,
    );
  }

  Future<SoundEngine?>? _engineOpening;

  Future<SoundEngine?> _openAppEngine() async {
    setState(() => _loadingSoundFont = true);
    SoundEngine? engine;
    try {
      engine = await _pickEngineWithSoundFont();
    } catch (e, st) {
      debugPrint('som: erro ao iniciar: $e\n$st');
      DiagLog.log('erro', 'som: erro ao iniciar: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('som: erro ao iniciar ($e)')));
      }
      engine = null;
    } finally {
      if (mounted) setState(() => _loadingSoundFont = false);
    }
    if (engine == null) return null;
    if (!mounted) {
      // A tela fechou enquanto abria (armado na entrada): ninguém mais o
      // descartaria.
      unawaited(engine.dispose());
      return null;
    }
    DiagLog.log('som', 'motor do app aberto');
    _appEngine = engine;
    return engine;
  }

  /// Abre (ou devolve) o motor de saída MIDI (M03) sobre o dispositivo
  /// conectado em [_midiDeviceManager]; `null` sem dispositivo conectado.
  SoundEngine? _ensureMidiOutEngine() {
    final existing = _midiOutEngine;
    if (existing != null) return existing;
    final device = _midiDeviceManager.connected.value;
    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('conecte um teclado MIDI primeiro')),
      );
      return null;
    }
    final engine = MidiOutSoundEngine(
      sender: FlutterMidiSender(),
      deviceId: device.id,
      useScoreInstruments: _useScoreInstruments,
    );
    _midiOutEngine = engine;
    return engine;
  }

  /// Troca a saída de som em uso (M03) para a escolhida nas configurações
  /// gerais (que já a guardaram) — ver [_onSettingsChanged]. Se o som ou o
  /// monitor MIDI estiverem ligados, silencia a saída antiga (`allNotesOff`)
  /// e reancora o agendador/monitor na nova — se a nova saída não abrir
  /// (ex.: MIDI sem dispositivo conectado), desliga os dois.
  Future<void> _applyOutput(SoundOutput next) async {
    if (next == _output) return;
    final wasSoundOn = _soundOn;
    final wasMonitorOn = _midiMonitorOn;
    if (!wasSoundOn && !wasMonitorOn) {
      setState(() => _output = next);
      return;
    }
    _engine?.allNotesOff();
    setState(() => _output = next);
    final engine = await _ensureEngine();
    if (!mounted) return;
    if (engine == null) {
      _scheduler?.pause();
      _player?.clock = null;
      _player?.speed = _speed;
      _midiMonitor?.dispose();
      setState(() {
        _soundOn = false;
        _midiMonitor = null;
        _midiMonitorOn = false;
      });
      return;
    }
    if (wasMonitorOn) _midiMonitor?.dispose();
    final track = _track;
    final player = _player;
    setState(() {
      if (wasMonitorOn) {
        _midiMonitor = MidiMonitor(input: _midiInput, engine: engine);
      }
      if (wasSoundOn && track != null) {
        _attachAudio(engine, track);
        if (player != null) {
          _scheduler!.play(
            player.position.inMicroseconds / 1000,
            speed: _speed,
          );
        }
      }
    });
  }

  /// Interruptor "usar instrumentos da partitura" (M03): Program Change ao
  /// teclado MIDI — desligado por padrão.
  void _setUseScoreInstruments(bool value) =>
      _settings.useScoreInstruments = value;

  /// Interruptor "monitor MIDI" (M02): liga [_midiInput] a [_engine] num
  /// canal reservado, para teclados controladores sem som próprio. Guarda a
  /// escolha por dispositivo em [MidiDeviceManager].
  Future<void> _toggleMidiMonitor() async {
    if (_midiMonitorOn) {
      _disableMidiMonitor();
      return;
    }
    final engine = await _ensureEngine();
    if (engine == null) return;
    setState(() {
      _midiMonitor?.dispose();
      _midiMonitor = MidiMonitor(input: _midiInput, engine: engine);
      _midiMonitorOn = true;
    });
    final device = _midiDeviceManager.connected.value;
    if (device != null) {
      unawaited(_midiDeviceManager.setMonitorEnabled(device.id, true));
    }
  }

  void _disableMidiMonitor() {
    _midiMonitor?.dispose();
    setState(() {
      _midiMonitor = null;
      _midiMonitorOn = false;
    });
    final device = _midiDeviceManager.connected.value;
    if (device != null) {
      unawaited(_midiDeviceManager.setMonitorEnabled(device.id, false));
    }
  }

  /// Chamado a cada troca de dispositivo MIDI conectado (M01/M02): manda
  /// note-off para o que o monitor ainda considerar retido do dispositivo
  /// anterior (evita nota presa) e aplica a preferência do novo — só liga de
  /// volta sozinho se [_engine] já existir, para nunca abrir o diálogo de
  /// `.sf2` sem o usuário ter pedido.
  void _onMidiDeviceChanged() {
    DiagLog.log(
      'midi-dev',
      'conectado agora: ${_midiDeviceManager.connected.value?.name}',
    );
    _midiMonitor?.allNotesOff();
    _tearDownMidiOutEngine();
    unawaited(_syncMidiMonitorToDevice());
  }

  /// Descarta o motor de saída MIDI (M03): seu `deviceId` só vale para o
  /// dispositivo que estava conectado quando foi criado — hot-plug ou troca
  /// de dispositivo sempre pede um novo, nunca reaproveita (`allNotesOff` no
  /// `dispose`, o critério "perder a conexão" do M03). Se ele for a saída
  /// ativa, desliga o som também.
  void _tearDownMidiOutEngine() {
    final engine = _midiOutEngine;
    if (engine == null) return;
    _midiOutEngine = null;
    unawaited(engine.dispose());
    if (_output != SoundOutput.midiKeyboard || !_soundOn) return;
    _scheduler?.pause();
    _player?.clock = null;
    _player?.speed = _speed;
    if (mounted) setState(() => _soundOn = false);
  }

  Future<void> _syncMidiMonitorToDevice() async {
    final device = _midiDeviceManager.connected.value;
    final wanted = device == null
        ? false
        : await _midiDeviceManager.monitorEnabled(device.id);
    if (!mounted || _midiDeviceManager.connected.value?.id != device?.id) {
      return;
    }
    final engine = _engine;
    setState(() {
      _midiMonitor?.dispose();
      if (wanted && engine != null) {
        _midiMonitor = MidiMonitor(input: _midiInput, engine: engine);
        _midiMonitorOn = true;
      } else {
        _midiMonitor = null;
        _midiMonitorOn = false;
      }
    });
  }

  /// Abre o motor e pede um soundfont ao usuário; `null` se o motor não
  /// abriu (sem dispositivo de áudio) ou o usuário cancelou o `.sf2`.
  /// Corpo em `lib/audio/engine_opener.dart` (I09, risco 4 do I00): a tela
  /// do exercício usa o mesmo.
  Future<SoundEngine?> _pickEngineWithSoundFont() =>
      openAppSoundEngine(soundFonts: _soundFonts);

  /// Troca o `.sf2` (o TimGM6mb embutido é o padrão): guarda o escolhido e,
  /// se o motor do app já está aberto, recarrega nele na hora.
  Future<void> _chooseSoundFont() async {
    final Uint8List? bytes;
    try {
      bytes = await pickSoundFontBytes();
    } catch (e) {
      DiagLog.log('erro', 'soundfont: $e');
      return;
    }
    if (bytes == null || !mounted) return;
    try {
      await _appEngine?.loadSoundFont(bytes);
      await _soundFonts.saveCustom(bytes);
      if (mounted) setState(() => _customSoundFont = true);
    } catch (e) {
      DiagLog.log('erro', 'soundfont: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('não consegui usar esse soundfont ($e)')),
        );
      }
    }
  }

  /// Volta ao TimGM6mb embutido.
  Future<void> _resetSoundFont() async {
    try {
      await _soundFonts.clearCustom();
      await _appEngine?.loadSoundFont(await _soundFonts.load());
      if (mounted) setState(() => _customSoundFont = false);
    } catch (e) {
      DiagLog.log('erro', 'soundfont: $e');
    }
  }

  void _onPageChanged(int target) {
    if (_pageCount == 0 || !mounted) return;
    setState(() {
      _pageIndex = target;
      _status = _pageCount > 1
          ? 'página ${target + 1} de $_pageCount'
          : 'pronto ✓';
    });
  }

  void _setLayoutValue(String key, Object value) =>
      setState(() => _layout = {..._layout, key: value});

  /// A layout option of this piece settled (slider released, toggle
  /// flipped): keep it for the piece and re-engrave.
  void _commitLayout() {
    _savePieceSettings();
    _renderAndShow();
  }

  /// Back to the app's default layout — for this piece only.
  void _resetLayout() {
    setState(() {
      _layout = _layoutDefaults;
      _pageFitsBox = true;
    });
    _commitLayout();
  }

  Future<void> _copyOptions() async {
    final json = const JsonEncoder.withIndent('  ')
        .convert(_effectiveOptions());
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
    if (!training && _practice != null) _stopPractice();
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
    final n = _player?.timeline.measureCount ?? 0;
    return n == 0 ? null : n;
  }

  /// A tela da partitura está no layout de celular (`build`): resumos e
  /// seletores entram pela lateral, não como folha inferior (U18).
  bool get _phoneLayout =>
      MediaQuery.sizeOf(context).width < kPhoneLayoutMaxWidth;

  Future<void> _openMeasureJump() async {
    final player = _player;
    // Na trilha o compasso fala a numeração do caminho (a da gaveta e do
    // resumo), não a das ocorrências da música expandida (U07).
    final trail = _trailMode ? _trail : null;
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
    if (result == null || !mounted || !identical(player, _player)) return;
    final ms =
        path?.startMsOfNumber(result) ??
        player.timeline.measures[result - 1].startMs;
    player.seek(Duration(milliseconds: ms.round()));
    _scheduler?.seek(ms.toDouble());
  }

  /// Selo do canto superior: modo (espera ou tempo real) e mão.
  String get _trainingPillText {
    final hand = _hand.shortLabel.toLowerCase();
    final realtime = _practiceMode == PracticeMode.realtime;
    if (_practice != null) {
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
    final piece = widget.opened?.piece;
    return PhoneTitleBar(
      number: piece?.number,
      title: piece?.title ?? '',
      onBack: _backToLibrary,
      center: _trailChip(),
      trailing: [
        _phoneSoundButton(),
        if (_trailMode)
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
        if (_practice case final practice?)
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
      final noKeyboard = _output == SoundOutput.midiKeyboard && device == null;
      if (noKeyboard) {
        return PhoneSoundButton(
          on: false,
          tooltip: 'Som no teclado: nenhum conectado',
          onPressed: () =>
              unawaited(showMidiDevicePicker(context, _midiDeviceManager)),
        );
      }
      return PhoneSoundButton(
        on: _soundOn,
        loading: _loadingSoundFont,
        tooltip: _soundOn ? 'Som ligado' : 'Som desligado',
        onPressed: _practice != null
            ? null
            : () => unawaited(_userToggleSound()),
      );
    },
  );

  /// A trilha na barra do título do celular (U01): no lugar da faixa, que
  /// cobria o topo da pauta. No treino livre com trilha, "Treino livre" e um
  /// toque volta à trilha.
  Widget? _trailChip() {
    if (_player == null) return null;
    final unavailable = _trailUnavailable;
    if (unavailable != null && _trail == null) {
      return TrailTitleChip(text: unavailable);
    }
    final trail = _trail;
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
    if (_player == null) return null;
    final unavailable = _trailUnavailable;
    if (unavailable != null && _trail == null) {
      return _trailMessage(unavailable);
    }
    final trail = _trail;
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
      onStart: () => unawaited(_startTrailStage()),
      onStop: _abandonTrailStage,
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
  /// Os retornos falam com o `_trail` corrente (não o da construção), pois
  /// reiniciar troca o controlador com a gaveta aberta.
  Widget _buildTrailDrawer() {
    final trail = _trail;
    if (trail == null) return const SizedBox.shrink();
    return TrailDrawer(
      plan: trail.plan,
      progress: trail.progress,
      selectedId: trail.selected?.id,
      currentId: trail.progress.current(trail.plan)?.id,
      blocks: trail.blockViews,
      footer: _practiceLegend(),
      onClose: () => setState(() => _trailDrawerOpen = false),
      onSelectStage: (id) {
        // Etapa rodando: escolher outra encerra a que roda (sem registro),
        // senão a faixa mostraria a nova com o treino ainda na antiga.
        if (_trail?.running ?? false) _abandonTrailStage();
        _trail?.select(id);
        setState(() => _trailDrawerOpen = false);
      },
      onRepeatStage: trail.running
          ? null
          : (id) {
              _trail?.select(id);
              setState(() => _trailDrawerOpen = false);
              unawaited(_startTrailStage());
            },
      onSkipCurrent: () async {
        final current = _trail;
        if (current == null) return;
        if (current.running) _abandonTrailStage();
        await current.skipSelected();
        current.next();
      },
      onRestartTrail: () async {
        if (_trail?.running ?? false) _abandonTrailStage();
        final id = _trail?.pieceId;
        if (id != null) await _trailStore.reset(id);
        unawaited(_setupTrail());
      },
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

  /// Trilha no comando (faixa) em vez do treino/modo livre de hoje.
  bool get _trailMode => _trail != null && !_trail!.freeMode;

  Widget _buildPhoneBody() {
    final player = _player;
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
                  final trail = _trailMode ? _trail : null;
                  final keyboard = _midiDeviceManager.connected.value != null;
                  return PhoneRail(
                    playing: _playing,
                    onListen: trail != null && !trail.running
                        ? () => unawaited(_listenTrailStage())
                        : null,
                    listening: _listening,
                    onPlayPause: trail != null
                        ? (keyboard
                              ? () => unawaited(_startTrailStage())
                              : () => unawaited(_listenTrailStage()))
                        : (_canTrain
                              ? () => unawaited(_togglePractice())
                              : (_canPlay ? _togglePlay : null)),
                    playTooltip: trail != null
                        ? (trail.running
                              ? 'Parar etapa'
                              : (keyboard
                                    ? 'Começar etapa'
                                    : (_listening
                                          ? 'Parar de ouvir'
                                          : 'Ouvir o trecho')))
                        : (_canTrain
                              ? (_practice != null ? 'Pausar' : 'Praticar')
                              : null),
                    playIcon: trail != null
                        ? (trail.running
                              ? null
                              : Icon(
                                  _listening ? Icons.stop : Icons.play_arrow,
                                  size: 24,
                                ))
                        : (_canTrain && _practice == null
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
                    tempoPercent: (_speed * 100).round(),
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
    final trailActive = _trailMode;
    return PhoneOptionsDrawer(
      mode: StudyMode.of(training: _trainingMode, mode: _practiceMode),
      onModeChanged: _practice != null ? null : _setStudyMode,
      trailMode: trailActive,
      hand: _hand,
      onHandChanged: _setHand,
      tempoPercent: (_speed * 100).round(),
      onTempoChanged: (v) => _setSpeed(v / 100),
      onClose: () => setState(() => _optionsOpen = false),
      // A trilha vem primeiro: na trilha a gaveta abre por ela, e no treino
      // livre "Voltar à trilha" fica no topo, à vista (U11).
      top: [
        if (_trail != null) ...[
          const PhoneSectionLabel('TRILHA'),
          PhoneActionRow(
            icon: trailActive ? Icons.school_outlined : Icons.route,
            label: trailActive ? 'Treino livre' : 'Voltar à trilha',
            onTap: () {
              final trail = _trail;
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
            value: _metronomeOn,
            onChanged: (_) => _toggleMetronome(),
          ),
          PhoneActionRow(
            icon: Icons.repeat,
            label: _loop == null
                ? 'Repetir um trecho'
                : 'Trecho: compassos ${_loop!.a + 1}–${_loop!.b + 1} — mudar',
            onTap: _player == null
                ? null
                : () {
                    setState(() => _optionsOpen = false);
                    unawaited(_openLoopSheet());
                  },
          ),
        ],
        // O que é só deste hino: cada um guarda o seu tamanho e layout.
        PhoneSectionLabel('${_term.este} ${_term.singular}'.toUpperCase()),
        if (widget.opened != null) ...[
          PhoneToggleRow(
            label: 'Trechos de ${_settings.trailMeasures} compassos (padrão)',
            value: _trailPieceN == null,
            onChanged: (v) =>
                unawaited(_setPieceTrailN(v ? null : _settings.trailMeasures)),
          ),
          if (_trailPieceN case final pieceN?)
            TrailNSelector(
              value: pieceN,
              max: _trailMaxN,
              onChanged: (v) => unawaited(_setPieceTrailN(v)),
            ),
        ],
        PhoneSliderRow(
          label: 'TAMANHO DA NOTAÇÃO',
          value: (_layout['unit']! as num).toDouble(),
          min: 4.5,
          max: 12,
          divisions: 15,
          formatValue: (v) => v.toStringAsFixed(1),
          onChanged: (v) => _setLayoutValue('unit', v),
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
          onTap: _pageIndex > 0 && !_busy ? _viewController.previousPage : null,
          trailing: Text(
            _pageCount == 0 ? '—' : '${_pageIndex + 1} / $_pageCount',
            style: const TextStyle(fontSize: 13, color: kInkCaption),
          ),
        ),
        PhoneActionRow(
          icon: Icons.chevron_right,
          label: 'Próxima página',
          onTap: _pageIndex < _pageCount - 1 && !_busy
              ? _viewController.nextPage
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
  bool get _timedPractice => _practice?.mode == PracticeMode.realtime;

  Widget _buildScoreArea({bool phone = false}) {
    // The page is engraved for this box, so its size has to be known before
    // the first render — hence measuring here rather than off the window.
    // Everything drawn over the score (zoom, panel) is a Stack child, so it
    // never changes this box and never re-engraves the piece.
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        _onBoxSize(constraints.biggest * dpr);
        _viewport = constraints.biggest;

        final document = _document;
        final hasPage = document != null && document.pages.isNotEmpty;
        final Widget content = hasPage
            // InteractiveViewer gives its child unbounded room, so the
            // view is pinned to the score box.
            ? SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: ScoreSizeLog(
                  label: 'hino ${widget.opened?.piece.id ?? _scoreName ?? '?'}',
                  document: document,
                  child: ScoreView(
                    document: document,
                    controller: _controller,
                    viewController: _viewController,
                    curtain: _player?.curtain,
                    mode: ScorePageMode.pagedSweep,
                    initialPage: _pageIndex.clamp(0, document.pages.length - 1),
                    onPageChanged: _onPageChanged,
                    onElementTap: _onScoreTap,
                    ghosts: _ghosts,
                    overlayIds:
                        (_trailMarkedIds().isEmpty &&
                                _errorMeasureIds.isEmpty) ||
                            _player == null
                        ? const []
                        : _allMeasureIds(_player!),
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
                            milliseconds: (300 * (_scheduler?.speed ?? 1))
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
                    switch (_renderError) {
                      final error? =>
                        'Não deu para abrir ${_term.o} ${_term.singular}: $error',
                      null => _scoreName ?? '',
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
                active: _playing,
                read: () => _silentCountIn?.call() ?? _scheduler?.countInTick,
              ),
            ),
            if (_busy)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
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
                  wrong: _practice?.wrongPitches,
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
                  values: _layout,
                  pageFitsBox: _pageFitsBox,
                  fittedPage: _fittedPage,
                  onChanged: _setLayoutValue,
                  onCommit: _commitLayout,
                  onFitChanged: (v) {
                    setState(() => _pageFitsBox = v);
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
                  customSoundFont: _customSoundFont,
                  onChooseSoundFont: () => unawaited(_chooseSoundFont()),
                  onResetSoundFont: () => unawaited(_resetSoundFont()),
                  onClose: () => setState(() => _generalOpen = false),
                  live: LiveSettingsActions(
                    busy: _loadingSoundFont,
                    monitorOn: _midiMonitorOn,
                    onMonitorChanged: (_) => unawaited(_toggleMidiMonitor()),
                    inputLatencyMs: _inputLatencyMs,
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
        title: switch (widget.opened?.piece) {
          final piece? => ScoreTitle(
            title: piece.title,
            caption: piece.number == null
                ? piece.composer
                : '${_term.singularCapitalized} ${piece.number} · ${piece.composer}',
          ),
          null => const ScoreTitle(title: 'nenhuma partitura'),
        },
        actions: [
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
                // score box just past `_onBoxSize`'s 2% threshold, which
                // schedules a re-render — whose *own* status text then differs
                // in length from this one, flipping the wrap back and forth
                // forever. Desktop windows are wide enough that no status
                // string wraps, so this never showed up before a real phone.
                Text(
                  'status: $_status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_trail != null)
                      IconButton.filledTonal(
                        tooltip: _trailMode
                            ? 'Treino livre'
                            : 'Voltar à trilha',
                        onPressed: () {
                          final trail = _trail;
                          if (trail != null) {
                            setState(() => trail.setFreeMode(!trail.freeMode));
                          }
                        },
                        icon: Icon(
                          _trailMode ? Icons.school_outlined : Icons.route,
                        ),
                      ),
                    IconButton.filled(
                      tooltip: _trailMode
                          ? ((_trail?.running ?? false)
                                ? 'Parar etapa'
                                : 'Começar etapa')
                          : (_canTrain
                                ? (_practice != null
                                      ? 'Parar prática'
                                      : 'Praticar (modo espera)')
                                : (_playing
                                      ? 'Pausar'
                                      : 'Tocar (destacar notas)')),
                      onPressed: _trailMode
                          ? () => unawaited(_startTrailStage())
                          : (_canTrain
                                ? () => unawaited(_togglePractice())
                                : (_canPlay ? _togglePlay : null)),
                      icon: Icon(
                        _trailMode
                            ? ((_trail?.running ?? false)
                                  ? Icons.pause
                                  : Icons.school)
                            : (_canTrain
                                  ? (_practice != null
                                        ? Icons.pause
                                        : Icons.school)
                                  : (_playing
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
                              (_playing ||
                                  (_player?.position ?? Duration.zero) >
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
                    if (_trainingMode && _practice == null)
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
                    if (_trainingMode && _practice == null)
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
                      tooltip: _metronomeOn
                          ? 'Desligar metrônomo'
                          : 'Ligar metrônomo (com som do app)',
                      onPressed: _toggleMetronome,
                      icon: Icon(
                        _metronomeOn ? Icons.av_timer : Icons.timer_outlined,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: _loop == null
                          ? 'Repetir um trecho (loop A-B)'
                          : 'Loop: compassos ${_loop!.a + 1}–${_loop!.b + 1}',
                      onPressed: _player == null
                          ? null
                          : () => unawaited(_openLoopSheet()),
                      icon: Icon(
                        _loop == null ? Icons.repeat : Icons.repeat_on,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: _soundOn
                          ? 'Desligar som'
                          : _output == SoundOutput.midiKeyboard
                          ? 'Ligar som (teclado MIDI conectado)'
                          : 'Ligar som (escolhe um .sf2)',
                      onPressed: _loadingSoundFont ? null : _userToggleSound,
                      icon: _engineButtonIcon(
                        _soundOn ? Icons.volume_up : Icons.volume_off,
                      ),
                    ),
                    PopupMenuButton<SoundOutput>(
                      tooltip: 'Saída de som',
                      initialValue: _output,
                      onSelected: (value) => _settings.output = value,
                      icon: Icon(
                        _output == SoundOutput.midiKeyboard
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
                    if (_output == SoundOutput.midiKeyboard)
                      IconButton.filledTonal(
                        tooltip: _useScoreInstruments
                            ? 'Voltar ao timbre do teclado'
                            : 'Trocar o timbre do teclado (usa o instrumento '
                                  'da partitura)',
                        onPressed: () =>
                            _setUseScoreInstruments(!_useScoreInstruments),
                        icon: Icon(
                          _useScoreInstruments
                              ? Icons.music_note
                              : Icons.music_off,
                        ),
                      ),
                    IconButton.filledTonal(
                      tooltip: _midiMonitorOn
                          ? 'Desligar monitor MIDI'
                          : 'Ligar monitor MIDI (teclado sem som próprio)',
                      onPressed: _loadingSoundFont ? null : _toggleMidiMonitor,
                      icon: _engineButtonIcon(
                        _midiMonitorOn ? Icons.piano : Icons.piano_outlined,
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
                              label: '${_speed.toStringAsFixed(2)}×',
                              value: _speed,
                              onChanged: _canPlay ? _setSpeed : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Página anterior',
                      onPressed: _pageIndex > 0 && !_busy
                          ? _viewController.previousPage
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      _pageCount == 0 ? '—' : '${_pageIndex + 1} / $_pageCount',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Próxima página',
                      onPressed: _pageIndex < _pageCount - 1 && !_busy
                          ? _viewController.nextPage
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
