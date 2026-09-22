// Regra da haste generalizada aos saltos de repetição (E03b, D-SALTO = (a)).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';

const _maxSweep = Duration(seconds: 1);
const _bar = 50.0;

VsbDocument _fixture(String name) =>
    VsbDocument.fromBytes(File('test/fixtures/$name').readAsBytesSync());

void main() {
  late VsbDocument mapleLeafRag;
  late ScoreTimeline tl;

  setUpAll(() {
    // ScoreController usa um Ticker (highlightAll com release) mesmo no
    // teste de reprodução completa abaixo, que não é testWidgets.
    TestWidgetsFlutterBinding.ensureInitialized();
    mapleLeafRag = _fixture('maple-leaf-rag.vsb');
    tl = ScoreTimeline(mapleLeafRag);
  });

  SweepCurtain? at(double ms) =>
      tl.curtainAt(ms, maxSweep: _maxSweep, barWidth: _bar);

  group('salto 39900ms: compasso 34 (página 1) -> 19 (página 0)', () {
    test(
      'entrada, estacionada e conclusão com targetPageIndex = 0 (critério 1)',
      () {
        final i = tl.measures.indexWhere((m) => m.startMs == 39900);
        final m = tl.measures[i - 1]; // compasso 34, última ocorrência antes
        final next = tl.measures[i]; // compasso 19, passagem 2
        expect(m.page, 1);
        expect(next.page, 0);
        final d = (m.endMs - m.startMs) / 4;
        final endX = sweepEndX(mapleLeafRag.pages[1], _bar);
        final x = mapleLeafRag.geometry.elementOf(m.id)!.bbox.left;

        // Antes da entrada: repouso.
        expect(at(m.startMs - 1.0), isNull);
        // Entrada: 0 -> x.
        final entering = at(m.startMs + d / 2)!;
        expect(entering.pageIndex, 1);
        expect(entering.targetPageIndex, 0);
        expect(entering.edgeX, closeTo(x / 2, 1e-6));
        // Estacionada em x.
        final parked = at((m.startMs + d + next.startMs) / 2)!;
        expect(parked.edgeX, closeTo(x, 1e-6));
        expect(parked.targetPageIndex, 0);
        // Conclusão: x -> fim.
        final concluding = at(next.startMs + d / 2)!;
        expect(concluding.edgeX, closeTo(x + (endX - x) / 2, 1e-6));
        // Repouso na página de destino, depois da conclusão.
        expect(at(next.startMs + d), isNull);
        expect(tl.restPageAt(next.startMs + d), 0);
      },
    );
  });

  group('salto 97500ms: compasso 67 (última página, 2) -> 52 (página 1)', () {
    test('a última página tem haste com destino explícito (critério 1)', () {
      final i = tl.measures.indexWhere((m) => m.startMs == 97500);
      final m = tl.measures[i - 1];
      final next = tl.measures[i];
      expect(m.page, 2);
      expect(next.page, 1);
      expect(m.page, mapleLeafRag.pages.length - 1);

      final d = (m.endMs - m.startMs) / 4;
      final parked = at((m.startMs + d + next.startMs) / 2)!;
      expect(parked.pageIndex, 2);
      expect(parked.targetPageIndex, 1);
      expect(at(next.startMs + d), isNull);
      expect(tl.restPageAt(next.startMs + d), 1);
    });
  });

  group('sem haste nos saltos de mesma página (fora de escopo)', () {
    test('84 -> 69 (passagem 2, mesma página): repouso o tempo todo', () {
      final i = tl.measures.indexWhere((m) => m.startMs == 135900);
      final m = tl.measures[i - 1];
      final next = tl.measures[i];
      expect(m.page, next.page);
      for (var ms = m.startMs - 500; ms <= next.startMs + 500; ms += 50) {
        expect(at(ms.toDouble()), isNull, reason: 'ms=$ms');
      }
    });
  });

  test(
    'ScorePlayer toca a Maple Leaf Rag do início ao fim a 4x sem exceção',
    () {
      final controller = ScoreController(document: mapleLeafRag);
      final player = ScorePlayer(
        document: mapleLeafRag,
        controller: controller,
      );
      try {
        // Sem tester.pump (a 4x é só para simular passos maiores que uma
        // entrada de timemap, cruzando vários saltos de uma vez): avança
        // manualmente até o fim, sem usar play()/isPlaying (que dependem
        // de um Ticker real, movido por frames reais — fora do escopo
        // deste teste, que só quer garantir que nada explode).
        var steps = 0;
        while (player.position < player.duration && steps < 20000) {
          player.advance(const Duration(milliseconds: 200)); // 50ms * 4x
          steps++;
        }
        expect(player.position, player.duration);
      } finally {
        controller.clearAll();
        player.dispose();
        controller.dispose();
      }
    },
  );
}
