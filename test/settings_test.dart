// Configurações: as gerais (lib/settings/app_settings.dart — som, MIDI,
// cores) e as de cada hino (lib/settings/piece_settings.dart — layout,
// andamento, mão), e os dois painéis que as editam. O contrato principal é a
// persistência: o que foi mudado volta numa nova instância (= o app aberto
// de novo, ou atualizado), e o que foi gravado por outra versão não quebra.

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:score_bridge/score_bridge.dart' show VsbDocument;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:zywny/render/layout_options.dart';
import 'package:zywny/library/piece.dart';
import 'package:zywny/app/library_screen.dart';
import 'package:zywny/main.dart';
import 'package:zywny/midi/midi_device_manager.dart';
import 'package:zywny/practice/hand.dart';
import 'package:zywny/practice/practice_controller.dart';
import 'package:zywny/render/score_renderer.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/app/general_settings_panel.dart';
import 'package:zywny/settings/piece_settings.dart';
import 'package:zywny/trail/trail_progress.dart';
import 'package:zywny/trail/trail_stage.dart';
import 'package:zywny/ui/phone_chrome.dart';
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

Piece _piece(int n, String title, {int? fifths}) => Piece(
  number: n,
  title: title,
  composer: 'Autor',
  fifths: fifths,
  titleKey: foldForSearch(title),
  composerKey: 'autor',
  searchKey: foldForSearch('$n $title'),
);

/// Guarda as opções de cada gravação pedida e devolve sempre a mesma
/// partitura pronta: o que importa é o que a tela pede ao Verovio.
class _RecordingRenderer implements ScoreRenderer {
  _RecordingRenderer()
    : _document = VsbDocument.fromBytes(
        File('test/fixtures/erik-satie.vsb').readAsBytesSync(),
      );

  final VsbDocument _document;
  final List<Map<String, Object>> options = [];

  @override
  Future<RenderedScore> render(ScoreRenderRequest request) async {
    options.add(request.options);
    return RenderedScore(_document);
  }
}

