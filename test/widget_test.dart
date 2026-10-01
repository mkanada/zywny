// Testes de widget da tela de partitura, sem hino aberto (nada nativo é
// tocado até a biblioteca abrir um — ela tem os testes dela em
// library_test.dart): a tela vazia, e o contrato de que o zoom e o
// painel de opções são camadas sobre a partitura — abrir, mover ou
// usar qualquer um deles não altera a caixa da partitura nem o tamanho de
// página pedido ao Verovio (que só o mudaria por um re-render). O zoom vive
// dentro do painel (não mais flutuando sobre a partitura), então os testes
// que o exercitam abrem o painel primeiro.

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:zywny/main.dart';
import 'package:zywny/ui/phone_chrome.dart';
import 'package:zywny/ui/theme.dart';

/// A tela de partitura sozinha, como a biblioteca a abre, mas sem hino.
Widget _scoreApp() =>
    MaterialApp(theme: buildAppTheme(), home: const ScoreHomePage());

/// `MidiDeviceManager`/`FlutterMidiInputService` (M01) falam com canais de
/// plataforma reais assim que a tela abre (para listar dispositivos e
/// reconectar ao último escolhido) — inexistentes em `flutter test`. Sem
/// isto, o primeiro `pumpWidget` já lançaria antes de
/// qualquer expectativa.
class _NoDevicesMidiCommandPlatform extends MidiCommandPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<MidiDevice>?> get devices async => const <MidiDevice>[];

  @override
  Stream<MidiPacket>? get onMidiDataReceived => null;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => null;
}

void _installFakeMidiAndPreferencesPlatforms() {
  MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
}

/// The score box: the [InteractiveViewer] fills it and nothing else does.
Size _scoreBox(WidgetTester tester) =>
    tester.getSize(find.byType(InteractiveViewer));

/// Page size the panel says the score box asks for ("1250×456 (125×46 mm)").
String _fittedPage(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining(' mm)')).data!;

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Layout deste hino'));
  await tester.pump();
}

/// O app tem dois layouts conforme a largura (`kPhoneLayoutMaxWidth`): o
/// banco de testes largo (desktop) e o de celular em paisagem. O tamanho
/// padrão de `flutter test` (800×600) cairia no de celular.
void _useSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _desktop(WidgetTester tester) => _useSize(tester, const Size(1280, 800));

void _phone(WidgetTester tester) => _useSize(tester, const Size(844, 390));

