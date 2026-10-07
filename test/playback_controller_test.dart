// R10: tocar a partitura (lib/app/playback_controller.dart) sem a tela. O
// relógio é simulado: o do áudio é o `now` de um [FakeSoundEngine], o de
// parede (contagem sem som) é uma variável do teste, e o `Ticker` do player
// anda com o `pump` do `testWidgets`.

import 'dart:io';

import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/app/playback_controller.dart';
import 'package:zywny/app/sound_output_controller.dart';
import 'package:zywny_audio/metronome.dart';
import 'package:zywny_midi/midi_device_manager.dart';
import 'package:zywny_audio/performance_track.dart';
import 'package:zywny/settings/app_settings.dart';

import 'support/practice_fakes.dart';

class _NoDevicesMidiCommandPlatform extends MidiCommandPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<MidiDevice>?> get devices async => const <MidiDevice>[];

  @override
  Stream<MidiPacket>? get onMidiDataReceived => null;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => null;
}

/// O controller montado sobre a Gymnopédie, com o som desligado e o
/// sintetizador do app fechado.
class _Harness {
  _Harness._(this.settings, this.devices, this.input);

  final AppSettings settings;
  final MidiDeviceManager devices;
  final FakeMidiInput input;
  final ScoreController scores = ScoreController();
  final List<FakeSoundEngine> appEngines = [];
  late final SoundOutputController sound;
  late final PlaybackController playback;

  /// O relógio de parede da contagem sem som, em segundos.
  double wall = 0;
  int ended = 0;

  static Future<_Harness> create(WidgetTester tester) async {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final settings = AppSettings();
    await settings.load();
    final h = _Harness._(settings, MidiDeviceManager(), FakeMidiInput());
    await tester.pump();
    h.sound = SoundOutputController(
      settings: settings,
      devices: h.devices,
      input: h.input,
      monitorPitch: (r, {required midiKeyboard}) => r,
      playback: SoundOutputPlayback(
        hasTrack: () => h.playback.track != null,
        attach: (engine, {required always}) =>
            h.playback.attachSound(engine, always: always),
        detach: () => h.playback.detachSound(),
        endPractice: () {},
      ),
      appEngineFactory: () async {
        final engine = FakeSoundEngine();
        h.appEngines.add(engine);
        return engine;
      },
    );
    h.playback = PlaybackController(
      sound: h.sound,
      settings: settings,
      controller: h.scores,
      onEnded: () => h.ended++,
      wallSeconds: () => h.wall,
      wakelock: (_) {},
    );
    final document = VsbDocument.fromBytes(
      File('test/fixtures/erik-satie.vsb').readAsBytesSync(),
    );
    h.playback.attach(document, PerformanceTrack.fromDocument(document));
    return h;
  }

  ScorePlayer get player => playback.player!;
  double get positionMs => player.position.inMicroseconds / 1000;

  /// Anda [seconds] nos dois relógios (o do motor aberto, se houver) e
  /// deixa o `Ticker` e os `Timer`s correrem.
  Future<void> advance(WidgetTester tester, double seconds) async {
    const step = 0.05;
    for (var t = 0.0; t < seconds - 1e-9; t += step) {
      wall += step;
      for (final e in appEngines) {
        e.now += step;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// No fim de cada teste (antes da conferência de `Timer`s pendentes).
  void dispose() {
    playback.dispose();
    sound.dispose();
    scores.dispose();
    input.dispose();
    devices.dispose();
    settings.dispose();
  }
}

void main() {
  testWidgets('play e stop sem som: a contagem é feita aqui, muda, e o stop '
      'volta ao começo', (tester) async {
    final h = await _Harness.create(tester);
    expect(h.sound.soundOn, isFalse);

    h.playback.togglePlay();
    expect(h.playback.playing, isTrue);
    expect(h.playback.countIn(), isNotNull, reason: 'contando');
    expect(h.player.isPlaying, isFalse, reason: 'o player espera a contagem');

    await h.advance(tester, 6);
    expect(h.playback.countIn(), isNull);
    expect(h.player.isPlaying, isTrue);
    expect(h.positionMs, greaterThan(0));

    h.playback.stop();
    expect(h.playback.playing, isFalse);
    expect(h.player.isPlaying, isFalse);
    expect(h.positionMs, 0);
    h.dispose();
  });

  testWidgets('contagem sem som com o sintetizador aberto: os cliques soam '
      'nele, a música não', (tester) async {
    final h = await _Harness.create(tester);
    await h.sound.ensureEngine();
    final engine = h.appEngines.single;
    expect(h.sound.soundOn, isFalse);

    h.playback.togglePlay();
    expect(h.playback.scheduler, isNull);
    final clicks = engine.scheduled.where((m) => m.status & 0xF0 == 0x90);
    expect(clicks, isNotEmpty);
    expect(clicks.every((m) => m.status & 0x0F == kMetronomeChannel), isTrue);

    // Pausar no meio da contagem desiste dela e dos cliques.
    h.playback.togglePlay();
    expect(h.playback.countIn(), isNull);
    await h.advance(tester, 6);
    expect(h.player.isPlaying, isFalse);
    expect(h.positionMs, 0);
    h.dispose();
  });

  testWidgets('loop A-B com som: passado o fim do trecho, volta ao início '
      'dele', (tester) async {
    final h = await _Harness.create(tester);
    await h.sound.toggleSound();
    expect(h.sound.soundOn, isTrue);
    final scheduler = h.playback.scheduler!;

    h.playback.setLoop(1, 1);
    final range = h.playback.loopRangeMs!;
    expect(h.positionMs, closeTo(range.startMs, 1));

    h.playback.togglePlay();
    final lap = (range.endMs - range.startMs) / 1000;
    // Contagem (um compasso) + a volta inteira + meio compasso.
    await h.advance(tester, lap * 2.5 + 1);
    expect(scheduler.loopLaps, greaterThanOrEqualTo(1));
    expect(h.positionMs, greaterThanOrEqualTo(range.startMs - 1));
    expect(h.positionMs, lessThan(range.endMs));

    h.playback.clearLoop();
    expect(h.playback.loop, isNull);
    h.dispose();
  });

  testWidgets('trocar o motor durante o play não perde a posição', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    await h.sound.toggleSound();
    h.playback.togglePlay();
    await h.advance(tester, 8);
    final before = h.positionMs;
    expect(before, greaterThan(1000), reason: 'já tocando, depois da contagem');

    // O que o `SoundOutputController` faz ao trocar de saída com o som
    // ligado: o agendador vai para o motor novo e retoma do player.
    final other = FakeSoundEngine()..now = 100;
    h.appEngines.add(other);
    h.playback.attachSound(other, always: true);
    expect(h.playback.scheduler!.engine, same(other));
    expect(h.playback.scheduler!.positionMs, closeTo(before, 1));

    await h.advance(tester, 1);
    expect(h.player.isPlaying, isTrue);
    expect(h.positionMs, greaterThan(before));
    expect(h.positionMs, lessThan(before + 2000));
    h.dispose();
  });

  testWidgets('a cada gravura nova o player é outro, parado no começo', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    h.playback.togglePlay();
    await h.advance(tester, 6);
    final first = h.player;

    final document = VsbDocument.fromBytes(
      File('test/fixtures/erik-satie.vsb').readAsBytesSync(),
    );
    h.playback.attach(document, PerformanceTrack.fromDocument(document));
    expect(h.player, isNot(same(first)));
    expect(h.playback.playing, isFalse);
    expect(h.positionMs, 0);
    h.dispose();
  });
}
