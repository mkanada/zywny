import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny/course/ui/course_flow.dart';
import 'package:zywny/course/ui/exercise_screen.dart';
import 'package:zywny/practice/hand.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/sight_reading/sight_progress.dart';
import 'package:zywny/sight_reading/sight_reading_source.dart';
import 'package:zywny_midi/midi_device_manager.dart';

import 'support/practice_fakes.dart';
import 'support/render_helper.dart';

class _FakeMidiCommand implements MidiCommand {
  List<MidiDevice> list = [];
  final StreamController<MidiSetupChange> setup =
      StreamController<MidiSetupChange>.broadcast();

  @override
  Future<List<MidiDevice>?> get devices async => list;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => setup.stream;

  @override
  Future<void> connectToDevice(
    MidiDevice device, {
    Duration? awaitConnectionTimeout,
  }) async {
    device.connected = true;
  }

  @override
  void disconnectDevice(MidiDevice device) => device.connected = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Toca cada nota da pauta do aluno no instante dela, como o aluno simulado
/// do tempo real (`playTimedRound`): anda o agendador até o evento e aperta.
Future<void> _playAllCorrect(
  WidgetTester tester,
  ScoreRoundRunner runner,
  FakeMidiInput midi,
  FakeSoundEngine engine,
  Future<RoundResult?> result,
) async {
  var done = false;
  unawaited(result.whenComplete(() => done = true));
  final staves = runner.practice.hand.studentStaves;
  final events = [
    for (final e in runner.track.events)
      if (staves.contains(e.staff) && !e.ornament) e,
  ];
  for (final event in events) {
    if (done) break;
    _advance(engine, runner, event.onMs);
    midi.press(event.pitch, atSeconds: engine.now);
    await tester.pump();
    midi.release(event.pitch, atSeconds: engine.now);
    await tester.pump();
  }
  _advance(engine, runner, runner.track.durationMs + 500);
  for (var i = 0; !done && i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await result;
}

void _advance(FakeSoundEngine engine, ScoreRoundRunner runner, double ms) {
  var guard = 0;
  while (runner.scheduler.positionMs < ms) {
    engine.now += 0.025;
    runner.scheduler.pump();
    if (guard++ > 200000) throw StateError('o relógio não chegou a $ms ms');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'treino de leitura: a rodada toca, o painel diz o progresso e grava',
    (tester) async {
      final fake = _FakeMidiCommand()
        ..list = [
          MidiDevice('id-1', 'Teclado Falso', MidiDeviceType.serial, false),
        ];
      final devices = MidiDeviceManager(
        midi: fake,
        prefs: SharedPreferencesAsync(),
      );
      addTearDown(devices.dispose);
      final midi = FakeMidiInput();
      final engine = FakeSoundEngine();
      final settings = AppSettings();
      addTearDown(() {
        midi.dispose();
        settings.dispose();
      });
      final deps = CourseScreenDeps(
        settings: settings,
        deviceManager: devices,
        midiInput: midi,
        progress: CourseProgressStore(prefs: SharedPreferencesAsync()),
        ensureEngine: () async => engine,
        rendererFactory: () => LibverovioRenderer(),
      );
      final store = SightReadingStore(prefs: SharedPreferencesAsync());
      final source = SightReadingSource(
        store: store,
        progress: const SightProgress(),
      );

      ScoreRoundRunner? runner;
      Future<RoundResult?>? resultFuture;
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseScreen.source(
            source: source,
            deps: deps,
            rng: Random(7),
            onRound: (r, f) {
              runner = r;
              resultFuture = f;
            },
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 100 && runner == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(runner, isNotNull, reason: 'a rodada não carregou');
      expect(find.text('Leitura 1a'), findsOneWidget);

      await _playAllCorrect(tester, runner!, midi, engine, resultFuture!);
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('1 de 3 rodadas limpas').evaluate().isNotEmpty) break;
      }
      expect(find.text('1 de 3 rodadas limpas'), findsOneWidget);
      expect(source.progress.clean, 1);
      final saved = await tester.runAsync(() => store.load());
      expect(saved?.clean, 1);
    },
    skip: !verovioAvailable,
  );
}
