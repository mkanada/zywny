// U13 — progresso à vista na biblioteca: a barra e o texto da linha, a
// coluna da direita vazia sem trilha e a gaveta da trilha.
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
import 'package:zywny/trail/trail_progress.dart';
import 'package:zywny/trail/trail_widgets.dart';
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

Piece _piece(int n, String composer, {int? level, int? fifths}) => Piece(
  number: n,
  title: 'Hino $n',
  composer: composer,
  level: level,
  fifths: fifths,
  titleKey: 'hino $n',
  composerKey: foldForSearch(composer),
  searchKey: 'hino $n ${foldForSearch(composer)}',
);

TrailProgress _progress({
  required int approved,
  required int skipped,
  required int total,
  bool finalApproved = false,
}) => TrailProgress(
  n: 5,
  total: total,
  records: {
    for (var i = 0; i < approved; i++)
      's$i': const StageRecord(state: StageState.aprovada, best: 92),
    for (var i = 0; i < skipped; i++)
      'p$i': const StageRecord(state: StageState.pulada, best: 0),
    if (finalApproved)
      'final.100': const StageRecord(state: StageState.aprovada, best: 95),
  },
);

void main() {
  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pumpLibrary(
    WidgetTester tester, {
    required List<Piece> pieces,
    PieceProgressStore? progress,
    TrailProgressStore? trail,
    Size size = const Size(760, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          loadCatalog: () async => PieceCatalog(pieces),
          loadScore: (piece) async => Uint8List(0),
          progress: progress,
          trailProgress: trail,
          scoreBuilder: (context, o) => const Scaffold(body: Text('partitura')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  // Nos testes o texto sai na fonte de quadrados (Ahem, 1 em de largura por
  // letra), muito mais larga que a real: por isso a janela (1000) é maior que
  // os 360 dp do critério — o que se confere é a regra (armadura, resto e
  // progresso inteiros; compositor fora da lista), não os pixels do aparelho.
  testWidgets('a linha mostra a armadura, não o compositor; o resto e o '
      'progresso aparecem inteiros', (tester) async {
    const composer = 'Compositor Com Um Nome Bem Longo X';
    final store = PieceProgressStore();
    await store.markOpened('007');
    await store.recordScore('007', 78);
    final trail = TrailProgressStore();
    await trail.save('007', _progress(approved: 12, skipped: 1, total: 75));
    await pumpLibrary(
      tester,
      pieces: [_piece(7, composer, level: 3, fifths: -3)],
      progress: store,
      trail: trail,
      size: const Size(1000, 900),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('13/75 · 1 pul.'), findsOneWidget);
    expect(find.text('3 bemóis'), findsOneWidget);
    expect(find.textContaining('Compositor'), findsNothing);
    const restText = ' · nível 3 de 5 · hoje · melhor 78%';
    final rest = find.text(restText);
    expect(rest, findsOneWidget);
    final natural = (TextPainter(
      text: const TextSpan(text: restText, style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout()).width;
    expect(tester.getSize(rest).width, closeTo(natural, 1));
  });

  testWidgets('sem armadura no índice a linha não começa com separador', (
    tester,
  ) async {
    await pumpLibrary(tester, pieces: [_piece(9, 'Fulano', level: 2)]);
    expect(find.text('nível 2 de 5'), findsOneWidget);
  });

  testWidgets('hino nunca aberto não tem nada na coluna da direita', (
    tester,
  ) async {
    await pumpLibrary(tester, pieces: [_piece(8, 'Fulano')]);
    expect(find.byType(TrailProgressBar), findsNothing);
    expect(find.text('—'), findsNothing);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('trilha concluída: barra cheia e a marca', (tester) async {
    final trail = TrailProgressStore();
    await trail.save(
      '009',
      _progress(approved: 50, skipped: 0, total: 51, finalApproved: true),
    );
    await pumpLibrary(tester, pieces: [_piece(9, 'Fulano')], trail: trail);
    expect(find.byTooltip('Trilha concluída'), findsOneWidget);
    final bar = tester.widget<TrailProgressBar>(find.byType(TrailProgressBar));
    expect(bar.done, bar.total);
  });

  testWidgets('a barra pinta as fatias com altura e proporção certas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: TrailProgressBar(
              done: 20,
              skipped: 5,
              total: 100,
              width: 200,
            ),
          ),
        ),
      ),
    );
    final boxes = find.descendant(
      of: find.byType(TrailProgressBar),
      matching: find.byType(ColoredBox),
    );
    final accent = boxes
        .evaluate()
        .map((e) => e.widget as ColoredBox)
        .where((w) => w.color == kAccent);
    expect(accent, hasLength(1));
    final size = tester.getSize(find.byWidget(accent.single));
    expect(size.height, 4); // antes: 0 — a barra aparecia vazia
    expect(size.width, closeTo(200 * 15 / 100, 0.5));
  });

  testWidgets('gaveta da trilha: "13 de 75 etapas" e a barra', (tester) async {
    // Os testes do J09 já cobrem a gaveta com plano; aqui só o cabeçalho.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TrailProgressBar(done: 13, skipped: 1, total: 75, width: 200),
              Text(trailProgressText(done: 13, total: 75, skipped: 1)),
            ],
          ),
        ),
      ),
    );
    expect(find.text('13 de 75 etapas · 1 pulada'), findsOneWidget);
    expect(tester.getSize(find.byType(TrailProgressBar)).width, 200);
  });
}
