// A biblioteca de hinos embutidos (lib/library/): ordenação, busca, progresso
// e a tela inicial. Os hinos de verdade ficam em `assets/hinos/`, que não é
// versionado — aqui o catálogo é uma lista pequena e nada vai a disco.

import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:zywny/library/hymn.dart';
import 'package:zywny/library/hymn_progress.dart';
import 'package:zywny/library/library_screen.dart';
import 'package:zywny/library/library_sort.dart';
import 'package:zywny/main.dart';
import 'package:zywny/trail/stage_result.dart';
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

Hymn _hymn(
  int n,
  String title,
  String composer, {
  String? original,
  int? fifths,
}) => Hymn(
  number: n,
  title: title,
  composer: composer,
  originalTitle: original,
  fifths: fifths,
  titleKey: foldForSearch(title),
  composerKey: foldForSearch(composer),
  searchKey: foldForSearch('$n $title ${original ?? ''} $composer'),
);

final _hymns = [
  _hymn(
    1,
    'Santo, Santo, Santo!',
    'John B. Dykes',
    original: 'Holy, Holy',
    fifths: 2,
  ),
  _hymn(12, 'Vinde, Povo do Senhor', 'George J. Elvey', fifths: -1),
  // Sem armadura no índice (antigo): vai para o fim na ordem de acidentes.
  _hymn(120, 'Ao Deus de Abraão Louvai', 'Melodia hebraica'),
  _hymn(244, 'Ó Vem à Igreja Comigo', 'William S. Pitts', fifths: 1),
];

Future<HymnCatalog> _loadCatalog() async => HymnCatalog(_hymns);

List<int> _numbers(Iterable<Hymn> hymns) => [for (final h in hymns) h.number];

