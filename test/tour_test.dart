// O motor do tutorial (`lib/tutorial/tour.dart`): passos, recorte, o cartão
// e onde ele fica. Nada aqui conhece a biblioteca nem a partitura.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/tutorial/tour.dart';

/// Uma tela com alvos nos lugares pedidos e um botão que abre o passeio.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.steps,
    required this.onEnd,
    this.targets = const {},
  });

  final List<TourStep> steps;
  final void Function(TourEnd? end) onEnd;

  /// Onde cada alvo fica (esquerda, topo, largura, altura), por chave.
  final Map<GlobalKey, Rect> targets;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Map<GlobalKey, Rect> targets = widget.targets;

  void move(GlobalKey key, Rect to) =>
      setState(() => targets = {...targets, key: to});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          for (final entry in targets.entries)
            Positioned.fromRect(
              rect: entry.value,
              child: ColoredBox(key: entry.key, color: Colors.blue),
            ),
          Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    widget.onEnd(await showTour(context, widget.steps)),
                child: const Text('Iniciar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  final a = GlobalKey(debugLabel: 'a');
  final b = GlobalKey(debugLabel: 'b');
  final missing = GlobalKey(debugLabel: 'ausente');

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<GlobalKey<_HostState>> start(
    WidgetTester tester,
    List<TourStep> steps,
    void Function(TourEnd? end) onEnd, {
    Map<GlobalKey, Rect>? targets,
  }) async {
    final host = GlobalKey<_HostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          key: host,
          steps: steps,
          onEnd: onEnd,
          targets:
              targets ??
              {
                a: const Rect.fromLTWH(20, 20, 80, 40),
                b: const Rect.fromLTWH(20, 500, 80, 40),
              },
        ),
      ),
    );
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    return host;
  }

  final steps = [
    const TourStep(title: 'Boas-vindas', body: 'Texto zero'),
    TourStep(targets: [a], title: 'Primeiro', body: 'Texto um'),
    TourStep(targets: [b], title: 'Segundo', body: 'Texto dois'),
    const TourStep(title: 'Fim', body: 'Texto três'),
  ];

  group('os passos', () {
    testWidgets('passam na ordem, voltam e terminam no "Entendi"', (
      tester,
    ) async {
      TourEnd? end;
      var ended = false;
      await start(tester, steps, (e) {
        end = e;
        ended = true;
      });

      expect(find.text('Boas-vindas'), findsOneWidget);
      expect(find.text('1 de 4'), findsOneWidget);
      // O primeiro passo não tem "Voltar"; o último não tem "Pular".
      expect(find.text('Voltar'), findsNothing);
      expect(find.text('Pular'), findsOneWidget);

      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();
      expect(find.text('Primeiro'), findsOneWidget);
      expect(find.text('2 de 4'), findsOneWidget);

      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Segundo'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Primeiro'), findsOneWidget);

      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Fim'), findsOneWidget);
      expect(find.text('4 de 4'), findsOneWidget);
      expect(find.text('Pular'), findsNothing);
      expect(ended, isFalse);

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(ended, isTrue);
      expect(end, TourEnd.finished);
      expect(find.text('Fim'), findsNothing);
    });

    testWidgets('"Pular" encerra o passeio', (tester) async {
      TourEnd? end;
      await start(tester, steps, (e) => end = e);
      await tester.tap(find.text('Pular'));
      await tester.pumpAndSettle();
      expect(end, TourEnd.skipped);
      expect(find.text('Boas-vindas'), findsNothing);
    });

    testWidgets('o "voltar" do aparelho e a tecla Esc contam como pular', (
      tester,
    ) async {
      TourEnd? end;
      await start(tester, steps, (e) => end = e);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(end, TourEnd.skipped);

      end = null;
      await tester.tap(find.text('Iniciar'));
      await tester.pumpAndSettle();
      expect(find.text('Boas-vindas'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(end, TourEnd.skipped);
    });

    testWidgets('as setas do teclado avançam e voltam', (tester) async {
      await start(tester, steps, (_) {});
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Primeiro'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Boas-vindas'), findsOneWidget);
    });

    testWidgets('passo cujo alvo não está na tela é pulado e não conta', (
      tester,
    ) async {
      await start(tester, [
        const TourStep(title: 'Boas-vindas', body: 'x'),
        TourStep(targets: [missing], title: 'Fantasma', body: 'x'),
        TourStep(targets: [a], title: 'Primeiro', body: 'x'),
      ], (_) {});
      expect(find.text('1 de 2'), findsOneWidget);
      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();
      expect(find.text('Fantasma'), findsNothing);
      expect(find.text('Primeiro'), findsOneWidget);
      expect(find.text('2 de 2'), findsOneWidget);
      expect(find.text('Entendi'), findsOneWidget);
    });

    testWidgets('com vários alvos, vale os que estão na tela', (tester) async {
      await start(tester, [
        TourStep(targets: [missing, a], title: 'Misto', body: 'x'),
      ], (_) {});
      expect(find.text('Misto'), findsOneWidget);
    });

    testWidgets('sem nenhum alvo na tela, o passeio nem abre', (tester) async {
      var ended = false;
      TourEnd? end = TourEnd.finished;
      await start(
        tester,
        [
          const TourStep(title: 'Só texto', body: 'x'),
          TourStep(targets: [missing], title: 'Fantasma', body: 'x'),
        ],
        (e) {
          ended = true;
          end = e;
        },
      );
      expect(ended, isTrue);
      expect(end, isNull);
      expect(find.text('Só texto'), findsNothing);
    });
  });

  group('o cartão', () {
    /// A caixa do cartão: o ancestral `Material` do título.
    Rect cardOf(WidgetTester tester, String title) => tester.getRect(
      find
          .ancestor(of: find.text(title), matching: find.byType(Material))
          .first,
    );

    testWidgets('fica embaixo de um alvo no topo e em cima de um embaixo', (
      tester,
    ) async {
      useSize(tester, const Size(400, 700));
      await start(tester, steps, (_) {});
      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();
      final target = tester.getRect(find.byKey(a));
      expect(cardOf(tester, 'Primeiro').top, greaterThan(target.bottom));

      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      final low = tester.getRect(find.byKey(b));
      expect(cardOf(tester, 'Segundo').bottom, lessThan(low.top));
    });

    testWidgets('em celular deitado, um botão na borda direita leva o cartão '
        'para o lado', (tester) async {
      useSize(tester, const Size(640, 360));
      await start(
        tester,
        [
          TourStep(targets: [a], title: 'Na borda', body: 'x ' * 40),
        ],
        (_) {},
        targets: {a: const Rect.fromLTWH(560, 150, 64, 48)},
      );
      expect(tester.takeException(), isNull);
      final target = tester.getRect(find.byKey(a));
      final card = cardOf(tester, 'Na borda');
      expect(card.right, lessThan(target.left));
      const screen = Rect.fromLTWH(0, 0, 640, 360);
      expect(screen.contains(card.topLeft), isTrue);
      expect(screen.contains(card.bottomRight), isTrue);
    });

    testWidgets('um alvo que toma a tela não esconde o cartão fora dela', (
      tester,
    ) async {
      useSize(tester, const Size(400, 700));
      await start(
        tester,
        [
          TourStep(targets: [a], title: 'Grande', body: 'x'),
        ],
        (_) {},
        targets: {a: const Rect.fromLTWH(8, 40, 384, 640)},
      );
      expect(tester.takeException(), isNull);
      final card = cardOf(tester, 'Grande');
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(400));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.bottom, lessThanOrEqualTo(700));
    });

    testWidgets('texto grande em tela pequena rola, em vez de estourar', (
      tester,
    ) async {
      useSize(tester, const Size(320, 220));
      await start(
        tester,
        [
          TourStep(
            targets: [a],
            title: 'Longo',
            body: 'um texto bem comprido que ocupa várias linhas. ' * 12,
          ),
        ],
        (_) {},
        targets: {a: const Rect.fromLTWH(20, 20, 60, 40)},
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Entendi'), findsOneWidget);
    });

    testWidgets('acompanha o alvo que se mexe', (tester) async {
      useSize(tester, const Size(400, 700));
      final host = await start(tester, [
        TourStep(targets: [a], title: 'Móvel', body: 'x'),
      ], (_) {});
      final before = cardOf(tester, 'Móvel');
      expect(before.top, greaterThan(tester.getRect(find.byKey(a)).bottom));

      // O alvo desce (a partitura terminou de carregar, por exemplo): na
      // próxima conferência o cartão passa para cima dele.
      host.currentState!.move(a, const Rect.fromLTWH(20, 560, 80, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final target = tester.getRect(find.byKey(a));
      expect(cardOf(tester, 'Móvel').bottom, lessThan(target.top));
    });
  });

  group('onde o cartão fica (TourCardLayout)', () {
    const screen = Size(400, 700);
    const card = Size(300, 160);
    Offset at(Rect? hole, {EdgeInsets insets = EdgeInsets.zero}) =>
        TourCardLayout(
          hole: hole,
          insets: insets,
        ).getPositionForChild(screen, card);

    test('sem alvo: no meio da tela', () {
      expect(at(null), const Offset(50, 270));
    });

    test('abaixo do alvo, alinhado ao centro dele e dentro da tela', () {
      final p = at(const Rect.fromLTWH(10, 40, 60, 40));
      expect(p.dy, greaterThan(80));
      expect(p.dx, 12); // o centro do alvo está perto da borda: encosta nela
    });

    test('sem espaço embaixo, em cima', () {
      final p = at(const Rect.fromLTWH(150, 620, 100, 40));
      expect(p.dy + card.height, lessThan(620));
    });

    test('sem espaço em cima nem embaixo, ao lado', () {
      const tall = Size(400, 220);
      final p = const TourCardLayout(
        hole: Rect.fromLTWH(320, 80, 60, 60),
        insets: EdgeInsets.zero,
      ).getPositionForChild(tall, const Size(280, 160));
      expect(p.dx + 280, lessThan(320)); // à esquerda do alvo
    });

    test('alvo que toma a tela: o cartão fica embaixo, por cima dele', () {
      final p = at(const Rect.fromLTWH(8, 40, 384, 600));
      expect(p.dy + card.height, 700 - 12); // encostado no pé da tela
    });

    test('respeita as bordas do aparelho (entalhe, barra de status)', () {
      final p = at(null, insets: const EdgeInsets.only(top: 100));
      expect(p.dy, greaterThanOrEqualTo(112));
    });
  });
}
