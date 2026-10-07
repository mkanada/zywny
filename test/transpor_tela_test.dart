// Transpor — a tela (fase Q, docs/plano/Q08): o item da gaveta, a lista dos
// 12 tons, o selo da partitura, a chave geral, a linha da biblioteca e o
// "Também estudada". A conta (intervalos, TRANSPOSE) é do Q02.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:score_bridge/score_bridge.dart' show ScoreView;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/app/library_screen.dart';
import 'package:zywny_library/piece.dart';
import 'package:zywny_library/piece_progress.dart';
import 'package:zywny/main.dart';
import 'package:zywny_music/tone_choices.dart';
import 'package:zywny_music/transposition.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/settings/piece_settings.dart';
import 'package:zywny/trail/trail_progress.dart';
import 'package:zywny/trail/trail_stage.dart';
import 'package:zywny/ui/theme.dart';
import 'package:zywny/ui/transpose_widgets.dart';

import 'support/score_page_fakes.dart';

class _NoDevicesMidiCommandPlatform extends MidiCommandPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<MidiDevice>?> get devices async => const <MidiDevice>[];

  @override
  Stream<MidiPacket>? get onMidiDataReceived => null;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => null;
}

Piece _piece(int n, {int? fifths}) => Piece(
  number: n,
  title: 'Hino $n',
  composer: 'Fulano',
  fifths: fifths,
  titleKey: 'hino $n',
  composerKey: 'fulano',
  searchKey: 'hino $n fulano',
);

final Transposition _inC = Transposition.parse('-m3')!; // Mi♭ → Dó

