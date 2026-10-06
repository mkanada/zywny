// Biblioteca em paisagem (O1 do estudo de orientação): num celular deitado o
// topo empilhado comia a altura inteira e a lista ficava com zero. Em duas
// colunas — atalhos à esquerda, busca e lista à direita — a lista tem a
// altura toda. Em retrato (e em janela alta, como a de desktop) nada muda.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/format/course_files.dart';
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/loaded_course.dart';
import 'package:zywny/library/library_screen.dart';
import 'package:zywny/library/piece.dart';
import 'package:zywny/library/piece_progress.dart';
import 'package:zywny/ui/theme.dart';

class _NoDevicesMidiCommandPlatform extends MidiCommandPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<MidiDevice>?> get devices async => const <MidiDevice>[];

  @override
  Stream<MidiPacket>? get onMidiDataReceived => null;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => null;
}

/// Um celular deitado (iPhone 14) e o mesmo em pé.
const _phoneLandscape = Size(844, 390);
const _phonePortrait = Size(390, 844);

// Mais difícil primeiro: ordenar por dificuldade muda o hino do topo.
final _pieces = [
  for (var n = 1; n <= 600; n++)
    Piece(
      number: n,
      title: 'Hino $n',
      composer: 'Autor',
      level: n == 1 ? 5 : 1,
      difficulty: n == 1 ? 90 : 10.0 + n / 100,
      titleKey: 'hino $n',
      composerKey: 'autor',
      searchKey: 'hino $n autor',
    ),
];

final _verticalLists = find.byWidgetPredicate(
  (w) => w is ListView && w.scrollDirection == Axis.vertical,
);

/// O hino na lista (e não no cartão "Continuar" nem no campo de busca).
Finder _inList(String title) =>
    find.descendant(of: _verticalLists, matching: find.text(title));

final _horizontalChips = find.byWidgetPredicate(
  (w) => w is ListView && w.scrollDirection == Axis.horizontal,
);

