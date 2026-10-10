// Snapshots da partitura num tablet Android (deitado e em pé): o app de
// verdade num emulador ou aparelho de tela grande. No tablet a partitura não
// trava deitada, como no celular — segue o aparelho —, e começa com o `unit`
// do tablet. Não é um teste de regressão: é o roteiro que gera as imagens.
//
//   emulator -avd Medium_Tablet_Edited -read-only -no-window -no-audio &
//   adb push dist/hinos.zywny /data/local/tmp/hinos.zywny
//   TELAS_DIR=docs/telas/tablet just telas-tablet \
//       --dart-define=ZYWNY_TEST_LIBRARY=/data/local/tmp/hinos.zywny

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zywny/main.dart';
import 'package:zywny/trail/trail_widgets.dart';
import 'package:zywny/ui/phone_chrome.dart';
import 'package:zywny_library/library_store.dart';

const _kHymnTitle = 'Jubilosos Te Adoramos';

final _shotKey = GlobalKey();
final _shots = <String, String>{};

bool _has(Finder finder) => finder.evaluate().isNotEmpty;

bool _portrait(WidgetTester tester) =>
    tester.view.physicalSize.height > tester.view.physicalSize.width;

Future<void> _wait(WidgetTester tester, [int ms = 800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  do {
    await tester.pump(const Duration(milliseconds: 40));
  } while (DateTime.now().isBefore(end));
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  required String what,
  int seconds = 60,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ready()) {
    if (DateTime.now().isAfter(end)) fail('não chegou a: $what');
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder, {int ms = 900}) async {
  await _until(tester, () => _has(finder), what: '$finder', seconds: 20);
  await tester.tap(finder.first, warnIfMissed: false);
  await _wait(tester, ms);
}

/// Fecha o passeio do tutorial, se ele abriu.
Future<void> _skipTour(WidgetTester tester) async {
  await _wait(tester, 1500);
  if (_has(find.text('Pular'))) await _tap(tester, find.text('Pular'));
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final png = await tester.runAsync(() async {
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  _shots[name] = base64Encode(png!);
  debugPrint('tela: $name');
}

/// Gira o aparelho de verdade (o sistema obedece à orientação pedida).
Future<void> _rotate(WidgetTester tester, {required bool portrait}) async {
  await SystemChrome.setPreferredOrientations([
    portrait ? DeviceOrientation.portraitUp : DeviceOrientation.landscapeLeft,
  ]);
  await _until(
    tester,
    () => _portrait(tester) == portrait,
    what: portrait ? 'em pé' : 'deitado',
  );
  await _wait(tester, 1500);
}

Future<void> _scoreReady(WidgetTester tester) async {
  await _until(
    tester,
    () =>
        _has(find.byType(ScoreView)) &&
        _has(find.byType(TrailTitleChip)) &&
        !_has(find.byType(LinearProgressIndicator)),
    what: 'partitura gravada',
    seconds: 90,
  );
  await _wait(tester, 1500);
}

Future<void> _typeSearch(WidgetTester tester, String text) async {
  tester
      .state<EditableTextState>(find.byType(EditableText).first)
      .updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
  await _wait(tester);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.reportData = {'telas': _shots};
  WidgetsApp.debugAllowBannerOverride = false;

  testWidgets(
    'partitura no tablet, deitado e em pé',
    (tester) async {
      await SharedPreferencesAsync().clear();
      const path = String.fromEnvironment('ZYWNY_TEST_LIBRARY');
      await LibraryStore().install(await File(path).readAsBytes());

      await tester.pumpWidget(
        RepaintBoundary(
          key: _shotKey,
          child: const MyApp(splash: false),
        ),
      );
      await _rotate(tester, portrait: false);
      await _until(
        tester,
        () => _has(find.textContaining(' hinos')),
        what: 'biblioteca',
      );
      await _skipTour(tester);
      await _shot(tester, 'tablet-01-biblioteca-deitado');

      await _typeSearch(tester, 'Jubilosos');
      await _tap(tester, find.text(_kHymnTitle).last, ms: 1500);
      await _until(
        tester,
        () => _has(find.byType(PhoneTitleBar)),
        what: 'tela da partitura',
      );
      await _skipTour(tester);
      await _scoreReady(tester);
      await _shot(tester, 'tablet-02-partitura-deitado');

      await _rotate(tester, portrait: true);
      await _scoreReady(tester);
      await _shot(tester, 'tablet-03-partitura-em-pe');

      await _tap(tester, find.byTooltip('Mais opções'));
      await _shot(tester, 'tablet-04-opcoes-em-pe');
      await _tap(tester, find.byTooltip('Fechar'));

      await _tap(tester, find.byType(TrailTitleChip));
      await _shot(tester, 'tablet-05-gaveta-da-trilha-em-pe');
      await _tap(tester, find.byTooltip('Fechar'));

      await _tap(tester, find.byTooltip('Voltar à biblioteca'), ms: 2000);
      await _until(
        tester,
        () => _has(find.textContaining(' hinos')),
        what: 'biblioteca de volta',
      );
      await _shot(tester, 'tablet-06-biblioteca-em-pe');
      await SystemChrome.setPreferredOrientations([]);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