void main() {
  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('busca', () {
    test('ignora acento, caixa e pontuação', () {
      expect(_numbers(filterHymns(_hymns, 'abraao')), [120]);
      expect(_numbers(filterHymns(_hymns, 'O VEM A IGREJA')), [244]);
      expect(_numbers(filterHymns(_hymns, 'santo santo')), [1]);
    });

    test('acha por compositor e por título original', () {
      expect(_numbers(filterHymns(_hymns, 'elvey')), [12]);
      expect(_numbers(filterHymns(_hymns, 'holy')), [1]);
    });

    test('só dígitos é o número do hino, pelo começo', () {
      expect(_numbers(filterHymns(_hymns, '12')), [12, 120]);
      expect(_numbers(filterHymns(_hymns, '012')), [12, 120]);
      expect(_numbers(filterHymns(_hymns, '2')), [244]);
    });

    test('vazia devolve tudo', () {
      expect(filterHymns(_hymns, '  ').length, _hymns.length);
    });
  });

  group('ordenação', () {
    test('dificuldade: do mais fácil ao mais difícil, pela nota (não pelo '
        'nível); sem classificação vai para o fim nas duas direções', () {
      Hymn h(int n, {int? level, double? difficulty}) => Hymn(
        number: n,
        title: 'Hino $n',
        composer: '',
        level: level,
        difficulty: difficulty,
        titleKey: 'hino $n',
        composerKey: '',
        searchKey: '$n',
      );
      final hymns = [
        h(1, level: 3, difficulty: 40.5),
        h(2),
        h(3, level: 1, difficulty: 20),
        h(4, level: 3, difficulty: 38.25),
        h(5, level: 5, difficulty: 61),
      ];
      final progress = HymnProgressStore();
      final easyFirst = const SortState().toggled(SortKey.difficulty);
      expect(easyFirst.ascending, isTrue);
      expect(_numbers(sortedHymns(hymns, easyFirst, progress)), [
        3,
        4,
        1,
        5,
        2,
      ]);
      expect(
        _numbers(
          sortedHymns(hymns, easyFirst.toggled(SortKey.difficulty), progress),
        ),
        [5, 1, 4, 3, 2],
      );
    });

    test('índice: nível e dificuldade são opcionais', () {
      final base = {'n': 7, 't': 'T', 'c': 'C', 'k': 't', 'ck': 'c', 'q': '7'};
      final plain = Hymn.fromJson(base);
      expect(plain.level, isNull);
      expect(plain.difficulty, isNull);
      final rated = Hymn.fromJson({...base, 'nv': 2, 'd': 36});
      expect(rated.level, 2);
      expect(rated.difficulty, 36.0);
    });

    test('número, nome e compositor', () {
      final progress = HymnProgressStore();
      expect(_numbers(sortedHymns(_hymns, const SortState(), progress)), [
        1,
        12,
        120,
        244,
      ]);
      expect(
        _numbers(
          sortedHymns(_hymns, const SortState(key: SortKey.title), progress),
        ),
        // "Ó Vem…" entra no O, não depois do Z.
        [120, 244, 1, 12],
      );
      // Acidentes: de poucos a muitos; empate de quantidade, sustenidos
      // antes de bemóis; sem armadura no fim, nas duas direções.
      expect(
        _numbers(
          sortedHymns(
            _hymns,
            const SortState(key: SortKey.accidentals),
            progress,
          ),
        ),
        [244, 12, 1, 120],
      );
      expect(
        _numbers(
          sortedHymns(
            _hymns,
            const SortState(key: SortKey.accidentals, ascending: false),
            progress,
          ),
        ),
        [1, 244, 12, 120],
      );
    });

    test(
      'recentes e pontuação: quem nunca foi estudado vai para o fim',
      () async {
        var now = DateTime(2026, 10, 1, 9);
        final progress = HymnProgressStore(now: () => now);
        await progress.markOpened(120);
        now = DateTime(2026, 10, 1, 10);
        await progress.markOpened(12);
        await progress.recordScore(12, 70);
        await progress.recordScore(120, 90);
        await progress.recordScore(120, 40); // pior que a melhor: não troca

        const recent = SortState(key: SortKey.recent, ascending: false);
        expect(_numbers(sortedHymns(_hymns, recent, progress)), [
          12,
          120,
          1,
          244,
        ]);
        expect(
          _numbers(
            sortedHymns(_hymns, recent.toggled(SortKey.recent), progress),
          ),
          [120, 12, 1, 244],
        );
        expect(
          _numbers(
            sortedHymns(
              _hymns,
              const SortState().toggled(SortKey.score),
              progress,
            ),
          ),
          [120, 12, 1, 244],
        );
        expect(progress[120]!.bestScore, 90);
        expect(progress.lastOpenedNumber, 12);
      },
    );

    test('o progresso sobrevive a fechar o app', () async {
      final prefs = SharedPreferencesAsync();
      final first = HymnProgressStore(prefs: prefs);
      await first.markOpened(244);
      await first.recordScore(244, 81);

      final second = HymnProgressStore(prefs: prefs);
      await second.load();
      expect(second.lastOpenedNumber, 244);
      expect(second[244]!.bestScore, 81);
    });
  });

  test('whenStudied conta em dias de calendário', () {
    final now = DateTime(2026, 10, 1, 8);
    expect(whenStudied(DateTime(2026, 10, 1, 0, 5), now), 'hoje');
    expect(whenStudied(DateTime(2026, 9, 30, 23, 50), now), 'ontem');
    expect(whenStudied(DateTime(2026, 9, 27), now), 'há 4 dias');
    expect(whenStudied(DateTime(2026, 9, 12), now), 'há 3 semanas');
    expect(whenStudied(DateTime(2026, 6, 1), now), 'há 4 meses');
  });

  group('tela', () {
    void phonePortrait(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('o app abre na biblioteca, sem importar partitura', (
      tester,
    ) async {
      phonePortrait(tester);
      await tester.pumpWidget(const MyApp(loadCatalog: _loadCatalog));
      await tester.pump();

      expect(find.text('Hinário'), findsOneWidget);
      expect(find.text('4 hinos'), findsOneWidget);
      expect(find.text('Santo, Santo, Santo!'), findsOneWidget);
      expect(find.text('2 sustenidos'), findsOneWidget);
      expect(find.byTooltip('Conectar teclado MIDI'), findsOneWidget);
      // Nada estudado ainda: sem cartão "Continuar", e nenhuma forma de
      // abrir arquivo.
      expect(find.text('CONTINUAR'), findsNothing);
      expect(find.byTooltip('Abrir arquivo'), findsNothing);
      expect(find.text('Abrir partitura'), findsNothing);
    });

    testWidgets('busca filtra e os chips reordenam', (tester) async {
      phonePortrait(tester);
      await tester.pumpWidget(const MyApp(loadCatalog: _loadCatalog));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'igreja');
      await tester.pump();
      expect(find.text('Ó Vem à Igreja Comigo'), findsOneWidget);
      expect(find.text('Santo, Santo, Santo!'), findsNothing);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump();
      expect(find.text('Nenhum hino com “xyz”.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Número ↑'), findsOneWidget);
      await tester.tap(find.text('Nome'));
      await tester.pump();
      expect(find.text('Nome ↑'), findsOneWidget);
      // Por nome, "Ao Deus…" (120) sobe para antes de "Santo…" (1).
      expect(
        tester.getTopLeft(find.text('Ao Deus de Abraão Louvai')).dy,
        lessThan(tester.getTopLeft(find.text('Santo, Santo, Santo!')).dy),
      );
      await tester.tap(find.text('Nome ↑'));
      await tester.pump();
      expect(find.text('Nome ↓'), findsOneWidget);
    });

    testWidgets('tocar num hino abre a partitura e vira "Continuar"', (
      tester,
    ) async {
      phonePortrait(tester);
      OpenedHymn? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            loadCatalog: _loadCatalog,
            loadScore: (hymn) async => Uint8List(0),
            scoreBuilder: (context, o) {
              opened = o;
              return const Scaffold(body: Text('partitura'));
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Vinde, Povo do Senhor'));
      await tester.pumpAndSettle();
      expect(find.text('partitura'), findsOneWidget);
      expect(opened!.hymn.number, 12);
      expect(opened!.scoreXml, isEmpty);

      // Um treino avaliado terminou com 83% de precisão.
      opened!.onPracticeScore(83);
      Navigator.of(tester.element(find.text('partitura'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('CONTINUAR'), findsOneWidget);
      expect(find.text('Hino 12 · hoje · melhor 83%'), findsOneWidget);
      // Na linha, o compositor e o resto são dois textos; sem a bolinha e o
      // número à direita (U13): a pontuação está escrita "melhor 83%".
      expect(find.text('1 bemol'), findsOneWidget);
      expect(find.text(' · hoje · melhor 83%'), findsOneWidget);
      expect(find.text('83'), findsNothing);
    });
  });

  group('trilha (J09)', () {
    void phonePortrait(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    /// 12 de 51 feitas (10 aprovadas + 2 puladas), parou no trecho 2/4.
    TrailProgress progress12of51() => TrailProgress(
      n: 5,
      total: 51,
      records: {
        for (var i = 0; i < 10; i++)
          's$i': const StageRecord(state: StageState.aprovada, best: 92),
        'p0': const StageRecord(state: StageState.pulada, best: 0),
        'p1': const StageRecord(state: StageState.pulada, best: 0),
      },
      resume: const TrailResume(
        stageId: 's12',
        label: 'Ritmo da esquerda 75%',
        segment: 1,
        segments: 4,
      ),
    );

    Future<Widget> libraryWith(TrailProgressStore trail) async {
      await trail.save(12, progress12of51());
      return MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          loadCatalog: _loadCatalog,
          loadScore: (hymn) async => Uint8List(0),
          trailProgress: trail,
          scoreBuilder: (context, o) => const Scaffold(body: Text('partitura')),
        ),
      );
    }

    testWidgets('linha mostra feitas/total e puladas; sem trilha, como hoje', (
      tester,
    ) async {
      phonePortrait(tester);
      await tester.pumpWidget(await libraryWith(TrailProgressStore()));
      await tester.pump();
      expect(find.textContaining('12/51'), findsOneWidget);
      expect(find.textContaining('2 pul.'), findsOneWidget);
      // O hino sem trilha não mostra nada dela (só compositor).
      expect(find.text('2 sustenidos'), findsOneWidget);
      expect(find.textContaining('12/51'), findsOneWidget);
    });

    testWidgets('final.100 aprovada marca concluído', (tester) async {
      phonePortrait(tester);
      final trail = TrailProgressStore();
      await trail.save(
        12,
        const TrailProgress(
          n: 5,
          total: 51,
          records: {
            'final.100': StageRecord(state: StageState.aprovada, best: 95),
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            loadCatalog: _loadCatalog,
            loadScore: (hymn) async => Uint8List(0),
            trailProgress: trail,
            scoreBuilder: (context, o) =>
                const Scaffold(body: Text('partitura')),
          ),
        ),
      );
      await tester.pump();
      expect(find.byTooltip('Trilha concluída'), findsOneWidget);
    });

    testWidgets('voltar da partitura atualiza a linha sem reabrir', (
      tester,
    ) async {
      phonePortrait(tester);
      final trail = TrailProgressStore();
      await tester.pumpWidget(await libraryWith(trail));
      await tester.pump();
      expect(find.textContaining('12/51'), findsOneWidget);
      // A partitura (mesmo store) grava mais uma etapa: a linha refaz.
      final updated = progress12of51().recordResult(
        's12',
        const StageResult(hits: 9, total: 10, badMeasures: {}),
      );
      await trail.save(12, updated);
      await tester.pump();
      expect(find.textContaining('13/51'), findsOneWidget);
    });

    testWidgets('continuar diz em que etapa parou', (tester) async {
      phonePortrait(tester);
      final trail = TrailProgressStore();
      final progress = HymnProgressStore();
      await progress.markOpened(12);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            loadCatalog: _loadCatalog,
            loadScore: (hymn) async => Uint8List(0),
            progress: progress,
            trailProgress: trail,
            scoreBuilder: (context, o) =>
                const Scaffold(body: Text('partitura')),
          ),
        ),
      );
      await trail.save(12, progress12of51());
      await tester.pump();
      expect(find.text('CONTINUAR'), findsOneWidget);
      expect(
        find.textContaining('Trecho 2/4 · Ritmo da esquerda 75%'),
        findsOneWidget,
      );
    });

    testWidgets('600 hinos abrem sem montar nenhum plano', (tester) async {
      phonePortrait(tester);
      final trail = TrailProgressStore();
      await trail.save(1, progress12of51());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            loadCatalog: () async => HymnCatalog([
              for (var n = 1; n <= 600; n++)
                Hymn(
                  number: n,
                  title: 'Hino $n',
                  composer: 'Autor',
                  titleKey: 'hino $n',
                  composerKey: 'autor',
                  searchKey: 'hino $n',
                ),
            ]),
            loadScore: (hymn) async => Uint8List(0),
            trailProgress: trail,
            scoreBuilder: (context, o) =>
                const Scaffold(body: Text('partitura')),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      // A primeira linha já sai do resumo, sem plano nenhum.
      expect(find.textContaining('12/51'), findsOneWidget);
      // A tela só lê resumos do store: nenhum plano entra aqui.
      final source = File('lib/library/library_screen.dart').readAsStringSync();
      expect(source, isNot(contains('trail_plan')));
      expect(source, isNot(contains('TrailPlan')));
    });
  });
}
