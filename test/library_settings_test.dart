// B06 — a seção Bibliotecas nas configurações gerais.
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny_library/library_blob_store.dart';
import 'package:zywny/app/library_screen.dart';
import 'package:zywny_library/library_store.dart';
import 'package:zywny_library/piece.dart';
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

void main() {
  late TestKeys keys;
  late MemoryLibraryBlobStore blobs;
  late LibraryStore store;
  Uint8List? picked;

  setUpAll(() async => keys = await TestKeys.generate());

  setUp(() async {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    blobs = MemoryLibraryBlobStore();
    store = LibraryStore(
      blobs: blobs,
      prefs: SharedPreferencesAsync(),
      publicKey: keys.pub,
    );
    picked = null;
    await store.load();
    await store.install(
      await keys.package(
        'hinos',
        name: 'Hinário',
        version: '2026.10.04',
        pieces: 3,
      ),
    );
    await store.install(
      await keys.package(
        'classicos',
        name: 'Clássicos',
        version: '1',
        pieces: 2,
      ),
    );
  });

  /// A biblioteca, aberta de verdade, com as configurações por cima.
  Future<void> pumpLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(760, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          libraryStore: store,
          pickLibraryFile: () async => picked,
          scoreBuilder: (context, o) => const Scaffold(body: Text('x')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Configurações gerais'));
    await tester.pumpAndSettle();
  }

  Future<void> closeSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String library) async {
    await tester.tap(find.byTooltip('Mais sobre $library'));
    await tester.pumpAndSettle();
  }

  testWidgets('lista as instaladas, a em uso marcada', (tester) async {
    await pumpLibrary(tester);
    // A última instalada é a em uso (D-BIB-NOVA).
    expect(find.text('T1'), findsOneWidget);
    await openSettings(tester);
    expect(find.text('Bibliotecas'), findsOneWidget);
    expect(find.text('Hinário'), findsOneWidget);
    expect(find.text('Clássicos'), findsOneWidget);
    expect(find.text('versão 2026.10.04 · 3 hinos'), findsOneWidget);
    expect(find.text('em uso · versão 1 · 2 hinos'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.text('Instalar outra…'), findsOneWidget);
  });

  testWidgets('trocar a em uso: a lista muda ao fechar o painel', (
    tester,
  ) async {
    await pumpLibrary(tester);
    expect(find.text('T3'), findsNothing); // Clássicos tem 2
    await openSettings(tester);
    await tester.tap(find.text('Hinário'));
    await tester.pumpAndSettle();
    expect(store.activeId, 'hinos');
    expect(find.text('em uso · versão 2026.10.04 · 3 hinos'), findsOneWidget);
    await closeSettings(tester);
    expect(find.text('T3'), findsOneWidget); // agora, os 3 hinos
  });

  testWidgets('sem trocar nada, fechar o painel não recarrega', (tester) async {
    var loads = 0;
    tester.view.physicalSize = const Size(760, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          libraryStore: store,
          loadCatalog: () async {
            loads++;
            return const PieceCatalog([]);
          },
          scoreBuilder: (context, o) => const Scaffold(body: Text('x')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);
    await closeSettings(tester);
    expect(loads, 1);
  });

  testWidgets('remover outra que não a em uso, confirmando', (tester) async {
    await pumpLibrary(tester);
    await openSettings(tester);
    await openMenu(tester, 'Hinário');
    await tester.tap(find.text('Remover…'));
    await tester.pumpAndSettle();
    expect(find.text('Remover Hinário?'), findsOneWidget);
    expect(find.textContaining('progresso e seus ajustes'), findsOneWidget);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(store.installed.map((e) => e.id), ['classicos']);
    expect(store.activeId, 'classicos');
    expect(blobs.blobs.keys, ['classicos']);
    expect(find.text('Hinário'), findsNothing);
  });

  testWidgets('cancelar a remoção não apaga', (tester) async {
    await pumpLibrary(tester);
    await openSettings(tester);
    await openMenu(tester, 'Clássicos');
    await tester.tap(find.text('Remover…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(store.installed, hasLength(2));
  });

  testWidgets('remover a em uso passa para a que sobra; a última leva ao '
      'cartão de instalar', (tester) async {
    await pumpLibrary(tester);
    await openSettings(tester);
    await openMenu(tester, 'Clássicos');
    await tester.tap(find.text('Remover…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(store.activeId, 'hinos');
    await openMenu(tester, 'Hinário');
    await tester.tap(find.text('Remover…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(store.installed, isEmpty);
    expect(find.text('Nenhuma biblioteca instalada.'), findsOneWidget);
    await closeSettings(tester);
    expect(find.text('Instale uma biblioteca de músicas'), findsOneWidget);
  });

  testWidgets('o progresso fica ao remover', (tester) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('lib_progress_hinos', '{"1":{"s":80}}');
    await pumpLibrary(tester);
    await openSettings(tester);
    await openMenu(tester, 'Hinário');
    await tester.tap(find.text('Remover…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(await prefs.getString('lib_progress_hinos'), isNotNull);
  });

  testWidgets('instalar outra pelas configurações: vira a em uso', (
    tester,
  ) async {
    await pumpLibrary(tester);
    picked = await keys.package('extra', name: 'Extra', pieces: 4);
    await openSettings(tester);
    await tester.tap(find.text('Instalar outra…'));
    await tester.pumpAndSettle();
    expect(store.activeId, 'extra');
    expect(find.text('Extra'), findsOneWidget);
    expect(find.text('Extra instalada (4 hinos)'), findsOneWidget);
    await closeSettings(tester);
    expect(find.text('T4'), findsOneWidget);
  });

  testWidgets('instalar a mesma pergunta antes de substituir', (tester) async {
    await pumpLibrary(tester);
    picked = await keys.package(
      'hinos',
      name: 'Hinário',
      version: '2026.11.02',
      pieces: 5,
    );
    await openSettings(tester);
    await tester.tap(find.text('Instalar outra…'));
    await tester.pumpAndSettle();
    expect(find.text('Substituir Hinário?'), findsOneWidget);
    await tester.tap(find.text('Substituir'));
    await tester.pumpAndSettle();
    expect(store['hinos']!.version, '2026.11.02');
    expect(store.activeId, 'hinos');
    await closeSettings(tester);
    expect(find.text('T5'), findsOneWidget);
  });

  testWidgets('Sobre esta biblioteca mostra os créditos', (tester) async {
    await pumpLibrary(tester);
    await openSettings(tester);
    await openMenu(tester, 'Hinário');
    await tester.tap(find.text('Sobre esta biblioteca'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Versão 2026.10.04'), findsOneWidget);
    expect(find.textContaining('3 hinos'), findsWidgets);
    expect(find.textContaining('Créditos do teste.'), findsOneWidget);
  });

  testWidgets('em 360 dp a seção não estoura', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          libraryStore: store,
          scoreBuilder: (context, o) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('Instalar outra…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
