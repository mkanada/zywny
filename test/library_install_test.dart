// B05 — tela sem biblioteca e instalar por arquivo.
import 'dart:convert';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny_library/library_blob_store.dart';
import 'package:zywny_library/library_installer.dart';
import 'package:zywny/app/library_screen.dart';
import 'package:zywny_library/library_store.dart';
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

  setUp(() {
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
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(760, 900);
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
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> tapOpenFile(WidgetTester tester) async {
    await tester.tap(find.text('Abrir arquivo…'));
    await tester.pumpAndSettle();
  }

  testWidgets('sem biblioteca: o cartão ensina a instalar, sem busca nem '
      'cartão de primeiro uso', (tester) async {
    await pumpLibrary(tester);
    expect(find.text('Instale uma biblioteca de músicas'), findsOneWidget);
    expect(find.textContaining('.zywny'), findsOneWidget);
    expect(find.text('Abrir arquivo…'), findsOneWidget);
    expect(find.text('COMECE POR AQUI'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    // D-BIB-DIST: nenhuma menção a onde baixar.
    expect(find.textContaining('http'), findsNothing);
    expect(find.textContaining('baixar'), findsNothing);
  });

  testWidgets('em 360 dp o cartão não estoura', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
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
    expect(find.text('Abrir arquivo…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instalar troca o cartão pela lista e avisa', (tester) async {
    await pumpLibrary(tester);
    picked = await keys.package('hinos', name: 'Hinário', pieces: 3);
    await tapOpenFile(tester);

    expect(find.text('Instale uma biblioteca de músicas'), findsNothing);
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('T3'), findsOneWidget);
    expect(find.text('Hinário instalada (3 hinos)'), findsOneWidget);
    expect(store.activeId, 'hinos');
    expect(blobs.blobs.keys, ['hinos']);
  });

  testWidgets('um só item: o aviso usa o singular do termo', (tester) async {
    await pumpLibrary(tester);
    picked = await keys.package('hinos', name: 'Hinário', pieces: 1);
    await tapOpenFile(tester);
    expect(find.text('Hinário instalada (1 hino)'), findsOneWidget);
  });

  testWidgets('cancelar o seletor não faz nada', (tester) async {
    await pumpLibrary(tester);
    await tapOpenFile(tester);
    expect(find.text('Instale uma biblioteca de músicas'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(blobs.blobs, isEmpty);
  });

  group('substituir (D-BIB-ATUALIZAR)', () {
    setUp(() async {
      await store.load();
      await store.install(
        await keys.package('hinos', name: 'Hinário', version: '2026.10.04'),
      );
    });

    testWidgets('mesmo id pergunta, mostrando as duas versões', (tester) async {
      await pumpLibrary(tester);
      // Já há biblioteca: o cartão vazio não existe; instala pelo B06. Aqui,
      // chama o fluxo direto, como as configurações farão.
      picked = await keys.package(
        'hinos',
        name: 'Hinário',
        version: '2026.11.02',
        pieces: 4,
      );
      await tester.pumpWidget(_installerHarness(store, () async => picked));
      await tester.tap(find.text('instalar'));
      await tester.pumpAndSettle();
      expect(find.text('Substituir Hinário?'), findsOneWidget);
      expect(find.textContaining('2026.10.04'), findsOneWidget);
      expect(find.textContaining('2026.11.02'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store['hinos']!.version, '2026.10.04');
      expect(store['hinos']!.pieceCount, 2);
    });

    testWidgets('confirmar substitui', (tester) async {
      picked = await keys.package(
        'hinos',
        name: 'Hinário',
        version: '2026.11.02',
        pieces: 4,
      );
      await tester.pumpWidget(_installerHarness(store, () async => picked));
      await tester.tap(find.text('instalar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Substituir'));
      await tester.pumpAndSettle();
      expect(store['hinos']!.version, '2026.11.02');
      expect(store['hinos']!.pieceCount, 4);
      expect(find.text('Hinário instalada (4 hinos)'), findsOneWidget);
    });

    testWidgets('a versão mais antiga também pergunta', (tester) async {
      picked = await keys.package(
        'hinos',
        name: 'Hinário',
        version: '2020.01.01',
      );
      await tester.pumpWidget(_installerHarness(store, () async => picked));
      await tester.tap(find.text('instalar'));
      await tester.pumpAndSettle();
      expect(find.text('Substituir Hinário?'), findsOneWidget);
      expect(find.textContaining('2020.01.01'), findsOneWidget);
    });

    testWidgets('outro id não pergunta e vira a em uso', (tester) async {
      picked = await keys.package('classicos', name: 'Clássicos', pieces: 5);
      await tester.pumpWidget(_installerHarness(store, () async => picked));
      await tester.tap(find.text('instalar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.activeId, 'classicos');
      expect(find.text('Clássicos instalada (5 hinos)'), findsOneWidget);
    });
  });

  group('erros: nada é gravado', () {
    Future<void> expectError(
      WidgetTester tester,
      Uint8List bytes,
      String message,
    ) async {
      await pumpLibrary(tester);
      picked = bytes;
      await tapOpenFile(tester);
      expect(find.text('Não deu para instalar'), findsOneWidget);
      expect(find.textContaining(message), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(blobs.blobs, isEmpty);
      expect(store.installed, isEmpty);
      expect(find.text('Instale uma biblioteca de músicas'), findsOneWidget);
    }

    testWidgets('um arquivo qualquer (não é zip nem biblioteca)', (
      tester,
    ) async {
      await expectError(
        tester,
        Uint8List.fromList(utf8.encode('não sou uma biblioteca')),
        'não é uma biblioteca do zywny',
      );
    });

    testWidgets('assinado por outra chave', (tester) async {
      final other = await TestKeys.generate();
      await expectError(
        tester,
        await other.package('hinos'),
        'não foi assinada pela chave deste app',
      );
    });

    testWidgets('app sem chave', (tester) async {
      store = LibraryStore(blobs: blobs, prefs: SharedPreferencesAsync());
      await expectError(
        tester,
        await keys.package('hinos'),
        'sem a chave das bibliotecas',
      );
    });
  });
}

/// Um botão que chama o fluxo de instalar, como as configurações (B06) farão.
Widget _installerHarness(
  LibraryStore store,
  Future<Uint8List?> Function() pick,
) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => installLibraryFromFile(context, store, pick: pick),
        child: const Text('instalar'),
      ),
    ),
  ),
);
