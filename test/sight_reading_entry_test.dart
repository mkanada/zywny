import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/ui/course_flow.dart';
import 'package:zywny/course/ui/courses_screen.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/sight_reading/sight_listen_source.dart';
import 'package:zywny/sight_reading/sight_progress.dart';
import 'package:zywny_midi/midi_device_manager.dart';

import 'support/practice_fakes.dart';
import 'support/render_helper.dart';

/// Sem teclado: a lista de dispositivos MIDI fica vazia.
class _NoMidiCommand implements MidiCommand {
  @override
  Future<List<MidiDevice>?> get devices async => const [];

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CoursesScreen _list({
  Future<void> Function(BuildContext context)? onSightReading,
  Future<void> Function(BuildContext context)? onSightListening,
  SightReadingStore? store,
}) => CoursesScreen(
  courses: const [],
  progress: CourseProgressStore(prefs: SharedPreferencesAsync()),
  onOpen: (context, course) {},
  onSightReading: onSightReading,
  onSightListening: onSightListening,
  sightStore: store,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('o cartão tem "Ler e tocar", "Só ouvido" e a chave do ouvido', (
    tester,
  ) async {
    var read = 0;
    var listened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _list(
          onSightReading: (context) async {
            read++;
          },
          onSightListening: (context) async {
            listened++;
          },
          store: SightReadingStore(prefs: SharedPreferencesAsync()),
        ),
      ),
    );
    expect(find.text('Leitura à primeira vista'), findsOneWidget);
    expect(find.text('Ler e tocar'), findsOneWidget);
    expect(find.text('Só ouvido'), findsOneWidget);
    expect(find.text('Níveis'), findsOneWidget);
    expect(find.text('Ouvido depois de cada leitura'), findsOneWidget);

    await tester.tap(find.text('Ler e tocar'));
    await tester.pump();
    await tester.tap(find.text('Só ouvido'));
    await tester.pump();
    expect(read, 1);
    expect(listened, 1);
  });

  testWidgets('o toque no título do cartão não abre o treino', (tester) async {
    var read = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _list(
          onSightReading: (context) async {
            read++;
          },
          store: SightReadingStore(prefs: SharedPreferencesAsync()),
        ),
      ),
    );
    await tester.tap(find.text('Leitura à primeira vista'));
    await tester.pump();
    expect(read, 0);
  });

  testWidgets('"Níveis" abre a lista dos passos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _list(
          onSightReading: (context) async {},
          store: SightReadingStore(prefs: SharedPreferencesAsync()),
        ),
      ),
    );
    await tester.tap(find.text('Níveis'));
    await tester.pump(const Duration(milliseconds: 400));
    // O progresso guardado chega de forma assíncrona; a lista aparece depois.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    expect(find.text('Níveis da leitura'), findsOneWidget);
    expect(find.text('Nível 1'), findsOneWidget);
  });

  testWidgets('desligar a chave do ouvido grava false', (tester) async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    await tester.pumpWidget(
      MaterialApp(
        home: _list(onSightReading: (context) async {}, store: store),
      ),
    );
    expect(await tester.runAsync(store.loadEarOn), isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(await tester.runAsync(store.loadEarOn), isFalse);
  });

  testWidgets('sem o "só ouvido", o cartão não mostra o botão', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _list(
          onSightReading: (context) async {},
          store: SightReadingStore(prefs: SharedPreferencesAsync()),
        ),
      ),
    );
    expect(find.text('Ler e tocar'), findsOneWidget);
    expect(find.text('Só ouvido'), findsNothing);
  });

  testWidgets('sem o treino, a lista não mostra o cartão', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoursesScreen(
          courses: const [],
          progress: CourseProgressStore(prefs: SharedPreferencesAsync()),
          onOpen: (context, course) {},
        ),
      ),
    );
    expect(find.text('Leitura à primeira vista'), findsNothing);
    expect(find.text('Só ouvido'), findsNothing);
  });

  testWidgets('"Só ouvido" abre a pergunta sem pedir o teclado', (
    tester,
  ) async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    final devices = MidiDeviceManager(
      midi: _NoMidiCommand(),
      prefs: SharedPreferencesAsync(),
    );
    addTearDown(devices.dispose);
    final midi = FakeMidiInput();
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
      ensureEngine: () async => FakeSoundEngine(),
      rendererFactory: () => LibverovioRenderer(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: _list(
          onSightReading: (context) async {},
          onSightListening: (context) =>
              openSightListening(context, deps, store: store),
          store: store,
        ),
      ),
    );

    await tester.tap(find.text('Só ouvido'));
    await tester.pump();
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Em que compasso soou diferente?').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.text('Ouvido 1a'), findsOneWidget);
    expect(find.text('Conectar teclado'), findsNothing);
    expect(find.text('Em que compasso soou diferente?'), findsOneWidget);

    // Sai da tela antes de o teste acabar: as esperas da pergunta são
    // canceladas com ela.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, skip: !verovioAvailable);
}
