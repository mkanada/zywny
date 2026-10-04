import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'library_keys.dart';
import 'piece.dart' show kHymnsLibraryId;

/// O que o app sabe do estudo de um hino: quando foi aberto pela última vez
/// e a melhor precisão de um treino avaliado (tempo real).
@immutable
class PieceProgress {
  const PieceProgress({this.lastOpened, this.bestScore});

  final DateTime? lastOpened;

  /// 0–100, ou `null` se nenhum treino avaliado terminou ainda.
  final int? bestScore;
}

/// Progresso por música de uma biblioteca, guardado num só JSON por
/// biblioteca em [SharedPreferencesAsync] (`lib_progress_<biblioteca>`, mapa
/// id → `{t, s}`). Avisa quem escuta a cada mudança — a biblioteca reordena
/// "Recentes" e "Pontuação" e refaz o cartão "Continuar".
///
/// Vale para uma biblioteca por vez: [load] diz qual (a em uso); trocar de
/// biblioteca é chamar [load] de novo.
class PieceProgressStore extends ChangeNotifier {
  PieceProgressStore({SharedPreferencesAsync? prefs, DateTime Function()? now})
    : _prefs = prefs ?? SharedPreferencesAsync(),
      _now = now ?? DateTime.now;

  final SharedPreferencesAsync _prefs;
  final DateTime Function() _now;
  final Map<String, PieceProgress> _byId = {};
  String _libraryId = kHymnsLibraryId;

  String get libraryId => _libraryId;

  PieceProgress? operator [](String id) => _byId[id];

  /// Id da música aberta mais recentemente, ou `null` se nenhuma.
  String? get lastOpenedId {
    String? best;
    DateTime? bestAt;
    _byId.forEach((id, p) {
      final at = p.lastOpened;
      if (at != null && (bestAt == null || at.isAfter(bestAt!))) {
        best = id;
        bestAt = at;
      }
    });
    return best;
  }

  /// Lê o progresso de [libraryId] (a que ficou em uso, se omitido).
  Future<void> load([String? libraryId]) async {
    if (libraryId != null) _libraryId = libraryId;
    _byId.clear();
    final text = await _prefs.getString(progressKeyFor(_libraryId));
    if (text != null) {
      try {
        final map = jsonDecode(text) as Map<String, dynamic>;
        map.forEach((id, value) {
          final v = value as Map<String, dynamic>;
          final at = v['t'] as int?;
          _byId[id] = PieceProgress(
            lastOpened: at == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(at),
            bestScore: v['s'] as int?,
          );
        });
      } on Object {
        // JSON estragado: começa do zero em vez de travar a biblioteca.
        _byId.clear();
      }
    }
    notifyListeners();
  }

  Future<void> markOpened(String id) {
    _byId[id] = PieceProgress(
      lastOpened: _now(),
      bestScore: _byId[id]?.bestScore,
    );
    return _save();
  }

  /// Guarda [score] (0–100) se for a melhor da música até aqui.
  Future<void> recordScore(String id, int score) {
    final current = _byId[id];
    final best = current?.bestScore;
    if (best != null && best >= score) return Future.value();
    _byId[id] = PieceProgress(
      lastOpened: current?.lastOpened ?? _now(),
      bestScore: score,
    );
    return _save();
  }

  Future<void> _save() {
    notifyListeners();
    return _prefs.setString(
      progressKeyFor(_libraryId),
      jsonEncode({
        for (final e in _byId.entries)
          e.key: {
            if (e.value.lastOpened case final at?)
              't': at.millisecondsSinceEpoch,
            's': ?e.value.bestScore,
          },
      }),
    );
  }
}
