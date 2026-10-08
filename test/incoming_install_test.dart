// B11 — o `.zywny` entregue pelo sistema é instalado pela biblioteca, como se
// tivesse saído do "Abrir arquivo…".
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/app/library_screen.dart';
import 'package:zywny/incoming/incoming_packages.dart';
import 'package:zywny/tutorial/tour.dart';
import 'package:zywny/tutorial/tour_store.dart';
import 'package:zywny/ui/theme.dart';
import 'package:zywny_library/library_blob_store.dart';
import 'package:zywny_library/library_store.dart';

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

IncomingPackage _arrived(String name, Uint8List bytes) =>
    IncomingPackage(name: name, read: () async => bytes);

void main() {
  late TestKeys keys;
  late MemoryLibraryBlobStore blobs;
  late LibraryStore store;
  late IncomingPackages incoming;

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
    incoming = IncomingPackages();
  });

  Future<void> pumpLibrary(
    WidgetTester tester, {
    TourStore? tourStore,
    Duration tourDelay = Duration.zero,
  }) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          libraryStore: store,
          incoming: incoming,
          tourStore: tourStore,
          tourDelay: tourDelay,
          scoreBuilder: (context, o) => const Scaffold(body: Text('x')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('o arquivo que abriu o app instala assim que a biblioteca '
      'aparece', (tester) async {
    // Chegou antes de a tela existir (a abertura a frio).
    incoming.add(
      _arrived(
        'hinos.zywny',
        await keys.package('hinos', name: 'Hinário', pieces: 3),
      ),
    );
    await pumpLibrary(tester);

    expect(find.text('Hinário instalada (3 hinos)'), findsOneWidget);
    expect(store.activeId, 'hinos');
    expect(blobs.blobs.keys, ['hinos']);
    expect(find.text('Instale uma biblioteca de músicas'), findsNothing);
    expect(find.text('T1'), findsOneWidget);
  });

  testWidgets('com o app aberto, o arquivo novo instala na hora', (
    tester,
  ) async {
    await pumpLibrary(tester);
    expect(find.text('Instale uma biblioteca de músicas'), findsOneWidget);

    incoming.add(
      _arrived('classicos.zywny', await keys.package('classicos', pieces: 2)),
    );
    await tester.pumpAndSettle();

    expect(store.activeId, 'classicos');
    expect(find.text('Biblioteca instalada (2 hinos)'), findsOneWidget);
  });

  testWidgets('pacote que já está instalado pergunta antes de substituir', (
    tester,
  ) async {
    await store.load();
    await store.install(
      await keys.package('hinos', name: 'Hinário', version: '1'),
    );
    await pumpLibrary(tester);

    incoming.add(
      _arrived(
        'hinos.zywny',
        await keys.package('hinos', name: 'Hinário', version: '2', pieces: 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Substituir Hinário?'), findsOneWidget);

    await tester.tap(find.text('Substituir'));
    await tester.pumpAndSettle();
    expect(store['hinos']!.version, '2');
    expect(store['hinos']!.pieceCount, 4);
  });

  testWidgets('dois arquivos seguidos: um de cada vez, na ordem', (
    tester,
  ) async {
    await pumpLibrary(tester);
    incoming
      ..add(
        _arrived(
          'a.zywny',
          await keys.package('a', name: 'Primeira', pieces: 1),
        ),
      )
      ..add(
        _arrived(
          'b.zywny',
          await keys.package('b', name: 'Segunda', pieces: 1),
        ),
      );
    await tester.pumpAndSettle();

    expect(store['a'], isNotNull);
    expect(store['b'], isNotNull);
    // A última instalada é a em uso.
    expect(store.activeId, 'b');
  });

  testWidgets('arquivo que não é pacote: o diálogo explica e nada é gravado', (
    tester,
  ) async {
    await pumpLibrary(tester);
    incoming.add(
      _arrived(
        'foto.zywny',
        Uint8List.fromList(utf8.encode('não sou uma biblioteca')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não deu para instalar'), findsOneWidget);
    expect(find.textContaining('não é uma biblioteca do zywny'), findsOne);
    expect(blobs.blobs, isEmpty);
  });

  testWidgets('arquivo que não deu para ler: o diálogo diz qual', (
    tester,
  ) async {
    await pumpLibrary(tester);
    incoming.add(packageThatFailed('hinos.zywny', 'Permission denied'));
    await tester.pumpAndSettle();

    expect(find.text('Não deu para abrir o arquivo'), findsOneWidget);
    expect(
      find.textContaining('Não consegui ler "hinos.zywny": Permission denied'),
      findsOneWidget,
    );
    expect(blobs.blobs, isEmpty);
  });

  testWidgets('estando em outra tela, depois de instalar volta à biblioteca', (
    tester,
  ) async {
    await pumpLibrary(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('outra tela')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('outra tela'), findsOneWidget);

    incoming.add(
      _arrived('hinos.zywny', await keys.package('hinos', name: 'Hinário')),
    );
    await tester.pumpAndSettle();

    expect(find.text('outra tela'), findsNothing);
    expect(find.text('T1'), findsOneWidget);
    expect(store.activeId, 'hinos');
  });

  testWidgets('se o usuário cancela a substituição, fica onde estava', (
    tester,
  ) async {
    await store.load();
    await store.install(await keys.package('hinos', name: 'Hinário'));
    await pumpLibrary(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('outra tela')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    incoming.add(
      _arrived(
        'hinos.zywny',
        await keys.package('hinos', name: 'Hinário', version: '2'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('outra tela'), findsOneWidget);
  });

  testWidgets('sair da biblioteca desliga a escuta: o arquivo seguinte '
      'espera', (tester) async {
    await pumpLibrary(tester);
    await tester.pumpWidget(const SizedBox());
    incoming.add(
      _arrived('hinos.zywny', await keys.package('hinos', name: 'Hinário')),
    );
    expect(incoming.hasWaiting, isTrue);
    expect(blobs.blobs, isEmpty);
  });

  group('com o passeio de primeiro uso', () {
    testWidgets('o passeio espera a instalação e começa depois', (
      tester,
    ) async {
      await store.load();
      await store.install(
        await keys.package('hinos', name: 'Hinário', version: '1'),
      );
      incoming.add(
        _arrived(
          'hinos.zywny',
          await keys.package('hinos', name: 'Hinário', version: '2'),
        ),
      );
      await pumpLibrary(tester, tourStore: TourStore());
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // O diálogo de substituir está de pé e o passeio não passou por cima.
      expect(find.text('Substituir Hinário?'), findsOneWidget);
      expect(find.byType(TourOverlay), findsNothing);

      await tester.tap(find.text('Substituir'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(store['hinos']!.version, '2');
      // Como ainda não tinha sido visto, o passeio começa quando a fila
      // esvazia.
      expect(find.byType(TourOverlay), findsOneWidget);
    });

    testWidgets('arquivo que chega durante a espera do passeio: o passeio '
        'cede a vez', (tester) async {
      await store.load();
      await store.install(
        await keys.package('hinos', name: 'Hinário', version: '1'),
      );
      // No app, o Android copia o arquivo antes de avisar: ele chega depois
      // de o passeio já ter decidido começar.
      await pumpLibrary(
        tester,
        tourStore: TourStore(),
        tourDelay: const Duration(seconds: 2),
      );
      await tester.pump(const Duration(milliseconds: 500));
      incoming.add(
        _arrived(
          'hinos.zywny',
          await keys.package('hinos', name: 'Hinário', version: '2'),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Substituir Hinário?'), findsOneWidget);
      expect(find.byType(TourOverlay), findsNothing);

      await tester.tap(find.text('Substituir'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TourOverlay), findsOneWidget);
    });
  });
}
