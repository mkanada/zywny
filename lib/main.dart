import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio/audio_playback_clock.dart';
import 'audio/metronome.dart';
import 'audio/score_audio_scheduler.dart';
import 'audio/sound_engine.dart';
import 'audio/sound_engine_debug_panel.dart';
import 'audio/sound_engine_factory.dart';
import 'audio/soundfont_store.dart';
import 'layout_options.dart';
import 'layout_panel.dart';
import 'midi/midi_device_manager.dart';
import 'midi/midi_device_picker.dart';
import 'midi/midi_input_service.dart';
import 'midi/midi_monitor.dart';
import 'midi/midi_monitor_panel.dart';
import 'midi/midi_out_sound_engine.dart';
import 'music/performance_track.dart';
import 'native_paths.dart';
import 'practice/hand.dart';
import 'practice/practice_colors.dart';
import 'practice/practice_controller.dart';
import 'practice/practice_report.dart';
import 'practice/practice_tools.dart';
import 'splash_screen.dart';
import 'ui/phone_chrome.dart';
import 'ui/theme.dart';
import 'diag_log.dart';
import 'verovio_render.dart';
import 'verovio_resources.dart';

/// Saída de som (K03/M03): o sintetizador do app (`.sf2`) ou o teclado MIDI
/// conectado, tocando no som próprio do piano digital do usuário.
enum SoundOutput { appSynth, midiKeyboard }

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await DiagLog.init();
  // Liberation Serif (the `t` runs of the scene, §5.4) ships inside
  // score_bridge and has to be registered before the first paint —
  // otherwise the engine falls back to a system serif without warning.
  await loadScoreFonts();
  runApp(MyApp(debugMode: args.contains('--debug'), splash: true));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.debugMode = false, this.splash = false});

  final bool debugMode;

  /// Splash de abertura (`lib/splash_screen.dart`); os testes ficam sem ela.
  final bool splash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zywny • partitura → .vsb',
      theme: buildAppTheme(),
      home: SplashOverlay(
        enabled: splash,
        child: ScoreHomePage(debugMode: debugMode),
      ),
    );
  }
}

class ScoreHomePage extends StatefulWidget {
  const ScoreHomePage({super.key, this.debugMode = false});

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
  String? _scoreName;
  String? _inputPath;
  VsbDocument? _document;
  int _pageIndex = 0;
  String _status = 'abra uma partitura (.mei, .musicxml, .mxml)';
  bool _busy = false;

  /// A render was asked for while another was running; it starts as soon as
  /// that one ends, with whatever the options are by then.
  bool _renderQueued = false;

  /// Size of the score box in device pixels, from the [LayoutBuilder] in
  /// [_buildScoreArea]. The page is engraved for exactly this box, so there
  /// is nothing to render before the first layout.
  Size? _boxDevicePx;
  Timer? _resizeDebounce;

  /// Verovio options being tried, by name (see `layout_options.dart`).
  Map<String, Object> _layout = initialLayoutValues(phone: _isPhone);

  /// Whether the page is sized from the score box ([_pageWidth] /
  /// [_pageHeight]) or from the `pageWidth`/`pageHeight` options.
  bool _pageFitsBox = true;
  bool _panelOpen = false;

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
  Hand _hand = Hand.direita;

  /// Espera (o tempo para até o aluno tocar) ou tempo real (T03).
  PracticeMode _practiceMode = PracticeMode.wait;
  PracticeController? _practice;

  /// Acessórios de treino (T04). O loop guarda **ocorrências** de compasso
  /// (índices em `ScorePlayer.measures`, ordem de execução); metrônomo e
  /// contagem só soam com o som do app ligado (o agendador é quem clica).
  bool _metronomeOn = false;
  bool _countInOn = false;
  ({int a, int b})? _loop;

  /// Latência de entrada+saída calibrada para o teclado/saída correntes.
  double _inputLatencyMs = 0;

  /// Saída escolhida (M03) e preferência de Program Change, persistidas em
  /// [SharedPreferencesAsync] — carregadas em [initState].
  final SharedPreferencesAsync _outputPrefs = SharedPreferencesAsync();
  static const _kOutputPrefKey = 'sound_output';
  static const _kUseScoreInstrumentsPrefKey = 'sound_use_score_instruments';
  SoundOutput _output = SoundOutput.appSynth;

