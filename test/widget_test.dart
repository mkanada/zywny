// Smoke test do app: com nenhuma partitura aberta, a tela inicial oferece o
// botão de abrir e não tenta tocar no Verovio nativo (nada é renderizado até
// um arquivo ser escolhido).

import 'package:flutter_test/flutter_test.dart';

import 'package:zywny/main.dart';

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

    // A página é derivada da caixa da partitura: depois do primeiro layout
    // o painel mostra o tamanho em unidades do Verovio e em milímetros.
    await tester.pump();
    expect(find.textContaining('zoom 1.0×'), findsOneWidget);
    expect(find.textContaining('página '), findsOneWidget);
    expect(find.textContaining(' mm)'), findsOneWidget);
  });
}
