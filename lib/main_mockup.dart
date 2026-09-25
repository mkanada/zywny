import 'package:flutter/material.dart';

import 'mockup/library_screen.dart';
import 'mockup/practice_screen.dart';
import 'mockup/practice_state.dart';
import 'mockup/theme.dart';

/// Ponto de entrada separado do mockup de interface (`lib/mockup/`) — as
/// telas de celular do artefato "zywny — interface de estudo", sem o
/// Verovio ligado no app (as imagens de partitura vêm prontas de
/// `assets/mockup/`, geradas por `tool/build_mockup_images.sh`).
///
/// `lib/main.dart` continua sendo o banco de testes do motor Verovio
/// (`just run`); este roda à parte: `flutter run -t lib/main_mockup.dart`.
void main() {
  runApp(const ZywnyMockupApp());
}

class ZywnyMockupApp extends StatelessWidget {
  const ZywnyMockupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zywny — mockup',
      debugShowCheckedModeBanner: false,
      theme: buildMockupTheme(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// Rotas nomeadas (`/estudo`, `/grande`, `/treino`, `/painel`) para abrir
  /// direto em cada um dos estados dos artboards `Celular*.dc.html` — usadas
  /// para tirar screenshot comparável ao artefato (`tool/capture_mockup_screens.sh`),
  /// além da navegação normal a partir da biblioteca.
  static const _littleBird = PracticeArgs(
    title: 'Little bird, op. 43 nº 4',
    composer: 'Edvard Grieg',
  );
  static const _littleBirdPracticing = PracticeArgs(
    title: 'Little bird, op. 43 nº 4',
    composer: 'Edvard Grieg',
    mode: PracticeMode.espera,
    hand: Hand.direita,
    tempoPercent: 80,
    measure: 4,
  );

  Route<Object?> _onGenerateRoute(RouteSettings settings) {
    final Widget page;
    switch (settings.name) {
      case '/estudo':
        page = const PracticeScreen(args: _littleBird);
      case '/grande':
        page = const PracticeScreen(
          args: PracticeArgs(
            title: 'Little bird, op. 43 nº 4',
            composer: 'Edvard Grieg',
            size: ScoreSize.grande,
          ),
        );
      case '/treino':
        page = const PracticeScreen(args: _littleBirdPracticing);
      case '/painel':
        page = const PracticeScreen(
          args: _littleBirdPracticing,
          startWithPanelOpen: true,
        );
      case '/':
      default:
        page = const LibraryScreen();
    }
    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }
}
