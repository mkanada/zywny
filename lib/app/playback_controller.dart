// R10: tocar a partitura — o player, o agendador, o relógio do áudio, a
// contagem, o loop, o metrônomo, o andamento e o seek. Saiu de
// `_ScoreHomePageState` (achado 5 da revisão); liga a gravura (R09,
// [attach]) ao som (R08, [SoundOutputController]). O treino e a trilha
// usam o player e o agendador daqui, mas moram fora.

import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:zywny_audio/audio_playback_clock.dart';
import 'package:zywny_audio/metronome.dart';
import 'package:zywny_audio/score_audio_scheduler.dart';
import 'package:zywny_audio/sound_engine.dart';
import 'package:zywny_audio/performance_track.dart';

import '../settings/app_settings.dart';
import 'sound_output_controller.dart';

void _setWakelock(bool on) =>
    unawaited(on ? WakelockPlus.enable() : WakelockPlus.disable());

double Function() _stopwatchSeconds() {
  final watch = Stopwatch()..start();
  return () => watch.elapsedMicroseconds / 1e6;
}

/// O transporte da partitura aberta: um [ScorePlayer] por gravura
/// ([attach]) e, com som, um [ScoreAudioScheduler] sobre o motor de
/// [sound], de quem o player lê o relógio.
///
/// Quem cria descarta: [dispose] para o que estiver tocando e solta o
/// player e o agendador. O motor é de [sound].
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required this.sound,
    required AppSettings settings,
    required this.controller,
    this.view,
    double speed = 1.0,
    this.barWidthOf,
    this.pitchOf,
    this.onEnded,
    this.onLoopChanged,
    double Function()? wallSeconds,
    void Function(bool on) wakelock = _setWakelock,
  }) : _settings = settings, // ignore: prefer_initializing_formals
       _speed = speed, // ignore: prefer_initializing_formals
       _wallSeconds = wallSeconds, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _wakelock = wakelock {
    _settings.addListener(_onSettingsChanged);
  }

  /// Por onde sai o som: diz se ele está ligado e qual é o motor.
  final SoundOutputController sound;
  final AppSettings _settings;

  /// Os destaques de nota (o player acende e apaga por ele).
  final ScoreController controller;

  /// A vista a acompanhar (virada de página, haste).
  final ScoreViewController? view;

  /// Largura da haste para [VsbDocument]; `null` usa a padrão do player.
  final double Function(VsbDocument document)? barWidthOf;

  /// A altura que [SoundEngine] deve receber para cada nota escrita (fase
  /// Q); `null` manda a escrita.
  final int Function(int written) Function(SoundEngine engine)? pitchOf;

  /// O player chegou ao fim da peça e parou (o treino acaba junto).
  final VoidCallback? onEnded;

  /// O loop foi para o agendador (`null` = desligado): o treino em curso
  /// segue o mesmo trecho.
  final void Function(({double startMs, double endMs})? range)? onLoopChanged;

  /// Relógio de parede, em segundos, da contagem sem som com o sintetizador
  /// fechado. `null` = um `Stopwatch` por contagem.
  final double Function()? _wallSeconds;
  final void Function(bool on) _wakelock;

  bool _disposed = false;

  ScorePlayer? _player;
  PerformanceTrack? _track;
  ScoreAudioScheduler? _scheduler;
  AudioPlaybackClock? _audioClock;
  bool _playing = false;
  double _speed;
  ({int a, int b})? _loop;

  /// Contagem do play com o som desligado: sem agendador para contar, o
  /// controller segura o player e conta sozinho — o número e, com o
  /// sintetizador do app aberto, os cliques (a música segue muda). `null`
  /// fora dela.
  Timer? _silentCountInTimer;
  CountInTick? Function()? _silentCountIn;
  SoundEngine? _silentCountInEngine;

  /// Espera a contagem do agendador acabar para soltar o player
  /// ([playPlayerAfterCount]).
  Timer? _countInPlayTimer;

  /// Walks the timemap, highlights notes through [controller] and drives
  /// the page-turn sweep. Rebuilt for every new engraving; `null` sem
  /// timemap.
  ScorePlayer? get player => _player;

  /// Notas tocáveis da gravura corrente — o que o agendador toca.
  PerformanceTrack? get track => _track;

  /// O agendador do som; `null` com o som desligado (até ligar uma vez).
  ScoreAudioScheduler? get scheduler => _scheduler;

  bool get playing => _playing;

  /// 0,5×–1,5×; alimenta o agendador com som ligado, ou `ScorePlayer.speed`
  /// mudo (C01: o relógio externo ignora `speed`).
  double get speed => _speed;

  /// O loop A-B, em **ocorrências** de compasso (índices em
  /// `ScorePlayer.measures`, ordem de execução).
  ({int a, int b})? get loop => _loop;

  /// O número da contagem na tela agora (a muda ou a do agendador).
  CountInTick? countIn() => _silentCountIn?.call() ?? _scheduler?.countInTick;

  /// `[startMs, endMs)` do loop atual, ou `null`.
  ({double startMs, double endMs})? get loopRangeMs {
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

  bool get metronomeOn => _settings.metronomeOn;

  void _onSettingsChanged() {
    _scheduler?.metronomeOn = _settings.metronomeOn;
  }

  /// Uma gravura nova: os ids (e talvez as páginas) mudaram, então o player
  /// e o agendador da anterior saem, e o novo player — sobre o relógio do
  /// áudio, com o som ligado — fica parado no começo.
  void attach(VsbDocument document, PerformanceTrack track) {
    cancelSilentCountIn();
    _player?.dispose();
    _player = null;
    _setPlaying(false);
    _scheduler?.dispose();
    _scheduler = null;
    _audioClock = null;
    _track = track;
    controller.clearAll();
    controller.attachDocument(document);
    final hasTimemap = document.timemap?.isNotEmpty ?? false;
    _player = hasTimemap
        ? ScorePlayer(
            document: document,
            controller: controller,
            view: view,
            onEntry: _onEntry,
            barWidth: barWidthOf?.call(document),
            highlightColor: _settings.highlightColor,
            // Ligadura é uma tecla só: a cadeia acende junta.
            mergeTies: true,
          )
        : null;
    final engine = sound.engine;
    if (_player != null && sound.soundOn && engine != null) {
      attachAudio(engine);
    }
    notifyListeners();
  }

  /// Every write to [playing] goes through here so the screen wakelock
  /// (X01: found the phone falling asleep mid-playback) never falls out of
  /// sync with one of the several places that flip the flag.
  void _setPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    _wakelock(value);
  }

  /// Marca o transporte como tocando ou parado — o treino e a trilha, que
  /// soltam o player eles mesmos, também passam por aqui.
  void setPlaying(bool value) {
    _setPlaying(value);
    notifyListeners();
  }

  /// Play/pausa da música (sem treino). Com som, o agendador conta um
  /// compasso antes; sem som, a contagem é feita aqui
  /// ([_startSilentCountIn]).
  void togglePlay() {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      cancelSilentCountIn();
      player.pause();
      _scheduler?.pause();
      controller.releaseAll();
      setPlaying(false);
      return;
    }
    // Posição fora do loop (ou depois do fim): começa pelo trecho.
    final range = loopRangeMs;
    if (range != null) {
      final ms = player.position.inMicroseconds / 1000;
      if (ms < range.startMs || ms >= range.endMs) {
        player.seek(Duration(microseconds: (range.startMs * 1000).round()));
      }
    }
    // Do fim, o play recomeça a música: a contagem é a do 1º compasso.
    if (player.position >= player.duration) player.seek(Duration.zero);
    if (sound.soundOn) {
      final fromMs = player.position.inMicroseconds / 1000;
      final scheduler = _scheduler;
      if (scheduler == null) {
        player.play();
      } else {
        scheduler.play(fromMs, speed: _speed, countIn: true);
        playPlayerAfterCount(fromMs);
      }
    } else {
      _startSilentCountIn(player);
    }
    setPlaying(true);
  }

  /// Play sem som: faz a contagem e só então solta [player] (que, mudo,
  /// anda pelo relógio próprio). Os cliques soam mesmo assim, pelo
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
    final engine = sound.appEngine;
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
      final wall = _wallSeconds ?? _stopwatchSeconds();
      final t0 = wall();
      elapsed = () => wall() - t0;
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

  /// Solta o player no ponto [startMs]. Com contagem inicial em curso nada
  /// fica aceso na pauta até o primeiro tempo (U09): apaga o destaque do
  /// instante de partida e o devolve, com o `seek`, quando a contagem acaba.
  void playPlayerAfterCount(double startMs) {
    final player = _player;
    if (player == null) return;
    cancelPlayAfterCount();
    final scheduler = _scheduler;
    if (scheduler == null || !scheduler.isCountingIn) {
      player.play();
      return;
    }
    controller.clearHighlights();
    _countInPlayTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (scheduler.isCountingIn) return;
      timer.cancel();
      _countInPlayTimer = null;
      if (_disposed || !identical(player, _player) || !_playing) return;
      player.seek(Duration(microseconds: (startMs * 1000).round()));
      player.play();
    });
  }

  /// Desiste de soltar o player depois da contagem do agendador.
  void cancelPlayAfterCount() {
    _countInPlayTimer?.cancel();
    _countInPlayTimer = null;
  }

  /// Desiste da contagem sem som em curso (e dos cliques que ainda não
  /// soaram); devolve se havia uma (o player ainda não tinha sido solto).
  bool cancelSilentCountIn() {
    cancelPlayAfterCount();
    final timer = _silentCountInTimer;
    if (timer == null) return false;
    timer.cancel();
    _silentCountInEngine?.clearScheduled();
    _silentCountInTimer = null;
    _silentCountIn = null;
    _silentCountInEngine = null;
    return true;
  }

  /// Para e volta ao começo da música. O treino, se havia, já acabou (quem
  /// chama encerra antes: `ScoreAudioScheduler.stop` não solta o freio nem
  /// o filtro de pauta dele).
  void stop() {
    final player = _player;
    if (player == null) return;
    cancelSilentCountIn();
    player.pause();
    player.seek(Duration.zero);
    _scheduler?.stop();
    controller.clearAll();
    if (_playing) setPlaying(false);
  }

  /// Reiniciar: volta ao começo do trecho em repetição (ou da música) e
  /// segue como estava — tocando, recomeça de lá; parado, fica parado.
  void restart() {
    if (_player == null) return;
    final wasPlaying = _playing;
    if (wasPlaying) togglePlay();
    controller.clearAll();
    seekTo(loopRangeMs?.startMs ?? 0);
    if (wasPlaying) togglePlay();
  }

  /// Leva o player e o agendador de áudio (se houver) para [ms].
  void seekTo(double ms) {
    _player?.seek(Duration(microseconds: (ms * 1000).round()));
    _scheduler?.seek(ms);
  }

  /// Tocar numa nota (E02c) move o player; K04 reflete o mesmo instante no
  /// agendador de áudio, senão os dois relógios divergem.
  void seekToElement(String id) {
    final player = _player;
    if (player == null || !player.seekToElement(id)) return;
    _scheduler?.seek(player.position.inMicroseconds / 1000);
  }

  /// The player pauses itself at the end of the piece; follow that here.
  void _onEntry(TimemapEntry entry) {
    final player = _player;
    if (player == null || !_playing) return;
    if (player.position >= player.duration) {
      onEnded?.call();
      _scheduler?.pause();
      controller.releaseAll();
      if (!_disposed) setPlaying(false);
    }
  }

  /// 0,5×–1,5×: alimenta o que estiver tocando de verdade agora — o
  /// agendador de áudio com som ligado, ou `ScorePlayer.speed` mudo.
  void setSpeed(double value) {
    _speed = value;
    if (sound.soundOn) {
      _scheduler?.setSpeed(value);
    } else {
      _player?.speed = value;
    }
    notifyListeners();
  }

  /// Liga o agendador sobre [engine] e passa o relógio de áudio ao player —
  /// chamado ao ligar o som, a cada nova gravura enquanto ele estiver
  /// ligado e pelo treino, que precisa do agendador.
  void attachAudio(SoundEngine engine) {
    final track = _track;
    if (track == null) return;
    // O som chegou no meio da contagem muda: daqui em diante quem manda no
    // tempo é o agendador, então o player é solto já.
    if (cancelSilentCountIn()) _player?.play();
    // O agendador anterior para de vez: trocar de saída tocando deixava o
    // timer dele vivo, agendando no motor antigo junto com o novo.
    _scheduler?.dispose();
    final scheduler = ScoreAudioScheduler(engine: engine, track: track);
    if (pitchOf case final pitchOf?) scheduler.pitchOf = pitchOf(engine);
    _scheduler = scheduler;
    _audioClock = AudioPlaybackClock(scheduler);
    _player?.clock = _audioClock;
    final player = _player;
    if (player != null) scheduler.beats = metronomeBeats(player.timeline);
    scheduler.metronomeOn = metronomeOn;
    _applyLoop();
  }

  /// [sound] pôs [engine] em uso ([SoundOutputPlayback.attach]): o
  /// agendador passa a tocar nele. Retoma de onde o player está se ele já
  /// tocava (mudo) — sem isto o agendador ficaria parado na âncora 0 e o
  /// próximo tick do player veria o relógio de áudio "voltar" para o início
  /// e daria um seek indevido — ou sempre, com [always] (troca de saída).
  void attachSound(SoundEngine engine, {required bool always}) {
    if (_track == null) return;
    attachAudio(engine);
    final player = _player;
    if (player != null && (always || _playing)) {
      _scheduler!.play(player.position.inMicroseconds / 1000, speed: _speed);
    }
  }

  /// [sound] desligou o som ([SoundOutputPlayback.detach]): o player volta
  /// ao próprio relógio (mudo).
  void detachSound() {
    _scheduler?.pause();
    _player?.clock = null;
    _player?.speed = _speed;
  }

  void toggleMetronome() {
    _settings.metronomeOn = !_settings.metronomeOn;
    _scheduler?.metronomeOn = _settings.metronomeOn;
    notifyListeners();
  }

  /// Liga o loop nos compassos `a..b` (ocorrências, 0-based) e vai ao início
  /// do trecho.
  void setLoop(int a, int b) {
    if (_player == null) return;
    _loop = (a: a, b: b);
    _applyLoop();
    seekTo(loopRangeMs?.startMs ?? 0);
    notifyListeners();
  }

  void clearLoop() {
    _loop = null;
    _applyLoop();
    notifyListeners();
  }

  /// Empurra o loop para o agendador e avisa [onLoopChanged].
  void _applyLoop() {
    final range = loopRangeMs;
    if (range == null) {
      _scheduler?.clearLoop();
    } else {
      _scheduler?.setLoop(range.startMs, range.endMs);
    }
    onLoopChanged?.call(range);
  }

  /// Cor de destaque do player (a do treino ou a das configurações).
  set highlightColor(Color color) => _player?.highlightColor = color;

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(_onSettingsChanged);
    cancelSilentCountIn();
    _setPlaying(false);
    _scheduler?.dispose();
    _player?.dispose();
    super.dispose();
  }
}
