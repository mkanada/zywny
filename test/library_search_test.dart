// U14 — ordem dos resultados, "por que casou", a seta da ordenação e a busca
// sem resultado.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/library/hymn.dart';
import 'package:zywny/library/library_screen.dart';
import 'package:zywny/library/library_sort.dart';
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
  String? lyricist,
  String? original,
}) => Hymn(
  number: n,
  title: title,
  composer: composer,
  lyricist: lyricist,
  originalTitle: original,
  titleKey: foldForSearch(title),
  composerKey: foldForSearch(composer),
  searchKey: foldForSearch(
    '$n $title ${original ?? ''} $composer ${lyricist ?? ''}',
  ),
);

List<int> _numbers(Iterable<Hymn> hymns) => [for (final h in hymns) h.number];

void main() {
  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('ordem dos resultados', () {
    test(
      'quem tem a palavra no título vem antes de quem a tem só no autor',
      () {
        final hymns = [
          _hymn(1, 'Cristo Vive', 'Jader D. Santos'),
          _hymn(2, 'Santo, Santo, Santo!', 'John B. Dykes'),
          _hymn(3, 'Hino Santo', 'Autor'),
        ];
        // Na ordem dada (por número), o de autor viria primeiro.
        expect(_numbers(filterHymns(hymns, 'santo')), [2, 3, 1]);
      },
    );

    test('a busca só por número não muda', () {
      final hymns = [
        _hymn(12, 'A', 'x'),
        _hymn(120, 'B', 'y'),
        _hymn(2, 'C', 'z'),
      ];
      expect(_numbers(filterHymns(hymns, '12')), [12, 120]);
    });
  });

  group('hymnMatch', () {
    test('acha o trecho no texto original, com acento', () {
      final h = _hymn(120, 'Ao Deus de Abraão Louvai', 'Melodia hebraica');
      final m = hymnMatch(h, 'abraao')!;
      expect(m.title, [(start: 11, end: 17)]);
      expect(m.composer, isEmpty);
      expect(h.title.substring(11, 17), 'Abraão');
    });

    test('com pontuação: todas as ocorrências', () {
      final h = _hymn(1, 'Santo, Santo, Santo!', 'John B. Dykes');
      final m = hymnMatch(h, 'santo santo')!;
      expect(m.title, [
        (start: 0, end: 5),
        (start: 7, end: 12),
        (start: 14, end: 19),
      ]);
    });

    test('casamento só no letrista', () {
      final h = _hymn(
        1,
        'Santo, Santo, Santo!',
        'John B. Dykes',
        lyricist: 'Reginald Heber',
      );
      final m = hymnMatch(h, 'heber')!;
      expect(m.title, isEmpty);
      expect(m.composer, isEmpty);
      expect(m.lyricist, [(start: 9, end: 14)]);
    });

    test('sem busca, ou só número, não há o que negritar', () {
      final h = _hymn(12, 'A', 'x');
      expect(hymnMatch(h, ''), isNull);
      expect(hymnMatch(h, '12'), isNull);
    });
  });

  group('seta da ordenação (D-ORDEM)', () {
    test('mostra a ordem real: ↑ crescente, ↓ decrescente', () {
      final number = const SortState(); // Número começa crescente
      expect(number.arrowFor(SortKey.number), ' ↑');
      expect(number.arrowFor(SortKey.score), '');
      final score = const SortState().toggled(SortKey.score); // decrescente
      expect(score.ascending, isFalse);
      expect(score.arrowFor(SortKey.score), ' ↓');
      expect(score.toggled(SortKey.score).arrowFor(SortKey.score), ' ↑');
    });
  });

  Future<void> pumpLibrary(WidgetTester tester, List<Hymn> hymns) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LibraryScreen(
          loadCatalog: () async => HymnCatalog(hymns),
          loadScore: (hymn) async => Uint8List(0),
          scoreBuilder: (context, o) => const Scaffold(body: Text('partitura')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('casou só no letrista: a segunda linha diz "letra: …"', (
    tester,
  ) async {
    await pumpLibrary(tester, [
      _hymn(
        1,
        'Santo, Santo, Santo!',
        'John B. Dykes',
        lyricist: 'Reginald Heber',
      ),
      _hymn(2, 'Outro Hino', 'Fulano'),
    ]);
    await tester.enterText(find.byType(TextField), 'heber');
    await tester.pump();
    expect(find.textContaining('letra: Reginald Heber'), findsOneWidget);
    expect(find.text('John B. Dykes'), findsNothing);
    expect(find.text('Outro Hino'), findsNothing);
  });

  testWidgets('casou só no título original: "original: …"', (tester) async {
    await pumpLibrary(tester, [
      _hymn(
        1,
        'Santo, Santo, Santo!',
        'John B. Dykes',
        original: 'Holy, Holy, Holy',
      ),
    ]);
    await tester.enterText(find.byType(TextField), 'holy');
    await tester.pump();
    expect(find.textContaining('original: Holy, Holy, Holy'), findsOneWidget);
  });

  testWidgets('sem resultado: "Limpar a busca" esvazia o campo e a lista '
      'volta', (tester) async {
    await pumpLibrary(tester, [
      _hymn(1, 'Santo, Santo, Santo!', 'John B. Dykes'),
      _hymn(2, 'Outro Hino', 'Fulano'),
    ]);
    await tester.enterText(find.byType(TextField), 'chopin');
    await tester.pump();
    expect(find.text('Nenhum hino com “chopin”.'), findsOneWidget);
    await tester.tap(find.text('Limpar a busca'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text('Santo, Santo, Santo!'), findsOneWidget);
    expect(find.text('Outro Hino'), findsOneWidget);
  });

  testWidgets('o "×" do campo limpa a busca', (tester) async {
    await pumpLibrary(tester, [_hymn(1, 'Santo', 'Autor')]);
    expect(find.byTooltip('Limpar a busca'), findsNothing);
    await tester.enterText(find.byType(TextField), 'santo');
    await tester.pump();
    await tester.tap(find.byTooltip('Limpar a busca'));
    await tester.pump();
    expect(find.byTooltip('Limpar a busca'), findsNothing);
  });
}
