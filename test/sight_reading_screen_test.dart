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
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/sight_reading/sight_progress.dart';
import 'package:zywny/sight_reading/sight_reading_source.dart';
import 'package:zywny_midi/midi_device_manager.dart';

import 'support/practice_fakes.dart';
import 'support/render_helper.dart';
import 'support/sight_reading_screen_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'treino de leitura: a rodada toca, o painel diz o progresso e grava',
    (tester) async {
      final fake = FakeMidiCommand()
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

      await playAllCorrect(tester, runner!, midi, engine, resultFuture!);
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
