import 'package:flutter/material.dart';

import 'theme.dart';

/// Uma partitura da biblioteca (mockup — sem leitura de arquivo real).
class Piece {
  const Piece({
    required this.title,
    required this.composer,
    required this.composerKey,
    this.score,
    this.daysAgo,
  });

  final String title;
  final String composer;

  /// Chave de ordenação do compositor (sobrenome), separada do texto de
  /// exibição — mesmo truque do artboard original.
  final String composerKey;

  /// Melhor pontuação (0-100) ou `null` se nunca estudada.
  final int? score;

  /// Dias desde o último estudo, ou `null` se nunca estudada.
  final int? daysAgo;
}

/// Mesmo corpus do artboard `CelularBiblioteca.dc.html`.
const kPieces = <Piece>[
  Piece(
    title: 'Little bird, op. 43 nº 4',
    composer: 'Edvard Grieg',
    composerKey: 'Grieg',
    score: 78,
    daysAgo: 0,
  ),
  Piece(
    title: 'Butterfly, op. 43 nº 1',
    composer: 'Edvard Grieg',
    composerKey: 'Grieg',
    score: 64,
    daysAgo: 1,
  ),
  Piece(
    title: 'Gymnopédie nº 1',
    composer: 'Erik Satie',
    composerKey: 'Satie',
    score: 92,
    daysAgo: 3,
  ),
  Piece(
    title: 'Nocturne op. 9 nº 1',
    composer: 'Frédéric Chopin',
    composerKey: 'Chopin',
    score: 70,
    daysAgo: 5,
  ),
  Piece(
    title: 'Prelúdio em Dó maior, BWV 846',
    composer: 'J. S. Bach',
    composerKey: 'Bach',
    score: 88,
    daysAgo: 7,
  ),
  Piece(
    title: 'Clair de Lune',
    composer: 'Claude Debussy',
    composerKey: 'Debussy',
    score: 41,
    daysAgo: 14,
  ),
  Piece(
    title: 'Mazurka op. 6 nº 1',
    composer: 'Frédéric Chopin',
    composerKey: 'Chopin',
    score: 55,
    daysAgo: 30,
  ),
  Piece(
    title: 'Étude op. 10 nº 9',
    composer: 'Frédéric Chopin',
    composerKey: 'Chopin',
  ),
  Piece(
    title: 'Maple Leaf Rag',
    composer: 'Scott Joplin',
    composerKey: 'Joplin',
  ),
  Piece(
    title: 'Sonata em Dó maior',
    composer: 'Domenico Scarlatti',
    composerKey: 'Scarlatti',
  ),
];

enum SortKey { recent, score, title, composer }

/// Direção padrão de cada chave — mesmo `DEF` do artboard: título e
/// compositor ordenam A→Z por padrão; pontuação e recência ordenam do maior
/// (melhor nota / mais recente) primeiro, mas como número crescente de
/// "distância", daí `asc: true` para `recent` (dias crescentes = mais
/// recente primeiro) e `asc: false` para `score` (nota decrescente).
bool defaultAscendingFor(SortKey key) => switch (key) {
  SortKey.title => true,
  SortKey.composer => true,
  SortKey.score => false,
  SortKey.recent => true,
};

String labelFor(SortKey key) => switch (key) {
  SortKey.title => 'Nome',
  SortKey.composer => 'Compositor',
  SortKey.score => 'Pontuação',
  SortKey.recent => 'Recentes',
};

@immutable
class SortState {
  const SortState({this.key = SortKey.recent, bool? ascending})
    : ascending = ascending ?? true;

  final SortKey key;
  final bool ascending;

  /// Toca a mesma chave (inverte a direção) ou troca de chave (volta à
  /// direção padrão dela) — mesma regra do `pick()` do artboard.
  SortState toggled(SortKey tapped) {
    if (tapped == key) return SortState(key: key, ascending: !ascending);
    return SortState(key: tapped, ascending: defaultAscendingFor(tapped));
  }

  /// Seta seguida por '↓'/'↑', só na chave ativa — mesma assimetria do
  /// artboard: em pontuação/recência a seta mostra a direção *relativa* ao
  /// padrão da chave, não o sinal literal de `ascending`.
  String arrowFor(SortKey k) {
    if (k != key) return '';
    final atDefault = ascending == defaultAscendingFor(k);
    return atDefault ? '↓' : '↑';
  }
}

int _compareNullLast(int? a, int? b, int Function(int, int) whenBoth) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return whenBoth(a, b);
}

List<Piece> sortedPieces(List<Piece> pieces, SortState sort) {
  final asc = sort.ascending;
  int byTitle(Piece a, Piece b) => a.title.compareTo(b.title);
  int cmp(Piece a, Piece b) {
    switch (sort.key) {
      case SortKey.title:
        return (asc ? 1 : -1) * byTitle(a, b);
      case SortKey.composer:
        final byComposer = a.composerKey.compareTo(b.composerKey);
        final signed = (asc ? 1 : -1) * byComposer;
        return signed != 0 ? signed : byTitle(a, b);
      case SortKey.score:
        final byScore = _compareNullLast(
          a.score,
          b.score,
          (x, y) => asc ? x - y : y - x,
        );
        return byScore != 0 ? byScore : byTitle(a, b);
      case SortKey.recent:
        final byRecent = _compareNullLast(
          a.daysAgo,
          b.daysAgo,
          (x, y) => asc ? x - y : y - x,
        );
        return byRecent != 0 ? byRecent : byTitle(a, b);
    }
  }

  final out = pieces.toList()..sort(cmp);
  return out;
}

/// "há N dias" etc. — mesma escala do artboard.
String whenStudied(int? daysAgo) {
  if (daysAgo == null) return 'nunca estudada';
  if (daysAgo == 0) return 'hoje';
  if (daysAgo == 1) return 'ontem';
  if (daysAgo < 7) return 'há $daysAgo dias';
  if (daysAgo < 14) return 'há 1 semana';
  if (daysAgo < 30) return 'há ${(daysAgo / 7).round()} semanas';
  return 'há 1 mês';
}

/// Cor da pontuação — mesma faixa do artboard (`band()`), com um cinza
/// diferente para "nunca estudada" (bolinha) e para nota baixa (texto).
Color scoreBandColor(int? score) {
  if (score == null) return kScoreNeverColor;
  if (score >= 85) return kGoodColor;
  if (score >= 60) return kOkColor;
  return kLowScoreColor;
}
