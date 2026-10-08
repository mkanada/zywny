import 'package:flutter/widgets.dart';
import 'package:zywny_library/library_package.dart' show LibraryTerm;

import '../ui/phone_chrome.dart' show PhoneRailKeys;
import 'tour.dart';

/// Os botões da tela da partitura (no celular) que o passeio aponta; a tela
/// os põe nos widgets.
class ScoreTourKeys {
  final score = GlobalKey(debugLabel: 'tour-score');
  final back = GlobalKey(debugLabel: 'tour-back');

  /// A trilha na barra do título (só no modo trilha).
  final trail = GlobalKey(debugLabel: 'tour-trail');
  final sound = GlobalKey(debugLabel: 'tour-sound');

  /// Os botões da barra lateral.
  final rail = PhoneRailKeys(
    play: GlobalKey(debugLabel: 'tour-play'),
    listen: GlobalKey(debugLabel: 'tour-listen'),
    restart: GlobalKey(debugLabel: 'tour-restart'),
    measure: GlobalKey(debugLabel: 'tour-measure'),
    tempo: GlobalKey(debugLabel: 'tour-tempo'),
    hand: GlobalKey(debugLabel: 'tour-hand'),
    options: GlobalKey(debugLabel: 'tour-options'),
  );
}

/// O passeio pela tela da partitura.
List<TourStep> scoreTourSteps(ScoreTourKeys keys, {required LibraryTerm term}) {
  final rail = keys.rail;
  return [
    TourStep(
      targets: [keys.score],
      title: 'A partitura',
      body:
          'É aqui que ${term.o} ${term.singular} aparece. Toque numa nota para '
          'posicionar a música ali. Com a música parada e mais de uma página, '
          'os cantos de baixo viram a página.',
    ),
    TourStep(
      targets: [keys.back],
      title: 'Voltar',
      body: 'Volta à biblioteca.',
    ),
    TourStep(
      targets: [keys.trail],
      title: 'A trilha',
      body:
          'Cada música vira uma trilha: trechos curtos e etapas que se '
          'liberam como as fases de um jogo, do devagar ao andamento real. '
          'Toque aqui para ver as etapas.',
    ),
    TourStep(
      targets: [keys.sound],
      title: 'Som',
      body:
          'Liga ou desliga o som do aplicativo. Se a saída for o teclado, '
          'mostra se ele está conectado.',
    ),
    TourStep(
      targets: [rail.play!, rail.listen!],
      title: 'Treinar',
      body:
          'Começa o treino. Com o teclado ligado, o Zywny espera você tocar '
          'cada nota e marca acertos e erros; sem teclado, ele toca para você '
          'ouvir. O ícone do ouvido, quando aparece, toca o trecho antes de '
          'você tentar.',
    ),
    TourStep(
      targets: [rail.restart!, rail.measure!],
      title: 'Reiniciar e compasso',
      body:
          'A seta volta ao começo. O número mostra o compasso em que você '
          'está; toque nele para ir a outro compasso.',
    ),
    TourStep(
      targets: [rail.tempo!, rail.hand!],
      title: 'Andamento e mão',
      body:
          'Mostram a velocidade e a mão do treino. No treino livre, toque '
          'para mudar; na trilha, cada etapa traz as suas, e o toque abre a '
          'lista de etapas.',
    ),
    TourStep(
      targets: [rail.options!],
      title: 'Mais opções',
      body:
          'Modo de treino (esperar ou tempo real), metrônomo, repetir um '
          'trecho, transpor para um tom mais fácil, tamanho da notação e as '
          'configurações gerais.',
    ),
    const TourStep(
      title: 'Bom estudo!',
      body:
          'Para rever este passeio, abra as configurações gerais e toque em '
          '“Rever o tutorial”.',
    ),
  ];
}