void main() {
  late LoadedCourse course;

  setUpAll(() async {
    final files = MemoryCourseFiles({
      'course.md':
          '---\nformat: 1\nid: t\ntitle: Curso Teste\nauthor: zywny\n'
          'version: "1"\nlessons: [a]\n---\n\nApresentação.\n',
      'lessons/01-a.md': '---\nid: a\ntitle: Primeira\n---\n\nLeia isto.\n',
    });
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

  Future<void> pumpLibrary(
    WidgetTester tester, {
    Size size = _phoneLandscape,
    PieceCatalog? catalog,
    bool opened = true,
    bool withCourse = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final progress = PieceProgressStore();
    if (opened) await progress.markOpened('600');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          loadCatalog: () async => catalog ?? PieceCatalog(_pieces),
          loadScore: (piece) async => Uint8List(0),
          loadCourses: () async => withCourse ? [course] : const [],
          progress: progress,
          scoreBuilder: (context, o) => const Scaffold(body: Text('partitura')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  group('celular deitado', () {
    testWidgets('a lista ocupa a altura toda, ao lado dos atalhos', (
      tester,
    ) async {
      await pumpLibrary(tester);
      expect(tester.takeException(), isNull);

      // O1: antes a lista tinha altura zero e nenhum hino aparecia.
      final list = tester.getRect(_verticalLists);
      expect(list.height, greaterThan(300));
      for (final n in [1, 2, 3, 4, 5]) {
        expect(_inList('Hino $n'), findsOneWidget, reason: 'hino $n');
      }

      // Os atalhos ficam à esquerda da lista, não em cima dela.
      for (final shortcut in ['CONTINUAR', 'Curso Teste', 'ORDENAR POR']) {
        expect(
          tester.getTopRight(find.text(shortcut)).dx,
          lessThan(list.left),
          reason: '"$shortcut" fica na coluna da esquerda',
        );
      }
      // A busca encabeça a lista, na mesma coluna, com a engrenagem e o
      // teclado no canto.
      final search = tester.getRect(find.byType(TextField));
      expect(search.left, closeTo(list.left, 1));
      expect(search.bottom, lessThanOrEqualTo(list.top));
      expect(find.byTooltip('Configurações gerais'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byTooltip('Configurações gerais')).dx,
        greaterThan(search.right - 1),
      );
      expect(find.byTooltip('Conectar teclado MIDI'), findsOneWidget);
    });

    testWidgets('as seis ordens ficam à vista, sem rolar as pastilhas', (
      tester,
    ) async {
      await pumpLibrary(tester);
      expect(_horizontalChips, findsNothing);
      for (final label in [
        'Número ↑',
        'Nome',
        'Dificuldade',
        'Acidentes',
        'Recentes',
        'Pontuação',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      // Fluem em linhas, cada uma do tamanho do texto: não uma por linha,
      // esticada à largura da coluna.
      expect(
        tester.getCenter(find.text('Número ↑')).dy,
        tester.getCenter(find.text('Nome')).dy,
      );
      final column = tester.getRect(find.text('CONTINUAR')).left;
      expect(
        tester.getRect(find.widgetWithText(InkWell, 'Nome')).width,
        lessThan(tester.getRect(find.byType(TextField)).left - column - 100),
      );

      // E ordenam: o mais difícil (1) sai do topo.
      await tester.tap(find.text('Dificuldade'));
      await tester.pump();
      expect(find.text('Dificuldade ↑'), findsOneWidget);
      expect(_inList('Hino 1'), findsNothing);
      expect(_inList('Hino 2'), findsOneWidget);
    });

    testWidgets('a busca mostra os resultados e a mensagem de vazio', (
      tester,
    ) async {
      await pumpLibrary(tester);
      await tester.enterText(find.byType(TextField), 'Hino 12');
      await tester.pump();
      // 12 e 120–129, na ordem do número.
      expect(_inList('Hino 12'), findsOneWidget);
      expect(_inList('Hino 120'), findsOneWidget);
      expect(_inList('Hino 5'), findsNothing);

      await tester.enterText(find.byType(TextField), 'chopin');
      await tester.pump();
      expect(find.textContaining('chopin'), findsWidgets);
      expect(find.text('Limpar a busca'), findsOneWidget);
      // A mensagem cabe na tela (antes ficava sob o cartão e a ordenação).
      expect(
        tester.getRect(find.text('Limpar a busca')).bottom,
        lessThan(_phoneLandscape.height),
      );
      await tester.tap(find.text('Limpar a busca'));
      await tester.pump();
      expect(_inList('Hino 1'), findsOneWidget);
    });

    testWidgets(
      'primeiro uso: "Comece por aqui" ocupa o lugar do "Continuar"',
      (tester) async {
        await pumpLibrary(tester, opened: false);
        expect(tester.takeException(), isNull);
        expect(find.text('COMECE POR AQUI'), findsOneWidget);
        expect(find.text('CONTINUAR'), findsNothing);
        expect(
          tester.getTopRight(find.text('COMECE POR AQUI')).dx,
          lessThan(tester.getRect(_verticalLists).left),
        );

        await tester.ensureVisible(find.text('Ver os mais fáceis'));
        await tester.tap(find.text('Ver os mais fáceis'));
        await tester.pump();
        expect(find.text('Dificuldade ↑'), findsOneWidget);
        expect(_inList('Hino 1'), findsNothing);
      },
    );

    testWidgets('sem biblioteca: o curso inicial na esquerda, instalar na '
        'direita, sem busca', (tester) async {
      await pumpLibrary(tester, catalog: PieceCatalog.none());
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
      final initial = tester.getCenter(find.text('Comece pelo curso inicial'));
      final install = tester.getCenter(
        find.text('Instale uma biblioteca de músicas'),
      );
      expect(initial.dx, lessThan(install.dx));
      // Os dois cartões começam na mesma linha.
      expect(
        tester.getTopLeft(find.text('Instale uma biblioteca de músicas')).dy,
        closeTo(
          tester.getTopLeft(find.text('Comece pelo curso inicial')).dy,
          1,
        ),
      );
      // Os dois cartões cabem sem rolar.
      expect(find.text('Começar'), findsOneWidget);
      expect(
        tester.getRect(find.text('Abrir arquivo…')).bottom,
        lessThan(_phoneLandscape.height),
      );
    });

    testWidgets('com a fonte grande a coluna da esquerda rola e nada estoura', (
      tester,
    ) async {
      tester.view.physicalSize = _phoneLandscape;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final progress = PieceProgressStore();
      await progress.markOpened('600');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: LibraryScreen(
            loadCatalog: () async => PieceCatalog(_pieces),
            loadScore: (piece) async => Uint8List(0),
            loadCourses: () async => [course],
            progress: progress,
            scoreBuilder: (context, o) =>
                const Scaffold(body: Text('partitura')),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // A ordenação, no pé da coluna, alcança-se rolando.
      await tester.ensureVisible(find.text('Pontuação'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Pontuação')).bottom,
        lessThanOrEqualTo(_phoneLandscape.height),
      );
    });
  });

  group('onde nada muda', () {
    testWidgets('retrato: tudo empilhado, pastilhas rolando de lado', (
      tester,
    ) async {
      await pumpLibrary(tester, size: _phonePortrait);
      expect(tester.takeException(), isNull);
      expect(_horizontalChips, findsOneWidget);
      // Uma coluna só: a busca, o "Continuar" e a lista no mesmo x.
      final left = tester.getTopLeft(find.byType(TextField)).dx;
      expect(tester.getTopLeft(find.text('CONTINUAR')).dx, greaterThan(left));
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThan(tester.getTopLeft(find.text('CONTINUAR')).dy),
      );
      expect(
        tester.getRect(_verticalLists).top,
        greaterThan(tester.getRect(find.text('CONTINUAR')).bottom),
      );
    });

    testWidgets('janela larga e alta (desktop): fica como em retrato', (
      tester,
    ) async {
      await pumpLibrary(tester, size: const Size(1280, 800));
      expect(tester.takeException(), isNull);
      expect(_horizontalChips, findsOneWidget);
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThan(tester.getTopLeft(find.text('CONTINUAR')).dy),
      );
    });
  });

  testWidgets('girar o aparelho mantém o ponto da lista', (tester) async {
    await pumpLibrary(tester, size: _phonePortrait);
    await tester.drag(_verticalLists, const Offset(0, -64.0 * 100));
    await tester.pumpAndSettle();
    expect(_inList('Hino 1'), findsNothing);
    final inView = [
      for (var n = 90; n <= 130; n++)
        if (_inList('Hino $n').evaluate().isNotEmpty) n,
    ];
    expect(inView, isNotEmpty, reason: 'rolou até perto do hino 100');

    tester.view.physicalSize = _phoneLandscape;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_horizontalChips, findsNothing);
    expect(_inList('Hino 1'), findsNothing);
    expect(_inList('Hino ${inView.first}'), findsOneWidget);

    // E de volta a retrato.
    tester.view.physicalSize = _phonePortrait;
    await tester.pumpAndSettle();
    expect(_horizontalChips, findsOneWidget);
    expect(_inList('Hino 1'), findsNothing);
    expect(_inList('Hino ${inView.first}'), findsOneWidget);
  });
}
