// Testes de widget do app, sem partitura aberta (nada nativo é tocado até um
// arquivo ser escolhido): a tela inicial, e o contrato de que o zoom e o
// painel de opções são camadas sobre a partitura — abrir, mover ou
// usar qualquer um deles não altera a caixa da partitura nem o tamanho de
// página pedido ao Verovio (que só o mudaria por um re-render). O zoom vive
// dentro do painel (não mais flutuando sobre a partitura), então os testes
// que o exercitam abrem o painel primeiro.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';

import 'package:zywny/main.dart';

/// The score box: the [InteractiveViewer] fills it and nothing else does.
Size _scoreBox(WidgetTester tester) =>
    tester.getSize(find.byType(InteractiveViewer));

/// Page size the panel says the score box asks for ("1250×456 (125×46 mm)").
String _fittedPage(WidgetTester tester) => tester
    .widget<Text>(find.textContaining(' mm)'))
    .data!;

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Opções'));
  await tester.pump();
}

void main() {
  testWidgets('tela inicial pede uma partitura', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Abrir partitura'), findsOneWidget);
    expect(find.text('nenhuma partitura'), findsOneWidget);
    expect(
      find.text('status: abra uma partitura (.mei, .musicxml, .mxml)'),
      findsOneWidget,
    );
    // Sem documento não há página desenhada.
    expect(find.byType(ScorePageView), findsNothing);
    expect(find.text('—'), findsOneWidget);

    // O painel de opções (que hospeda o zoom) começa fechado.
    expect(find.byTooltip('Opções'), findsOneWidget);
    expect(find.text('Opções'), findsNothing);
  });

  testWidgets('o painel mostra a página derivada da caixa da partitura',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // primeiro layout: a caixa passa a ser conhecida
    await _openPanel(tester);

    expect(find.text('Opções'), findsOneWidget);
    expect(find.text('Página acompanha a área'), findsOneWidget);
    expect(_fittedPage(tester), matches(RegExp(r'^\d+×\d+ \(\d+×\d+ mm\)$')));
  });

  testWidgets('zoom não altera a caixa nem a página pedida ao Verovio',
      (tester) async {
    await tester.pumpWidget(const MyApp());
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

  testWidgets('abrir e fechar o painel não altera a caixa da partitura',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    final box = _scoreBox(tester);

    await _openPanel(tester);
    expect(_scoreBox(tester), box);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pump();
    expect(find.text('Opções'), findsNothing);
    expect(_scoreBox(tester), box);
  });

  testWidgets('o zoom não passa dos limites', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await _openPanel(tester);

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byTooltip('Diminuir zoom'), warnIfMissed: false);
      await tester.pump();
    }
    expect(find.text('50%'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
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
}
