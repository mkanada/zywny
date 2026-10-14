import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny/course/ui/course_flow.dart';
import 'package:zywny/course/ui/exercise_screen.dart';
import 'package:zywny/render/score_renderer.dart';
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

  // O render FFI roda uma vez, no relógio real (setUpAll), e as telas usam a
  // partitura pronta: num widget test ele não termina, e um segundo render no
  // mesmo processo trava a rodada (ver `exercise_question_screens_test.dart`).
  // A rodada de `Random(7)` é a mesma em todo teste.
  late VsbDocument leituraDoc;
  setUpAll(() async {
    if (!verovioAvailable) return;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final source = SightReadingSource(
      store: SightReadingStore(prefs: SharedPreferencesAsync()),
      progress: const SightProgress(),
    );
    final round = await source.nextRound(Random(7)) as ScoreRound;
    leituraDoc = await renderBytes(round.bytes, round.fileName);
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
        rendererFactory: () => _CachedRenderer(leituraDoc),
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

  // O metrônomo do exercício com tempo vale na rodada inteira, ligado por
  // padrão (a configuração global de metrônomo é de outras telas).
  testWidgets(
    'leitura no ritmo: o metrônomo toca a rodada inteira, não só a contagem',
    (tester) async {
      final r = await _abrirLeitura(tester, leituraDoc);
      await playAllCorrect(tester, r.runner, r.midi, r.engine, r.result);
      final clicks = r.engine.scheduled.where((m) => m.status == 0x99).length;
      // A contagem (um compasso de cliques) mais uma batida por tempo da
      // rodada: sem o metrônomo, só a contagem soaria.
      expect(clicks, greaterThan(r.runner.scheduler.beats.length));
    },
    skip: !verovioAvailable,
  );

  testWidgets(
    'leitura no ritmo: o botão desliga o metrônomo da rodada inteira',
    (tester) async {
      final r = await _abrirLeitura(tester, leituraDoc);
      await tester.tap(find.byTooltip('Desligar metrônomo'));
      await tester.pump();
      expect(find.byTooltip('Ligar metrônomo'), findsOneWidget);
      await playAllCorrect(tester, r.runner, r.midi, r.engine, r.result);
      final clicks = r.engine.scheduled.where((m) => m.status == 0x99).length;
      // Só a contagem (um compasso de cliques), sem as batidas da rodada.
      expect(clicks, lessThan(r.runner.scheduler.beats.length));
    },
    skip: !verovioAvailable,
  );
}

typedef _Leitura = ({
  ScoreRoundRunner runner,
  Future<RoundResult?> result,
  FakeMidiInput midi,
  FakeSoundEngine engine,
});

/// Abre o treino de leitura com o teclado conectado e espera a primeira
/// rodada carregar.
Future<_Leitura> _abrirLeitura(WidgetTester tester, VsbDocument doc) async {
  final fake = FakeMidiCommand()
    ..list = [
      MidiDevice('id-1', 'Teclado Falso', MidiDeviceType.serial, false),
    ];
  final devices = MidiDeviceManager(
    midi: fake,
    prefs: SharedPreferencesAsync(),
  );
  final midi = FakeMidiInput();
  final engine = FakeSoundEngine();
  final settings = AppSettings();
  addTearDown(() {
    devices.dispose();
    midi.dispose();
    settings.dispose();
  });
  final deps = CourseScreenDeps(
    settings: settings,
    deviceManager: devices,
    midiInput: midi,
    progress: CourseProgressStore(prefs: SharedPreferencesAsync()),
    ensureEngine: () async => engine,
    rendererFactory: () => _CachedRenderer(doc),
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
  return (runner: runner!, result: resultFuture!, midi: midi, engine: engine);
}

/// A partitura já renderizada (ver `setUpAll`): o widget não renderiza de novo.
class _CachedRenderer implements ScoreRenderer {
  _CachedRenderer(this.document);

  final VsbDocument document;

  @override
  Future<RenderedScore> render(ScoreRenderRequest request) async =>
      RenderedScore(document);
}
