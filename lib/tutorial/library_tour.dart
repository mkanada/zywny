import 'package:flutter/widgets.dart';
import 'package:zywny_library/library_package.dart' show LibraryTerm;

import 'tour.dart';

/// Os botões da biblioteca que o passeio aponta; a tela os põe nos widgets.
class LibraryTourKeys {
  /// A linha "Cursos" (com biblioteca) ou o cartão do curso inicial (sem).
  final courses = GlobalKey(debugLabel: 'tour-courses');

  /// O cartão "Instale uma biblioteca de músicas" (só sem biblioteca).
  final install = GlobalKey(debugLabel: 'tour-install');
  final search = GlobalKey(debugLabel: 'tour-search');

  /// "Comece por aqui" ou "Continuar".
  final start = GlobalKey(debugLabel: 'tour-start');
  final sort = GlobalKey(debugLabel: 'tour-sort');

  /// A primeira linha da lista.
  final firstRow = GlobalKey(debugLabel: 'tour-first-row');
  final keyboard = GlobalKey(debugLabel: 'tour-keyboard');
  final settings = GlobalKey(debugLabel: 'tour-settings');
}

/// O passeio pela biblioteca. [numbered] diz se as músicas têm número (muda
/// o que a busca aceita); [hasLibrary], se há biblioteca instalada;
/// [scoreTour], se o passeio da partitura vai rodar quando se abrir uma
/// música (na janela larga do desktop não roda).
List<TourStep> libraryTourSteps(
  LibraryTourKeys keys, {
  required LibraryTerm term,
  required bool numbered,
  required bool hasLibrary,
  required bool scoreTour,
}) {
  final openIt = term.feminine ? 'abri-la' : 'abri-lo';
  // Sem biblioteca o app ainda não sabe como chamar as músicas ("hinos",
  // "peças"…): fala em "músicas", como o título da tela.
  final plural = hasLibrary ? term.plural : 'músicas';
  final os = hasLibrary ? term.os : 'as';
  return [
    const TourStep(
      title: 'Bem-vindo ao Zywny',
      body:
          'Aqui você treina música no seu teclado MIDI: o Zywny mostra a '
          'partitura, ouve o que você toca e diz o que acertou. Vou mostrar '
          'onde fica cada coisa. Dá para pular quando quiser.',
    ),
    TourStep(
      targets: [keys.courses],
      title: 'Cursos',
      body:
          'Nunca leu partitura? O curso inicial ensina do zero, com '
          'exercícios para tocar no teclado ou responder na tela. É o melhor '
          'lugar para começar.',
    ),
    TourStep(
      targets: [keys.install],
      title: 'Músicas',
      body:
          'O Zywny não traz músicas: elas chegam em bibliotecas, arquivos '
          '.zywny. Abra uma aqui. Depois, pelas configurações, você troca de '
          'biblioteca ou instala outras.',
    ),
    TourStep(
      targets: [keys.search],
      title: 'Busca',
      body: numbered
          ? 'Procure pelo número, pelo título ou pelo autor.'
          : 'Procure pelo título ou pelo autor.',
    ),
    TourStep(
      targets: [keys.start],
      title: 'Por onde começar',
      body:
          'Este atalho muda com o seu uso. No começo, “Comece por aqui” mostra '
          'como começar; depois, “Continuar” reabre '
          '${term.o} ${term.singular} que você estava estudando.',
    ),
    TourStep(
      targets: [keys.sort],
      title: 'Ordem',
      body:
          'Toque numa pastilha para ordenar a lista (por nome, acidentes, '
          'recentes, pontuação…). Toque de novo para inverter.',
    ),
    TourStep(
      targets: [keys.firstRow],
      title: 'A lista',
      body:
          'Toque ${term.um} ${term.singular} para $openIt. Em cada linha você '
          'vê a armadura e, depois de estudar, o seu progresso.',
    ),
    TourStep(
      targets: [keys.keyboard],
      title: 'Teclado MIDI',
      body:
          'Ligue o teclado ao aparelho (no celular, com um cabo USB): ele '
          'conecta sozinho. Este botão mostra se há teclado e deixa escolher '
          'outro. Sem teclado você ainda ouve $os $plural e '
          'faz os exercícios de responder na tela.',
    ),
    TourStep(
      targets: [keys.settings],
      title: 'Configurações',
      body:
          'Som, cores, nome das notas (Dó-Ré-Mi ou C-D-E), bibliotecas e '
          'cursos. No fim da lista estão o “Sobre o Zywny” e este tutorial, '
          'para rever quando quiser.',
    ),
    TourStep(
      title: hasLibrary ? 'Agora é com você' : 'Pronto para começar',
      body: hasLibrary
          ? 'Abra ${term.um} ${term.singular}'
                '${scoreTour ? ': na primeira vez, mostro também a tela da partitura.' : '.'}'
          : 'Comece pelo curso inicial. Quando você instalar uma biblioteca, '
                'as músicas aparecem aqui.',
    ),
  ];
}
