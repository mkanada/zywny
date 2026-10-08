// O tutorial de primeiro uso da biblioteca: começa sozinho uma vez, aponta
// os botões que existem naquele momento, não volta depois de visto e pode
// ser revisto pelas configurações.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/app/general_settings_panel.dart';
import 'package:zywny/app/library_screen.dart';
import 'package:zywny/course/loaded_course.dart';
import 'package:zywny/midi/midi_device_picker.dart' show MidiStatusPill;
import 'package:zywny/tutorial/tour.dart';
import 'package:zywny/tutorial/tour_store.dart';
import 'package:zywny/ui/theme.dart';
import 'package:zywny_course_format/course_reader.dart';
import 'package:zywny_library/piece.dart';

import 'support/course_helpers.dart';

class _NoDevicesMidiCommandPlatform extends MidiCommandPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<MidiDevice>?> get devices async => const <MidiDevice>[];

  @override
  Stream<MidiPacket>? get onMidiDataReceived => null;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => null;
}

Piece _piece(int n, String title) => Piece(
  number: n,
  title: title,
  composer: 'Autor',
  titleKey: foldForSearch(title),
  composerKey: 'autor',
  searchKey: foldForSearch('$n $title autor'),
);

final _pieces = [_piece(1, 'Hino Um'), _piece(2, 'Hino Dois')];

