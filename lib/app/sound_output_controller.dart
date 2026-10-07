// R08: por onde sai o som da partitura — os dois motores (sintetizador do
// app e teclado MIDI), a saída em uso, o `.sf2` e o monitor MIDI. Saiu de
// `_ScoreHomePageState` (achado 5 da revisão); a reprodução (agendador,
// player) ainda é da tela, que entra por [SoundOutputPlayback].

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/engine_opener.dart';
import '../audio/sound_engine.dart';
import '../audio/soundfont_store.dart';
import '../core/diag_log.dart';
import '../midi/midi_device_manager.dart';
import '../midi/midi_input_service.dart';
import '../midi/midi_monitor.dart';
import '../midi/midi_out_sound_engine.dart';
import '../settings/app_settings.dart';
import 'general_settings_panel.dart' show pickSoundFontBytes;

/// O que o controller pede a quem toca a partitura (a tela, até o R10): ele
/// decide o motor; quem toca prende ou solta o agendador.
class SoundOutputPlayback {
  const SoundOutputPlayback({
    required this.hasTrack,
    required this.attach,
    required this.detach,
    required this.endPractice,
  });

  /// Há gravura para tocar. Sem ela, ligar o som não abre motor nenhum.
  final bool Function() hasTrack;

  /// Prende o agendador a [engine] e passa o relógio de áudio ao player.
  /// Retoma de onde o player está se ele estava tocando, ou sempre, com
  /// [always] (troca de saída com o som ligado).
  final void Function(SoundEngine engine, {required bool always}) attach;

  /// Pausa o agendador e devolve o player ao relógio próprio (mudo).
  final VoidCallback detach;

  /// O usuário vai desligar o som: o treino, que depende do agendador para
  /// o freio e a mão do app, acaba antes.
  final VoidCallback endPractice;
}

/// A altura que o monitor manda a um motor para a nota [received] que chegou
/// do teclado; [midiKeyboard] diz se o motor é o próprio teclado.
typedef MonitorPitch = int Function(int received, {required bool midiKeyboard});

/// Saída de som da partitura: um motor por [SoundOutput] (M03), som
/// ligado/desligado (K04), `.sf2` (D-SF) e monitor MIDI (M02).
///
/// Quem cria descarta: [dispose] fecha os dois motores e o monitor. As
/// configurações e o gerenciador MIDI são de fora (da biblioteca).
class SoundOutputController extends ChangeNotifier {
  SoundOutputController({
    required AppSettings settings,
    required MidiDeviceManager devices,
    required MidiInputService input,
    required this.playback,
    required MonitorPitch monitorPitch,
    Future<SoundEngine?> Function()? appEngineFactory,
    MidiSender Function()? midiSender,
    SoundFontStore soundFonts = const SoundFontStore(),
    Future<Uint8List?> Function() pickSoundFont = pickSoundFontBytes,
    this.onMessage,
  }) : _settings = settings,
       _devices = devices, // ignore: prefer_initializing_formals
       _input = input, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _monitorPitch = monitorPitch,
       _soundFonts = soundFonts,
       _appEngineFactory =
           appEngineFactory ??
           (() => openAppSoundEngine(soundFonts: soundFonts)),
       _midiSender = midiSender ?? FlutterMidiSender.new,
       _pickSoundFont = pickSoundFont, // ignore: prefer_initializing_formals
       // Lidos já aqui (e não na primeira vez que forem usados): é contra
       // eles que [_onSettingsChanged] compara para saber o que mudou.
       _output = settings.output,
       _soundSetting = settings.soundOn {
    _devices.connected.addListener(_onMidiDeviceChanged);
    _settings.addListener(_onSettingsChanged);
    unawaited(
      _soundFonts.hasCustom().then((v) {
        if (_disposed) return;
        _customSoundFont = v;
        notifyListeners();
      }),
    );
  }

  final AppSettings _settings;
  final MidiDeviceManager _devices;
  final MidiInputService _input;
  final MonitorPitch _monitorPitch;
  final SoundFontStore _soundFonts;
  final Future<SoundEngine?> Function() _appEngineFactory;
  final MidiSender Function() _midiSender;
  final Future<Uint8List?> Function() _pickSoundFont;
  final SoundOutputPlayback playback;

  /// Avisos para a pessoa (a tela mostra num `SnackBar`).
  final ValueChanged<String>? onMessage;

  bool _disposed = false;

  /// Motor de áudio (K03): criado sob demanda no primeiro "ligar som", não
  /// no início do app — mudo por padrão, como antes de K04. Sobrevive a
  /// novas gravuras (só o agendador é recriado, um por `.vsb`).
  ///
  /// Um motor por [SoundOutput] (M03): trocar de saída não descarta o
  /// sintetizador do app (com `.sf2` já carregado) nem o motor MIDI (que é
  /// recriado se o dispositivo conectado mudar — ver [_onMidiDeviceChanged]).
  SoundEngine? _appEngine;
  MidiOutSoundEngine? _midiOutEngine;

