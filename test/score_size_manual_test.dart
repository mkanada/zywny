// Mede o tamanho real (px de tela) do pentagrama: hino vs. exercício do curso.
//   SCORE_SIZE=1 flutter test test/score_size_manual_test.dart
@Tags(['manual'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:zywny/course/score/lesson_score.dart';
import 'package:zywny/course/ui/course_chrome.dart' show kPhoneLessonScoreZoom;
import 'package:zywny/layout_options.dart';

import 'support/hymn_package.dart';
import 'support/render_helper.dart';

double _staffPagePx(VsbDocument doc) {
  double? found;
  void walk(SceneChild c) {
    if (found != null || c is! SceneNode) return;
    final g = c.staffGeometry;
    if (g != null) {
      final page = doc.pages.first;
      found = 8 * g.unit * page.widthPx / page.viewBox.width;
      return;
    }
    c.children.forEach(walk);
  }

  walk(doc.pages.first.root);
  return found!;
}

/// Pentagrama em dp na tela: a página vai "contain" na caixa.
String _onScreen(VsbDocument doc, double boxW, double boxH, double dpr) {
  final p = doc.pages.first;
  final s = min(boxW / p.widthPx, boxH / p.heightPx);
  final dp = _staffPagePx(doc) * s / dpr;
  return 'páginas=${doc.pages.length} pág=${p.widthPx}×${p.heightPx} '
      'escala=${s.toStringAsFixed(2)} pentagrama=${dp.toStringAsFixed(1)} dp';
}

void main() {
  test('mede', skip: Platform.environment['SCORE_SIZE'] != '1', () async {
    const dpr = 2.625;
    // Celular deitado 914×411 dp. Hino: caixa sob a barra (~56 dp).
    // Exercício: barra de 44 dp + controles (~48 dp).
    final hymns = await openLocalHymnPackage();
    final hymnXml = await hymns!.loadScore('001');
    final hymnOpts = layoutOptionsToSend(initialLayoutValues(phone: true));
    const hw = 914 * dpr, hh = (411 - 56) * dpr;
    final hymn = await renderBytes(
      hymnXml,
      'h.musicxml',
      pageWidth: hw.round(),
      pageHeight: hh.round(),
      options: hymnOpts,
    );
    debugPrint('hino   $hymnOpts\n  ${_onScreen(hymn, hw, hh, dpr)}');

    final ode = File('assets/cursos/iniciacao/media/ode-a-alegria.musicxml')
        .readAsBytesSync();
    for (final (label, w, h) in [
      ('deitado', 914.0, 411.0 - 44 - 48),
      ('em pé', 411.0, 914.0 - 56 - 48),
    ]) {
      final bw = w * dpr, bh = h * dpr;
      final layout = lessonScoreLayout(
        bw / kPhoneLessonScoreZoom,
        heightPx: bh / kPhoneLessonScoreZoom,
        phone: true,
      );
      final doc = await renderBytes(
        ode,
        'ode.musicxml',
        pageWidth: layout.pageWidth,
        pageHeight: layout.pageHeight,
        options: layout.options,
      );
      debugPrint(
        'curso $label ${layout.options}\n  ${_onScreen(doc, bw, bh, dpr)}',
      );
    }
  });
}
