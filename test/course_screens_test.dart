// I09, critérios 2 e 3 — `test/course_screens_test.dart`: a lista mostra o
// estado certo; lição bloqueada mostra o motivo e abre com "assim mesmo";
// sem teclado, o exercício MIDI mostra "Conecte o teclado"; com o
// `FakeMidiInput`, uma rodada `play-notes` toda certa termina com o painel
// de aprovado e grava o progresso. E a entrada na biblioteca (cartão sem
// biblioteca, linha "Cursos" com biblioteca).
//
// Todo IO/FFI no `setUpAll` (relógio real); os widgets consomem memória.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/exercise/exercise_kind.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/exercise/score_round_runner.dart';
import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/course_reader.dart';
import 'package:zywny/course/loaded_course.dart';
import 'package:zywny/course/score/lesson_score.dart';
import 'package:zywny/course/ui/course_flow.dart';
import 'package:zywny/course/ui/course_screen.dart';
import 'package:zywny/course/ui/courses_screen.dart';
import 'package:zywny/course/ui/exercise_screen.dart';
import 'package:zywny/course/ui/lesson_screen.dart';
import 'package:zywny/app/library_screen.dart';
import 'package:zywny_library/piece.dart';
import 'package:zywny_midi/midi_device_manager.dart';
import 'package:zywny/render/score_renderer.dart';
import 'package:zywny/settings/app_settings.dart';

import 'support/practice_fakes.dart';
import 'support/render_helper.dart';

class _NoDevicesMidiCommandPlatform extends MidiCommandPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<MidiDevice>?> get devices async => const <MidiDevice>[];

  @override
  Stream<MidiPacket>? get onMidiDataReceived => null;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => null;
}

/// Teclado falso na lista do gerenciador (a conexão automática o adota, como
/// no aparelho — e o `refresh` não limpa o que está na lista).
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

class _CachedRenderer implements ScoreRenderer {
  _CachedRenderer(this.document);

  final VsbDocument document;

  @override
  Future<RenderedScore> render(ScoreRenderRequest request) async =>
      RenderedScore(document);
}

MemoryCourseFiles _twoLessons() => MemoryCourseFiles({
  'course.md':
      '---\nformat: 1\nid: t\ntitle: Curso Teste\nauthor: zywny\nversion: "1"\n'
      'lessons: [a, b]\n---\n\nApresentação do curso.\n',
  'lessons/01-a.md':
      '---\nid: a\ntitle: Primeira\n---\n\nLeia isto.\n\n'
      '```zywny-exercise\nid: ex-a\ntype: play-notes\ntitle: Toque A\n'
      'clef: treble\nnotes: {random: C4-G4, count: 12}\npass: {accuracy: 90}\n```\n',
  'lessons/02-b.md':
      '---\nid: b\ntitle: Segunda\nrequires: [a]\n---\n\nLeia aquilo.\n\n'
      '```zywny-exercise\nid: ex-b\ntype: play-notes\ntitle: Toque B\n'
      'clef: treble\nnotes: {random: C4-G4, count: 12}\npass: {accuracy: 90}\n```\n',
});

