// I07, critério 3 — sem teclado, `name-note`, `count-beats` e `choice`
// abrem e rodam; `find-key` pede o teclado.
//
// Todo IO/FFI no `setUpAll` (relógio real); os widgets consomem memória
// (`_CachedRenderer`), como o `course_screens_test.dart` — o render FFI não
// termina no relógio falso do widget test.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:zywny/course/exercise/question_kinds.dart';
import 'package:zywny_course_format/course_model.dart';
import 'package:zywny_course_format/course_reader.dart';
import 'package:zywny/course/loaded_course.dart';
import 'package:zywny/course/ui/course_flow.dart';
import 'package:zywny/course/ui/exercise_screen.dart';
import 'package:zywny/course/ui/question_body.dart';
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

/// Entrega a partitura já renderizada de cada pergunta (a `listen-score`
/// tem uma por pergunta; a chave é o MusicXML inteiro).
class _ByScoreRenderer implements ScoreRenderer {
  _ByScoreRenderer(this.docs);

  final Map<String, VsbDocument> docs;

  @override
  Future<RenderedScore> render(ScoreRenderRequest request) async =>
      RenderedScore(docs[utf8.decode(request.source)]!);
}

/// Espera de verdade (o cronômetro da sessão é o relógio de parede), andando
/// os timers falsos.
Future<void> _waitReal(WidgetTester tester, double seconds) async {
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

/// Põe um `QuestionBody` com [round] na tela. Cada partitura da rodada é
/// renderizada fora do relógio falso; devolve os documentos por MusicXML.
Future<Map<String, VsbDocument>> _pumpListen(
  WidgetTester tester, {
  required LoadedCourse loaded,
  required QuestionRound round,
  required FakeSoundEngine engine,
  required AppSettings settings,
  required ValueChanged<RoundResult> onDone,
  FakeMidiInput? midi,
}) async {
  final docs = <String, VsbDocument>{};
  for (final question in round.questions) {
    final compare = question.compare!;
    // O ditado (E09) mostra o ritmo enquanto o aluno responde.
    for (final bytes in [compare.scoreBytes, ?compare.promptBytes]) {
      final key = utf8.decode(bytes);
      if (docs.containsKey(key)) continue;
      docs[key] = (await tester.runAsync(
        () => _renderBytes(bytes, compare.fileName),
      ))!;
    }
  }
  // Alto o bastante para a partitura e os botões ficarem visíveis (sem
  // rolagem), como num celular na vertical.
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // O teste que toca notas passa o seu `midi` (e o fecha).
  final input = midi ?? FakeMidiInput();
  if (midi == null) addTearDown(input.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuestionBody(
          spec: loaded.course.lessons.single.exercises.single,
          round: round,
          files: loaded.files,
          settings: settings,
          midiInput: input,
          rendererFactory: () => _ByScoreRenderer(docs),
          onDone: onDone,
          ensureEngine: () async => engine,
        ),
      ),
    ),
  );
  return docs;
}

