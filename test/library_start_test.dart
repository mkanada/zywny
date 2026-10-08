// U16 — cartão de primeiro uso da biblioteca.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny_library/piece.dart';
import 'package:zywny_library/piece_progress.dart';
import 'package:zywny/app/library_screen.dart';
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

Piece _piece(int n, String title) => Piece(
  number: n,
  title: title,
  composer: 'Autor',
  titleKey: foldForSearch(title),
  composerKey: 'autor',
  searchKey: foldForSearch('$n $title autor'),
);

final _pieces = [
  _piece(1, 'Hino Um'),
  _piece(2, 'Hino Dois'),
  _piece(3, 'Hino Três'),
];

void main() {
  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pumpLibrary(
    WidgetTester tester, {
    PieceProgressStore? progress,
    Size size = const Size(760, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          loadCatalog: () async => PieceCatalog(_pieces),
          loadScore: (piece) async => Uint8List(0),
          progress: progress,
          scoreBuilder: (context, o) => const Scaffold(body: Text('partitura')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('primeiro uso: "COMECE POR AQUI", sem "CONTINUAR"', (
    tester,
  ) async {
    await pumpLibrary(tester);
    expect(find.text('COMECE POR AQUI'), findsOneWidget);
    expect(find.text('CONTINUAR'), findsNothing);
    expect(find.text('Conectar teclado'), findsOneWidget);
    expect(find.text('Ver os mais fáceis'), findsNothing);
  });

  testWidgets('com um hino já aberto o cartão de começo não existe', (
    tester,
  ) async {
    final progress = PieceProgressStore();
    await progress.markOpened('002');
    await pumpLibrary(tester, progress: progress);
    expect(find.text('COMECE POR AQUI'), findsNothing);
    expect(find.text('CONTINUAR'), findsOneWidget);
  });

  testWidgets('em 360 dp o cartão não estoura', (tester) async {
    await pumpLibrary(tester, size: const Size(360, 780));
    expect(find.text('COMECE POR AQUI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