/// O aluno simulado com o relógio do widget test: lê o passo pendente,
/// anda o `FakeSoundEngine` até ele e aperta/solta as teclas (tudo certo).
/// `pumpEventQueue` não volta no relógio falso — aqui quem anda é o
/// `tester.pump()`.
Future<void> _playAllCorrect(
  WidgetTester tester,
  ScoreRoundRunner runner,
  FakeMidiInput midi,
  FakeSoundEngine engine,
  Future<RoundResult?> result,
) async {
  var done = false;
  unawaited(result.whenComplete(() => done = true));
  final practice = runner.practice;
  var guard = 0;
  while (!done) {
    if (guard++ > 5000) throw StateError('a rodada não terminou');
    final step = practice.currentStep.value;
    if (step == null) {
      await tester.pump();
      continue;
    }
    var inner = 0;
    while (runner.scheduler.positionMs < step.onMs) {
      engine.now += 0.025;
      runner.scheduler.pump();
      if (inner++ > 200000) throw StateError('o relógio não chegou');
    }
    final wanted = {for (final e in step.notes) e.pitch};
    for (final pitch in wanted) {
      midi.press(pitch, atSeconds: engine.now);
    }
    await tester.pump();
    for (final pitch in wanted) {
      midi.release(pitch, atSeconds: engine.now);
    }
    await tester.pump();
  }
  await result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadedCourse loaded;
  late MemoryCourseFiles files;
  VsbDocument? cachedScore;

  setUpAll(() async {
    await loadScoreFonts();
    files = _twoLessons();
    final result = await readCourse(files);
    expect(result.course, isNotNull, reason: result.issues.join('\n'));
    loaded = LoadedCourse(
      course: result.course!,
      files: files,
      origin: CourseOrigin.installed,
    );
    if (verovioAvailable) {
      // A partitura da PRIMEIRA rodada (semente 7, a mesma da tela): o
      // render FFI não termina no relógio falso, então o widget usa este
      // documento pronto — com os compassos e ids da rodada de verdade.
      final firstSpec = result.course!.lessons.first.exercises.single;
      final firstRound =
          await generateRound(firstSpec, files, Random(7)) as ScoreRound;
      final layout = lessonScoreLayout(800);
      final rendered = await LibverovioRenderer().render(
        ScoreRenderRequest(
          source: firstRound.bytes,
          fileName: firstRound.fileName,
          pageWidth: layout.pageWidth,
          pageHeight: layout.pageHeight,
          options: layout.options,
        ),
      );
      cachedScore = rendered.document;
    }
  });

  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  CourseScreenDeps makeDeps({
    required MidiDeviceManager devices,
    required FakeMidiInput midi,
    required FakeSoundEngine engine,
    required CourseProgressStore progress,
  }) => CourseScreenDeps(
    settings: AppSettings(),
    deviceManager: devices,
    midiInput: midi,
    progress: progress,
    ensureEngine: () async => engine,
    rendererFactory: () => _CachedRenderer(cachedScore!),
  );

  Future<MidiDeviceManager> makeDevices({bool connected = false}) async {
    // Sem `pumpEventQueue` aqui: no relógio falso do widget test ele não
    // volta (o `refresh` do gerenciador é `unawaited` e assenta nos `pump`).
    final fake = _FakeMidiCommand();
    if (connected) {
      fake.list = [
        MidiDevice('id-1', 'Teclado Falso', MidiDeviceType.serial, false),
      ];
    }
    final manager = MidiDeviceManager(
      midi: fake,
      prefs: SharedPreferencesAsync(),
    );
    addTearDown(manager.dispose);
    return manager;
  }

  testWidgets('a lista mostra o estado certo e continua', (tester) async {
    final progress = MemoryCourseProgressStore();
    final spec = loaded.course.lessons.first.exercises.single;
    await progress.recordAttempt(
      't',
      spec,
      const RoundResult(hits: 12, total: 12),
    );
    LoadedCourse? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: CoursesScreen(
          courses: [loaded],
          progress: progress,
          onOpen: (context, course) => opened = course,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Curso Teste'), findsOneWidget);
    expect(find.text('1 de 2 lições'), findsOneWidget);
    expect(find.text('Continuar: Segunda'), findsOneWidget);
    await tester.tap(find.text('Curso Teste'));
    await tester.pump();
    expect(opened?.id, 't');
  });

  testWidgets('lição bloqueada mostra o motivo e abre com "assim mesmo"', (
    tester,
  ) async {
    final devices = await makeDevices();
    final progress = MemoryCourseProgressStore();
    final deps = makeDeps(
      devices: devices,
      midi: FakeMidiInput(),
      engine: FakeSoundEngine(),
      progress: progress,
    );
    addTearDown(() {
      deps.midiInput.dispose();
      deps.settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: CourseScreen(loaded: loaded, progress: progress, deps: deps),
      ),
    );
    await tester.pump();
    expect(find.text('Depois de: Primeira'), findsOneWidget);
    await tester.tap(find.text('Segunda'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir assim mesmo'), findsOneWidget);
    await tester.tap(find.text('Abrir assim mesmo'));
    await tester.pumpAndSettle();
    // A lição abriu (texto + aviso de ordem).
    expect(
      find.textContaining('Leia aquilo.', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('assim mesmo'), findsWidgets);
  });

  testWidgets('lição aberta mostra estado e próxima lição', (tester) async {
    final devices = await makeDevices();
    final progress = MemoryCourseProgressStore();
    final spec = loaded.course.lessons.first.exercises.single;
    await progress.recordAttempt(
      't',
      spec,
      const RoundResult(hits: 12, total: 12),
    );
    final deps = makeDeps(
      devices: devices,
      midi: FakeMidiInput(),
      engine: FakeSoundEngine(),
      progress: progress,
    );
    addTearDown(() {
      deps.midiInput.dispose();
      deps.settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          loaded: loaded,
          lessonId: 'a',
          progress: progress,
          deps: deps,
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('aprovado · melhor 100%'), findsOneWidget);
    expect(find.textContaining('Próxima lição: Segunda'), findsOneWidget);
    await tester.tap(find.textContaining('Próxima lição: Segunda'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Leia aquilo.', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('sem teclado, o exercício MIDI mostra "Conecte o teclado"', (
    tester,
  ) async {
    final devices = await makeDevices(connected: false);
    final progress = MemoryCourseProgressStore();
    final deps = makeDeps(
      devices: devices,
      midi: FakeMidiInput(),
      engine: FakeSoundEngine(),
      progress: progress,
    );
    addTearDown(() {
      deps.midiInput.dispose();
      deps.settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          loaded: loaded,
          lesson: loaded.course.lessons.first,
          spec: loaded.course.lessons.first.exercises.single,
          deps: deps,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Conecte o teclado'), findsOneWidget);
    expect(find.text('Conectar teclado'), findsOneWidget);
    expect(find.byType(ScoreView), findsNothing);
  });

  testWidgets('rodada toda certa aprova e grava o progresso', (tester) async {
    final devices = await makeDevices(connected: true);
    final midi = FakeMidiInput();
    final engine = FakeSoundEngine();
    final progress = MemoryCourseProgressStore();
    final deps = makeDeps(
      devices: devices,
      midi: midi,
      engine: engine,
      progress: progress,
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });
    ScoreRoundRunner? runner;
    Future<RoundResult?>? resultFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          loaded: loaded,
          lesson: loaded.course.lessons.first,
          spec: loaded.course.lessons.first.exercises.single,
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
    for (var i = 0; i < 50 && runner == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(runner, isNotNull, reason: 'a rodada não carregou');
    await _playAllCorrect(tester, runner!, midi, engine, resultFuture!);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Exercício aprovado!').evaluate().isNotEmpty) break;
    }
    expect(find.text('Exercício aprovado!'), findsOneWidget);
    expect(find.textContaining('12 de 12 de primeira'), findsOneWidget);
    // Primeira vez: só o número de erros (ainda não há melhor anterior).
    expect(find.text('nenhum erro'), findsOneWidget);
    expect(progress['t'].records['ex-a']?.passed, isTrue);
    expect(progress['t'].records['ex-a']?.bestPercent, 100);
    // Outra rodada recomeça (rodada 2). O painel fica no pé da tela.
    await tester.tap(find.text('Outra rodada'));
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('rodada 2').evaluate().isNotEmpty) break;
    }
    expect(find.text('rodada 2'), findsOneWidget);
  });

  testWidgets('biblioteca sem músicas mostra o cartão do curso inicial', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          loadCatalog: () async => PieceCatalog.none(),
          loadScore: (piece) async => Uint8List(0),
          loadCourses: () async => [loaded],
          scoreBuilder: (context, o) => const Scaffold(body: Text('partitura')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Comece pelo curso inicial'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    // Abre direto na primeira lição aberta (a Primeira).
    expect(find.textContaining('Leia isto.', findRichText: true), findsWidgets);
  });

  testWidgets('biblioteca com músicas mostra o item "Cursos"', (tester) async {
    final pieces = [
      Piece(
        number: 1,
        title: 'Hino Um',
        composer: 'Autor',
        titleKey: 'hino um',
        composerKey: 'autor',
        searchKey: 'hino um autor',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          loadCatalog: () async => PieceCatalog(pieces),
          loadScore: (piece) async => Uint8List(0),
          loadCourses: () async => [loaded],
          scoreBuilder: (context, o) => const Scaffold(body: Text('partitura')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Curso Teste'), findsOneWidget);
    expect(find.textContaining('0 de 2'), findsOneWidget);
    await tester.tap(find.text('Curso Teste'));
    await tester.pumpAndSettle();
    // A lista de cursos; mais um toque chega à tela do curso.
    expect(find.text('Cursos'), findsWidgets);
    expect(find.text('Continuar: Primeira'), findsOneWidget);
    await tester.tap(find.text('Curso Teste'));
    await tester.pumpAndSettle();
    expect(find.text('Apresentação'), findsOneWidget);
  });
}
