// Carregamento explícito das TTFs do pacote em teste/headless (R04a).
//
// Em teste/headless as fontes do pacote não são carregadas automaticamente
// em todos os caminhos: este helper alimenta um `FontLoader` com os bytes
// dos assets (as chaves validam a declaração `flutter/fonts` do pubspec) e
// deve ser chamado no `setUpAll` de todo teste que mede texto — e pelo
// `compare` quando ele for renderizar texto (R04b).
library;

import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';

/// Assets de fonte do pacote, na ordem Regular/Italic/Bold/BoldItalic.
const kScoreFontAssets = [
  'packages/score_bridge/fonts/LiberationSerif-Regular.ttf',
  'packages/score_bridge/fonts/LiberationSerif-Italic.ttf',
  'packages/score_bridge/fonts/LiberationSerif-Bold.ttf',
  'packages/score_bridge/fonts/LiberationSerif-BoldItalic.ttf',
];

bool _loaded = false;

/// Carrega os 4 estilos de [kScoreTextFamily] via [FontLoader] (idempotente
/// por processo; `flutter test` isola um processo por arquivo).
///
/// O motor casa estilo/peso pelos metadados da própria fonte (OS/2), por
/// isso os 4 TTFs entram num único `FontLoader` sem descritores.
Future<void> loadScoreFonts() async {
  if (_loaded) {
    return;
  }
  final loader = FontLoader(kScoreTextFamily);
  for (final asset in kScoreFontAssets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
  _loaded = true;
}