  /// O sintetizador do app, se já aberto (os cliques da contagem muda e o
  /// teste de ouvido da conferência do TRANSPOSE só soam nele).
  SoundEngine? get appEngine => _appEngine;

  /// O motor da saída em uso, se já aberto.
  SoundEngine? get engine =>
      _output == SoundOutput.midiKeyboard ? _midiOutEngine : _appEngine;

  /// Saída **em uso** (M03). A escolhida mora nas configurações; quando ela
  /// muda, [_onSettingsChanged] troca o motor e só então atualiza esta.
  SoundOutput get output => _output;
  SoundOutput _output;

  /// Interruptor "som" (K04): liga o agendador de áudio sobre o player;
  /// desligado, o player volta ao próprio relógio interno (`speed`), o
  /// modo mudo de sempre.
  ///
  /// É o estado **de agora**; o que o usuário quer ao abrir um hino é
  /// `settings.soundOn` ([_soundSetting] guarda o último valor visto, para
  /// distinguir "o usuário mexeu" de "o treino ligou o som por conta").
  bool get soundOn => _soundOn;
  bool _soundOn = false;
  bool _soundSetting;
  bool _autoSoundDone = false;

  /// Abrindo o sintetizador do app (carregando o `.sf2`).
  bool get loadingSoundFont => _loadingSoundFont;
  bool _loadingSoundFont = false;

  /// O usuário escolheu um `.sf2` próprio (senão vale o TimGM6mb embutido).
  bool get customSoundFont => _customSoundFont;
  bool _customSoundFont = false;

  /// Monitor MIDI pelo sintetizador do app (M02): o que chega na entrada
  /// sai por [engine] num canal reservado, para teclados controladores sem
  /// som próprio. Mesmo motor de [toggleSound] (K04) — [ensureEngine] pede
  /// um `.sf2` só na primeira vez, para qualquer um dos dois. Preferência
  /// guardada por dispositivo em [MidiDeviceManager].
  bool get midiMonitorOn => _midiMonitorOn;
  MidiMonitor? _midiMonitor;
  bool _midiMonitorOn = false;

  Future<SoundEngine?>? _engineOpening;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _onSettingsChanged() {
    if (_disposed) return;
    if (_settings.output != _output) unawaited(applyOutput(_settings.output));
    _midiOutEngine?.useScoreInstruments = _settings.useScoreInstruments;
    if (_settings.soundOn != _soundSetting) {
      _soundSetting = _settings.soundOn;
      if (_soundSetting != _soundOn && !_loadingSoundFont) {
        unawaited(toggleSound());
      }
    }
  }

  /// O monitor MIDI (M02) sobre [engine]: toca a soada da tecla apertada.
  MidiMonitor newMidiMonitor(SoundEngine engine) {
    final midiKeyboard = engine is MidiOutSoundEngine;
    return MidiMonitor(
      input: _input,
      engine: engine,
      pitchOf: (r) => _monitorPitch(r, midiKeyboard: midiKeyboard),
    );
  }

  /// A tela ligou o agendador por conta própria (treino, ouvir a etapa):
  /// o som está ligado agora, sem mexer na preferência.
  void markSoundOn() {
    if (_soundOn) return;
    _soundOn = true;
    _changed();
  }

  /// Interruptor "som" (K04). Desligar volta ao modo mudo de sempre
  /// (relógio interno do player); ligar abre o motor (K03) e — só na
  /// primeira vez, D-SF ainda em aberto — pede um `.sf2` ao usuário.
  Future<void> toggleSound() async {
    if (_soundOn) {
      // Modo treino (T02) depende do agendador de som para o freio e a mão
      // do app — sem som, não há como continuar.
      playback.endPractice();
      playback.detach();
      engine?.allNotesOff();
      _soundOn = false;
      _changed();
      return;
    }
    if (!playback.hasTrack()) return;
    final opened = await ensureEngine();
    if (opened == null || _disposed) return;
    playback.attach(opened, always: false);
    _soundOn = true;
    _changed();
  }

  /// O usuário mexeu no interruptor de som desta tela: além de ligar ou
  /// desligar agora, vira a preferência geral (o próximo hino abre igual).
  Future<void> userToggleSound() async {
    await toggleSound();
    _soundSetting = _soundOn;
    _settings.soundOn = _soundOn;
  }

