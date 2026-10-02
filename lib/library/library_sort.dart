import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'hymn.dart';
import 'hymn_progress.dart';

/// Ordenações da biblioteca — as do artboard `CelularBiblioteca.dc.html`
/// (recentes, pontuação, nome, compositor) mais o número do hinário, que é
/// como um hino é procurado, e a dificuldade (do mais fácil ao mais
/// difícil), para escolher o que estudar.
enum SortKey { number, title, difficulty, recent, score, composer }

/// Direção em que cada chave começa: número, nome, compositor e dificuldade
/// (do mais fácil) crescentes; recentes e pontuação do maior (mais recente / melhor nota) para o menor.
bool defaultAscendingFor(SortKey key) => switch (key) {
  SortKey.number ||
  SortKey.title ||
  SortKey.composer ||
  SortKey.difficulty => true,
  SortKey.recent || SortKey.score => false,
};

String labelFor(SortKey key) => switch (key) {
  SortKey.number => 'Número',
  SortKey.title => 'Nome',
  SortKey.difficulty => 'Dificuldade',
  SortKey.recent => 'Recentes',
  SortKey.score => 'Pontuação',
  SortKey.composer => 'Compositor',
};

@immutable
class SortState {
  const SortState({this.key = SortKey.number, this.ascending = true});

  final SortKey key;
  final bool ascending;

  /// Toca a mesma chave (inverte a direção) ou troca de chave (volta à
  /// direção padrão dela) — mesma regra do `pick()` do artboard.
  SortState toggled(SortKey tapped) => tapped == key
      ? SortState(key: key, ascending: !ascending)
      : SortState(key: tapped, ascending: defaultAscendingFor(tapped));

  /// '↓' na direção padrão da chave ativa, '↑' na invertida, nada nas
  /// outras — como no artboard.
  String arrowFor(SortKey k) {
    if (k != key) return '';
    return ascending == defaultAscendingFor(k) ? ' ↓' : ' ↑';
  }
}

/// Quem não tem o dado (nunca aberto, sem nota) vai para o fim, em qualquer
/// direção.
int _compareNullLast<T extends Comparable<Object>>(T? a, T? b, bool ascending) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return ascending ? a.compareTo(b) : b.compareTo(a);
}

List<Hymn> sortedHymns(
  Iterable<Hymn> hymns,
  SortState sort,
  HymnProgressStore progress,
) {
  final sign = sort.ascending ? 1 : -1;
  int byNumber(Hymn a, Hymn b) => a.number.compareTo(b.number);
  int cmp(Hymn a, Hymn b) {
    final primary = switch (sort.key) {
      SortKey.number => sign * byNumber(a, b),
      SortKey.title => sign * a.titleKey.compareTo(b.titleKey),
      SortKey.composer => sign * a.composerKey.compareTo(b.composerKey),
      SortKey.difficulty => _compareNullLast(
        a.difficulty,
        b.difficulty,
        sort.ascending,
      ),
      SortKey.recent => _compareNullLast(
        progress[a.number]?.lastOpened,
        progress[b.number]?.lastOpened,
        sort.ascending,
      ),
      SortKey.score => _compareNullLast(
        progress[a.number]?.bestScore,
        progress[b.number]?.bestScore,
        sort.ascending,
      ),
    };
    return primary != 0 ? primary : byNumber(a, b);
  }

  return hymns.toList()..sort(cmp);
}

/// Filtra pelo que foi digitado: todas as palavras têm de aparecer no número,
/// num dos títulos ou num dos autores. Só dígitos = número do hino, e aí o
/// que começa por eles ("12" acha 12 e 120–129).
List<Hymn> filterHymns(List<Hymn> hymns, String query) {
  final words = foldForSearch(query).split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return hymns;
  if (words.length == 1 && int.tryParse(words.first) != null) {
    final digits = int.parse(words.first).toString();
    return hymns.where((h) => '${h.number}'.startsWith(digits)).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }
  return hymns
      .where((h) => words.every((w) => h.searchKey.contains(w)))
      .toList();
}

/// "hoje", "ontem", "há 3 dias"… — mesma escala do artboard.
String whenStudied(DateTime at, DateTime now) {
  final days = DateUtils.dateOnly(now)
      .difference(DateUtils.dateOnly(at))
      .inDays;
  if (days <= 0) return 'hoje';
  if (days == 1) return 'ontem';
  if (days < 7) return 'há $days dias';
  if (days < 14) return 'há 1 semana';
  if (days < 30) return 'há ${(days / 7).round()} semanas';
  if (days < 60) return 'há 1 mês';
  return 'há ${(days / 30).round()} meses';
}

/// Cor da bolinha de pontuação — as faixas do `band()` do artboard.
Color scoreBandColor(int? score) {
  if (score == null) return kScoreNeverColor;
  if (score >= 85) return kGoodColor;
  if (score >= 60) return kOkColor;
  return kLowScoreColor;
}
