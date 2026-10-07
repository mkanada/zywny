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

Piece _piece(int n, String title, {double? difficulty, int? level}) => Piece(
  number: n,
  title: title,
  composer: 'Autor',
  level: level,
  difficulty: difficulty,
  titleKey: foldForSearch(title),
  composerKey: 'autor',
  searchKey: foldForSearch('$n $title autor'),
);

// Na ordem do número, o mais difícil vem primeiro: ordenar por dificuldade
// muda o hino do topo.
final _pieces = [
  _piece(1, 'Hino Difícil', difficulty: 60, level: 5),
  _piece(2, 'Hino Médio', difficulty: 40, level: 3),
  _piece(3, 'Hino Fácil', difficulty: 20, level: 1),
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
    expect(find.text('Ver os mais fáceis'), findsOneWidget);
    expect(find.text('Conectar teclado'), findsOneWidget);
  });

  testWidgets('"Ver os mais fáceis" ordena por dificuldade, o mais fácil no '
      'topo', (tester) async {
    await pumpLibrary(tester);
    // Por número, o "Difícil" (1) vem antes do "Fácil" (3).
    expect(
      tester.getTopLeft(find.text('Hino Difícil')).dy,
      lessThan(tester.getTopLeft(find.text('Hino Fácil')).dy),
    );
    await tester.tap(find.text('Ver os mais fáceis'));
    await tester.pumpAndSettle();
    expect(find.text('Dificuldade ↑'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Hino Fácil')).dy,
      lessThan(tester.getTopLeft(find.text('Hino Difícil')).dy),
    );
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

  testWidgets('a linha diz a escala: "nível 1 de 5"', (tester) async {
    await pumpLibrary(tester);
    expect(find.textContaining('nível 1 de 5'), findsOneWidget);
  });

  testWidgets('em 360 dp o cartão não estoura', (tester) async {
    await pumpLibrary(tester, size: const Size(360, 780));
    expect(find.text('COMECE POR AQUI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