void main() {
  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('configurações gerais', () {
    test('o que foi mudado volta ao abrir o app de novo', () async {
      final first = AppSettings();
      await first.load();
      expect(first.output, SoundOutput.appSynth);
      expect(first.soundOn, isTrue); // padrão de instalação nova (U04)

      first
        ..output = SoundOutput.midiKeyboard
        ..useScoreInstruments = true
        ..soundOn = true
        ..metronomeOn = true
        ..practiceMode = PracticeMode.realtime
        ..highlightColor = const Color(0xFF00838F)
        ..practicePendingColor = const Color(0xFFF57C00)
        ..practiceWrongColor = const Color(0xFFAD1457)
        ..haloWidth = 2.5
        ..barColor = const Color(0xFF6A1B9A);
      await pumpEventQueue();

      final second = AppSettings();
      await second.load();
      expect(second.output, SoundOutput.midiKeyboard);
      expect(second.useScoreInstruments, isTrue);
      expect(second.soundOn, isTrue);
      expect(second.metronomeOn, isTrue);
      expect(second.practiceMode, PracticeMode.realtime);
      expect(second.highlightColor, const Color(0xFF00838F));
      expect(second.practicePendingColor, const Color(0xFFF57C00));
      expect(second.practiceWrongColor, const Color(0xFFAD1457));
      expect(second.haloWidth, 2.5);
      expect(second.barColor, const Color(0xFF6A1B9A));
    });

    test('lê a saída gravada por versões anteriores e ignora lixo', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setString('sound_output', 'midiKeyboard'); // chave antiga
      await prefs.setString('practice_mode', 'modo-que-nao-existe-mais');
      await prefs.setDouble('ui_halo_width', 99);

      final settings = AppSettings();
      await settings.load();
      expect(settings.output, SoundOutput.midiKeyboard);
      expect(settings.practiceMode, PracticeMode.wait);
      expect(settings.haloWidth, 3.0);
    });

    test('etapas e andamentos da trilha: gravam, voltam e nunca ficam '
        'vazios', () async {
      final first = AppSettings();
      await first.load();
      expect(first.trailPhases, TrailPhase.values.toSet());
      expect(first.trailSpeeds, kTrailSpeeds.toSet());
      first
        ..trailPhases = {TrailPhase.notasJ, TrailPhase.junto}
        ..trailSpeeds = {0.75, 1.0}
        ..trailPhases = {}
        ..trailSpeeds = {};
      await pumpEventQueue();

      final second = AppSettings();
      await second.load();
      expect(second.trailPhases, {TrailPhase.notasJ, TrailPhase.junto});
      expect(second.trailSpeeds, {0.75, 1.0});

      // Ordem: a junto primeiro; as que não vieram completam no fim.
      second.trailPhaseOrder = [TrailPhase.junto, TrailPhase.notasD];
      await pumpEventQueue();
      final third = AppSettings();
      await third.load();
      expect(third.trailPhaseOrder.first, TrailPhase.junto);
      expect(third.trailPhaseOrder.toSet(), TrailPhase.values.toSet());
      expect(third.trailPlanPhases, [TrailPhase.junto, TrailPhase.notasJ]);
    });

    test('margem do tempo: grava, volta e fica entre os limites', () async {
      final first = AppSettings();
      await first.load();
      expect(first.rhythmToleranceMs, 75);
      first.rhythmToleranceMs = 120;
      await pumpEventQueue();
      final second = AppSettings();
      await second.load();
      expect(second.rhythmToleranceMs, 120);
      second.rhythmToleranceMs = 5000;
      expect(second.rhythmToleranceMs, kMaxRhythmToleranceMs);
    });

    test('quem gravou o som desligado continua desligado (U04)', () async {
      await SharedPreferencesAsync().setBool('sound_on', false);
      final settings = AppSettings();
      await settings.load();
      expect(settings.soundOn, isFalse);
    });

    test('"abrir sem acidentes" (fase Q): desligado, grava e volta', () async {
      final first = AppSettings();
      await first.load();
      expect(first.transposeByDefault, isFalse);
      first.transposeByDefault = true;
      await pumpEventQueue();
      expect(
        await SharedPreferencesAsync().getBool('score_transpose_default'),
        isTrue,
      );

      final second = AppSettings();
      await second.load();
      expect(second.transposeByDefault, isTrue);
      second.transposeByDefault = false;
      await pumpEventQueue();
      final third = AppSettings();
      await third.load();
      expect(third.transposeByDefault, isFalse);
    });

    test('avisa quem escuta só quando o valor muda', () {
      final settings = AppSettings();
      var calls = 0;
      settings.addListener(() => calls++);
      settings.metronomeOn = true;
      settings.metronomeOn = true;
      expect(calls, 1);
    });
  });

  group('configurações de um hino', () {
    final defaults = initialLayoutValues(phone: true);

    test('guarda só o que saiu do padrão', () {
      final values = {...defaults, 'unit': 8.0, 'breaks': 'line'};
      expect(PieceSettings.layoutOverrides(values, defaults), {
        'unit': 8.0,
        'breaks': 'line',
      });
      expect(PieceSettings.layoutOverrides(defaults, defaults), isEmpty);
    });

    test('cada hino tem a sua, e ela volta ao abrir o app de novo', () async {
      final first = PieceSettingsStore();
      await first.save(
        'hinos',
        '012',
        const PieceSettings(
          layout: {'unit': 8.0, 'spacingStaff': 20},
          speed: 0.8,
          hand: Hand.esquerda,
        ),
      );

      final second = PieceSettingsStore();
      final twelve = await second.load('hinos', '012');
      expect(twelve.layout, {'unit': 8.0, 'spacingStaff': 20});
      expect(twelve.pageFitsBox, isTrue);
      expect(twelve.speed, 0.8);
      expect(twelve.hand, Hand.esquerda);
      expect(twelve.layoutOver(defaults)['unit'], 8.0);
      expect(twelve.layoutOver(defaults)['footer'], defaults['footer']);

      // Outro hino não herda nada.
      final other = await second.load('hinos', '013');
      expect(other.isDefault, isTrue);
      expect(other.layoutOver(defaults), defaults);
    });

    test('voltar ao padrão apaga a chave do hino', () async {
      final store = PieceSettingsStore();
      await store.save(
        'hinos',
        '007',
        const PieceSettings(layout: {'unit': 6.0}),
      );
      await store.save('hinos', '007', const PieceSettings());
      expect(
        await SharedPreferencesAsync().getString('piece_settings_hinos_007'),
        isNull,
      );
    });

    test('transpor (fase Q): três estados que voltam ao abrir o app de novo', () async {
      final store = PieceSettingsStore();
      // Sem escolha: não ocupa chave e segue a chave geral.
      expect(const PieceSettings().transpose, isNull);
      expect(const PieceSettings().toJson().containsKey('tr'), isFalse);

      await store.save('hinos', '013', const PieceSettings(transpose: '-m3'));
      await store.save(
        'hinos',
        '014',
        const PieceSettings(transpose: kTransposeNone),
      );
      const withIt = PieceSettings(transpose: '-m3');
      expect(withIt.isDefault, isFalse);
      expect(withIt.toJson()['tr'], '-m3');

      final again = PieceSettingsStore();
      expect((await again.load('hinos', '013')).transpose, '-m3');
      // "Não": a escolha existe (vence a chave geral), então a chave é gravada.
      final none = await again.load('hinos', '014');
      expect(none.transpose, kTransposeNone);
      expect(none.isDefault, isFalse);
      expect(kTransposeNone, 'P1');
      expect((await again.load('hinos', '015')).transpose, isNull);

      // Tirar a escolha de um hino que só tinha ela apaga a chave.
      await store.save('hinos', '013', const PieceSettings());
      expect(
        await SharedPreferencesAsync().getString('piece_settings_hinos_013'),
        isNull,
      );
    });

    test('transpor: o que não é "P1" nem um intervalo é descartado', () {
      PieceSettings read(Object? tr) => PieceSettings.fromJson({'tr': tr});
      expect(read('-m3').transpose, '-m3');
      expect(read('P1').transpose, 'P1');
      expect(read('+p4').transpose, 'P4', reason: 'guarda o texto canônico');
      expect(read('-P1').transpose, isNull, reason: 'não transpõe');
      for (final junk in ['', 'P3', 'm4', 'P8', 'C', 'tom', 'm3 ', 7, true]) {
        expect(read(junk).transpose, isNull, reason: '$junk');
      }
      expect(PieceSettings.fromJson({}).transpose, isNull);
    });

    test('o que outra versão do app gravou nunca chega torto', () async {
      await SharedPreferencesAsync().setString(
        'piece_settings_hinos_003',
        jsonEncode({
          'v': 9,
          'layout': {
            'unit': 400, // fora da faixa: vem para o máximo
            'spacingStaff': 'doze', // tipo errado: descartado
            'breaks': 'opcao-removida', // escolha que não existe: descartada
            'opcaoQueSaiuDoApp': 1, // desconhecida: descartada
            'justifyVertically': true,
          },
          'speed': 7,
          'hand': 'terceira',
          'campoNovo': {'x': 1},
        }),
      );
      final settings = await PieceSettingsStore().load('hinos', '003');
      expect(settings.layout, {'unit': 12.0, 'justifyVertically': true});
      expect(settings.speed, kSpeedMax);
      expect(settings.hand, isNull);

      await SharedPreferencesAsync().setString(
        'piece_settings_hinos_004',
        '{quebrado',
      );
      expect(
        (await PieceSettingsStore().load('hinos', '004')).isDefault,
        isTrue,
      );
    });
  });

  group('transpor (fase Q): o que o hino pede ao Verovio', () {
    final settings = <AppSettings>[];
    tearDown(() {
      for (final s in settings) {
        s.dispose();
      }
      settings.clear();
    });

    /// Abre a tela de um hino em 3♭ e espera a primeira gravação.
    Future<_RecordingRenderer> open(
      WidgetTester tester, {
      PieceSettings pieceSettings = const PieceSettings(),
      AppSettings? appSettings,
      int? fifths = -3,
    }) async {
      final app = appSettings ?? AppSettings();
      settings.add(app);
      final renderer = _RecordingRenderer();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ScoreHomePage(
            renderer: renderer,
            opened: OpenedPiece(
              piece: _piece(13, 'Hino', fifths: fifths),
              scoreXml: Uint8List(1),
              midiDeviceManager: MidiDeviceManager(),
              onPracticeScore: (_, _) {},
              appSettings: app,
              pieceSettings: pieceSettings,
              onPieceSettingsChanged: (_) {},
              trailProgress: TrailProgressStore(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return renderer;
    }

    testWidgets('sem transposição nenhuma opção nova vai ao Verovio', (
      tester,
    ) async {
      final renderer = await open(tester);
      expect(renderer.options, hasLength(1));
      expect(renderer.options.single.containsKey('transpose'), isFalse);
    });

    testWidgets('a chave geral manda o hino em 3♭ para Dó (-m3)', (
      tester,
    ) async {
      final renderer = await open(
        tester,
        appSettings: AppSettings()..transposeByDefault = true,
      );
      expect(renderer.options, hasLength(1));
      expect(renderer.options.single['transpose'], '-m3');
    });

    testWidgets('hino sem armadura no catálogo: a chave geral não age', (
      tester,
    ) async {
      final renderer = await open(
        tester,
        fifths: null,
        appSettings: AppSettings()..transposeByDefault = true,
      );
      expect(renderer.options.single.containsKey('transpose'), isFalse);
    });

    testWidgets('"Não" na música vence a chave geral', (tester) async {
      final renderer = await open(
        tester,
        pieceSettings: const PieceSettings(transpose: kTransposeNone),
        appSettings: AppSettings()..transposeByDefault = true,
      );
      expect(renderer.options.single.containsKey('transpose'), isFalse);
    });

    testWidgets('o intervalo escolhido na música vale sem a chave geral', (
      tester,
    ) async {
      final renderer = await open(
        tester,
        pieceSettings: const PieceSettings(transpose: 'M2'),
      );
      expect(renderer.options.single['transpose'], 'M2');
    });

    testWidgets('ligar e desligar a chave geral regrava o hino aberto', (
      tester,
    ) async {
      final app = AppSettings();
      final renderer = await open(tester, appSettings: app);
      expect(renderer.options, hasLength(1));

      app.transposeByDefault = true;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(renderer.options, hasLength(2));
      expect(renderer.options.last['transpose'], '-m3');

      // Uma mudança que não é da transposição não regrava.
      app.haloWidth = 2;
      await tester.pump(const Duration(milliseconds: 100));
      expect(renderer.options, hasLength(2));

      app.transposeByDefault = false;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(renderer.options, hasLength(3));
      expect(renderer.options.last.containsKey('transpose'), isFalse);
    });
  });

  group('painéis', () {
    void desktop(WidgetTester tester) {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('geral e do hino são painéis separados', (tester) async {
      desktop(tester);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const ScoreHomePage()),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Ajustes da partitura'));
      await tester.pump();
      expect(find.text('Ajustes da partitura'), findsOneWidget);
      expect(find.text('Tamanho da notação (unit)'), findsOneWidget);
      // Nada do que é geral mora aqui.
      expect(find.text('Nota certa'), findsNothing);
      expect(find.text('o app toca a música'), findsNothing);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pump();

      await tester.tap(find.byTooltip('Configurações gerais'));
      await tester.pump();
      expect(find.text('Configurações gerais'), findsOneWidget);
      expect(find.text('o app toca a música'), findsOneWidget);
      // Um nome só para o teclado, no cabeçalho e na linha (U15).
      expect(find.text('Teclado MIDI'), findsWidgets);
      expect(find.text('Dispositivo'), findsNothing);
      expect(find.text('Conectar'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Nota certa'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(GeneralSettingsPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Nota certa'), findsOneWidget);
      // E nada do que é de um hino.
      expect(find.text('Tamanho da notação (unit)'), findsNothing);
      expect(find.text('Página acompanha a área'), findsNothing);
    });

    testWidgets('mudar no painel geral grava na hora', (tester) async {
      desktop(tester);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const ScoreHomePage()),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Configurações gerais'));
      await tester.pump();

      await tester.tap(find.text('Teclado').first); // o segmento da saída
      await tester.pump();
      expect(find.text('Trocar o timbre do teclado'), findsOneWidget);
      await tester.tap(find.text('Trocar o timbre do teclado'));
      await tester.pump();

      final reopened = AppSettings();
      await tester.runAsync(reopened.load);
      expect(reopened.output, SoundOutput.midiKeyboard);
      expect(reopened.useScoreInstruments, isTrue);
    });

    testWidgets('celular: a gaveta separa "este hino" de "geral", e o que é '
        'geral grava', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const ScoreHomePage()),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pump();

      expect(find.text('ESTE HINO'), findsOneWidget);
      expect(find.text('TAMANHO DA NOTAÇÃO'), findsOneWidget);
      expect(find.text('Ajustes da partitura (avançado)'), findsOneWidget);
      expect(find.text('GERAL'), findsOneWidget);
      // Som e MIDI saíram da gaveta de estudo: estão no painel geral.
      expect(find.text('o app toca a música'), findsNothing);
      expect(find.text('SOM E TECLADO'), findsNothing);

      final metronome = find.descendant(
        of: find.widgetWithText(PhoneToggleRow, 'Metrônomo (com som)'),
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(metronome);
      await tester.pump();
      await tester.tap(metronome);
      await tester.pump();
      final reopened = AppSettings();
      await tester.runAsync(reopened.load);
      expect(reopened.metronomeOn, isTrue);

      final general = find.text('Configurações gerais');
      await tester.ensureVisible(general);
      await tester.pump();
      await tester.tap(general);
      await tester.pump();
      expect(find.text('Opções de estudo'), findsNothing);
      expect(find.text('valem para todos os hinos'), findsOneWidget);
      expect(find.text('o app toca a música'), findsOneWidget);
    });

    testWidgets('a biblioteca abre as configurações gerais e entrega a cada '
        'hino a configuração dele', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      OpenedPiece? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            loadCatalog: () async =>
                PieceCatalog([_piece(1, 'Primeiro'), _piece(2, 'Segundo')]),
            loadScore: (piece) async => Uint8List(0),
            scoreBuilder: (context, o) {
              opened = o;
              return const Scaffold(body: Text('partitura'));
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Configurações gerais'));
      await tester.pumpAndSettle();
      expect(find.text('valem para todos os hinos'), findsOneWidget);
      // Sem partitura aberta não há monitor nem calibração a oferecer.
      expect(find.text('Ouvir o que eu toco pelo celular'), findsNothing);
      await tester.tap(find.text('o app toca a música'));
      await tester.pump();
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      Future<void> open(String title) async {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }

      Future<void> back() async {
        Navigator.of(tester.element(find.text('partitura'))).pop();
        await tester.pumpAndSettle();
      }

      await open('Primeiro');
      // O hino recebe as mesmas configurações gerais que a biblioteca editou.
      // (O som nasce ligado, U04: o toque em "Som" o desligou.)
      expect(opened!.appSettings.soundOn, isFalse);
      expect(opened!.pieceSettings.isDefault, isTrue);
      opened!.onPieceSettingsChanged(
        const PieceSettings(layout: {'unit': 7.0}, speed: 0.6),
      );
      await back();

      await open('Segundo');
      expect(opened!.pieceSettings.isDefault, isTrue);
      await back();

      await open('Primeiro');
      expect(opened!.pieceSettings.layout, {'unit': 7.0});
      expect(opened!.pieceSettings.speed, 0.6);
    });
  });
}
