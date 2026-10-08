// O tutorial da tela da partitura (celular): começa na primeira música
// aberta, aponta os botões da barra lateral e do título, e não volta depois
// de visto. A trilha na barra do título depende de uma música com áudio de
// verdade; esse passo é conferido no aparelho.

import 'package:flutter/material.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:score_bridge/score_bridge.dart' show ScorePageView;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/app/general_settings_panel.dart';
import 'package:zywny/main.dart';
import 'package:zywny/trail/trail_widgets.dart' show TrailTitleChip;
import 'package:zywny/tutorial/tour.dart';
import 'package:zywny/tutorial/tour_store.dart';
import 'package:zywny/ui/phone_chrome.dart';
import 'package:zywny/ui/theme.dart';

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

/// A lista do painel de configurações (a primeira área rolável dele; mais
/// abaixo há outras, aninhadas).
Finder _panelScrollable() => find
    .descendant(
      of: find.byType(GeneralSettingsPanel),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  setUp(() {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget scoreApp(TourStore? store) => MaterialApp(
    theme: buildAppTheme(),
    home: ScoreHomePage(
      renderer: RecordingRenderer(),
      tourStore: store,
      opened: fakeOpenedPiece(
        piece: fakePiece(number: 244, title: 'Ó Vem à Igreja Comigo'),
      ),
    ),
  );

  bool touring(WidgetTester tester) =>
      find.byType(TourOverlay).evaluate().isNotEmpty;

  /// Deixa a partitura gravar e o passeio aparecer (ou não).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30 && !touring(tester); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Depois de um toque: a transição (180 ms) e o quadro que tira a rota da
  /// árvore. `pumpAndSettle` não serve aqui: a partitura anima sempre. Um
  /// `pump` grande só dá a largada à animação naquele quadro; o seguinte a
  /// termina.
  Future<void> afterTap(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(kTourTitleKey)).data!;

  Rect? holeOf(WidgetTester tester) =>
      (tester.widget<CustomPaint>(find.byKey(kTourScrimKey)).painter!
              as TourScrimPainter)
          .hole;

  Rect card(WidgetTester tester) => tester.getRect(
    find
        .ancestor(
          of: find.byKey(kTourTitleKey),
          matching: find.byType(Material),
        )
        .first,
  );

  Future<void> next(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(TourOverlay),
        matching: find.byType(FilledButton),
      ),
    );
    await afterTap(tester);
  }

  testWidgets('a primeira música aberta mostra o passeio, botão por botão', (
    tester,
  ) async {
    useSize(tester, const Size(844, 390));
    // A fonte de teste (Ahem) é o dobro de larga da real, e o texto ocuparia
    // o dobro de linhas: a escala menor devolve ao cartão a altura que ele
    // tem no aparelho, que é o que importa para saber onde ele cabe.
    tester.platformDispatcher.textScaleFactorTestValue = 0.55;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = TourStore();
    await tester.pumpWidget(scoreApp(store));
    await settle(tester);
    expect(touring(tester), isTrue);

    /// O que cada passo deve cercar, lido na tela durante o próprio passo
    /// (depois do passeio a tela muda). Na trilha, o botão do ouvido e as
    /// etapas de andamento e mão têm outros rótulos.
    final targets = <String, List<Finder>>{
      'Voltar': [find.widgetWithIcon(IconButton, Icons.arrow_back)],
      'A trilha': [find.byType(TrailTitleChip)],
      'Som': [find.byType(PhoneSoundButton)],
      'Treinar': [
        find
            .descendant(
              of: find.byType(PhoneRail),
              matching: find.byType(IconButton),
            )
            .first,
        find.widgetWithIcon(IconButton, Icons.hearing),
      ],
      'Reiniciar e compasso': [
        find.widgetWithIcon(IconButton, Icons.skip_previous),
        find.byTooltip('Ir para compasso'),
      ],
      'Andamento e mão': [find.byTooltip(RegExp(r'^(Andamento|Mão)'))],
      'Mais opções': [find.widgetWithIcon(IconButton, Icons.more_horiz)],
    };

    final seen = <String>[];
    while (touring(tester)) {
      final name = title(tester);
      seen.add(name);
      expect(tester.takeException(), isNull, reason: name);
      final hole = holeOf(tester);
      if (name == 'A partitura') {
        // A partitura inteira é o alvo do primeiro passo.
        final page = tester.getRect(find.byType(ScorePageView).first);
        expect(hole!.contains(page.center), isTrue, reason: name);
      } else if (targets.containsKey(name)) {
        final rects = [
          for (final finder in targets[name]!)
            for (final element in finder.evaluate())
              tester.getRect(find.byWidget(element.widget)),
        ];
        expect(rects, isNotEmpty, reason: name);
        final expected = rects.reduce((a, b) => a.expandToInclude(b));
        expect(hole, expected, reason: 'o recorte de "$name"');
        // O cartão nunca esconde o botão que explica.
        expect(
          card(tester).overlaps(hole!),
          isFalse,
          reason: 'o cartão de "$name" (${card(tester)}) cobre $hole',
        );
      } else {
        expect(hole, isNull, reason: 'o último passo não recorta nada');
      }
      await next(tester);
    }

    expect(seen, [
      'A partitura',
      'Voltar',
      'A trilha',
      'Som',
      'Treinar',
      'Reiniciar e compasso',
      'Andamento e mão',
      'Mais opções',
      'Bom estudo!',
    ]);
    expect(await store.seen(TourId.score), isTrue);
  });

  testWidgets('visto uma vez, não volta ao abrir outra música', (tester) async {
    useSize(tester, const Size(844, 390));
    final store = TourStore();
    await store.markSeen(TourId.score);
    await tester.pumpWidget(scoreApp(store));
    await settle(tester);
    expect(touring(tester), isFalse);
  });

  testWidgets('pular na primeira vez também vale como visto', (tester) async {
    useSize(tester, const Size(844, 390));
    final store = TourStore();
    await tester.pumpWidget(scoreApp(store));
    await settle(tester);
    await tester.tap(find.text('Pular'));
    await afterTap(tester);
    expect(touring(tester), isFalse);
    expect(await store.seen(TourId.score), isTrue);
  });

  testWidgets('sem registro do tutorial (os testes), não aparece', (
    tester,
  ) async {
    useSize(tester, const Size(844, 390));
    await tester.pumpWidget(scoreApp(null));
    await settle(tester);
    expect(touring(tester), isFalse);
  });

  testWidgets('na janela larga do desktop, o passeio da partitura não roda', (
    tester,
  ) async {
    useSize(tester, const Size(1280, 800));
    final store = TourStore();
    await tester.pumpWidget(scoreApp(store));
    await settle(tester);
    expect(touring(tester), isFalse);
    expect(await store.seen(TourId.score), isFalse);
  });

  testWidgets('"Rever o tutorial" nas configurações volta ao passeio', (
    tester,
  ) async {
    useSize(tester, const Size(844, 390));
    final store = TourStore();
    await store.markSeen(TourId.score);
    await tester.pumpWidget(scoreApp(store));
    await settle(tester);
    expect(touring(tester), isFalse);

    await tester.tap(find.byTooltip('Mais opções'));
    await afterTap(tester);
    await tester.scrollUntilVisible(
      find.text('Configurações gerais'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Configurações gerais'));
    await afterTap(tester);
    await tester.scrollUntilVisible(
      find.text('Rever o tutorial'),
      300,
      scrollable: _panelScrollable(),
    );
    await tester.tap(find.text('Rever o tutorial'));
    await settle(tester);

    expect(touring(tester), isTrue);
    expect(title(tester), 'A partitura');
    // O painel das configurações fechou: o passeio não fica por cima dele.
    expect(find.text('Rever o tutorial'), findsNothing);
  });

  testWidgets('em celular pequeno em pé (360 dp) também não estoura', (
    tester,
  ) async {
    useSize(tester, const Size(360, 640));
    await tester.pumpWidget(scoreApp(TourStore()));
    await settle(tester);
    var guard = 0;
    while (touring(tester) && guard++ < 20) {
      expect(tester.takeException(), isNull, reason: title(tester));
      await next(tester);
    }
    expect(guard, lessThan(20));
  });
}
