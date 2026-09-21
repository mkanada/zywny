// Testes de widget do app, sem partitura aberta (nada nativo é tocado até um
// arquivo ser escolhido): a tela inicial, e o contrato de que o zoom e o
// painel de parâmetros são camadas sobre a partitura — abrir, mover ou
// usar qualquer um deles não altera a caixa da partitura nem o tamanho de
// página pedido ao Verovio (que só o mudaria por um re-render).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zywny/main.dart';

/// The score box: the [InteractiveViewer] fills it and nothing else does.
Size _scoreBox(WidgetTester tester) =>
    tester.getSize(find.byType(InteractiveViewer));

/// Page size the panel says the score box asks for ("1250×456 (125×46 mm)").
String _fittedPage(WidgetTester tester) => tester
    .widget<Text>(find.textContaining(' mm)'))
    .data!;

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Parâmetros do Verovio'));
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
    expect(find.byType(VsbPageView), findsNothing);
    expect(find.text('—'), findsOneWidget);

    // Zoom flutuando sobre a partitura, começando em 100%; o painel de
    // parâmetros começa fechado.
    expect(find.text('100%'), findsOneWidget);
    expect(find.byTooltip('Parâmetros do Verovio'), findsOneWidget);
    expect(find.text('Parâmetros do Verovio'), findsNothing);
  });

  testWidgets('o painel mostra a página derivada da caixa da partitura',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // primeiro layout: a caixa passa a ser conhecida
    await _openPanel(tester);

    expect(find.text('Parâmetros do Verovio'), findsOneWidget);
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
    expect(find.text('Parâmetros do Verovio'), findsNothing);
    expect(_scoreBox(tester), box);
  });

  testWidgets('o zoom não passa dos limites', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

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