  /// Uma vez por hino, depois da primeira gravura: religa o som se ele
  /// estava ligado da última vez. Com saída no teclado MIDI e nenhum
  /// conectado, deixa quieto em vez de reclamar a cada hino aberto.
  void restoreSound() {
    if (_autoSoundDone) return;
    _autoSoundDone = true;
    if (_soundOn) return;
    if (!_settings.soundOn) {
      // Som desligado: mesmo assim deixa o motor do app armado (dispositivo
      // aberto, `.sf2` carregado) enquanto o aluno ainda olha a partitura —
      // senão o primeiro play espera por isso. O play continua mudo até
      // alguém ligar o som. O motor MIDI não custa nada para abrir e
      // reclamaria da falta de teclado, então fica para quando for usado.
      if (_output == SoundOutput.appSynth) unawaited(ensureEngine());
      return;
    }
    if (_output == SoundOutput.midiKeyboard &&
        _devices.connected.value == null) {
      return;
    }
    unawaited(toggleSound());
  }

  /// Abre [engine] se ainda não existir — pedindo um `.sf2` ao usuário só
  /// na primeira vez (D-SF) — e o devolve; `null` se o motor não abriu ou o
  /// usuário cancelou o `.sf2`. Compartilhado por [toggleSound] e
  /// [toggleMidiMonitor] (M02): é o mesmo motor que toca a partitura e o
  /// monitor.
  Future<SoundEngine?> ensureEngine() async {
    final existing = engine;
    if (existing != null) return existing;
    if (_output == SoundOutput.midiKeyboard) return ensureMidiOutEngine();
    // Já abrindo (armado na entrada, ou dois pedidos seguidos): quem chega
    // depois espera a mesma abertura em vez de desistir.
    return _engineOpening ??= openAppEngine().whenComplete(
      () => _engineOpening = null,
    );
  }

