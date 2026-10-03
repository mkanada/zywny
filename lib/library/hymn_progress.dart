import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O que o app sabe do estudo de um hino: quando foi aberto pela última vez
/// e a melhor precisão de um treino avaliado (tempo real).
@immutable
class HymnProgress {
  const HymnProgress({this.lastOpened, this.bestScore});

  final DateTime? lastOpened;

  /// 0–100, ou `null` se nenhum treino avaliado terminou ainda.
  final int? bestScore;
}

/// Progresso por hino, guardado num só JSON em [SharedPreferencesAsync].
/// Avisa quem escuta a cada mudança — a biblioteca reordena "Recentes" e
/// "Pontuação" e refaz o cartão "Continuar".
class HymnProgressStore extends ChangeNotifier {
  HymnProgressStore({SharedPreferencesAsync? prefs, DateTime Function()? now})
    : _prefs = prefs ?? SharedPreferencesAsync(),
      _now = now ?? DateTime.now;

  static const _kKey = 'hymn_progress';

  final SharedPreferencesAsync _prefs;
  final DateTime Function() _now;
  final Map<int, HymnProgress> _byNumber = {};

  HymnProgress? operator [](int number) => _byNumber[number];

  /// Número do hino aberto mais recentemente, ou `null` se nenhum.
  int? get lastOpenedNumber {
    int? best;
    DateTime? bestAt;
    _byNumber.forEach((number, p) {
      final at = p.lastOpened;
      if (at != null && (bestAt == null || at.isAfter(bestAt!))) {
        best = number;
        bestAt = at;
      }
    });
    return best;
  }

  Future<void> load() async {
    final text = await _prefs.getString(_kKey);
    if (text == null) return;
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      _byNumber.clear();
      map.forEach((key, value) {
        final v = value as Map<String, dynamic>;
        final at = v['t'] as int?;
        _byNumber[int.parse(key)] = HymnProgress(
          lastOpened: at == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(at),
          bestScore: v['s'] as int?,
        );
      });
    } on Object {
      // JSON estragado: começa do zero em vez de travar a biblioteca.
      _byNumber.clear();
    }
    notifyListeners();
  }

  Future<void> markOpened(int number) {
    _byNumber[number] = HymnProgress(
      lastOpened: _now(),
      bestScore: _byNumber[number]?.bestScore,
    );
    return _save();
  }

  /// Guarda [score] (0–100) se for a melhor do hino até aqui.
  Future<void> recordScore(int number, int score) {
    final current = _byNumber[number];
    final best = current?.bestScore;
    if (best != null && best >= score) return Future.value();
    _byNumber[number] = HymnProgress(
      lastOpened: current?.lastOpened ?? _now(),
      bestScore: score,
    );
    return _save();
  }

  Future<void> _save() {
    notifyListeners();
    return _prefs.setString(
      _kKey,
      jsonEncode({
        for (final e in _byNumber.entries)
          '${e.key}': {
            if (e.value.lastOpened case final at?)
              't': at.millisecondsSinceEpoch,
            's': ?e.value.bestScore,
          },
      }),
    );
  }
}
