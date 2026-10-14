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
import 'package:zywny/sight_reading/sight_listen.dart';
import 'package:zywny/sight_reading/sight_progress.dart';
import 'package:zywny/sight_reading/sight_reading_source.dart';
import 'package:zywny/sight_reading/sight_steps.dart';
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
    'leitura certa, "Agora, de ouvido", resposta certa: a próxima leitura '
    'vem direto, sem painel',
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
      var readings = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseScreen.source(
            source: source,
            deps: deps,
            rng: Random(7),
            onRound: (r, f) {
              runner = r;
              resultFuture = f;
              readings++;
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
      expect(runner, isNotNull, reason: 'a leitura não carregou');
      await playAllCorrect(tester, runner!, midi, engine, resultFuture!);

      Future<void> until(String text) async {
        for (var i = 0; i < 100; i++) {
          if (find.text(text).evaluate().isNotEmpty) return;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      await until('Agora, de ouvido');
      expect(find.text('Agora, de ouvido'), findsOneWidget);
      await tester.tap(find.text('Agora, de ouvido'));
      await tester.pump();
      await until('Em que compasso soou diferente?');
      expect(find.text('Em que compasso soou diferente?'), findsOneWidget);

      // A pergunta é a da semente da primeira leitura: o ExerciseScreen
      // sorteia com `Random(7)` e a leitura é a primeira rodada.
      final seed = Random(7).nextInt(1 << 31);
      final correct = sightListenQuestion(sightSteps.first, seed).correct!;
      await tester.tap(find.widgetWithText(FilledButton, '${correct + 1}'));
      await tester.pump();
      await until('Terminar');
      expect(find.text('Certo!'), findsOneWidget);
      await tester.tap(find.text('Terminar'));
      await tester.pump();

      // Sem painel: a próxima leitura começa sozinha.
      for (var i = 0; i < 100 && readings < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(readings, 2, reason: 'a próxima leitura não começou');
      expect(find.text('Agora, de ouvido'), findsNothing);
      expect(find.text('Em que compasso soou diferente?'), findsNothing);
      expect(source.progress.earHits, 1);
      expect(source.progress.earTotal, 1);
      expect(source.progress.clean, 1);
      expect(find.text('Leitura 1a'), findsOneWidget);
    },
    skip: !verovioAvailable,
  );
}