void main() {
  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // Com uma trilha montada a tela pode começar a tocar, e o wakelock não
    // tem plugin no teste.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );
  });

  group('os textos', () {
    test('a armadura em poucos caracteres', () {
      expect(keySignatureShort(-3), '3♭');
      expect(keySignatureShort(2), '2♯');
      expect(keySignatureShort(0), '0');
      expect(keySignatureTransposed(-3, _inC), '3♭ → 0');
      expect(keySignatureTransposed(-3, null), '3♭');
    });

    test('os 12 tons, do Dó ao Si, com a armadura e o TRANSPOSE', () {
      final choices = toneChoices(-3, lowest: 40, highest: 80);
      expect(choices, hasLength(12));
      expect(choices.map((c) => c.name), [
        'Dó',
        'Ré♭',
        'Ré',
        'Mi♭',
        'Mi',
        'Fá',
        'Fá♯',
        'Sol',
        'Lá♭',
        'Lá',
        'Si♭',
        'Si',
      ]);
      String label(String name) =>
          choices.singleWhere((c) => c.name == name).label;
      expect(label('Dó'), 'Dó · sem acidentes · teclado +3');
      expect(label('Ré'), 'Ré · 2♯ · teclado +1');
      // A original é a única sem transposição, e vem marcada.
      expect(label('Mi♭'), 'Mi♭ · 3♭ · original');
      expect(choices.where((c) => c.isOriginal).map((c) => c.name), ['Mi♭']);
      // Os 12 são tons diferentes: cada um tem uma armadura só.
      expect(choices.map((c) => c.fifths).toSet(), hasLength(12));
    });

    test('música em Dó: o Dó é a original', () {
      final choices = toneChoices(0, lowest: 40, highest: 80);
      expect(choices.first.label, 'Dó · sem acidentes · original');
      expect(choices.where((c) => c.isOriginal), hasLength(1));
    });

    test('armadura que a lista não traz (7♯) entra no lugar do enarmônico', () {
      final choices = toneChoices(7, lowest: 40, highest: 80);
      expect(choices, hasLength(12));
      expect(choices.singleWhere((c) => c.isOriginal).fifths, 7);
    });

    test('o selo diz o teclado, ou que o app toca no tom original', () {
      expect(
        transposeSealText(-3, _inC, appIsSound: false),
        'Mi♭ → Dó · teclado +3',
      );
      expect(
        transposeSealText(-3, _inC, appIsSound: true),
        'Mi♭ → Dó · o app toca no tom original',
      );
    });

    test('a pergunta de trocar de tom', () {
      expect(
        toneChangeMessage(-3, from: null, to: _inC),
        'Em Dó a trilha começa do zero. A do tom original fica guardada.',
      );
      expect(
        toneChangeMessage(-3, from: _inC, to: null),
        'No tom original a trilha começa do zero. A de Dó fica guardada.',
      );
    });

    test(
      '"também estudada" lista os outros tons e nunca o que está em uso',
      () {
        final tones = [
          (
            transposition: null as Transposition?,
            progress: const TrailProgress(
              n: 5,
              total: 8,
              records: {
                's0': StageRecord(state: StageState.aprovada, best: 90),
                's1': StageRecord(state: StageState.aprovada, best: 90),
                's2': StageRecord(state: StageState.aprovada, best: 90),
              },
            ),
          ),
          (
            transposition: _inC as Transposition?,
            progress: const TrailProgress(
              n: 5,
              total: 8,
              records: {
                's0': StageRecord(state: StageState.aprovada, best: 90),
              },
            ),
          ),
        ];
        expect(
          alsoStudiedText(tones, current: _inC, fifths: -3),
          'Também estudada: original, 3 de 8 etapas',
        );
        expect(
          alsoStudiedText(tones, current: null, fifths: -3),
          'Também estudada: Dó, 1 de 8 etapas',
        );
        expect(alsoStudiedText(const [], current: null, fifths: -3), isNull);
      },
    );
  });

  group('as três escolhas', () {
    Future<List<String>> tap(
      WidgetTester tester, {
      required int fifths,
      TransposeMode mode = TransposeMode.none,
      String? alsoStudied,
      String? tapped,
    }) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: TransposeSection(
              fifths: fifths,
              mode: mode,
              noAccidentals: Transposition.toNoAccidentals(
                fifths,
                lowest: 40,
                highest: 80,
              ),
              currentTone: mode == TransposeMode.none ? null : _inC,
              alsoStudied: alsoStudied,
              onNone: () => calls.add('none'),
              onNoAccidentals: () => calls.add('noAccidentals'),
              onPick: () => calls.add('pick'),
            ),
          ),
        ),
      );
      if (tapped != null) {
        await tester.tap(find.text(tapped));
        await tester.pump();
      }
      return calls;
    }

    testWidgets('armadura com acidentes: Não, Sem acidentes e Escolher…', (
      tester,
    ) async {
      await tap(tester, fifths: -3);
      expect(find.text('TRANSPOR'), findsOneWidget);
      expect(find.text('Não (3♭)'), findsOneWidget);
      expect(find.text('Sem acidentes'), findsOneWidget);
      expect(find.text('teclado +3'), findsOneWidget);
      expect(find.text('Escolher…'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('cada linha chama a sua ação', (tester) async {
      expect(await tap(tester, fifths: -3, tapped: 'Não (3♭)'), ['none']);
      expect(await tap(tester, fifths: -3, tapped: 'Sem acidentes'), [
        'noAccidentals',
      ]);
      expect(await tap(tester, fifths: -3, tapped: 'Escolher…'), ['pick']);
    });

    testWidgets('sem acidentes na armadura só sobra "Escolher…"', (
      tester,
    ) async {
      await tap(tester, fifths: 0);
      expect(find.text('Escolher…'), findsOneWidget);
      expect(find.text('Sem acidentes'), findsNothing);
      expect(find.textContaining('Não ('), findsNothing);
    });

    testWidgets('um tom escolhido aparece em "Escolher…"', (tester) async {
      await tap(tester, fifths: -3, mode: TransposeMode.other);
      expect(find.text('Dó · teclado +3'), findsOneWidget);
    });

    testWidgets('mostra o também estudada', (tester) async {
      await tap(
        tester,
        fifths: -3,
        alsoStudied: 'Também estudada: original, 3 de 8 etapas',
      );
      expect(
        find.text('Também estudada: original, 3 de 8 etapas'),
        findsOneWidget,
      );
    });

    test('qual escolha descreve a transposição em uso', () {
      final none = Transposition.toNoAccidentals(-3, lowest: 40, highest: 80);
      expect(transposeModeOf(null, none), TransposeMode.none);
      expect(transposeModeOf(none, none), TransposeMode.noAccidentals);
      expect(
        transposeModeOf(Transposition.parse('M2'), none),
        TransposeMode.other,
      );
    });
  });

  group('o selo', () {
    testWidgets('mostra o texto e abre a conferência ao tocar', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: TransposeSeal(
              text: 'Mi♭ → Dó · teclado +3',
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('Mi♭ → Dó · teclado +3'), findsOneWidget);
      await tester.tap(find.text('Mi♭ → Dó · teclado +3'));
      expect(taps, 1);
    });

    testWidgets('numa barra estreita corta em vez de estourar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 120,
              child: Row(
                children: [
                  Flexible(
                    child: TransposeSeal(
                      text: 'Mi♭ → Dó · o app toca no tom original',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('na tela da música (celular)', () {
    final settings = <AppSettings>[];
    tearDown(() {
      for (final s in settings) {
        s.dispose();
      }
      settings.clear();
    });

    PieceSettings? saved;

    Future<RecordingRenderer> open(
      WidgetTester tester, {
      int? fifths = -3,
      PieceSettings pieceSettings = const PieceSettings(),
      AppSettings? appSettings,
      TrailProgressStore? trail,
      bool emptyFirst = false,
    }) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      saved = null;
      if (appSettings != null) settings.add(appSettings);
      final renderer = RecordingRenderer();
      if (emptyFirst) renderer.next = renderer.empty;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ScoreHomePage(
            renderer: renderer,
            opened: fakeOpenedPiece(
              piece: _piece(13, fifths: fifths),
              appSettings: appSettings,
              pieceSettings: pieceSettings,
              onPieceSettingsChanged: (s) => saved = s,
              trailProgress: trail,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return renderer;
    }

    Future<void> openDrawer(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('gravura sem páginas mostra o motivo, sem estourar', (
      tester,
    ) async {
      await open(tester, emptyFirst: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(ScoreView), findsNothing);
      expect(find.textContaining('a gravura veio sem páginas'), findsOneWidget);
    });

    testWidgets('regravar sem páginas mantém a partitura anterior', (
      tester,
    ) async {
      final renderer = await open(tester);
      expect(find.byType(ScoreView), findsOneWidget);

      renderer.next = renderer.empty;
      await openDrawer(tester);
      await tester.tap(find.text('Sem acidentes'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(renderer.options.last['transpose'], '-m3');
      expect(find.byType(ScoreView), findsOneWidget);
    });

    testWidgets('a gaveta tem Não, Sem acidentes e Escolher…', (tester) async {
      await open(tester);
      await openDrawer(tester);
      expect(find.text('TRANSPOR'), findsOneWidget);
      expect(find.text('Não (3♭)'), findsOneWidget);
      expect(find.text('Sem acidentes'), findsOneWidget);
      expect(find.text('Escolher…'), findsOneWidget);
    });

    testWidgets('música em Dó: só "Escolher…"; sem armadura: nada', (
      tester,
    ) async {
      await open(tester, fifths: 0);
      await openDrawer(tester);
      expect(find.text('TRANSPOR'), findsOneWidget);
      expect(find.text('Escolher…'), findsOneWidget);
      expect(find.text('Sem acidentes'), findsNothing);
    });

    testWidgets('música sem armadura conhecida não tem o item', (tester) async {
      await open(tester, fifths: null);
      await openDrawer(tester);
      expect(find.text('TRANSPOR'), findsNothing);
    });

    testWidgets('"Sem acidentes" grava em Dó, guarda a escolha e põe o selo; '
        '"Não" volta ao original', (tester) async {
      final renderer = await open(tester);
      expect(find.textContaining('Mi♭ → Dó'), findsNothing);

      await openDrawer(tester);
      await tester.tap(find.text('Sem acidentes'));
      await settle(tester);
      expect(renderer.options.last['transpose'], '-m3');
      expect(saved?.transpose, '-m3');
      expect(find.text('Mi♭ → Dó · teclado +3'), findsOneWidget);
      // A gaveta fecha para a pauta aparecer.
      expect(find.text('Opções de estudo'), findsNothing);

      await openDrawer(tester);
      await tester.tap(find.text('Não (3♭)'));
      await settle(tester);
      expect(renderer.options.last.containsKey('transpose'), isFalse);
      expect(saved?.transpose, kTransposeNone);
      expect(find.textContaining('Mi♭ → Dó'), findsNothing);
    });

    testWidgets('"Escolher…" abre os 12 tons e o escolhido vai ao Verovio', (
      tester,
    ) async {
      final renderer = await open(tester);
      await openDrawer(tester);
      await tester.tap(find.text('Escolher…'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Dó · sem acidentes · teclado +3'), findsOneWidget);
      expect(find.text('Mi♭ · 3♭ · original'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.textContaining('teclado'),
        ),
        findsNWidgets(11),
      );

      await tester.tap(find.text('Ré · 2♯ · teclado +1'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(renderer.options.last['transpose'], '-m2');
      expect(find.text('Mi♭ → Ré · teclado +1'), findsOneWidget);
    });

    testWidgets('a música já guardada em Dó abre com o selo e marcada', (
      tester,
    ) async {
      final renderer = await open(
        tester,
        pieceSettings: const PieceSettings(transpose: '-m3'),
      );
      expect(renderer.options.first['transpose'], '-m3');
      expect(find.text('Mi♭ → Dó · teclado +3'), findsOneWidget);
      await openDrawer(tester);
      // "Sem acidentes" marcado, com o TRANSPOSE ao lado.
      expect(find.text('teclado +3'), findsOneWidget);
    });

    testWidgets('trilha começada: trocar de tom pede confirmação', (
      tester,
    ) async {
      final trail = TrailProgressStore();
      final piece = _piece(13, fifths: -3);
      await tester.runAsync(
        () => trail.save(
          piece.id,
          TrailProgress(
            n: kTrailDefaultMeasures,
            total: 8,
            records: {
              for (var i = 0; i < 3; i++)
                's$i': const StageRecord(state: StageState.aprovada, best: 90),
            },
          ),
        ),
      );
      final renderer = await open(tester, trail: trail);
      final gravacoes = renderer.options.length;

      await openDrawer(tester);
      await tester.tap(find.text('Sem acidentes'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(
          'Em Dó a trilha começa do zero. A do tom original fica '
          'guardada.',
        ),
        findsOneWidget,
      );

      // Cancelar não muda nada.
      await tester.tap(find.text('Cancelar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(renderer.options, hasLength(gravacoes));
      expect(saved, isNull);

      await tester.tap(find.text('Sem acidentes'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Trocar'));
      await settle(tester);
      expect(renderer.options.last['transpose'], '-m3');
      expect(saved?.transpose, '-m3');
    });

    testWidgets('sem trilha começada, trocar de tom não pergunta', (
      tester,
    ) async {
      final renderer = await open(tester);
      await openDrawer(tester);
      await tester.tap(find.text('Sem acidentes'));
      await settle(tester);
      expect(find.text('Trocar de tom?'), findsNothing);
      expect(renderer.options.last['transpose'], '-m3');
    });

    testWidgets(
      'na trilha em Dó, a gaveta diz o que foi estudado no original',
      (tester) async {
        final trail = TrailProgressStore();
        final piece = _piece(13, fifths: -3);
        await tester.runAsync(
          () => trail.save(
            piece.id,
            TrailProgress(
              n: kTrailDefaultMeasures,
              total: 8,
              records: {
                for (var i = 0; i < 3; i++)
                  's$i': const StageRecord(
                    state: StageState.aprovada,
                    best: 90,
                  ),
              },
            ),
          ),
        );
        await open(
          tester,
          pieceSettings: const PieceSettings(transpose: '-m3'),
          trail: trail,
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await settle(tester);
        await openDrawer(tester);
        expect(
          find.textContaining('Também estudada: original, 3 de'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a chave geral aparece nas configurações gerais e grava', (
      tester,
    ) async {
      final app = AppSettings();
      await open(tester, appSettings: app);
      await openDrawer(tester);
      final general = find.text('Configurações gerais');
      await tester.ensureVisible(general);
      await tester.pump();
      await tester.tap(general);
      await tester.pump();

      final tile = find.widgetWithText(
        SwitchListTile,
        'Abrir as músicas já sem acidentes',
      );
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.text('Cada música pode voltar ao original na gaveta'),
        findsOneWidget,
      );
      expect(app.transposeByDefault, isFalse);
      await tester.tap(tile);
      await settle(tester);
      expect(app.transposeByDefault, isTrue);
      expect(find.text('Mi♭ → Dó · teclado +3'), findsOneWidget);
    });
  });

  group('na biblioteca', () {
    testWidgets('a armadura da música transposta aparece como "3♭ → 0"', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = SharedPreferencesAsync();
      final progress = PieceProgressStore(prefs: prefs);
      await progress.load('hinos');
      await progress.markOpened('007', transpose: '-m3');
      final settings = AppSettings();
      addTearDown(settings.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            loadCatalog: () async =>
                PieceCatalog([_piece(7, fifths: -3), _piece(8, fifths: -3)]),
            loadScore: (piece) async => throw UnimplementedError(),
            appSettings: settings,
            progress: progress,
            trailProgress: TrailProgressStore(prefs: prefs),
            scoreBuilder: (context, o) =>
                const Scaffold(body: Text('partitura')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // O 7 está em Dó; o 8, no original.
      expect(find.textContaining('3♭ → 0'), findsOneWidget);
      expect(find.textContaining('3 bemóis'), findsOneWidget);
    });
  });
}
