// Q04 — Progresso separado por tom (D-TRP-PROGRESSO): a trilha e a pontuação
// de cada tom são independentes, e o tom original guarda as chaves de antes da
// fase Q.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/library/library_keys.dart';
import 'package:zywny/library/library_screen.dart';
import 'package:zywny/library/library_sort.dart';
import 'package:zywny/library/piece.dart';
import 'package:zywny/library/piece_progress.dart';
import 'package:zywny/music/transposition.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/settings/piece_settings.dart';
import 'package:zywny/trail/trail_progress.dart';
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

final Transposition _inC = Transposition.parse('-m3')!; // Mi♭ → Dó
final Transposition _inA = Transposition.parse('-M2')!; // Si → Lá (outro tom)

TrailProgress _trail(int approved, int total) => TrailProgress(
  n: 5,
  total: total,
  records: {
    for (var i = 0; i < approved; i++)
      's$i': const StageRecord(state: StageState.aprovada, best: 92),
  },
);

Piece _piece(int n, {int? fifths}) => Piece(
  number: n,
  title: 'Hino $n',
  composer: 'Fulano',
  fifths: fifths,
  titleKey: 'hino $n',
  composerKey: 'fulano',
  searchKey: 'hino $n fulano',
);

void main() {
  late SharedPreferencesAsync prefs;
  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  group('progressIdFor', () {
    test('o original é o id da música; um tom acrescenta o intervalo', () {
      expect(progressIdFor('001', null), '001');
      expect(progressIdFor('001', _inC), '001@-m3');
      expect(progressIdFor('op100-2', _inA), 'op100-2@-M2');
    });

    test('a chave antiga continua a do original, sem migração', () {
      expect(
        trailKeyFor('hinos', progressIdFor('001', null)),
        'trail_hinos_001',
      );
      expect(
        trailKeyFor('hinos', progressIdFor('001', _inC)),
        'trail_hinos_001@-m3',
      );
    });

    test('desmonta o id de volta em música e tom', () {
      expect(pieceIdOfProgressId('001@-m3'), '001');
      expect(pieceIdOfProgressId('001'), '001');
      expect(toneOfProgressId('001@-m3'), _inC);
      expect(toneOfProgressId('001'), isNull);
    });
  });

  group('trilha', () {
    test('o original e o tom transposto são trilhas independentes', () async {
      final store = TrailProgressStore(prefs: prefs);
      await store.load(const [], 'hinos');
      await store.save('001', _trail(8, 20));
      await store.save(progressIdFor('001', _inC), _trail(2, 20));

      final again = TrailProgressStore(prefs: prefs);
      await again.load(['001', progressIdFor('001', _inC)], 'hinos');
      expect(again['001'].done, 8);
      expect(again[progressIdFor('001', _inC)].done, 2);

      // Recomeçar a trilha em Dó não mexe na do original.
      await again.reset(progressIdFor('001', _inC));
      expect(again['001'].done, 8);
      expect(again[progressIdFor('001', _inC)], TrailProgress.empty);
      expect(await prefs.getString('trail_hinos_001@-m3'), isNull);
      expect(await prefs.getString('trail_hinos_001'), isNotNull);
    });

    test('lê a chave de antes da fase Q como a trilha do original', () async {
      await prefs.setString(
        'trail_hinos_009',
        jsonEncode(_trail(1, 4).toJson()),
      );
      final store = TrailProgressStore(prefs: prefs);
      final p = await store.ensureLoaded(progressIdFor('009', null));
      expect(p.done, 1);
      expect((await store.ensureLoaded(progressIdFor('009', _inC))).total, 0);
    });

    test('loadMissing lê só os ids que ainda não foram procurados', () async {
      final store = TrailProgressStore(prefs: prefs);
      await store.load(const ['a'], 'lib');
      await prefs.setString(
        'trail_lib_a',
        '{"v":1,"n":5,"total":3,"records":{}}',
      );
      await prefs.setString(
        'trail_lib_b',
        '{"v":1,"n":5,"total":7,"records":{}}',
      );
      await store.loadMissing(const ['a', 'b']);
      expect(store['a'].total, 0); // já procurada: não relê
      expect(store['b'].total, 7);
    });

    test('também estudada: o original e os tons com etapa feita', () async {
      final store = TrailProgressStore(prefs: prefs);
      await store.load(const [], 'hinos');
      await store.save('001', _trail(3, 8));
      await store.save(progressIdFor('001', _inC), _trail(1, 8));
      await store.save(progressIdFor('001', _inA), _trail(0, 8)); // sem etapa
      await store.save('0010', _trail(5, 8)); // outra música, mesmo prefixo
      await store.save(progressIdFor('0010', _inC), _trail(5, 8));

      final tones = await store.studiedTones('001');
      expect(tones.map((t) => t.transposition), [null, _inC]);
      expect(tones.map((t) => t.progress.done), [3, 1]);
      expect(await store.studiedTones('777'), isEmpty);
    });

    test(
      'trocar de tom pede confirmação só se a trilha ficaria para trás',
      () async {
        final store = TrailProgressStore(prefs: prefs);
        await store.load(const [], 'hinos');
        await store.save('001', _trail(3, 8));

        // Em andamento no original, nenhuma em Dó: recomeça.
        expect(await store.toneChangeStartsOver('001', null, _inC), isTrue);
        // O mesmo tom: nada muda.
        expect(await store.toneChangeStartsOver('001', null, null), isFalse);
        // Dó já tem trilha: reencontra, sem perguntar.
        await store.save(progressIdFor('001', _inC), _trail(1, 8));
        expect(await store.toneChangeStartsOver('001', null, _inC), isFalse);
        // Saindo de um tom sem trilha começada: nada a perder.
        expect(await store.toneChangeStartsOver('001', _inA, null), isFalse);
      },
    );
  });

  group('pontuação', () {
    test('cada tom guarda a sua melhor; a abertura é da música', () async {
      final store = PieceProgressStore(
        prefs: prefs,
        now: () => DateTime(2026, 10, 6, 12),
      );
      await store.load('hinos');
      await store.markOpened('001');
      await store.recordScore('001', 70);
      await store.recordScore(progressIdFor('001', _inC), 90);
      await store.recordScore(progressIdFor('001', _inC), 80); // não rebaixa

      expect(store.forTone('001', null)!.bestScore, 70);
      expect(store.forTone('001', _inC)!.bestScore, 90);
      expect(store.forTone('001', _inA)!.bestScore, isNull);
      // "Última aberta" não vê a entrada do tom como música.
      expect(store.lastOpenedId, '001');
      expect(store.forTone('001', _inC)!.lastOpened, DateTime(2026, 10, 6, 12));

      final again = PieceProgressStore(prefs: prefs);
      await again.load('hinos');
      expect(again.forTone('001', _inC)!.bestScore, 90);
      expect(again.lastOpenedId, '001');
    });

    test(
      'pontuar um tom antes de abrir a música não a torna "aberta"',
      () async {
        final store = PieceProgressStore(prefs: prefs);
        await store.load('hinos');
        await store.recordScore(progressIdFor('002', _inC), 60);
        expect(store.lastOpenedId, isNull);
      },
    );

    test(
      'a escolha de transposição da música é guardada com a abertura',
      () async {
        final store = PieceProgressStore(prefs: prefs);
        await store.load('hinos');
        await store.markOpened('001', transpose: '-m3');
        await store.setTranspose('001', kTransposeNone);
        await store.recordScore('001', 50);

        final again = PieceProgressStore(prefs: prefs);
        await again.load('hinos');
        expect(again.transposeChoice('001'), kTransposeNone);
        expect(again.transposeChoice('002'), isNull);
        expect(again['001']!.bestScore, 50);
      },
    );

    test('a ordem por pontuação usa o tom em uso', () async {
      final store = PieceProgressStore(prefs: prefs);
      await store.load('hinos');
      await store.recordScore('001', 95);
      await store.recordScore(progressIdFor('002', _inC), 90);
      final pieces = [_piece(1), _piece(2)];
      const byScore = SortState(key: SortKey.score, ascending: false);

      // Os dois no original: o 1 (95) vence o 2 (sem nota).
      expect(sortedPieces(pieces, byScore, store).map((p) => p.number), [1, 2]);
      // O 2 em Dó: a nota de Dó (90) vale; o 1 segue no original.
      final sorted = sortedPieces(
        pieces,
        byScore,
        store,
        progressOf: (p) => store.forTone(p.id, p.number == 2 ? _inC : null),
      );
      expect(sorted.map((p) => p.number), [1, 2]);
      final byLow = sortedPieces(
        pieces,
        const SortState(key: SortKey.score),
        store,
        progressOf: (p) => store.forTone(p.id, p.number == 2 ? _inC : null),
      );
      expect(byLow.map((p) => p.number), [2, 1]);
    });
  });

  group('biblioteca', () {
    Future<void> pump(
      WidgetTester tester, {
      required AppSettings settings,
      required PieceProgressStore progress,
      required TrailProgressStore trail,
    }) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            loadCatalog: () async => PieceCatalog([_piece(7, fifths: -3)]),
            loadScore: (piece) async => throw UnimplementedError(),
            appSettings: settings,
            progress: progress,
            trailProgress: trail,
            scoreBuilder: (context, o) =>
                const Scaffold(body: Text('partitura')),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
    }

    Future<TrailProgressStore> seededTrail() async {
      final trail = TrailProgressStore(prefs: prefs);
      await trail.save('007', _trail(8, 20));
      await trail.save('007@-m3', _trail(4, 10));
      return trail;
    }

    testWidgets('mostra o progresso do original quando nada transpõe', (
      tester,
    ) async {
      await pump(
        tester,
        settings: AppSettings(),
        progress: PieceProgressStore(prefs: prefs),
        trail: await seededTrail(),
      );
      expect(find.text('8/20'), findsOneWidget);
      expect(find.text('4/10'), findsNothing);
    });

    testWidgets('a chave geral leva a biblioteca ao progresso do tom em Dó', (
      tester,
    ) async {
      final settings = AppSettings()..transposeByDefault = true;
      await pump(
        tester,
        settings: settings,
        progress: PieceProgressStore(prefs: prefs),
        trail: await seededTrail(),
      );
      expect(find.text('4/10'), findsOneWidget);
      expect(find.text('8/20'), findsNothing);
    });

    testWidgets('a escolha "Não" da música vence a chave geral', (
      tester,
    ) async {
      final progress = PieceProgressStore(prefs: prefs);
      await progress.load('hinos');
      await progress.markOpened('007', transpose: kTransposeNone);
      final settings = AppSettings()..transposeByDefault = true;
      await pump(
        tester,
        settings: settings,
        progress: progress,
        trail: await seededTrail(),
      );
      expect(find.text('8/20'), findsOneWidget);
    });

    testWidgets('a escolha de um tom da música mostra a trilha desse tom', (
      tester,
    ) async {
      final progress = PieceProgressStore(prefs: prefs);
      await progress.load('hinos');
      await progress.markOpened('007', transpose: '-m3');
      await pump(
        tester,
        settings: AppSettings(),
        progress: progress,
        trail: await seededTrail(),
      );
      expect(find.text('4/10'), findsOneWidget);
    });
  });
}
