// R08: por onde sai o som (lib/app/sound_output_controller.dart), sem a
// tela. Os motores são falsos: o do app é um [FakeSoundEngine] que conta os
// descartes, o MIDI é o de verdade sobre um remetente que só anota bytes.

import 'dart:typed_data';

import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/app/sound_output_controller.dart';
import 'package:zywny_midi/midi_device_manager.dart';
import 'package:zywny_midi/midi_out_sound_engine.dart';
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

class _AppEngine extends FakeSoundEngine {
  bool disposed = false;

  @override
  Future<void> dispose() async => disposed = true;
}

/// Anota cada mensagem com o dispositivo a que se destina.
class _Sender implements MidiSender {
  final List<(String?, List<int>)> sent = [];

  @override
  void send(Uint8List data, {String? deviceId}) =>
      sent.add((deviceId, List<int>.of(data)));

  /// O motor mandou "all notes off" (CC 123) a [deviceId] — o que o
  /// `dispose` do motor MIDI faz.
  bool silenced(String deviceId) =>
      sent.any((m) => m.$1 == deviceId && m.$2.length == 3 && m.$2[1] == 123);
}

MidiDevice _device(String id) =>
    MidiDevice(id, 'Teclado $id', MidiDeviceType.serial, false);

void main() {
  late AppSettings settings;
  late MidiDeviceManager devices;
  late FakeMidiInput input;
  late List<_AppEngine> appEngines;
  late List<_Sender> senders;
  late int attached;
  late int detached;
  late SoundOutputController sound;
  late bool soundDisposed;

  setUp(() async {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = AppSettings();
    await settings.load();
    devices = MidiDeviceManager();
    // A primeira listagem (vazia) zeraria o `connected` que os testes põem:
    // espera ela terminar.
    await pumpEventQueue();
    input = FakeMidiInput();
    appEngines = [];
    senders = [];
    attached = 0;
    detached = 0;
    soundDisposed = false;
    sound = SoundOutputController(
      settings: settings,
      devices: devices,
      input: input,
      monitorPitch: (r, {required midiKeyboard}) => r,
      playback: SoundOutputPlayback(
        hasTrack: () => true,
        attach: (_, {required always}) => attached++,
        detach: () => detached++,
        endPractice: () {},
      ),
      appEngineFactory: () async {
        final engine = _AppEngine();
        appEngines.add(engine);
        return engine;
      },
      midiSender: () {
        final sender = _Sender();
        senders.add(sender);
        return sender;
      },
    );
  });

  tearDown(() {
    if (!soundDisposed) sound.dispose();
    input.dispose();
    devices.dispose();
    settings.dispose();
  });

  test('trocar de saída preserva o motor do app', () async {
    devices.connected.value = _device('a');
    await pumpEventQueue();
    await sound.toggleSound();
    expect(sound.soundOn, isTrue);
    final app = sound.engine;
    expect(app, same(appEngines.single));

    settings.output = SoundOutput.midiKeyboard;
    await pumpEventQueue();
    expect(sound.output, SoundOutput.midiKeyboard);
    expect(sound.engine, isA<MidiOutSoundEngine>());
    expect(sound.soundOn, isTrue);

    settings.output = SoundOutput.appSynth;
    await pumpEventQueue();
    expect(sound.output, SoundOutput.appSynth);
    expect(sound.engine, same(app));
    expect(appEngines, hasLength(1));
    expect(app, isA<_AppEngine>().having((e) => e.disposed, 'disposed', false));
    // Ligou, foi para o teclado e voltou: o agendador religou nas três.
    expect(attached, 3);
  });

  test('o motor MIDI é recriado quando o dispositivo muda', () async {
    settings.output = SoundOutput.midiKeyboard;
    devices.connected.value = _device('a');
    await pumpEventQueue();
    await sound.toggleSound();
    final first = sound.engine;
    expect(first, isA<MidiOutSoundEngine>());

    devices.connected.value = _device('b');
    await pumpEventQueue();
    // O antigo foi descartado (e silenciou o teclado que estava ligado),
    // e o som, que saía por ele, desligou.
    expect(senders.single.silenced('a'), isTrue);
    expect(sound.engine, isNull);
    expect(sound.soundOn, isFalse);
    expect(detached, 1);

    final second = await sound.ensureEngine();
    expect(second, isA<MidiOutSoundEngine>());
    expect(second, isNot(same(first)));
    expect(senders, hasLength(2));
  });

  test('o monitor segue o dispositivo', () async {
    await devices.setMonitorEnabled('a', true);
    await sound.ensureEngine(); // o motor do app já aberto
    final app = appEngines.single;

    devices.connected.value = _device('a');
    await pumpEventQueue();
    expect(sound.midiMonitorOn, isTrue);
    input.press(60);
    await pumpEventQueue();
    expect(
      app.sent.where((m) => m[0] & 0xF0 == 0x90 && m[1] == 60),
      hasLength(1),
    );

    devices.connected.value = _device('b'); // sem o monitor guardado
    await pumpEventQueue();
    expect(sound.midiMonitorOn, isFalse);
    input.press(62);
    await pumpEventQueue();
    expect(app.sent.where((m) => m[1] == 62), isEmpty);

    devices.connected.value = _device('a');
    await pumpEventQueue();
    expect(sound.midiMonitorOn, isTrue);
  });

  test('sem motor aberto, o monitor não liga sozinho', () async {
    await devices.setMonitorEnabled('a', true);
    devices.connected.value = _device('a');
    await pumpEventQueue();
    expect(sound.midiMonitorOn, isFalse);
    expect(appEngines, isEmpty);
  });

  test('dispose fecha os dois motores', () async {
    devices.connected.value = _device('a');
    await pumpEventQueue();
    await sound.ensureEngine();
    settings.output = SoundOutput.midiKeyboard;
    await pumpEventQueue();
    await sound.ensureEngine();
    expect(senders, hasLength(1));

    sound.dispose();
    soundDisposed = true;
    await pumpEventQueue();
    expect(appEngines.single.disposed, isTrue);
    expect(senders.single.silenced('a'), isTrue);
  });
}