/// Uma rodada de `listen-score` cuja primeira pergunta soa igual ao escrito.
Future<QuestionRound> _sameFirstRound(LoadedCourse loaded) async {
  final spec = loaded.course.lessons.single.exercises.single as ListenScoreSpec;
  for (var seed = 1; seed <= 50; seed++) {
    final round = await const ListenScoreKind().generate(
      spec,
      loaded.files,
      Random(seed),
    );
    if (round.questions.first.compare!.changedIds.isEmpty) return round;
  }
  throw StateError('nenhuma semente de 1 a 50 deu uma pergunta igual');
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

/// Alturas das notas ligadas que o motor falso recebeu, na ordem.
List<int> _ons(FakeSoundEngine engine) => [
  for (final e in engine.scheduled)
    if (e.status == 0x90) e.d1,
];

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

  // Duas notas no modo espera: a rodada pré-renderizada, a mesma do `Random(7)`.
  late LoadedCourse playNotesLoaded;
  late VsbDocument playNotesDoc;

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

    playNotesLoaded = await _loadedWith(
      'id: p\ntype: play-notes\ntitle: P\nnotes: [C4, D4]\n',
    );
    final playNotesRound = await generateRound(
      playNotesLoaded.course.lessons.single.exercises.single,
      playNotesLoaded.files,
      Random(7),
    ) as ScoreRound;
    playNotesDoc = await _renderBytes(
      playNotesRound.bytes,
      playNotesRound.fileName,
    );
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
        home: ExerciseScreen.course(
          loaded: loaded,
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
          home: ExerciseScreen.course(
            loaded: loaded,
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
      // (1 s de limite + 1,5 s de revelação).
      await _waitReal(tester, 2.9);
      // A primeira estourou: errada; a da vez agora é a segunda.
      expect(controller().colorOf('zn1'), deps.settings.practiceWrongColor);
      expect(controller().colorOf('zn2'), deps.settings.practicePendingColor);

      // A última também estoura: a rodada termina (sem ficar girando).
      await _waitReal(tester, 2.9);
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
        home: ExerciseScreen.course(
          loaded: rhythmLoaded,
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
        home: ExerciseScreen.course(
          loaded: rhythmLoaded,
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

  testWidgets('play-notes: a tecla errada fica na partitura ao terminar', (
    tester,
  ) async {
    final lesson = playNotesLoaded.course.lessons.single;
    final devices = await _makeDevices(connected: true);
    final midi = FakeMidiInput();
    final deps = _makeDeps(
      devices: devices,
      midi: midi,
      engine: FakeSoundEngine(),
      progress: MemoryCourseProgressStore(),
      rendererFactory: () => _CachedRenderer(playNotesDoc),
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen.course(
          loaded: playNotesLoaded,
          spec: lesson.exercises.single,
          deps: deps,
          rng: Random(7),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 64 no lugar do C4 (60); depois as duas certas.
    midi.press(64);
    await tester.pump(const Duration(milliseconds: 10));
    midi.release(64);
    await tester.pump(const Duration(milliseconds: 10));
    midi.press(60);
    await tester.pump(const Duration(milliseconds: 10));
    midi.press(62);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('de primeira'), findsOneWidget);
    // Sem tocar em "Rever": a nota errada já está fixa na partitura.
    final ghosts = tester.widget<ScoreView>(find.byType(ScoreView)).ghosts!;
    expect(ghosts.review.map((g) => g.key), [64]);
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
        home: ExerciseScreen.course(
          loaded: loaded,
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
        home: ExerciseScreen.course(
          loaded: choiceLoaded,
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
        home: ExerciseScreen.course(
          loaded: findKeyLoaded,
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
          home: ExerciseScreen.course(
            key: UniqueKey(),
            loaded: loaded,
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

  testWidgets('listen-note com teclado: toca a referência e a nota, aprova', (
    tester,
  ) async {
    final loaded = await _loadedWith(
      'id: o\ntype: listen-note\ntitle: Ouça\nnotes: [E4]\nreference: C4\n',
    );
    final devices = await _makeDevices(connected: true);
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
        home: ExerciseScreen.course(
          loaded: loaded,
          spec: loaded.course.lessons.single.exercises.single,
          deps: deps,
          rng: Random(1),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Ouvir de novo'), findsOneWidget);
    expect(_ons(engine), [60, 64]);

    await tester.tap(find.text('Ouvir de novo'));
    await tester.pump();
    expect(_ons(engine), [60, 64, 60, 64]);

    midi.press(64);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Exercício aprovado!').evaluate().isNotEmpty) break;
    }
    expect(find.text('Exercício aprovado!'), findsOneWidget);
    expect(progress['t'].records['o']?.passed, isTrue);
  });

  testWidgets('listen-note com botões, sem teclado: uma nota por pergunta', (
    tester,
  ) async {
    final loaded = await _loadedWith(
      'id: o\ntype: listen-note\ntitle: Ouça\nnotes: [C4, D4]\n'
      'input: buttons\nchoices: [C, D]\n',
    );
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
        home: ExerciseScreen.course(
          loaded: loaded,
          spec: loaded.course.lessons.single.exercises.single,
          deps: deps,
          rng: Random(1),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Conecte o teclado'), findsNothing);
    expect(_ons(engine), [60]);

    await tester.tap(find.text('Dó').first);
    await tester.pump();
    // A segunda nota toca sozinha, depois do silêncio entre as perguntas.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Ré').first);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Exercício aprovado!').evaluate().isNotEmpty) break;
    }
    expect(find.text('Exercício aprovado!'), findsOneWidget);
    expect(_ons(engine), [60, 62]);
  });

  testWidgets('listen-note sem saída de som: avisa e o exercício segue', (
    tester,
  ) async {
    final loaded = await _loadedWith(
      'id: o\ntype: listen-note\ntitle: Ouça\nnotes: [C4]\n'
      'input: buttons\nchoices: [C, D]\n',
    );
    final devices = await _makeDevices(connected: false);
    final midi = FakeMidiInput();
    final deps = CourseScreenDeps(
      settings: AppSettings(),
      deviceManager: devices,
      midiInput: midi,
      progress: MemoryCourseProgressStore(),
      ensureEngine: () async => null,
      rendererFactory: createScoreRenderer,
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen.course(
          loaded: loaded,
          spec: loaded.course.lessons.single.exercises.single,
          deps: deps,
          rng: Random(1),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.text('Sem som: confira a saída de som nas configurações.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Dó').first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Exercício aprovado!').evaluate().isNotEmpty) break;
    }
    expect(find.text('Exercício aprovado!'), findsOneWidget);
  });

  testWidgets(
    'listen-interval sem teclado: toca o intervalo e escolhe o nome',
    (tester) async {
      final loaded = await _loadedWith(
        'id: o\ntype: listen-interval\ntitle: Intervalo\nnotes: [C4]\n'
        'intervals: [M3, P5]\n',
      );
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
          home: ExerciseScreen.course(
            loaded: loaded,
            spec: loaded.course.lessons.single.exercises.single,
            deps: deps,
            rng: Random(1),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Que intervalo é este?'), findsOneWidget);
      expect(find.text('Conecte o teclado'), findsNothing);
      expect(find.text('Ouvir de novo'), findsOneWidget);
      // A raiz (60) e a segunda nota: 64 é a 3ª maior; 67, a 5ª justa.
      final ons = _ons(engine);
      expect(ons.first, 60);
      expect(ons.last, anyOf(64, 67));

      await tester.tap(find.text(ons.last == 64 ? '3ª maior' : '5ª justa'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Exercício aprovado!').evaluate().isNotEmpty) break;
      }
      expect(find.text('Exercício aprovado!'), findsOneWidget);
      expect(progress['t'].records['o']?.passed, isTrue);
    },
  );

  // E07: a pergunta de `listen-score` com a sua partitura, a frase que toca
  // sozinha e a revelação depois da resposta.
  group('listen-score', skip: !verovioAvailable, () {
    testWidgets('a frase toca sozinha: o acorde, depois as notas; "Ouvir de '
        'novo" repete', (tester) async {
      final loaded = await _loadedWith(
        'id: s\ntype: listen-score\ntitle: S\nstep: 1c\ncount: 2\n',
      );
      final round = await generateRound(
        loaded.course.lessons.single.exercises.single,
        loaded.files,
        Random(7),
      ) as QuestionRound;
      final engine = FakeSoundEngine();
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await _pumpListen(
        tester,
        loaded: loaded,
        round: round,
        engine: engine,
        settings: settings,
        onDone: (_) {},
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Em que compasso soou diferente?'), findsOneWidget);
      expect(
        find.text('Primeiro o acorde, depois a partitura.'),
        findsOneWidget,
      );
      for (final label in ['1', '2', '3', '4']) {
        expect(find.widgetWithText(FilledButton, label), findsOneWidget);
      }
      // O acorde de Dó (60, 64, 67 e 48) e depois a frase da pergunta.
      final played = [
        for (final note in round.questions.first.compare!.played) note.pitch,
      ];
      expect(played.take(4).toList(), [60, 64, 67, 48]);
      expect(_ons(engine), played);

      await tester.tap(find.text('Ouvir de novo'));
      await tester.pump();
      expect(_ons(engine), [...played, ...played]);
    });

    testWidgets('errou e depois acertou: a revelação pinta a nota que mudou, '
        'diz o compasso e toca as duas versões', (tester) async {
      final loaded = await _loadedWith(
        'id: s\ntype: listen-score\ntitle: S\nstep: 1c\ncount: 2\n',
      );
      final round = await generateRound(
        loaded.course.lessons.single.exercises.single,
        loaded.files,
        Random(7),
      ) as QuestionRound;
      final engine = FakeSoundEngine();
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await _pumpListen(
        tester,
        loaded: loaded,
        round: round,
        engine: engine,
        settings: settings,
        onDone: (_) {},
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final question = round.questions.first;
      final compare = question.compare!;
      final correct = question.correct!;
      await tester.tap(
        find.widgetWithText(FilledButton, question.answers[(correct + 1) % 4]),
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, question.answers[correct]),
      );
      await tester.pump();

      expect(find.text('Era aqui.'), findsOneWidget);
      expect(
        find.text('Compasso ${compare.measure! + 1}: ${compare.description}.'),
        findsOneWidget,
      );
      expect(find.text('Ouvir o que soou'), findsOneWidget);
      expect(find.text('Ouvir o escrito'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);
      // A nota que mudou fica destacada na partitura desta pergunta.
      final controller = tester
          .widget<ScoreView>(find.byType(ScoreView))
          .controller!;
      expect(
        controller.colorOf(compare.changedIds.first),
        settings.practiceWrongColor,
      );

      final before = _ons(engine).length;
      await tester.tap(find.text('Ouvir o escrito'));
      await tester.pump();
      expect(_ons(engine).skip(before).toList(), [
        for (final note in compare.written) note.pitch,
      ]);
      // "E" também toca o escrito, no teclado do computador.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(_ons(engine).length, before + 2 * compare.written.length);
    });

    testWidgets('"Próxima" mostra a pergunta seguinte com a sua partitura; a '
        'última termina a rodada', (tester) async {
      final loaded = await _loadedWith(
        'id: s\ntype: listen-score\ntitle: S\nstep: 1c\ncount: 2\n',
      );
      final round = await generateRound(
        loaded.course.lessons.single.exercises.single,
        loaded.files,
        Random(7),
      ) as QuestionRound;
      final engine = FakeSoundEngine();
      final settings = AppSettings();
      addTearDown(settings.dispose);
      RoundResult? result;
      final docs = await _pumpListen(
        tester,
        loaded: loaded,
        round: round,
        engine: engine,
        settings: settings,
        onDone: (r) => result = r,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Pergunta 1: erra e acerta. Pergunta 2: acerta de primeira.
      final first = round.questions[0];
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          first.answers[(first.correct! + 1) % 4],
        ),
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, first.answers[first.correct!]),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Próxima'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final second = round.questions[1];
      expect(find.text('Em que compasso soou diferente?'), findsOneWidget);
      expect(find.text('Próxima'), findsNothing);
      expect(
        identical(
          tester.widget<ScoreView>(find.byType(ScoreView)).document,
          docs[utf8.decode(second.compare!.scoreBytes)],
        ),
        isTrue,
      );
      final played = [for (final note in second.compare!.played) note.pitch];
      expect(
        _ons(engine).skip(_ons(engine).length - played.length).toList(),
        played,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, second.answers[second.correct!]),
      );
      await tester.pump();
      expect(find.text('Certo!'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Terminar'));
      await tester.pump();
      expect(result?.hits, 1);
      expect(result?.total, 2);
    });

    testWidgets('igual ou diferente: "Era igual." e sem "Ouvir o escrito" '
        'quando nada mudou', (tester) async {
      final loaded = await _loadedWith(
        'id: s\ntype: listen-score\ntitle: S\nstep: 1c\n'
        'answer: same-different\ncount: 2\n',
      );
      final round = await _sameFirstRound(loaded);
      final engine = FakeSoundEngine();
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await _pumpListen(
        tester,
        loaded: loaded,
        round: round,
        engine: engine,
        settings: settings,
        onDone: (_) {},
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Soou igual ao escrito?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Diferente'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Igual'));
      await tester.pump();

      expect(find.text('Era igual.'), findsOneWidget);
      expect(find.text('O que soou foi exatamente o escrito.'), findsOneWidget);
      expect(find.text('Ouvir o que soou'), findsOneWidget);
      expect(find.text('Ouvir o escrito'), findsNothing);
    });

    testWidgets('estourou o tempo: a revelação espera o aluno, e o relógio '
        'para nela', (tester) async {
      final loaded = await _loadedWith(
        'id: s\ntype: listen-score\ntitle: S\nstep: 1c\ncount: 2\n'
        'pass: {time-limit: 1}\n',
      );
      final round = await generateRound(
        loaded.course.lessons.single.exercises.single,
        loaded.files,
        Random(7),
      ) as QuestionRound;
      final engine = FakeSoundEngine();
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await _pumpListen(
        tester,
        loaded: loaded,
        round: round,
        engine: engine,
        settings: settings,
        onDone: (_) {},
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 1 s de limite e 1,5 s de revelação da sessão: a revelação da tela
      // aparece depois disso.
      await _waitReal(tester, 2.9);
      expect(find.text('Era aqui.'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);

      // Parada na revelação, a pergunta seguinte não aparece sozinha.
      await _waitReal(tester, 3);
      expect(find.text('Próxima'), findsOneWidget);
      expect(find.text('Em que compasso soou diferente?'), findsNothing);

      // Ao seguir, a pergunta 2 ganha o seu tempo inteiro (1 s).
      await tester.tap(find.widgetWithText(FilledButton, 'Próxima'));
      await tester.pump();
      await _waitReal(tester, 0.5);
      expect(find.text('Em que compasso soou diferente?'), findsOneWidget);
    });
  });

  group('listen-score ditado', skip: !verovioAvailable, () {
    testWidgets('a frase toca sozinha uma vez; a partitura mostra só o ritmo, '
        'com a figura da vez acesa, e não há botões', (tester) async {
      final loaded = await _loadedWith(
        'id: d\ntype: listen-score\ntitle: D\nstep: 1c\n'
        'answer: dictation\ncount: 2\n',
      );
      final round = await generateRound(
        loaded.course.lessons.single.exercises.single,
        loaded.files,
        Random(7),
      ) as QuestionRound;
      final engine = FakeSoundEngine();
      final settings = AppSettings();
      addTearDown(settings.dispose);
      await _pumpListen(
        tester,
        loaded: loaded,
        round: round,
        engine: engine,
        settings: settings,
        onDone: (_) {},
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Toque as notas que ouviu'), findsOneWidget);
      expect(
        find.text('A primeira já está escrita. Vale qualquer oitava.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, '1'), findsNothing);
      // O acorde e a frase, uma vez.
      final played = [
        for (final note in round.questions.first.compare!.played) note.pitch,
      ];
      expect(_ons(engine), played);
      // A figura da vez (a primeira que se toca) está acesa.
      final controller = tester
          .widget<ScoreView>(find.byType(ScoreView))
          .controller!;
      expect(
        controller.colorOf(round.questions.first.highlightId!),
        settings.practicePendingColor,
      );
    });

    testWidgets('tocar a frase em outra oitava conta; a revelação vem no fim '
        'da frase, e "Próxima" toca a frase seguinte uma vez', (tester) async {
      final loaded = await _loadedWith(
        'id: d\ntype: listen-score\ntitle: D\nstep: 1c\n'
        'answer: dictation\ncount: 2\n',
      );
      final round = await generateRound(
        loaded.course.lessons.single.exercises.single,
        loaded.files,
        Random(7),
      ) as QuestionRound;
      final engine = FakeSoundEngine();
      final settings = AppSettings();
      addTearDown(settings.dispose);
      final midi = FakeMidiInput();
      addTearDown(midi.dispose);
      RoundResult? result;
      await _pumpListen(
        tester,
        loaded: loaded,
        round: round,
        engine: engine,
        settings: settings,
        midi: midi,
        onDone: (r) => result = r,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Frase 1: as três notas (a primeira está escrita), uma oitava acima.
      final firstPhrase = round.questions.take(3).toList();
      for (final q in firstPhrase) {
        midi.press(q.expectedPitch! + 12);
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.text('A frase era esta:'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Próxima'), findsOneWidget);
      expect(find.text('Ouvir o escrito'), findsNothing);
      expect(find.text('Ouvir de novo'), findsOneWidget);
      // A frase tocou uma vez, na entrada da frase, e não uma vez por nota.
      expect(_ons(engine), [
        for (final note in round.questions.first.compare!.played) note.pitch,
      ]);

      await tester.tap(find.widgetWithText(FilledButton, 'Próxima'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Toque as notas que ouviu'), findsOneWidget);
      final secondPlayed = [
        for (final note in round.questions[3].compare!.played) note.pitch,
      ];
      expect(
        _ons(engine).skip(_ons(engine).length - secondPlayed.length).toList(),
        secondPlayed,
      );

      for (final q in round.questions.skip(3)) {
        midi.press(q.expectedPitch!);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Terminar'));
      await tester.pump();
      expect(result?.hits, 6);
      expect(result?.total, 6);
    });

    testWidgets(
      'tecla errada diz "tente de novo"; a revelação pinta a nota que '
      'não foi de primeira',
      (tester) async {
        final loaded = await _loadedWith(
          'id: d\ntype: listen-score\ntitle: D\nstep: 1c\n'
          'answer: dictation\ncount: 1\n',
        );
        final round = await generateRound(
          loaded.course.lessons.single.exercises.single,
          loaded.files,
          Random(7),
        ) as QuestionRound;
        final engine = FakeSoundEngine();
        final settings = AppSettings();
        addTearDown(settings.dispose);
        final midi = FakeMidiInput();
        addTearDown(midi.dispose);
        await _pumpListen(
          tester,
          loaded: loaded,
          round: round,
          engine: engine,
          settings: settings,
          midi: midi,
          onDone: (_) {},
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        final first = round.questions[0];
        midi.press(first.expectedPitch! + 1);
        await tester.pump(const Duration(milliseconds: 10));
        expect(find.textContaining('tente de novo'), findsOneWidget);
        midi.press(first.expectedPitch!);
        await tester.pump(const Duration(milliseconds: 10));
        for (final q in round.questions.skip(1)) {
          midi.press(q.expectedPitch!);
          await tester.pump(const Duration(milliseconds: 10));
        }

        // A partitura da revelação desenha depois do quadro da nota certa.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('A frase era esta:'), findsOneWidget);
        final controller = tester
            .widget<ScoreView>(find.byType(ScoreView))
            .controller!;
        expect(
          controller.colorOf(first.highlightId!),
          settings.practiceWrongColor,
        );
        expect(
          controller.colorOf(round.questions[1].highlightId!),
          isNot(settings.practiceWrongColor),
        );
      },
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

  // Imagem de conferência (manual): o fim de um exercício com duas notas
  // erradas, em celular deitado. Só roda com ERROS_PNG=/caminho.png. Fica no
  // fim do arquivo porque carrega fontes que mudam o texto dos outros testes.
  testWidgets('imagem: erros na partitura ao terminar o exercício', (
    tester,
  ) async {
    final out = Platform.environment['ERROS_PNG']!;
    await tester.runAsync(() async {
      // Fontes parecidas com as do app (que usa Google Fonts, sem rede aqui).
      await _loadFont(
        'Roboto',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      );
      await _loadFont(
        'MaterialIcons',
        '/home/mauricio/development_tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
    });
    final loaded = await _loadedWith(
      'id: e\ntype: play-notes\ntitle: Escala de dó\n'
      'notes: [C4, D4, E4, F4, G4, A4]\n',
    );
    final lesson = loaded.course.lessons.single;
    final spec = lesson.exercises.single;
    final doc = await tester.runAsync(() async {
      final round =
          await generateRound(spec, loaded.files, Random(7)) as ScoreRound;
      return _renderBytes(round.bytes, round.fileName);
    });
    final devices = await _makeDevices(connected: true);
    final midi = FakeMidiInput();
    final deps = _makeDeps(
      devices: devices,
      midi: midi,
      engine: FakeSoundEngine(),
      progress: MemoryCourseProgressStore(),
      rendererFactory: () => _CachedRenderer(doc!),
    );
    addTearDown(() {
      midi.dispose();
      deps.settings.dispose();
    });
    // Celular deitado, 844×390 dp a 2,5× (ERROS_RETRATO=1: em pé, 390×844).
    final standing = Platform.environment['ERROS_RETRATO'] != null;
    tester.view.physicalSize = standing
        ? const Size(390 * 2.5, 844 * 2.5)
        : const Size(844 * 2.5, 390 * 2.5);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: ExerciseScreen.course(
            key: UniqueKey(),
            loaded: loaded,
            spec: spec,
            deps: deps,
            rng: Random(7),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Toca 63 no lugar do D4 (62) e 66 no lugar do F4 (65); o resto certo.
    Future<void> play(int pitch) async {
      midi.press(pitch);
      await tester.pump(const Duration(milliseconds: 10));
      midi.release(pitch);
      await tester.pump(const Duration(milliseconds: 10));
    }

    await play(60);
    await play(63);
    await play(62);
    await play(64);
    await play(66);
    await play(65);
    await play(67);
    await play(69);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('de primeira'), findsOneWidget);
    final ghosts = tester.widget<ScoreView>(find.byType(ScoreView)).ghosts!;
    expect(ghosts.review.map((g) => g.key), [63, 66]);
    // A página sai em trabalho assíncrono: deixa correr de verdade antes da
    // foto.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print('fantasmas visíveis: ${ghosts.visible.length}');

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File(out).writeAsBytesSync(png!);
    // ignore: avoid_print
    print('imagem -> $out');
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['ERROS_PNG'] == null || !verovioAvailable);
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}
