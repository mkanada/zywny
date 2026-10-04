// B04 — a tela de músicas lê a biblioteca em uso (pacote assinado e cifrado),
// guarda o progresso por biblioteca e migra o progresso de antes da fase B.
import 'dart:convert';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/library/legacy_migration.dart';
import 'package:zywny/library/library_blob_store.dart';
import 'package:zywny/library/library_screen.dart';
import 'package:zywny/library/library_store.dart';
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
  setUpAll(() async => keys = await TestKeys.generate());

  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  LibraryStore storeWith(MemoryLibraryBlobStore blobs, {Uint8List? key}) =>
      LibraryStore(
        blobs: blobs,
        prefs: SharedPreferencesAsync(),
        publicKey: key ?? keys.pub,
      );

  Future<void> pump(
    WidgetTester tester,
    LibraryStore store, {
    Widget Function(BuildContext, OpenedPiece)? scoreBuilder,
  }) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          libraryStore: store,
          scoreBuilder:
              scoreBuilder ?? (context, o) => const Scaffold(body: Text('x')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('mostra as músicas da biblioteca em uso e abre a partitura '
      'do pacote', (tester) async {
    final store = storeWith(MemoryLibraryBlobStore());
    await store.load();
    await store.install(await keys.package('hinos', pieces: 3));
    late OpenedPiece opened;
    await pump(
      tester,
      store,
      scoreBuilder: (context, o) {
        opened = o;
        return const Scaffold(body: Text('partitura'));
      },
    );
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('T3'), findsOneWidget);
    await tester.tap(find.text('T2'));
    await tester.pumpAndSettle();
    expect(find.text('partitura'), findsOneWidget);
    expect(opened.piece.id, '2');
    expect(opened.piece.libraryId, 'hinos');
    expect(utf8.decode(opened.scoreXml), '<score-partwise id="2"/>');
  });

  testWidgets('o progresso vai para a chave da biblioteca em uso', (
    tester,
  ) async {
    final store = storeWith(MemoryLibraryBlobStore());
    await store.load();
    await store.install(await keys.package('classicos', pieces: 2));
    await pump(tester, store);
    await tester.tap(find.text('T1'));
    await tester.pumpAndSettle();
    final prefs = SharedPreferencesAsync();
    expect(await prefs.getString('lib_progress_classicos'), contains('"1"'));
    expect(await prefs.getString('lib_progress_hinos'), isNull);
  });

  testWidgets('sem biblioteca: catálogo vazio, sem erro', (tester) async {
    final store = storeWith(MemoryLibraryBlobStore());
    await pump(tester, store);
    expect(find.textContaining('Não consegui abrir'), findsNothing);
    expect(find.text('T1'), findsNothing);
  });

  testWidgets('pacote que não abre (chave errada) é erro, não vazio', (
    tester,
  ) async {
    final blobs = MemoryLibraryBlobStore();
    final installer = storeWith(blobs);
    await installer.load();
    await installer.install(await keys.package('hinos'));
    final other = await TestKeys.generate();
    await pump(tester, storeWith(blobs, key: other.pub));
    expect(find.textContaining('Não consegui abrir'), findsOneWidget);
  });

  test('instalar a biblioteca de hinos migra o progresso de antes', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('hymn_progress', '{"1":{"s":80}}');
    await prefs.setString('trail_1', '{"n":5,"total":4,"records":{}}');
    final store = storeWith(MemoryLibraryBlobStore());
    await store.load();

    // Outra biblioteca antes: não migra.
    await store.install(await keys.package('classicos'));
    expect(await prefs.getString('hymn_progress'), isNotNull);

    await store.install(await keys.package('hinos'));
    expect(await prefs.getString('hymn_progress'), isNull);
    expect(await prefs.getString('lib_progress_hinos'), contains('"001"'));
    expect(await prefs.getString('trail_hinos_001'), isNotNull);
    expect(await prefs.getBool(kLegacyMigratedKey), isTrue);

    // Reinstalar (atualizar) não repete nada.
    await prefs.setString('trail_2', '{}');
    await store.install(await keys.package('hinos', version: '2'));
    expect(await prefs.getString('trail_2'), '{}');
  });
}