/// A lista do painel de configurações (a primeira área rolável dele; mais
/// abaixo há outras, aninhadas).
Finder _panelScrollable() => find
    .descendant(
      of: find.byType(GeneralSettingsPanel),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  late LoadedCourse course;

  setUpAll(() async {
    final files = oneLessonCourse('Leia isto.');
    final result = await readCourse(files);
    expect(result.course, isNotNull, reason: result.issues.join('\n'));
    course = LoadedCourse(
      course: result.course!,
      files: files,
      origin: CourseOrigin.installed,
    );
  });

  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpLibrary(
    WidgetTester tester, {
    TourStore? store,
    Size size = const Size(390, 844),
    bool library = true,
    bool courses = false,
    Duration delay = Duration.zero,
  }) async {
    useSize(tester, size);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          loadCatalog: () async =>
              library ? PieceCatalog(_pieces) : PieceCatalog.none(),
          loadScore: (piece) async => Uint8List(0),
          loadCourses: () async => courses ? [course] : const [],
          tourStore: store,
          tourDelay: delay,
          scoreBuilder: (context, o) => const Scaffold(body: Text('partitura')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  bool touring(WidgetTester tester) =>
      find.byType(TourOverlay).evaluate().isNotEmpty;

  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(kTourTitleKey)).data!;

  /// Passa pelo passeio inteiro, devolvendo o título de cada passo.
  Future<List<String>> walk(WidgetTester tester) async {
    final titles = <String>[];
    for (var i = 0; i < 40 && touring(tester); i++) {
      titles.add(title(tester));
      expect(tester.takeException(), isNull, reason: titles.last);
      await tester.tap(
        find.descendant(
          of: find.byType(TourOverlay),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(touring(tester), isFalse, reason: 'o passeio não terminou');
    return titles;
  }

  testWidgets('primeiro uso: começa sozinho, aponta o que existe e marca '
      'como visto', (tester) async {
    final store = TourStore();
    await pumpLibrary(tester, store: store);

    expect(touring(tester), isTrue);
    final titles = await walk(tester);
    expect(await store.seen(TourId.library), isTrue);
    expect(titles, [
      'Bem-vindo ao Zywny',
      // Sem cursos nem "instalar": esses passos não aparecem.
      'Busca',
      'Por onde começar',
      'Ordem',
      'A lista',
      'Teclado MIDI',
      'Configurações',
      'Agora é com você',
    ]);
  });

  testWidgets('com o curso inicial, ele é o primeiro destaque', (tester) async {
    await pumpLibrary(tester, store: TourStore(), courses: true);
    final titles = await walk(tester);
    expect(titles.take(3), ['Bem-vindo ao Zywny', 'Cursos', 'Busca']);
  });

  testWidgets('sem biblioteca: o destaque é instalar uma, e não há lista', (
    tester,
  ) async {
    await pumpLibrary(tester, store: TourStore(), library: false);
    final titles = await walk(tester);
    expect(titles, [
      'Bem-vindo ao Zywny',
      'Músicas',
      'Teclado MIDI',
      'Configurações',
      'Pronto para começar',
    ]);
  });

  testWidgets('sem biblioteca e com o curso inicial, "Cursos" vem antes de '
      '"Músicas"', (tester) async {
    await pumpLibrary(
      tester,
      store: TourStore(),
      library: false,
      courses: true,
    );
    final titles = await walk(tester);
    expect(titles.take(3), ['Bem-vindo ao Zywny', 'Cursos', 'Músicas']);
  });

  testWidgets('o texto concorda com o vocabulário da biblioteca (hino)', (
    tester,
  ) async {
    await pumpLibrary(tester, store: TourStore());
    // Passo "Por onde começar".
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mostra como começar'), findsOneWidget);
    expect(find.textContaining('reabre o hino'), findsOneWidget);
  });

  testWidgets('pular também conta como visto, e o passeio não volta', (
    tester,
  ) async {
    final store = TourStore();
    await pumpLibrary(tester, store: store);
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();
    expect(touring(tester), isFalse);
    expect(await store.seen(TourId.library), isTrue);

    // Uma abertura nova do app: nada de passeio.
    await pumpLibrary(tester, store: TourStore());
    expect(touring(tester), isFalse);
  });

  testWidgets('sem registro do tutorial (os testes), nunca aparece', (
    tester,
  ) async {
    await pumpLibrary(tester);
    expect(touring(tester), isFalse);
  });

  testWidgets('espera a abertura sair antes de aparecer', (tester) async {
    useSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          loadCatalog: () async => PieceCatalog(_pieces),
          loadScore: (piece) async => Uint8List(0),
          tourStore: TourStore(),
          tourDelay: const Duration(seconds: 2),
          scoreBuilder: (context, o) => const Scaffold(body: Text('x')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(touring(tester), isFalse);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(touring(tester), isTrue);
  });

  testWidgets('"Rever o tutorial" nas configurações mostra de novo', (
    tester,
  ) async {
    final store = TourStore();
    await store.markSeen(TourId.library);
    await pumpLibrary(tester, store: store);
    expect(touring(tester), isFalse);

    await tester.tap(find.byTooltip('Configurações gerais'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Rever o tutorial'),
      300,
      scrollable: _panelScrollable(),
    );
    await tester.tap(find.text('Rever o tutorial'));
    await tester.pumpAndSettle();

    // Voltou à biblioteca, com o passeio na tela.
    expect(find.text('Configurações gerais'), findsNothing);
    expect(touring(tester), isTrue);
    expect(title(tester), 'Bem-vindo ao Zywny');
  });

  testWidgets('"Sobre o Zywny" nas configurações abre a tela', (tester) async {
    await pumpLibrary(tester, store: TourStore());
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Configurações gerais'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sobre o Zywny'),
      300,
      scrollable: _panelScrollable(),
    );
    await tester.tap(find.text('Sobre o Zywny'));
    await tester.pumpAndSettle();
    expect(find.text('De onde vem o nome'), findsOneWidget);
  });

  testWidgets('celular deitado (duas colunas): todos os passos têm alvo e '
      'o cartão cabe', (tester) async {
    await pumpLibrary(
      tester,
      store: TourStore(),
      size: const Size(844, 390),
      courses: true,
    );
    final titles = await walk(tester);
    expect(titles, [
      'Bem-vindo ao Zywny',
      'Cursos',
      'Busca',
      'Por onde começar',
      'Ordem',
      'A lista',
      'Teclado MIDI',
      'Configurações',
      'Agora é com você',
    ]);
  });

  testWidgets('celular pequeno em pé (360 dp) não estoura', (tester) async {
    await pumpLibrary(
      tester,
      store: TourStore(),
      size: const Size(360, 640),
      courses: true,
    );
    expect((await walk(tester)).length, 9);
  });

  testWidgets('o recorte cerca o botão certo em cada passo', (tester) async {
    await pumpLibrary(tester, store: TourStore(), courses: true);

    Rect? hole() =>
        (tester.widget<CustomPaint>(find.byKey(kTourScrimKey)).painter!
                as TourScrimPainter)
            .hole;
    Future<void> next() async {
      await tester.tap(
        find.descendant(
          of: find.byType(TourOverlay),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Passa até o passo [name] e devolve o recorte dele.
    Future<Rect?> holeOf(String name) async {
      while (title(tester) != name) {
        await next();
      }
      return hole();
    }

    expect(hole(), isNull, reason: 'a boas-vindas não recorta nada');
    expect(await holeOf('Busca'), tester.getRect(find.byType(TextField)));
    expect(
      await holeOf('Teclado MIDI'),
      tester.getRect(find.byType(MidiStatusPill)),
    );
    expect(
      await holeOf('Configurações'),
      tester.getRect(find.widgetWithIcon(IconButton, Icons.settings_outlined)),
    );
    expect(await holeOf('Agora é com você'), isNull);
  });

  testWidgets('a despedida promete o passeio da partitura só no celular', (
    tester,
  ) async {
    /// O texto do último passo, numa abertura nova do app (sem "visto").
    Future<String> farewell(Size size) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await tester.pumpWidget(const SizedBox()); // descarta a tela anterior
      await pumpLibrary(tester, store: TourStore(), size: size);
      while (title(tester) != 'Agora é com você') {
        await tester.tap(
          find.descendant(
            of: find.byType(TourOverlay),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
      }
      return [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(TourOverlay),
            matching: find.byType(Text),
          ),
        ))
          text.data ?? '',
      ].join(' ');
    }

    expect(
      await farewell(const Size(390, 844)),
      contains('mostro também a tela da partitura'),
    );
    // Janela larga: o desktop é o banco de testes, sem o passeio da partitura.
    expect(await farewell(const Size(1280, 800)), isNot(contains('partitura')));
  });
}
