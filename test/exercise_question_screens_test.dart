// I07, critério 3 — sem teclado, `name-note`, `count-beats` e `choice`
// abrem e rodam; `find-key` pede o teclado.
//
// Todo IO/FFI no `setUpAll` (relógio real); os widgets consomem memória
// (`_CachedRenderer`), como o `course_screens_test.dart` — o render FFI não
// termina no relógio falso do widget test.
import 'dart:async';
import 'dart:math';

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
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/loaded_course.dart';
import 'package:zywny/course/ui/course_flow.dart';
import 'package:zywny/course/ui/exercise_screen.dart';
import 'package:zywny/midi/midi_device_manager.dart';
import 'package:zywny/render/score_renderer.dart';
import 'package:zywny/settings/app_settings.dart';

import 'support/course_helpers.dart';
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

Future<MidiDeviceManager> _makeDevices({bool connected = false}) async {
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

CourseScreenDeps _makeDeps({
  required MidiDeviceManager devices,
  required FakeMidiInput midi,
  required FakeSoundEngine engine,
  required CourseProgressStore progress,
  ScoreRenderer Function()? rendererFactory,
}) => CourseScreenDeps(
  settings: AppSettings(),
  deviceManager: devices,
  midiInput: midi,
  progress: progress,
  ensureEngine: () async => engine,
  rendererFactory: rendererFactory ?? createScoreRenderer,
);

Future<LoadedCourse> _loadedWith(String exerciseBody) async {
  final files = oneLessonCourse('```zywny-exercise\n$exerciseBody\n```\n');
  final result = await readCourse(files);
  if (result.course == null) {
    throw StateError('curso inválido:\n${result.issues.join('\n')}');
  }
  return LoadedCourse(
    course: result.course!,
    files: files,
    origin: CourseOrigin.installed,
  );
}

Future<VsbDocument> _renderRound(QuestionRound round) async {
  const options = {
    'adjustPageHeight': true,
    'header': 'none',
    'footer': 'none',
    'breaks': 'auto',
    'pageMarginTop': 40,
    'pageMarginBottom': 40,
    'pageMarginLeft': 40,
    'pageMarginRight': 40,
    'unit': 6,
  };
  return (await LibverovioRenderer().render(
    ScoreRenderRequest(
      source: round.scoreBytes!,
      fileName: round.fileName!,
      pageWidth: 800,
      pageHeight: 2000,
      options: options,
    ),
  )).document;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadedCourse nameNoteLoaded;
  late QuestionRound nameNoteRound;
  late VsbDocument nameNoteDoc;

  late LoadedCourse countBeatsLoaded;
  late VsbDocument countBeatsDoc;

  late LoadedCourse choiceLoaded;
  late LoadedCourse findKeyLoaded;

  setUpAll(() async {
    await loadScoreFonts();
    if (!verovioAvailable) return;
    nameNoteLoaded = await _loadedWith(
      'id: n\ntype: name-note\ntitle: Nota\nnotes: [C4, D4]\n',
    );
    nameNoteRound =
        await generateRound(
              nameNoteLoaded.course.lessons.single.exercises.single,
              nameNoteLoaded.files,
              Random(7),
            )
            as QuestionRound;
    nameNoteDoc = await _renderRound(nameNoteRound);

    countBeatsLoaded = await _loadedWith(
      'id: c\ntype: count-beats\ntitle: Tempos\ntime: 4/4\n'
      'figures: [quarter, half]\ncount: 2',
    );
    final countRound =
        await generateRound(
              countBeatsLoaded.course.lessons.single.exercises.single,
              countBeatsLoaded.files,
              Random(7),
            )
            as QuestionRound;
    countBeatsDoc = await _renderRound(countRound);
  });

  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('name-note sem teclado abre, roda e aprova', (tester) async {
    final loaded = await _loadedWith(
      'id: n\ntype: name-note\ntitle: Nota\nnotes: [C4, D4]\n',
    );
    final lesson = loaded.course.lessons.single;
    final spec = lesson.exercises.single;

    final devices = await _makeDevices(connected: false);
    final midi = FakeMidiInput();
    final engine = FakeSoundEngine();
    final progress = MemoryCourseProgressStore();
    final deps = _makeDeps(
      devices: devices,
      midi: midi,
      engine: engine,
      progress: progress,
      rendererFactory: verovioAvailable ? () => _CachedRenderer(nameNoteDoc) : null,
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          loaded: loaded,
          lesson: lesson,
          spec: spec,
          deps: deps,
          rng: Random(7),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Conecte o teclado'), findsNothing);
    expect(find.text('Dó'), findsOneWidget);
    expect(find.text('Ré'), findsOneWidget);

    // Notas fixas [C4, D4]: a ordem é a do autor.
    await tester.tap(find.text('Dó').first);
    await tester.pump();
    await tester.tap(find.text('Ré').first);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Exercício aprovado!').evaluate().isNotEmpty) break;
    }
    expect(find.text('Exercício aprovado!'), findsOneWidget);
    expect(progress['t'].records['n']?.passed, isTrue);
  });

  testWidgets('count-beats sem teclado abre e roda', (tester) async {
    final loaded = await _loadedWith(
      'id: c\ntype: count-beats\ntitle: Tempos\ntime: 4/4\n'
      'figures: [quarter, half]\ncount: 2',
    );
    final lesson = loaded.course.lessons.single;
    final spec = lesson.exercises.single;

    final devices = await _makeDevices(connected: false);
    final midi = FakeMidiInput();
    final engine = FakeSoundEngine();
    final progress = MemoryCourseProgressStore();
    final deps = _makeDeps(
      devices: devices,
      midi: midi,
      engine: engine,
      progress: progress,
      rendererFactory: verovioAvailable
          ? () => _CachedRenderer(countBeatsDoc)
          : null,
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          loaded: loaded,
          lesson: lesson,
          spec: spec,
          deps: deps,
          rng: Random(7),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Conecte o teclado'), findsNothing);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('choice sem teclado abre e aprova', (tester) async {
    choiceLoaded = await _loadedWith(
      'id: c\ntype: choice\ntitle: Pergunta\nquestion: Quanto vale?\n'
      'options: [1, 2]\nanswer: 2',
    );
    final lesson = choiceLoaded.course.lessons.single;
    final spec = lesson.exercises.single;

    final devices = await _makeDevices(connected: false);
    final midi = FakeMidiInput();
    final engine = FakeSoundEngine();
    final progress = MemoryCourseProgressStore();
    final deps = _makeDeps(
      devices: devices,
      midi: midi,
      engine: engine,
      progress: progress,
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          loaded: choiceLoaded,
          lesson: lesson,
          spec: spec,
          deps: deps,
          rng: Random(1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Conecte o teclado'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Exercício aprovado!').evaluate().isNotEmpty) break;
    }
    expect(find.text('Exercício aprovado!'), findsOneWidget);
  });

  testWidgets('find-key sem teclado pede o teclado', (tester) async {
    findKeyLoaded = await _loadedWith(
      'id: f\ntype: find-key\ntitle: Ache\nnotes: [C4]',
    );
    final lesson = findKeyLoaded.course.lessons.single;
    final spec = lesson.exercises.single;

    final devices = await _makeDevices(connected: false);
    final midi = FakeMidiInput();
    final engine = FakeSoundEngine();
    final progress = MemoryCourseProgressStore();
    final deps = _makeDeps(
      devices: devices,
      midi: midi,
      engine: engine,
      progress: progress,
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          loaded: findKeyLoaded,
          lesson: lesson,
          spec: spec,
          deps: deps,
          rng: Random(1),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Conecte o teclado'), findsOneWidget);
    expect(find.text('Conectar teclado'), findsOneWidget);
  });

  // Uso das variáveis do `setUpAll` (evita aviso de não usadas quando o
  // `.so` falta e os testes de partitura são pulados).
  test('pré-render do setUpAll existe', () {
    if (!verovioAvailable) return;
    expect(nameNoteLoaded.course.id, 't');
    expect(nameNoteRound.questions, hasLength(2));
    expect(countBeatsLoaded.course.id, 't');
  });
}