  /// Program Change (M03): manda o instrumento da partitura ao teclado MIDI
  /// só se ligado — desligado por padrão, o usuário quer o som do próprio
  /// piano.
  bool _useScoreInstruments = false;

  /// Interruptor "som" (K04): liga o agendador de áudio sobre [_player];
  /// desligado, o player volta ao próprio relógio interno (`speed`), o
  /// modo mudo de sempre.
  bool _soundOn = false;
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
  final MidiDeviceManager _midiDeviceManager = MidiDeviceManager();
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
  double _speed = 1.0;

  /// Appearance, set from the "Opções" panel — pure paint-time settings, none
  /// of them reach Verovio or reflow the score.
  Color _highlightColor = kDefaultHighlightColor;
  double _haloWidth = 1.0;
  Color _barColor = kDefaultBarColor;

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
    unawaited(_loadOutputPrefs());
    unawaited(
      _soundFonts.hasCustom().then((v) {
        if (mounted) setState(() => _customSoundFont = v);
      }),
    );
    // A partitura é para ler em paisagem no celular (a biblioteca, em
    // retrato, ainda não existe no app real); no desktop isto não vale nada.
    if (_isPhone) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    }
  }

  Future<void> _loadOutputPrefs() async {
    final outputName = await _outputPrefs.getString(_kOutputPrefKey);
    final useScoreInstruments = await _outputPrefs.getBool(
      _kUseScoreInstrumentsPrefKey,
    );
    if (!mounted) return;
    setState(() {
      _output = SoundOutput.values.firstWhere(
        (v) => v.name == outputName,
        orElse: () => SoundOutput.appSynth,
      );
      _useScoreInstruments = useScoreInstruments ?? false;
    });
  }

  @override
  void dispose() {
    if (_playing) unawaited(WakelockPlus.disable());
    _resizeDebounce?.cancel();
    _practice?.dispose();
    _midiDeviceManager.connected.removeListener(_onMidiDeviceChanged);
    _midiMonitor?.dispose();
    _midiInput.dispose();
    _midiDeviceManager.dispose();
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
      // is still showing no page size. Nothing to re-render yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    // A fixed page size does not depend on the box, so a resize has nothing
    // to re-engrave.
    if (_inputPath == null || !_pageFitsBox) return;
    // 2% of slack: a one-pixel wobble is not worth re-engraving the piece.
    final changed =
        (previous.width - devicePx.width).abs() / previous.width > 0.02 ||
        (previous.height - devicePx.height).abs() / previous.height > 0.02;
    if (!changed) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 400), _renderAndShow);
  }

  Future<void> _abrirPartitura() async {
    if (_busy) return;
    // Extension filtering can come back empty on Android (SAF matches by
    // MIME type, which these extensions don't map to) — skip the filter
    // there rather than have the picker appear to show nothing (X01).
    final typeGroup = Platform.isAndroid
        ? const XTypeGroup(label: 'partituras')
        : const XTypeGroup(
            label: 'partituras',
            extensions: ['mei', 'musicxml', 'mxml', 'mxl', 'xml'],
          );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    if (!mounted) return;

    final inputPath = await _readablePath(file);
    if (!mounted) return;

    _view.value = Matrix4.identity();
    setState(() {
      _inputPath = inputPath;
      _scoreName = file.name;
      _pageIndex = 0;
    });
    await _renderAndShow();
  }

  /// The FFI render call needs a real path on disk. On Android, `file_selector`
  /// goes through the Storage Access Framework and `file.path` can be a
  /// content:// URI or an unreadable cache path (X01) — copy the bytes to a
  /// temp file when that happens. Elsewhere `file.path` is already a normal
  /// path.
  Future<String> _readablePath(XFile file) async {
    if (!Platform.isAndroid || await File(file.path).exists()) return file.path;
    final tmpDir = await Directory.systemTemp.createTemp('zywny_open');
    final tmpFile = File('${tmpDir.path}/${file.name}');
    await tmpFile.writeAsBytes(await file.readAsBytes());
    return tmpFile.path;
  }

  /// Every option that reaches Verovio for the current state: the page size
  /// plus whatever differs from Verovio's defaults.
  Map<String, Object> _effectiveOptions() => {
    'pageWidth': _pageWidth,
    'pageHeight': _pageHeight,
    ...layoutOptionsToSend(_layout),
    if (widget.debugMode) 'vsbDebug': true,
  };

  /// Renders [_inputPath] with the current options and displays it. The
  /// previous page stays on screen meanwhile, so the effect of an option can
  /// be compared at the same zoom and pan.
  Future<void> _renderAndShow() async {
    final inputPath = _inputPath;
    if (inputPath == null || _boxDevicePx == null || !mounted) return;
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
      _status = 'gerando .vsb…';
    });

    Directory? tmpDir;
    try {
      tmpDir = await Directory.systemTemp.createTemp('zywny');
      final outPath = '${tmpDir.path}/score.vsb';
      final name = _scoreName ?? '';

      setState(() => _status = 'renderizando $name ($pageWidth×$pageHeight)…');

      final renderStopwatch = Stopwatch()..start();
      final document = await renderScoreToVsb(
        VsbRenderRequest(
          inputPath: inputPath,
          outputPath: outPath,
          libraryPath: findVerovioLibrary(),
          resourcePath: await verovioResourcePath(),
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          options: options,
        ),
      );
      debugPrint(
        '_renderAndShow: renderScoreToVsb($name) levou '
        '${renderStopwatch.elapsedMilliseconds}ms',
      );

      // `--debug` (widget.debugMode): o .vsb some com o tmpDir no `finally`
      // abaixo, então guardamos uma cópia no diretório corrente antes disso,
      // com data/hora no nome para achar depois.
      String? debugCopyPath;
      if (widget.debugMode) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(
          RegExp(r'[:.]'),
          '-',
        );
        debugCopyPath = '${Directory.current.path}/score_$timestamp.vsb';
        await File(outPath).copy(debugCopyPath);
      }

      if (!mounted) return;
      // A new engraving has new ids (and possibly new pages): drop the
      // playback that belonged to the old one.
      _practice?.dispose();
      _practice = null;
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
                highlightColor: _highlightColor,
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'erro: $e';
        _busy = false;
      });
    } finally {
      // The .vsb is fully in memory by now; one temp dir per render adds up
      // fast when trying options.
      unawaited(tmpDir?.delete(recursive: true).then((_) {}, onError: (_) {}));
    }

    if (mounted && _renderQueued) {
      _renderQueued = false;
      unawaited(_renderAndShow());
    }
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
    if (_playing) {
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
    player.play();
    _scheduler?.play(
      player.position.inMicroseconds / 1000,
      speed: _speed,
      countIn: _countInOn,
    );
    setState(() => _setPlaying(true));
  }

  /// Stops playback and rewinds to the start.
  void _stop() {
    final player = _player;
    if (player == null) return;
    // `ScoreAudioScheduler.stop` reancora em 0 mas não solta o freio nem o
    // filtro de pauta do modo treino (T02) — sem isto, o próximo Play
    // ficaria preso no freio antigo.
    _endPractice();
    player.pause();
    player.seek(Duration.zero);
    _scheduler?.stop();
    _controller.clearAll();
    if (_playing && mounted) setState(() => _setPlaying(false));
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
  void _setHand(Hand hand) => setState(() => _hand = hand);

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
      magicEngine: _practiceMode == PracticeMode.rhythm ? engine : null,
      measureIndexAt: player.timeline.measureIndexAt,
      passOf: (i) => player.measures[i].pass,
      onLoopRestart: (ms) =>
          player.seek(Duration(microseconds: (ms * 1000).round())),
    );
    _midiMonitor?.muted = _practiceMode == PracticeMode.rhythm;
    practice.start(fromMs: fromMs, countIn: _countInOn);
    if (range != null) practice.setLoop(range.startMs, range.endMs);
    player.play();
    // No treino, o "esperado agora" acende em azul (kPracticePendingColor):
    // o vermelho padrão do player confundia pendente com errada.
    player.highlightColor = kPracticePendingColor;
    setState(() {
      _practice = practice;
      _soundOn = true;
      _setPlaying(true);
    });
  }

  /// Encerra a sessão de treino: solta freio/filtro/destaques, descarta o
  /// controlador e — no tempo real, se algo foi avaliado — abre o resumo (T03).
  void _endPractice() {
    final practice = _practice;
    if (practice == null) return;
    PracticeReport? report;
    _midiMonitor?.muted = false;
    // Devolve a cor de destaque configurada (o treino usa o azul de
    // "esperado agora", ver _togglePractice).
    _player?.highlightColor = _highlightColor;
    if (practice.mode != PracticeMode.wait && practice.hasVerdicts) {
      practice.finish();
      report = practice.report;
    }
    practice.stop();
    practice.dispose();
    _practice = null;
    if (report != null) {
      final r = report;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showSummary(r));
      });
    }
  }

  Future<void> _showSummary(PracticeReport report) =>
      showPracticeSummary(context, report, onRepeatWorst: _repeatWorst);

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

  void _toggleCountIn() => setState(() => _countInOn = !_countInOn);

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
    final device = _midiDeviceManager.connected.value;
    final ms = device == null
        ? null
        : await _midiDeviceManager.inputLatencyMs(device.id, _outputKey);
    if (mounted) setState(() => _inputLatencyMs = ms ?? 0);
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

  /// Abre [_engine] se ainda não existir — pedindo um `.sf2` ao usuário só
  /// na primeira vez (D-SF) — e o devolve; `null` se o motor não abriu ou o
  /// usuário cancelou o `.sf2`. Compartilhado por [_toggleSound] e
  /// [_toggleMidiMonitor] (M02): é o mesmo motor que toca a partitura e o
  /// monitor.
  Future<SoundEngine?> _ensureEngine() async {
    final existing = _engine;
    if (existing != null) return existing;
    if (_output == SoundOutput.midiKeyboard) return _ensureMidiOutEngine();
    if (_loadingSoundFont) return null;
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
    if (engine == null || !mounted) return null;
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

  /// Troca a saída de som (M03), persistindo a escolha. Se o som ou o
  /// monitor MIDI estiverem ligados, silencia a saída antiga (`allNotesOff`)
  /// e reancora o agendador/monitor na nova — se a nova saída não abrir
  /// (ex.: MIDI sem dispositivo conectado), desliga os dois.
  Future<void> _setOutput(SoundOutput next) async {
    if (next == _output) return;
    unawaited(_outputPrefs.setString(_kOutputPrefKey, next.name));
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
  void _setUseScoreInstruments(bool value) {
    setState(() => _useScoreInstruments = value);
    _midiOutEngine?.useScoreInstruments = value;
    unawaited(_outputPrefs.setBool(_kUseScoreInstrumentsPrefKey, value));
  }

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
  Future<SoundEngine?> _pickEngineWithSoundFont() async {
    final engine = createSoundEngine();
    await engine.start();
    await engine.loadSoundFont(await _soundFonts.load());
    return engine;
  }

  /// Troca o `.sf2` (o TimGM6mb embutido é o padrão): guarda o escolhido e,
  /// se o motor do app já está aberto, recarrega nele na hora.
  Future<void> _chooseSoundFont() async {
    const typeGroup = XTypeGroup(label: 'soundfont', extensions: ['sf2']);
    final file = await openFile(
      acceptedTypeGroups: [
        if (!Platform.isAndroid)
          typeGroup
        else
          const XTypeGroup(label: 'soundfont'),
      ],
    );
    if (file == null || !mounted) return;
    try {
      final bytes = await file.readAsBytes();
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

  /// Only the **next** note to light up gets the new color — [ScorePlayer]
  /// doesn't recolor one that's already animating.
  void _setHighlightColor(Color color) {
    setState(() => _highlightColor = color);
    _player?.highlightColor = color;
  }

  void _resetLayout() {
    setState(() {
      _layout = initialLayoutValues(phone: _isPhone);
      _pageFitsBox = true;
    });
    _renderAndShow();
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

  /// Compasso (base 1) e total para a barra lateral; `null` sem partitura.
  int? get _measureCount {
    final n = _player?.timeline.measureCount ?? 0;
    return n == 0 ? null : n;
  }

  Future<void> _openMeasureJump() async {
    final player = _player;
    final total = _measureCount;
    if (player == null || total == null) return;
    var target = player.currentMeasureIndex.value + 1;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: kSurface,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                  activeColor: kAccent,
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
      ),
    );
    if (result == null || !mounted || !identical(player, _player)) return;
    final ms = player.timeline.measures[result - 1].startMs;
    player.seek(Duration(milliseconds: ms.round()));
    _scheduler?.seek(ms.toDouble());
  }

  /// Selo do canto superior: modo (espera ou tempo real) e mão.
  String get _trainingPillText {
    final hand = _hand.shortLabel.toLowerCase();
    final realtime = _practiceMode == PracticeMode.realtime;
    if (_practiceMode == PracticeMode.rhythm) {
      if (_practice == null && _midiDeviceManager.connected.value == null) {
        return 'Conecte o teclado MIDI';
      }
      return 'Ritmo · mão $hand';
    }
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
                  child: _buildScoreArea(phone: true),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: player?.currentMeasureIndex ?? _noMeasure,
                builder: (context, index, _) => PhoneRail(
                  playing: _playing,
                  onPlayPause: _canTrain
                      ? () => unawaited(_togglePractice())
                      : (_canPlay ? _togglePlay : null),
                  playTooltip: _canTrain
                      ? (_practice != null ? 'Pausar' : 'Praticar')
                      : null,
                  playIcon: _canTrain && _practice == null
                      ? const Icon(Icons.play_arrow, size: 24)
                      : null,
                  measure: _measureCount == null ? null : index + 1,
                  totalMeasures: _measureCount,
                  onMeasureTap: _measureCount == null ? null : _openMeasureJump,
                  tempoPercent: (_speed * 100).round(),
                  handLabel: _hand.shortLabel,
                  onOptions: () => setState(() => _optionsOpen = true),
                ),
              ),
            ],
          ),
        ),
        if (_optionsOpen) _buildOptionsDrawer(),
      ],
    );
  }

  final ValueNotifier<int> _noMeasure = ValueNotifier(0);

  /// Celular de verdade (não só janela estreita): começa com [kPhoneUnit].
  static final bool _isPhone = Platform.isAndroid || Platform.isIOS;

  Widget _buildOptionsDrawer() {
    return PhoneOptionsDrawer(
      training: _trainingMode,
      onTrainingChanged: _setTrainingFromDrawer,
      hand: _hand,
      onHandChanged: _setHand,
      tempoPercent: (_speed * 100).round(),
      onTempoChanged: (v) => _setSpeed(v / 100),
      onClose: () => setState(() => _optionsOpen = false),
      children: [
        const PhoneSectionLabel('TREINO'),
        PhoneToggleRow(
          label: 'Tempo real (a música não espera)',
          value: _practiceMode == PracticeMode.realtime,
          onChanged: _practice != null
              ? null
              : (v) => setState(
                  () => _practiceMode = v
                      ? PracticeMode.realtime
                      : PracticeMode.wait,
                ),
        ),
        PhoneToggleRow(
          label: 'Ritmo (qualquer tecla, no tempo da partitura)',
          value: _practiceMode == PracticeMode.rhythm,
          onChanged: _practice != null
              ? null
              : (v) => setState(
                  () => _practiceMode = v
                      ? PracticeMode.rhythm
                      : PracticeMode.wait,
                ),
        ),
        PhoneToggleRow(
          label: 'Metrônomo (com som do app)',
          value: _metronomeOn,
          onChanged: (_) => _toggleMetronome(),
        ),
        PhoneToggleRow(
          label: 'Contagem antes de começar',
          value: _countInOn,
          onChanged: (_) => _toggleCountIn(),
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
        PhoneActionRow(
          icon: Icons.timer_outlined,
          label: _inputLatencyMs == 0
              ? 'Calibrar latência do teclado'
              : 'Latência: ${_inputLatencyMs.round()} ms — recalibrar',
          onTap: _midiDeviceManager.connected.value == null
              ? null
              : () {
                  setState(() => _optionsOpen = false);
                  unawaited(_openCalibration());
                },
        ),
        const PhoneSectionLabel('SOM E TECLADO'),
        PhoneToggleRow(
          label: 'Som do app',
          value: _soundOn,
          onChanged: _loadingSoundFont
              ? null
              : (_) => unawaited(_toggleSound()),
        ),
        PhoneActionRow(
          icon: _output == SoundOutput.midiKeyboard
              ? Icons.piano
              : Icons.graphic_eq,
          label: _output == SoundOutput.midiKeyboard
              ? 'Saída: teclado MIDI'
              : 'Saída: sintetizador do app',
          onTap: () => unawaited(
            _setOutput(
              _output == SoundOutput.midiKeyboard
                  ? SoundOutput.appSynth
                  : SoundOutput.midiKeyboard,
            ),
          ),
        ),
        PhoneActionRow(
          icon: Icons.library_music,
          label: _customSoundFont
              ? 'Soundfont: personalizado — trocar'
              : 'Soundfont: TimGM6mb (padrão) — trocar',
          onTap: _loadingSoundFont ? null : () => unawaited(_chooseSoundFont()),
        ),
        if (_customSoundFont)
          PhoneActionRow(
            icon: Icons.restore,
            label: 'Voltar ao soundfont padrão',
            onTap: _loadingSoundFont
                ? null
                : () => unawaited(_resetSoundFont()),
          ),
        PhoneToggleRow(
          label: 'Monitor MIDI (teclado sem som)',
          value: _midiMonitorOn,
          onChanged: _loadingSoundFont
              ? null
              : (_) => unawaited(_toggleMidiMonitor()),
        ),
        const PhoneSectionLabel('PARTITURA'),
        PhoneActionRow(
          icon: Icons.folder_open,
          label: 'Abrir partitura',
          onTap: () {
            setState(() => _optionsOpen = false);
            unawaited(_abrirPartitura());
          },
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
        PhoneActionRow(
          icon: Icons.tune,
          label: 'Ajustes de layout (avançado)',
          onTap: () => setState(() {
            _optionsOpen = false;
            _panelOpen = true;
          }),
        ),
        PhoneActionRow(
          icon: Icons.piano,
          label: 'Painel do monitor MIDI',
          onTap: () => setState(() {
            _optionsOpen = false;
            _midiPanelOpen = true;
          }),
        ),
      ],
    );
  }

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
                  haloSigmaScale: _haloWidth,
                  barColor: _barColor,
                ),
              )
            : phone
            ? Center(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _abrirPartitura,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir partitura'),
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
            if (_busy)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
            if (phone && hasPage)
              Positioned(
                left: 10,
                top: 4,
                child: IconButton(
                  tooltip: 'Abrir partitura',
                  onPressed: _busy ? null : _abrirPartitura,
                  icon: const Icon(
                    Icons.folder_open,
                    size: 24,
                    color: kInkCaption,
                  ),
                ),
              ),
            if (phone && _trainingMode)
              Positioned(
                left: 54,
                right: 12,
                top: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PhoneStatusPill(text: _trainingPillText),
                    if (_practice case final practice?)
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          practice.correctCount,
                          practice.wrongCount,
                        ]),
                        builder: (context, _) => PhoneCountersPill(
                          correct: practice.correctCount.value,
                          mistakes: practice.wrongCount.value,
                        ),
                      ),
                  ],
                ),
              ),
            if (_midiPanelOpen)
              Positioned(
                top: 8,
                left: 8,
                bottom: 8,
                width: math.min(360, constraints.maxWidth - 16),
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
                  tooltip: 'Monitor MIDI',
                  onPressed: () => setState(() => _midiPanelOpen = true),
                  icon: const Icon(Icons.piano),
                ),
              ),
            if (_panelOpen)
              Positioned(
                top: 8,
                right: 8,
                bottom: 8,
                width: math.min(360, constraints.maxWidth - 16),
                child: LayoutPanel(
                  values: _layout,
                  pageFitsBox: _pageFitsBox,
                  fittedPage: _fittedPage,
                  onChanged: _setLayoutValue,
                  onCommit: _renderAndShow,
                  onFitChanged: (v) {
                    setState(() => _pageFitsBox = v);
                    _renderAndShow();
                  },
                  onReset: _resetLayout,
                  onCopy: _copyOptions,
                  onClose: () => setState(() => _panelOpen = false),
                  zoomSection: _zoomControls(),
                  highlightColor: _highlightColor,
                  onHighlightColorChanged: _setHighlightColor,
                  haloWidth: _haloWidth,
                  onHaloWidthChanged: (v) => setState(() => _haloWidth = v),
                  barColor: _barColor,
                  onBarColorChanged: (c) => setState(() => _barColor = c),
                ),
              )
            else if (!phone)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Opções',
                  onPressed: () => setState(() => _panelOpen = true),
                  icon: const Icon(Icons.tune),
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
      return Scaffold(backgroundColor: kSurface, body: _buildPhoneBody());
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('zywny • partitura → .vsb'),
        actions: [
          MidiDevicePickerButton(
            deviceManager: _midiDeviceManager,
            onCalibrate: () => unawaited(_openCalibration()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _abrirPartitura,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir partitura'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _scoreName ?? 'nenhuma partitura',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildScoreArea(),
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
                IconButton.filled(
                  tooltip: _canTrain
                      ? (_practice != null
                            ? 'Parar prática'
                            : 'Praticar (modo espera)')
                      : (_playing ? 'Pausar' : 'Tocar (destacar notas)'),
                  onPressed: _canTrain
                      ? () => unawaited(_togglePractice())
                      : (_canPlay ? _togglePlay : null),
                  icon: Icon(
                    _canTrain
                        ? (_practice != null ? Icons.pause : Icons.school)
                        : (_playing ? Icons.pause : Icons.play_arrow),
                  ),
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
                        'Tempo real — trocar para ritmo (qualquer tecla)',
                      PracticeMode.rhythm => 'Ritmo — trocar para modo espera',
                    },
                    onPressed: () => setState(
                      () => _practiceMode = switch (_practiceMode) {
                        PracticeMode.wait => PracticeMode.realtime,
                        PracticeMode.realtime => PracticeMode.rhythm,
                        PracticeMode.rhythm => PracticeMode.wait,
                      },
                    ),
                    icon: Icon(switch (_practiceMode) {
                      PracticeMode.wait => Icons.hourglass_bottom,
                      PracticeMode.realtime => Icons.speed,
                      PracticeMode.rhythm => Icons.music_note,
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
                  tooltip: _countInOn
                      ? 'Desligar contagem inicial'
                      : 'Ligar contagem de 1 compasso antes de começar',
                  onPressed: _toggleCountIn,
                  icon: Icon(
                    _countInOn ? Icons.filter_1 : Icons.filter_1_outlined,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: _loop == null
                      ? 'Repetir um trecho (loop A-B)'
                      : 'Loop: compassos ${_loop!.a + 1}–${_loop!.b + 1}',
                  onPressed: _player == null
                      ? null
                      : () => unawaited(_openLoopSheet()),
                  icon: Icon(_loop == null ? Icons.repeat : Icons.repeat_on),
                ),
                IconButton.filledTonal(
                  tooltip: _soundOn
                      ? 'Desligar som'
                      : _output == SoundOutput.midiKeyboard
                      ? 'Ligar som (teclado MIDI conectado)'
                      : 'Ligar som (escolhe um .sf2)',
                  onPressed: _loadingSoundFont ? null : _toggleSound,
                  icon: _engineButtonIcon(
                    _soundOn ? Icons.volume_up : Icons.volume_off,
                  ),
                ),
                PopupMenuButton<SoundOutput>(
                  tooltip: 'Saída de som',
                  initialValue: _output,
                  onSelected: (value) => unawaited(_setOutput(value)),
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
                        ? 'Desligar instrumentos da partitura (usar o som '
                              'do teclado)'
                        : 'Usar instrumentos da partitura (Program Change)',
                    onPressed: () =>
                        _setUseScoreInstruments(!_useScoreInstruments),
                    icon: Icon(
                      _useScoreInstruments ? Icons.music_note : Icons.music_off,
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
    );
  }
}