  /// Abre o sintetizador do app (`.sf2` do usuário ou o embutido).
  Future<SoundEngine?> openAppEngine() async {
    _loadingSoundFont = true;
    _changed();
    SoundEngine? engine;
    try {
      engine = await pickEngineWithSoundFont();
    } catch (e, st) {
      debugPrint('som: erro ao iniciar: $e\n$st');
      DiagLog.log('erro', 'som: erro ao iniciar: $e\n$st');
      if (!_disposed) onMessage?.call('som: erro ao iniciar ($e)');
      engine = null;
    } finally {
      _loadingSoundFont = false;
      _changed();
    }
    if (engine == null) return null;
    if (_disposed) {
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
  /// conectado; `null` sem dispositivo conectado.
  SoundEngine? ensureMidiOutEngine() {
    final existing = _midiOutEngine;
    if (existing != null) return existing;
    final device = _devices.connected.value;
    if (device == null) {
      onMessage?.call('conecte um teclado MIDI primeiro');
      return null;
    }
    final engine = MidiOutSoundEngine(
      sender: _midiSender(),
      deviceId: device.id,
      useScoreInstruments: _settings.useScoreInstruments,
    );
    _midiOutEngine = engine;
    return engine;
  }

  /// Troca a saída de som em uso (M03) para a escolhida nas configurações
  /// gerais (que já a guardaram) — ver [_onSettingsChanged]. Se o som ou o
  /// monitor MIDI estiverem ligados, silencia a saída antiga (`allNotesOff`)
  /// e reancora o agendador/monitor na nova — se a nova saída não abrir
  /// (ex.: MIDI sem dispositivo conectado), desliga os dois.
  Future<void> applyOutput(SoundOutput next) async {
    if (next == _output) return;
    final wasSoundOn = _soundOn;
    final wasMonitorOn = _midiMonitorOn;
    if (!wasSoundOn && !wasMonitorOn) {
      _output = next;
      _changed();
      return;
    }
    engine?.allNotesOff();
    _output = next;
    _changed();
    final opened = await ensureEngine();
    if (_disposed) return;
    if (opened == null) {
      playback.detach();
      _midiMonitor?.dispose();
      _soundOn = false;
      _midiMonitor = null;
      _midiMonitorOn = false;
      _changed();
      return;
    }
    if (wasMonitorOn) {
      _midiMonitor?.dispose();
      _midiMonitor = newMidiMonitor(opened);
    }
    if (wasSoundOn && playback.hasTrack()) {
      playback.attach(opened, always: true);
    }
    _changed();
  }

  /// Interruptor "usar instrumentos da partitura" (M03): Program Change ao
  /// teclado MIDI — desligado por padrão.
  void setUseScoreInstruments(bool value) =>
      _settings.useScoreInstruments = value;

  /// Interruptor "monitor MIDI" (M02): liga a entrada a [engine] num canal
  /// reservado, para teclados controladores sem som próprio. Guarda a
  /// escolha por dispositivo em [MidiDeviceManager].
  Future<void> toggleMidiMonitor() async {
    if (_midiMonitorOn) {
      disableMidiMonitor();
      return;
    }
    final engine = await ensureEngine();
    if (engine == null || _disposed) return;
    _midiMonitor?.dispose();
    _midiMonitor = newMidiMonitor(engine);
    _midiMonitorOn = true;
    _changed();
    final device = _devices.connected.value;
    if (device != null) {
      unawaited(_devices.setMonitorEnabled(device.id, true));
    }
  }

  void disableMidiMonitor() {
    _midiMonitor?.dispose();
    _midiMonitor = null;
    _midiMonitorOn = false;
    _changed();
    final device = _devices.connected.value;
    if (device != null) {
      unawaited(_devices.setMonitorEnabled(device.id, false));
    }
  }

  /// Chamado a cada troca de dispositivo MIDI conectado (M01/M02): manda
  /// note-off para o que o monitor ainda considerar retido do dispositivo
  /// anterior (evita nota presa) e aplica a preferência do novo — só liga de
  /// volta sozinho se [engine] já existir, para nunca abrir o diálogo de
  /// `.sf2` sem o usuário ter pedido.
  void _onMidiDeviceChanged() {
    DiagLog.log(
      'midi-dev',
      'conectado agora: ${_devices.connected.value?.name}',
    );
    _midiMonitor?.allNotesOff();
    tearDownMidiOutEngine();
    unawaited(syncMidiMonitorToDevice());
  }

  /// Descarta o motor de saída MIDI (M03): seu `deviceId` só vale para o
  /// dispositivo que estava conectado quando foi criado — hot-plug ou troca
  /// de dispositivo sempre pede um novo, nunca reaproveita (`allNotesOff` no
  /// `dispose`, o critério "perder a conexão" do M03). Se ele for a saída
  /// ativa, desliga o som também.
  void tearDownMidiOutEngine() {
    final engine = _midiOutEngine;
    if (engine == null) return;
    _midiOutEngine = null;
    unawaited(engine.dispose());
    if (_output != SoundOutput.midiKeyboard || !_soundOn) return;
    playback.detach();
    _soundOn = false;
    _changed();
  }

  /// Liga ou desliga o monitor conforme a preferência guardada para o
  /// dispositivo conectado agora.
  Future<void> syncMidiMonitorToDevice() async {
    final device = _devices.connected.value;
    final wanted = device == null
        ? false
        : await _devices.monitorEnabled(device.id);
    if (_disposed || _devices.connected.value?.id != device?.id) return;
    final engine = this.engine;
    _midiMonitor?.dispose();
    if (wanted && engine != null) {
      _midiMonitor = newMidiMonitor(engine);
      _midiMonitorOn = true;
    } else {
      _midiMonitor = null;
      _midiMonitorOn = false;
    }
    _changed();
  }

  /// Abre o motor e pede um soundfont ao usuário; `null` se o motor não
  /// abriu (sem dispositivo de áudio) ou o usuário cancelou o `.sf2`.
  /// Corpo em `lib/audio/engine_opener.dart` (I09, risco 4 do I00): a tela
  /// do exercício usa o mesmo.
  Future<SoundEngine?> pickEngineWithSoundFont() => _appEngineFactory();

  /// Troca o `.sf2` (o TimGM6mb embutido é o padrão): guarda o escolhido e,
  /// se o motor do app já está aberto, recarrega nele na hora.
  Future<void> chooseSoundFont() async {
    final Uint8List? bytes;
    try {
      bytes = await _pickSoundFont();
    } catch (e) {
      DiagLog.log('erro', 'soundfont: $e');
      return;
    }
    if (bytes == null || _disposed) return;
    try {
      await _appEngine?.loadSoundFont(bytes);
      await _soundFonts.saveCustom(bytes);
      _customSoundFont = true;
      _changed();
    } catch (e) {
      DiagLog.log('erro', 'soundfont: $e');
      if (!_disposed) onMessage?.call('não consegui usar esse soundfont ($e)');
    }
  }

  /// Volta ao TimGM6mb embutido.
  Future<void> resetSoundFont() async {
    try {
      await _soundFonts.clearCustom();
      await _appEngine?.loadSoundFont(await _soundFonts.load());
      _customSoundFont = false;
      _changed();
    } catch (e) {
      DiagLog.log('erro', 'soundfont: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _devices.connected.removeListener(_onMidiDeviceChanged);
    _settings.removeListener(_onSettingsChanged);
    _midiMonitor?.dispose();
    _midiMonitor = null;
    unawaited(_appEngine?.dispose());
    unawaited(_midiOutEngine?.dispose());
    _appEngine = null;
    _midiOutEngine = null;
    super.dispose();
  }
}
