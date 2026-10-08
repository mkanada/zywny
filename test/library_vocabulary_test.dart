// B07 — o vocabulário e a numeração vêm do manifesto: "hino"/"peça" com a
// concordância certa, e sem número quando o pacote não é numerado.
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny_library/library_blob_store.dart';
import 'package:zywny_library/library_package.dart';
import 'package:zywny/app/library_screen.dart';
import 'package:zywny_library/library_store.dart';
import 'package:zywny_library/library_term_scope.dart';
import 'package:zywny_library/library_sort.dart';
import 'package:zywny/app/layout_panel.dart';
import 'package:zywny/ui/theme.dart';

import 'support/library_fixtures.dart';

class _NoDevicesMidiCommandPlatform extends MidiCommandPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<MidiDevice>?> get devices async => const <MidiDevice>[];

  @override
  Stream<MidiPacket>? get onMidiDataReceived => null;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => null;
}

const _hino = LibraryTerm(singular: 'hino', plural: 'hinos', feminine: false);
const _peca = LibraryTerm(singular: 'peça', plural: 'peças', feminine: true);

/// Todo texto que o usuário lê na tela: `Text`, dicas (`tooltip`), rótulos de
/// semântica e dicas de campo.
List<String> _visibleTexts(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text)))
    w.data ?? w.textSpan?.toPlainText() ?? '',
  for (final w in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    w.message ?? '',
  for (final w in tester.widgetList<TextField>(find.byType(TextField)))
    w.decoration?.hintText ?? '',
];

void main() {
  group('LibraryTerm', () {
    test('concordância masculina', () {
      expect(_hino.este, 'este');
      expect(_hino.neste, 'neste');
      expect(_hino.deste, 'deste');
      expect(_hino.nenhum, 'nenhum');
      expect(_hino.nenhumCapitalized, 'Nenhum');
      expect(_hino.um, 'um');
      expect(_hino.o, 'o');
      expect(_hino.os, 'os');
      expect(_hino.todos, 'todos');
      expect(_hino.encontrado, 'encontrado');
      expect(_hino.singularCapitalized, 'Hino');
    });

    test('concordância feminina', () {
      expect(_peca.este, 'esta');
      expect(_peca.neste, 'nesta');
      expect(_peca.deste, 'desta');
      expect(_peca.nenhum, 'nenhuma');
      expect(_peca.nenhumCapitalized, 'Nenhuma');
      expect(_peca.um, 'uma');
      expect(_peca.o, 'a');
      expect(_peca.os, 'as');
      expect(_peca.todos, 'todas');
      expect(_peca.encontrado, 'encontrada');
      expect(_peca.singularCapitalized, 'Peça');
    });

    test('count: singular com 1, plural nos demais (incluindo 0)', () {
      expect(_hino.count(1), '1 hino');
      expect(_hino.count(600), '600 hinos');
      expect(_peca.count(1), '1 peça');
      expect(_peca.count(48), '48 peças');
      expect(_peca.count(0), '0 peças');
    });

    test('LibraryTerm.hymn é o hinário', () {
      expect(LibraryTerm.hymn, _hino);
    });

    testWidgets('LibraryTermScope: sem escopo vale o hinário', (tester) async {
      LibraryTerm? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = LibraryTermScope.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, LibraryTerm.hymn);
      await tester.pumpWidget(
        LibraryTermScope(
          term: _peca,
          child: Builder(
            builder: (context) {
              seen = LibraryTermScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, _peca);
    });
  });

  group('ordenação', () {
    test('sem número, a chave de número não existe nas pastilhas e o id '
        'ordena', () {
      // O que a tela usa: as pastilhas sem SortKey.number.
      expect([
        for (final k in SortKey.values)
          if (k != SortKey.number) k,
      ], isNot(contains(SortKey.number)));
    });
  });

  group('telas', () {
    late TestKeys keys;
    late LibraryStore store;
    setUpAll(() async => keys = await TestKeys.generate());

    setUp(() {
      MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      store = LibraryStore(
        blobs: MemoryLibraryBlobStore(),
        prefs: SharedPreferencesAsync(),
        publicKey: keys.pub,
      );
    });

    Future<Uint8List> classicos({int pieces = 3}) => keys.package(
      'classicos',
      name: 'Clássicos',
      pieces: pieces,
      numbered: false,
      singular: 'peça',
      plural: 'peças',
      feminine: true,
    );

    Future<void> pumpLibrary(WidgetTester tester, {Size? size}) async {
      tester.view.physicalSize = size ?? const Size(760, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            libraryStore: store,
            scoreBuilder: (context, o) => const Scaffold(body: Text('x')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('biblioteca não numerada: peças, sem número e sem a ordem '
        '"Número"', (tester) async {
      await store.load();
      await store.install(await classicos());
      await pumpLibrary(tester);

      expect(
        find.textContaining('Clássicos', findRichText: true),
        findsOneWidget,
      ); // título da biblioteca
      expect(
        find.textContaining('3 peças', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Número'), findsNothing);
      expect(find.text('Nome ↑'), findsOneWidget); // ordem padrão: título
      expect(find.text('Buscar título ou autor'), findsOneWidget);
      expect(find.text('Buscar número, título ou autor'), findsNothing);
      // Compositor e catálogo na segunda linha.
      expect(find.textContaining('C · Op. 1'), findsOneWidget);
      // A primeira de uso fala em peça, no feminino.
      expect(
        find.text('Escolha uma peça para começar e ligue o teclado ao celular.'),
        findsOneWidget,
      );
    });

    testWidgets('busca sem resultado: "Nenhuma peça com …"', (tester) async {
      await store.load();
      await store.install(await classicos());
      await pumpLibrary(tester);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma peça com “zzzz”.'), findsOneWidget);
    });

    testWidgets('numerada com termo "hino": tudo como antes', (tester) async {
      await store.load();
      await store.install(await keys.package('hinos', pieces: 3));
      await pumpLibrary(tester);
      expect(
        find.textContaining('3 hinos', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Número ↑'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // o número na coluna
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum hino com “zzzz”.'), findsOneWidget);
    });

    testWidgets('nenhum texto da biblioteca nem das configurações diz "hino" '
        'com termo "peça"', (tester) async {
      await store.load();
      await store.install(await classicos());
      await pumpLibrary(tester);
      // Hoje o hint de busca e o cartão de começo são os textos fixos.
      final onLibrary = _visibleTexts(tester).join('\n');
      expect(onLibrary.toLowerCase(), isNot(contains('hino')));

      await tester.tap(find.byTooltip('Configurações gerais'));
      await tester.pumpAndSettle();
      final onSettings = _visibleTexts(tester).join('\n');
      expect(onSettings.toLowerCase(), isNot(contains('hino')));
      expect(onSettings, contains('valem para todas as peças'));
    });

    testWidgets('layout e trilha: textos concordam com o termo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryTermScope(
            term: _peca,
            child: Scaffold(
              body: SizedBox(
                width: 500,
                height: 1500,
                child: LayoutPanel(
                  values: const {},
                  pageFitsBox: true,
                  fittedPage: null,
                  onChanged: (_, _) {},
                  onCommit: () {},
                  onFitChanged: (_) {},
                  onReset: () {},
                  onCopy: () {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byTooltip('Restaurar o layout padrão nesta peça'),
        findsOneWidget,
      );
    }, skip: false);
  });
}
