import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sight_steps.dart';

/// Rodadas limpas (sem nenhum erro) que levam ao próximo subnível.
const sightCleanToAdvance = 3;

/// Onde o aluno está no treino: o passo atual e quantas rodadas limpas já
/// fez nele. Rodada com erro não conta e não zera o que já foi feito.
class SightProgress {
  const SightProgress({this.level = 1, this.sub = 0, this.clean = 0});

  /// Lê o JSON guardado; valores fora da faixa são cortados, e o que não
  /// for número volta ao início.
  factory SightProgress.fromJson(Map<String, Object?> json) {
    int read(String key) => json[key] is int ? json[key]! as int : 0;
    final level = read('level');
    final sub = read('sub');
    final clean = read('clean');
    return SightProgress(
      level: level.clamp(1, sightLastLevel),
      sub: sub.clamp(0, sightSubLevels - 1),
      clean: clean.clamp(0, sightCleanToAdvance - 1),
    );
  }

  final int level;
  final int sub;

  /// Rodadas limpas no passo atual, de 0 a 2.
  final int clean;

  SightStep get step => sightStep(level, sub);

  /// Rodadas limpas que faltam para o próximo subnível.
  int get remaining => sightCleanToAdvance - clean;

  /// O progresso depois de uma rodada: [wasClean] diz se ela saiu sem erro.
  SightProgress afterRound({required bool wasClean}) {
    if (!wasClean) return this;
    final next = clean + 1;
    if (next < sightCleanToAdvance) {
      return SightProgress(level: level, sub: sub, clean: next);
    }
    if (sub < sightSubLevels - 1) {
      return SightProgress(level: level, sub: sub + 1);
    }
    if (level < sightLastLevel) {
      return SightProgress(level: level + 1);
    }
    // 20d é o fim: o treino continua nele, sem subir mais.
    return const SightProgress(level: sightLastLevel, sub: sightSubLevels - 1);
  }

  Map<String, Object?> toJson() => {'level': level, 'sub': sub, 'clean': clean};
}

/// Guarda o progresso do treino de leitura no aparelho. Sem armazenamento
/// (modo privado, plataforma sem suporte), o aluno começa do 1a.
class SightReadingStore {
  SightReadingStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const key = 'sight_reading_progress';

  final SharedPreferencesAsync _prefs;

  Future<SightProgress> load() async {
    try {
      final raw = await _prefs.getString(key);
      if (raw == null) return const SightProgress();
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return const SightProgress();
      return SightProgress.fromJson(json);
    } on Object {
      return const SightProgress();
    }
  }

  Future<void> save(SightProgress progress) async {
    try {
      await _prefs.setString(key, jsonEncode(progress.toJson()));
    } on Object {
      // Sem gravar, o progresso vale só nesta sessão.
    }
  }
}
