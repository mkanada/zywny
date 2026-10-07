// I07, critério 3 — sem teclado, `name-note`, `count-beats` e `choice`
// abrem e rodam; `find-key` pede o teclado.
//
// Todo IO/FFI no `setUpAll` (relógio real); os widgets consomem memória
// (`_CachedRenderer`), como o `course_screens_test.dart` — o render FFI não
// termina no relógio falso do widget test.
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
import 'package:zywny_course_format/course_reader.dart';
import 'package:zywny/course/loaded_course.dart';
import 'package:zywny/course/ui/course_flow.dart';
import 'package:zywny/course/ui/exercise_screen.dart';
import 'package:zywny_midi/midi_device_manager.dart';
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

/// Segura cada render até [release]: a rodada fica "carregando" o tempo
/// que o teste quiser.
class _GatedRenderer implements ScoreRenderer {
  _GatedRenderer(this.document, this.gates);

  final VsbDocument document;
  final List<Completer<void>> gates;

  @override
  Future<RenderedScore> render(ScoreRenderRequest request) async {
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return RenderedScore(document);
  }
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

Future<VsbDocument> _renderRound(QuestionRound round) =>
    _renderBytes(round.scoreBytes!, round.fileName!);

Future<VsbDocument> _renderBytes(Uint8List bytes, String fileName) async {
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
      source: bytes,
      fileName: fileName,
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

  // Ritmo (I08): a rodada pré-renderizada, a mesma do `Random(7)` da tela.
  late LoadedCourse rhythmLoaded;
  late VsbDocument rhythmDoc;
  late LoadedCourse findKeyLoaded;

  setUpAll(() async {
    await loadScoreFonts();
    if (!verovioAvailable) return;
    nameNoteLoaded = await _loadedWith(
      'id: n\ntype: name-note\ntitle: Nota\nnotes: [C4, D4]\n',
    );
    nameNoteRound = await generateRound(
      nameNoteLoaded.course.lessons.single.exercises.single,
      nameNoteLoaded.files,
      Random(7),
    ) as QuestionRound;
    nameNoteDoc = await _renderRound(nameNoteRound);

    countBeatsLoaded = await _loadedWith(
      'id: c\ntype: count-beats\ntitle: Tempos\ntime: 4/4\n'
      'figures: [quarter, half]\ncount: 2',
    );
    final countRound = await generateRound(
      countBeatsLoaded.course.lessons.single.exercises.single,
      countBeatsLoaded.files,
      Random(7),
    ) as QuestionRound;
    countBeatsDoc = await _renderRound(countRound);

    rhythmLoaded = await _loadedWith(
      'id: r\ntype: rhythm\ntitle: Ritmo\ntime: 4/4\n'
      'figures: [half, quarter, quarter-rest]\nmeasures: 2\nbpm: 70\n'
      'note: C4\npass: {accuracy: 85, speed: 100}',
    );
    final rhythmRound = await generateRound(
      rhythmLoaded.course.lessons.single.exercises.single,
      rhythmLoaded.files,
      Random(7),
    ) as ScoreRound;
    rhythmDoc = await _renderBytes(rhythmRound.bytes, rhythmRound.fileName);
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
      rendererFactory: verovioAvailable
          ? () => _CachedRenderer(nameNoteDoc)
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

  testWidgets(
    'name-note: estourou o tempo, o destaque vai para a nota seguinte e a '
    'última estourada encerra a rodada',
    (tester) async {
      // Mesmas notas da partitura pré-renderizada ([C4, D4]), com 1 s.
      final loaded = await _loadedWith(
        'id: n\ntype: name-note\ntitle: Nota\nnotes: [C4, D4]\n'
        'pass: {accuracy: 90, time-limit: 1}\n',
      );
      final lesson = loaded.course.lessons.single;
      final devices = await _makeDevices(connected: false);
      final midi = FakeMidiInput();
      final deps = _makeDeps(
        devices: devices,
        midi: midi,
        engine: FakeSoundEngine(),
        progress: MemoryCourseProgressStore(),
        rendererFactory: () => _CachedRenderer(nameNoteDoc),
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
            spec: lesson.exercises.single,
            deps: deps,
            rng: Random(7),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      ScoreController controller() =>
          tester.widget<ScoreView>(find.byType(ScoreView)).controller!;
      expect(controller().colorOf('zn1'), deps.settings.practicePendingColor);

      // O cronômetro da sessão é o relógio de parede: espera de verdade
      // (1 s de limite + 1,5 s de revelação), andando os timers falsos.
      Future<void> waitReal(double seconds) async {
        final until = DateTime.now().add(
          Duration(milliseconds: (seconds * 1000).round()),
        );
        while (DateTime.now().isBefore(until)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      await waitReal(2.9);
      // A primeira estourou: errada; a da vez agora é a segunda.
      expect(controller().colorOf('zn1'), deps.settings.practiceWrongColor);
      expect(controller().colorOf('zn2'), deps.settings.practicePendingColor);

      // A última também estoura: a rodada termina (sem ficar girando).
      await waitReal(2.9);
      await tester.pump();
      expect(find.textContaining('0 de 2 de primeira'), findsOneWidget);
    },
    skip: !verovioAvailable,
  );

  testWidgets('ritmo: "ouvir antes" toca o metrônomo da rodada', (
    tester,
  ) async {
    final lesson = rhythmLoaded.course.lessons.single;
    final devices = await _makeDevices(connected: true);
    final midi = FakeMidiInput();
    final engine = FakeSoundEngine();
    final deps = _makeDeps(
      devices: devices,
      midi: midi,
      engine: engine,
      progress: MemoryCourseProgressStore(),
      rendererFactory: () => _CachedRenderer(rhythmDoc),
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          loaded: rhythmLoaded,
          lesson: lesson,
          spec: lesson.exercises.single,
          deps: deps,
          rng: Random(7),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    engine.scheduled.clear();
    await tester.tap(find.byTooltip('Ouvir antes (sem avaliar)'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Cliques do metrônomo: note-on no canal 10 (status 0x99).
    expect(
      engine.scheduled.where((m) => m.status == 0x99),
      isNotEmpty,
      reason: 'ouvir sem metrônomo',
    );
    await tester.tap(find.byTooltip('Parar de ouvir'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  }, skip: !verovioAvailable);

  // A caixa mudou de altura com a rodada ainda carregando (as barras do
  // sistema somem ao abrir o exercício): a rodada antiga não pode seguir
  // tocando junto da nova — o metrônomo e o acompanhamento saíam dobrados.
  testWidgets('caixa muda durante o carregamento: uma rodada só', (
    tester,
  ) async {
    final lesson = rhythmLoaded.course.lessons.single;
    final devices = await _makeDevices(connected: true);
    final midi = FakeMidiInput();
    final engine = FakeSoundEngine();
    final gates = <Completer<void>>[];
    final deps = _makeDeps(
      devices: devices,
      midi: midi,
      engine: engine,
      progress: MemoryCourseProgressStore(),
      rendererFactory: () => _GatedRenderer(rhythmDoc, gates),
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
      tester.view.resetPhysicalSize();
    });
    var rounds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          loaded: rhythmLoaded,
          lesson: lesson,
          spec: lesson.exercises.single,
          deps: deps,
          rng: Random(7),
          onRound: (_, _) => rounds++,
        ),
      ),
    );
    for (var i = 0; i < 10 && gates.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(gates, hasLength(1), reason: 'a primeira rodada está renderizando');
    // Mais alta: as barras do sistema sumiram.
    tester.view.physicalSize = Size(
      tester.view.physicalSize.width,
      tester.view.physicalSize.height + 150,
    );
    for (var i = 0; i < 10 && gates.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(gates, hasLength(2), reason: 'a caixa nova pede outra rodada');
    // A antiga termina de renderizar depois da nova.
    gates[1].complete();
    await tester.pump(const Duration(milliseconds: 50));
    gates[0].complete();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(rounds, 1, reason: 'duas rodadas tocando juntas');
    await tester.pumpWidget(const SizedBox());
  }, skip: !verovioAvailable);

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

  testWidgets('find-key: a tecla errada aparece com o nome', (tester) async {
    Future<void> run(String yaml, int wrong, String expected) async {
      final loaded = await _loadedWith(yaml);
      final lesson = loaded.course.lessons.single;
      final devices = await _makeDevices(connected: true);
      final midi = FakeMidiInput();
      final deps = _makeDeps(
        devices: devices,
        midi: midi,
        engine: FakeSoundEngine(),
        progress: MemoryCourseProgressStore(),
      );
      addTearDown(() {
        midi.dispose();
        deps.settings.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseScreen(
            key: UniqueKey(),
            loaded: loaded,
            lesson: lesson,
            spec: lesson.exercises.single,
            deps: deps,
            rng: Random(1),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      midi.press(wrong);
      await tester.pump();
      // A nota do teclado falso chega num microtask depois do quadro.
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.textContaining(expected), findsOneWidget);
      // Some sozinha depois de um tempo.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.textContaining('Você tocou'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }

    await run(
      'id: f\ntype: find-key\ntitle: Ache\nnotes: [C4, C4]',
      64,
      'Você tocou Mi — tente de novo.',
    );
    await run(
      'id: f\ntype: find-key\ntitle: Ache\nnotes: [C4, C4]\noctave: exact',
      72,
      'em outra oitava',
    );
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
