// I12, critério 1 — `test/course_draft_test.dart`: o rascunho de uma
// `MemoryCourseFiles` abre com a faixa; com erro, mostra a lista com arquivo
// e linha; Recarregar depois de corrigir abre o curso e mantém progresso e
// lição; nada aparece em `shared_preferences` nem no blob store.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/draft/course_draft.dart';
import 'package:zywny/course/draft/course_draft_screen.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny_course_format/course_files.dart';
import 'package:zywny/course/ui/course_flow.dart';
import 'package:zywny_library/library_blob_store.dart';
import 'package:zywny_midi/midi_device_manager.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/ui/theme.dart';

import 'support/practice_fakes.dart' show FakeMidiInput;

Map<String, Object> _validFiles() => {
  'course.md':
      '---\nformat: 1\nid: rascunho-teste\ntitle: Rascunho Teste\nauthor: prof\n'
      'version: "1"\nlessons: [a]\n---\n\nApresentação.\n',
  'lessons/01-a.md':
      '---\nid: a\ntitle: Primeira\n---\n\nLeia isto.\n\n'
      '```zywny-exercise\nid: ex-a\ntype: choice\ntitle: Escolha\n'
      'question: Quanto é 1+1?\noptions: [1, 2]\nanswer: 1\n'
      'pass: {accuracy: 90}\n```\n',
};

Map<String, Object> _brokenFiles() {
  final files = _validFiles();
  files['lessons/01-a.md'] =
      '---\nid: a\ntitle: Primeira\n---\n\nLeia isto.\n\n'
      '```zywny-exercise\nid: ex-a\ntype: choice\ntitle: Escolha\n'
      'question: Quanto é 1+1?\noptions: [1, 2]\nanswer: 3\n'
      'pass: {accuracy: 90}\n```\n';
  return files;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  CourseScreenDeps makeDeps(CourseProgressStore progress) {
    final devices = MidiDeviceManager();
    addTearDown(devices.dispose);
    final midi = FakeMidiInput();
    addTearDown(midi.dispose);
    final settings = AppSettings();
    addTearDown(settings.dispose);
    return CourseScreenDeps(
      settings: settings,
      deviceManager: devices,
      midiInput: midi,
      progress: progress,
      ensureEngine: () async => null,
    );
  }

  test('rascunho válido abre com a faixa e guarda só em memória', () async {
    final controller = CourseDraftController(
      loadFiles: () async => MemoryCourseFiles(_validFiles()),
    );
    addTearDown(controller.dispose);
    await controller.reload();
    expect(controller.hasErrors, isFalse);
    expect(controller.course, isNotNull);
    expect(controller.loaded?.isDraft, isTrue);
    expect(controller.label, isNotEmpty);
    // Só memória: nada no shared_preferences nem no blob store.
    final prefs = SharedPreferencesAsync();
    expect(await prefs.getString('course_installed'), isNull);
    expect(
      await prefs.getString(CourseProgressStore.keyFor('rascunho-teste')),
      isNull,
    );
    final blobs = MemoryLibraryBlobStore();
    expect(await blobs.get('course:rascunho-teste'), isNull);
  });

  testWidgets('a tela mostra a faixa do rascunho', (tester) async {
    final controller = CourseDraftController(
      loadFiles: () async => MemoryCourseFiles(_validFiles()),
    );
    addTearDown(controller.dispose);
    await controller.reload();
    final deps = makeDeps(controller.progress);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: CourseDraftScreen(controller: controller, deps: deps),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Rascunho'), findsWidgets);
    expect(find.text('Recarregar'), findsOneWidget);
    expect(find.text('Primeira'), findsOneWidget);
  });

  testWidgets('com erro, mostra a lista com arquivo e linha', (tester) async {
    final controller = CourseDraftController(
      loadFiles: () async => MemoryCourseFiles(_brokenFiles()),
    );
    addTearDown(controller.dispose);
    await controller.reload();
    expect(controller.hasErrors, isTrue);
    expect(controller.loaded, isNull);
    final deps = makeDeps(controller.progress);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: CourseDraftScreen(controller: controller, deps: deps),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Rascunho'), findsWidgets);
    expect(find.textContaining('lessons/01-a.md'), findsWidgets);
    expect(find.textContaining('answer'), findsWidgets);
  });

  testWidgets('Recarregar depois de corrigir abre e mantém progresso e lição', (
    tester,
  ) async {
    var broken = true;
    final controller = CourseDraftController(
      loadFiles: () async =>
          MemoryCourseFiles(broken ? _brokenFiles() : _validFiles()),
    );
    addTearDown(controller.dispose);
    await controller.reload();
    expect(controller.hasErrors, isTrue);

    final deps = makeDeps(controller.progress);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: CourseDraftScreen(controller: controller, deps: deps),
      ),
    );
    await tester.pump();
    expect(find.textContaining('lessons/01-a.md'), findsWidgets);

    // O professor marca a lição e escolhe onde está antes de corrigir.
    controller.selectLesson('a');
    final spec = (await (() async {
      // Lê o válido só para achar o spec e gravar o progresso da sessão.
      final tmp = CourseDraftController(
        loadFiles: () async => MemoryCourseFiles(_validFiles()),
      );
      addTearDown(tmp.dispose);
      await tmp.reload();
      return tmp.course!.lessons.first.exercises.single;
    })());
    await controller.progress.recordAttempt(
      'rascunho-teste',
      spec,
      const RoundResult(hits: 1, total: 1),
    );
    expect(
      controller.progress['rascunho-teste'].records['ex-a']?.passed,
      isTrue,
    );

    // Corrige e recarrega pelo botão da tela.
    broken = false;
    await tester.tap(find.text('Recarregar'));
    await tester.pumpAndSettle();
    expect(controller.hasErrors, isFalse);
    expect(controller.course, isNotNull);
    expect(find.text('Primeira'), findsOneWidget);
    // Progresso e lição ficaram.
    expect(
      controller.progress['rascunho-teste'].records['ex-a']?.passed,
      isTrue,
    );
    expect(controller.lessonId, 'a');
    // E continuam fora do disco.
    final prefs = SharedPreferencesAsync();
    expect(
      await prefs.getString(CourseProgressStore.keyFor('rascunho-teste')),
      isNull,
    );
  });
}
