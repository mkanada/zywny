// I04, critério 1 — `test/course_install_test.dart`: o pacote de curso
// instala e aparece na lista; sem assinatura válida, sem envelope, com curso
// e biblioteca juntos, com erro de validação ou com o id do embutido, recusa
// sem gravar nada; substituir mantém o progresso; remover some da lista e o
// progresso fica. O fluxo de tela (diálogos, aviso) vai como o de biblioteca
// do `library_install_test.dart`.
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/course_installer.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/course_store.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/format/course_files.dart';
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/loaded_course.dart';
import 'package:zywny/course/ui/courses_screen.dart';
import 'package:zywny/library/library_blob_store.dart';
import 'package:zywny/library/library_package.dart' show LibraryFormatException;
import 'package:zywny/library/library_store.dart';
import 'package:zywny/app/courses_section.dart';
import 'package:zywny/ui/theme.dart';

import 'support/course_fixtures.dart';
import 'support/library_fixtures.dart';

void main() {
  late TestKeys keys;
  late MemoryLibraryBlobStore blobs;
  late CourseStore store;
  late CourseProgressStore progress;

  setUpAll(() async => keys = await TestKeys.generate());

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    blobs = MemoryLibraryBlobStore();
    store = CourseStore(
      blobs: blobs,
      prefs: SharedPreferencesAsync(),
      publicKey: keys.pub,
    );
    progress = CourseProgressStore(prefs: SharedPreferencesAsync());
  });

  Future<Uint8List> sealed(Map<String, String> files) =>
      sealCourse(files, keys);

  group('store', () {
    test('curso válido instala e aparece na lista', () async {
      final installed = await store.install(await sealed(minimalCourse()));
      expect(installed.id, 'curso-teste');
      expect(installed.title, 'Curso Teste');
      expect(store.installed.map((e) => e.id), ['curso-teste']);

      final loaded = await store.open('curso-teste');
      expect(loaded, isNotNull);
      expect(loaded!.course.lessons.map((l) => l.id), ['a']);

      await store.load();
      expect(store.installed.map((e) => e.id), ['curso-teste']);
    });

    test('assinado por outra chave: recusado', () async {
      final other = await TestKeys.generate();
      await expectLater(
        store.install(await sealCourse(minimalCourse(), other)),
        throwsA(
          isA<LibraryFormatException>().having(
            (e) => e.message,
            'message',
            contains('não foi assinada pela chave deste app'),
          ),
        ),
      );
      expect(store.installed, isEmpty);
      expect(blobs.blobs, isEmpty);
    });

    test('zip sem envelope: recusado', () async {
      await expectLater(
        store.install(plainCourseZip(minimalCourse())),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(store.installed, isEmpty);
    });

    test('course.md e manifest.json juntos: recusado', () async {
      final files = {...minimalCourse(), 'manifest.json': '{"formato": 1}'};
      await expectLater(
        store.install(await sealed(files)),
        throwsA(
          isA<LibraryFormatException>().having(
            (e) => e.message,
            'message',
            contains('ao mesmo tempo'),
          ),
        ),
      );
      expect(store.installed, isEmpty);
    });

    test('curso com erro: recusado com a mensagem', () async {
      final files = minimalCourse();
      files['course.md'] = files['course.md']!.replaceAll(
        'lessons: [a]',
        'lessons: [a, b]',
      );
      await expectLater(
        store.install(await sealed(files)),
        throwsA(
          isA<LibraryFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('erros'), contains('não tem arquivo')),
          ),
        ),
      );
      expect(store.installed, isEmpty);
    });

    test('id do embutido: recusado', () async {
      await expectLater(
        store.install(await sealed(minimalCourse(id: 'iniciacao'))),
        throwsA(
          isA<LibraryFormatException>().having(
            (e) => e.message,
            'message',
            contains('já vem no app'),
          ),
        ),
      );
      expect(store.installed, isEmpty);
    });

    test('substituir mantém o progresso', () async {
      await store.install(await sealed(minimalCourse()));
      final loaded = (await store.open('curso-teste'))!;
      final spec = loaded.course.lessons.first.exercises.single;
      await progress.recordAttempt(
        'curso-teste',
        spec,
        const RoundResult(hits: 1, total: 1),
      );
      expect(progress['curso-teste'].records['ex-a']?.passed, isTrue);

      final replaced = await store.install(await sealed(minimalCourseV2()));
      expect(replaced.version, '2');
      expect(store.installed, hasLength(1));
      expect(progress['curso-teste'].records['ex-a']?.passed, isTrue);
    });

    test('remover some da lista e o progresso fica', () async {
      await store.install(await sealed(minimalCourse()));
      final loaded = (await store.open('curso-teste'))!;
      final spec = loaded.course.lessons.first.exercises.single;
      await progress.recordAttempt(
        'curso-teste',
        spec,
        const RoundResult(hits: 1, total: 1),
      );

      await store.remove('curso-teste');
      expect(store.installed, isEmpty);
      expect(await store.open('curso-teste'), isNull);
      expect(progress['curso-teste'].records['ex-a']?.passed, isTrue);
    });
  });

  group('fluxo de tela', () {
    Future<void> pumpInstaller(
      WidgetTester tester,
      Future<Uint8List?> Function() pick,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    installCourseFromFile(context, store, pick: pick),
                child: const Text('instalar'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> tapInstall(WidgetTester tester) async {
      await tester.tap(find.text('instalar'));
      await tester.pumpAndSettle();
    }

    testWidgets('válido instala e avisa', (tester) async {
      final bytes = await sealed(minimalCourse());
      await pumpInstaller(tester, () async => bytes);
      await tapInstall(tester);

      expect(find.text('Curso Teste instalado (1 lição)'), findsOneWidget);
      expect(store['curso-teste'], isNotNull);
    });

    testWidgets('erro mostra o diálogo e nada é gravado', (tester) async {
      final other = await TestKeys.generate();
      await pumpInstaller(
        tester,
        () async => sealCourse(minimalCourse(), other),
      );
      await tapInstall(tester);

      expect(find.text('Não deu para instalar'), findsOneWidget);
      expect(find.textContaining('assinada'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(store.installed, isEmpty);
      expect(blobs.blobs, isEmpty);
    });

    testWidgets('mesmo id pergunta; cancelar mantém', (tester) async {
      await store.install(await sealed(minimalCourse()));
      await pumpInstaller(tester, () async => sealed(minimalCourseV2()));
      await tapInstall(tester);

      expect(find.text('Substituir Curso Teste?'), findsOneWidget);
      expect(find.textContaining('versão 1'), findsOneWidget);
      expect(find.textContaining('versão 2'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store['curso-teste']!.version, '1');
    });

    testWidgets('confirmar substitui e mantém o progresso', (tester) async {
      await store.install(await sealed(minimalCourse()));
      final spec = (await store.open('curso-teste'))!
          .course
          .lessons
          .first
          .exercises
          .single;
      await progress.recordAttempt(
        'curso-teste',
        spec,
        const RoundResult(hits: 1, total: 1),
      );

      await pumpInstaller(tester, () async => sealed(minimalCourseV2()));
      await tapInstall(tester);
      await tester.tap(find.text('Substituir'));
      await tester.pumpAndSettle();

      expect(store['curso-teste']!.version, '2');
      expect(progress['curso-teste'].records['ex-a']?.passed, isTrue);
    });

    testWidgets('mesma versão: "já instalado"', (tester) async {
      await store.install(await sealed(minimalCourse()));
      await pumpInstaller(tester, () async => sealed(minimalCourse()));
      await tapInstall(tester);

      expect(find.text('Já instalado'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(store['curso-teste']!.version, '1');
    });

    testWidgets('o despacho instala biblioteca ou curso', (tester) async {
      final libraries = LibraryStore(
        blobs: MemoryLibraryBlobStore(),
        prefs: SharedPreferencesAsync(),
        publicKey: keys.pub,
      );
      final courseBytes = await sealed(minimalCourse());
      final libraryBytes = await keys.package('hinos', name: 'Hinário');
      Uint8List? picked;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => installPackageFromFile(
                  context,
                  libraries,
                  store,
                  pick: () async => picked,
                ),
                child: const Text('instalar'),
              ),
            ),
          ),
        ),
      );

      picked = courseBytes;
      await tapInstall(tester);
      expect(store['curso-teste'], isNotNull);
      expect(find.textContaining('instalado'), findsOneWidget);

      // O aviso do curso sai antes do próximo: senão o da biblioteca fica
      // na fila e não aparece.
      await tester.pump(const Duration(seconds: 5));

      picked = libraryBytes;
      await tapInstall(tester);
      expect(libraries['hinos'], isNotNull);
      expect(find.textContaining('instalada'), findsOneWidget);
    });
  });

  group('lista e configurações', () {
    Future<LoadedCourse> memoryCourse() async {
      final files = MemoryCourseFiles({
        for (final e in minimalCourse().entries) e.key: e.value,
      });
      final result = await readCourse(files);
      expect(result.course, isNotNull, reason: result.issues.join('\n'));
      return LoadedCourse(
        course: result.course!,
        files: files,
        origin: CourseOrigin.builtIn,
      );
    }

    testWidgets('a lista mostra o cartão de instalar', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: CoursesScreen(
            courses: [await memoryCourse()],
            progress: MemoryCourseProgressStore(),
            onOpen: (context, course) {},
            onInstall: () => tapped = true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Curso Teste'), findsOneWidget);
      expect(find.text('Instalar curso…'), findsOneWidget);
      await tester.tap(find.text('Instalar curso…'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('sem onInstall não há cartão', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: CoursesScreen(
            courses: [await memoryCourse()],
            progress: MemoryCourseProgressStore(),
            onOpen: (context, course) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Instalar curso…'), findsNothing);
    });

    testWidgets('a seção lista e remove, e o progresso fica', (tester) async {
      await store.install(await sealed(minimalCourse()));
      final spec = (await store.open('curso-teste'))!
          .course
          .lessons
          .first
          .exercises
          .single;
      await progress.recordAttempt(
        'curso-teste',
        spec,
        const RoundResult(hits: 1, total: 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: CoursesSection(store: store, onInstall: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Curso Teste'), findsOneWidget);
      expect(find.textContaining('versão 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Remover Curso Teste'));
      await tester.pumpAndSettle();
      expect(find.text('Remover Curso Teste?'), findsOneWidget);
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();

      expect(store.installed, isEmpty);
      expect(find.textContaining('Nenhum curso instalado'), findsOneWidget);
      expect(progress['curso-teste'].records['ex-a']?.passed, isTrue);
    });
  });
}