void main() {
  setUp(_installFakeMidiAndPreferencesPlatforms);

  testWidgets('sem hino, a tela fica vazia e oferece voltar à biblioteca', (
    WidgetTester tester,
  ) async {
    _desktop(tester);
    await tester.pumpWidget(_scoreApp());

    // O app não importa partitura: não há "Abrir partitura" em lugar algum.
    expect(find.text('Abrir partitura'), findsNothing);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('nenhuma partitura'), findsOneWidget);
    expect(find.text('status: nenhuma partitura'), findsOneWidget);
    // Sem documento não há página desenhada.
    expect(find.byType(ScorePageView), findsNothing);
    expect(find.text('—'), findsOneWidget);

    // O painel de opções (que hospeda o zoom) começa fechado.
    expect(find.byTooltip('Layout deste hino'), findsOneWidget);
    expect(find.text('Layout deste hino'), findsNothing);
  });

  testWidgets('o painel mostra a página derivada da caixa da partitura', (
    tester,
  ) async {
    _desktop(tester);
    await tester.pumpWidget(_scoreApp());
    await tester.pump(); // primeiro layout: a caixa passa a ser conhecida
    await _openPanel(tester);

    expect(find.text('Layout deste hino'), findsOneWidget);
    expect(find.text('Página acompanha a área'), findsOneWidget);
    expect(_fittedPage(tester), matches(RegExp(r'^\d+×\d+ \(\d+×\d+ mm\)$')));
  });

  testWidgets('zoom não altera a caixa nem a página pedida ao Verovio', (
    tester,
  ) async {
    _desktop(tester);
    await tester.pumpWidget(_scoreApp());
    await tester.pump();
    await _openPanel(tester);

    final box = _scoreBox(tester);
    final page = _fittedPage(tester);

    await tester.tap(find.byTooltip('Aumentar zoom'));
    await tester.tap(find.byTooltip('Aumentar zoom'));
    await tester.pump();
    expect(find.text('156%'), findsOneWidget); // 1,25²
    expect(_scoreBox(tester), box);
    expect(_fittedPage(tester), page);

    await tester.tap(find.byTooltip('Diminuir zoom'));
    await tester.pump();
    expect(find.text('125%'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar a 100%'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(_scoreBox(tester), box);
    expect(_fittedPage(tester), page);
  });

  testWidgets('abrir e fechar o painel não altera a caixa da partitura', (
    tester,
  ) async {
    _desktop(tester);
    await tester.pumpWidget(_scoreApp());
    await tester.pump();
    final box = _scoreBox(tester);

    await _openPanel(tester);
    expect(_scoreBox(tester), box);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pump();
    expect(find.text('Layout deste hino'), findsNothing);
    expect(_scoreBox(tester), box);
  });

  testWidgets('o zoom não passa dos limites', (tester) async {
    _desktop(tester);
    await tester.pumpWidget(_scoreApp());
    await tester.pump();
    await _openPanel(tester);

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byTooltip('Diminuir zoom'), warnIfMissed: false);
      await tester.pump();
    }
    expect(find.text('50%'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Voltar a 100%'));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byTooltip('Aumentar zoom'), warnIfMissed: false);
      await tester.pump();
    }
    expect(find.text('800%'), findsOneWidget);
  });

  testWidgets('celular: barra lateral e gaveta de opções do artefato', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_scoreApp());
    await tester.pump();

    // Sem partitura: a volta para a biblioteca e a barra lateral já estão lá.
    expect(find.byTooltip('Voltar à biblioteca'), findsOneWidget);
    expect(find.text('andamento'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byTooltip('Mais opções'), findsOneWidget);
    expect(find.text('Opções de estudo'), findsNothing);

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pump();
    expect(find.text('Opções de estudo'), findsOneWidget);
    expect(find.text('MODO'), findsOneWidget);
    expect(find.text('Ouvir'), findsOneWidget);
    expect(find.text('Espera'), findsOneWidget);

    // Espera: uma mão só e andamento 80%, como no artefato (CelularTreino).
    await tester.tap(find.text('Espera'));
    await tester.pump();
    expect(find.text('Conecte o teclado MIDI'), findsOneWidget);
    expect(find.text('80%'), findsWidgets);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pump();
    expect(find.text('Opções de estudo'), findsNothing);
  });

  testWidgets('celular: a faixa do topo mostra o número e o título do hino', (
    tester,
  ) async {
    _phone(tester);
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PhoneTitleBar(
            number: 244,
            title: 'Ó Vem à Igreja Comigo',
            onBack: () => backs++,
            trailing: const [PhoneStatusPill(text: 'Espera · mão dir.')],
          ),
        ),
      ),
    );

    expect(find.text('244'), findsOneWidget);
    expect(find.text('Ó Vem à Igreja Comigo'), findsOneWidget);
    expect(find.text('Espera · mão dir.'), findsOneWidget);
    // Uma faixa baixa: a partitura em paisagem não tem altura sobrando.
    expect(tester.getSize(find.byType(PhoneTitleBar)).height, 40);
    await tester.tap(find.byTooltip('Voltar à biblioteca'));
    expect(backs, 1);

    // Na tela de partitura a faixa fica acima da área da partitura, não
    // por cima dela.
    await tester.pumpWidget(_scoreApp());
    await tester.pump();
    final bar = tester.getRect(find.byType(PhoneTitleBar));
    final rail = tester.getRect(find.byType(PhoneRail));
    expect(bar.top, 0);
    expect(bar.right, rail.left);
  });
}
