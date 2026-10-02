// Configurações: as gerais (lib/settings/app_settings.dart — som, MIDI,
// cores) e as de cada hino (lib/settings/hymn_settings.dart — layout,
// andamento, mão), e os dois painéis que as editam. O contrato principal é a
// persistência: o que foi mudado volta numa nova instância (= o app aberto
// de novo, ou atualizado), e o que foi gravado por outra versão não quebra.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:zywny/layout_options.dart';
import 'package:zywny/library/hymn.dart';
import 'package:zywny/library/library_screen.dart';
import 'package:zywny/main.dart';
import 'package:zywny/practice/hand.dart';
import 'package:zywny/practice/practice_controller.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/settings/general_settings_panel.dart';
import 'package:zywny/settings/hymn_settings.dart';
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

Hymn _hymn(int n, String title) => Hymn(
  number: n,
  title: title,
  composer: 'Autor',
  titleKey: foldForSearch(title),
  composerKey: 'autor',
  searchKey: foldForSearch('$n $title'),
);

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
      expect(first.soundOn, isFalse);

      first
        ..output = SoundOutput.midiKeyboard
        ..useScoreInstruments = true
        ..soundOn = true
        ..metronomeOn = true
        ..practiceMode = PracticeMode.rhythm
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
      expect(second.practiceMode, PracticeMode.rhythm);
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
      expect(HymnSettings.layoutOverrides(values, defaults), {
        'unit': 8.0,
        'breaks': 'line',
      });
      expect(HymnSettings.layoutOverrides(defaults, defaults), isEmpty);
    });

    test('cada hino tem a sua, e ela volta ao abrir o app de novo', () async {
      final first = HymnSettingsStore();
      await first.save(
        12,
        const HymnSettings(
          layout: {'unit': 8.0, 'spacingStaff': 20},
          speed: 0.8,
          hand: Hand.esquerda,
        ),
      );

      final second = HymnSettingsStore();
      final twelve = await second.load(12);
      expect(twelve.layout, {'unit': 8.0, 'spacingStaff': 20});
      expect(twelve.pageFitsBox, isTrue);
      expect(twelve.speed, 0.8);
      expect(twelve.hand, Hand.esquerda);
      expect(twelve.layoutOver(defaults)['unit'], 8.0);
      expect(twelve.layoutOver(defaults)['footer'], defaults['footer']);

      // Outro hino não herda nada.
      final other = await second.load(13);
      expect(other.isDefault, isTrue);
      expect(other.layoutOver(defaults), defaults);
    });

    test('voltar ao padrão apaga a chave do hino', () async {
      final store = HymnSettingsStore();
      await store.save(7, const HymnSettings(layout: {'unit': 6.0}));
      await store.save(7, const HymnSettings());
      expect(
        await SharedPreferencesAsync().getString('hymn_settings_7'),
        isNull,
      );
    });

    test('o que outra versão do app gravou nunca chega torto', () async {
      await SharedPreferencesAsync().setString(
        'hymn_settings_3',
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
      final settings = await HymnSettingsStore().load(3);
      expect(settings.layout, {'unit': 12.0, 'justifyVertically': true});
      expect(settings.speed, kSpeedMax);
      expect(settings.hand, isNull);

      await SharedPreferencesAsync().setString('hymn_settings_4', '{quebrado');
      expect((await HymnSettingsStore().load(4)).isDefault, isTrue);
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

      await tester.tap(find.byTooltip('Layout deste hino'));
      await tester.pump();
      expect(find.text('Layout deste hino'), findsOneWidget);
      expect(find.text('Tamanho da notação (unit)'), findsOneWidget);
      // Nada do que é geral mora aqui.
      expect(find.text('Nota destacada'), findsNothing);
      expect(find.text('Som do app'), findsNothing);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pump();

      await tester.tap(find.byTooltip('Configurações gerais'));
      await tester.pump();
      expect(find.text('Configurações gerais'), findsOneWidget);
      expect(find.text('Som do app'), findsOneWidget);
      expect(find.text('Dispositivo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Nota destacada'),
        200,
        scrollable: find.descendant(
          of: find.byType(GeneralSettingsPanel),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Nota destacada'), findsOneWidget);
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

      await tester.tap(find.text('Teclado MIDI').first); // o segmento da saída
      await tester.pump();
      expect(find.text('Instrumentos da partitura'), findsOneWidget);
      await tester.tap(find.text('Instrumentos da partitura'));
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
      expect(find.text('Layout deste hino (avançado)'), findsOneWidget);
      expect(find.text('GERAL'), findsOneWidget);
      // Som e MIDI saíram da gaveta de estudo: estão no painel geral.
      expect(find.text('Som do app'), findsNothing);
      expect(find.text('SOM E TECLADO'), findsNothing);

      final metronome = find.descendant(
        of: find.widgetWithText(PhoneToggleRow, 'Metrônomo (com som do app)'),
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
      expect(find.text('Som do app'), findsOneWidget);
    });

    testWidgets('a biblioteca abre as configurações gerais e entrega a cada '
        'hino a configuração dele', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      OpenedHymn? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LibraryScreen(
            loadCatalog: () async =>
                HymnCatalog([_hymn(1, 'Primeiro'), _hymn(2, 'Segundo')]),
            extractScore: (hymn) async => '/tmp/${hymn.paddedNumber}.musicxml',
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
      expect(find.text('Monitor MIDI'), findsNothing);
      await tester.tap(find.text('Som do app'));
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
      expect(opened!.appSettings.soundOn, isTrue);
      expect(opened!.hymnSettings.isDefault, isTrue);
      opened!.onHymnSettingsChanged(
        const HymnSettings(layout: {'unit': 7.0}, speed: 0.6),
      );
      await back();

      await open('Segundo');
      expect(opened!.hymnSettings.isDefault, isTrue);
      await back();

      await open('Primeiro');
      expect(opened!.hymnSettings.layout, {'unit': 7.0});
      expect(opened!.hymnSettings.speed, 0.6);
    });
  });
}
