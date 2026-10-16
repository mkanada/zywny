import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'sight_steps.dart';

/// Rodadas limpas (sem nenhum erro) que levam ao próximo subnível.
const sightCleanToAdvance = 3;

/// Onde o aluno está no treino: o passo atual e quantas rodadas limpas já
/// fez nele. Rodada com erro não conta e não zera o que já foi feito.
///
/// [earHits] e [earTotal] são as perguntas de ouvido (E08) deste passo: quantas
/// foram certas de primeira e quantas foram feitas. Não contam para subir de
/// passo (D-LEI-PROGRESSO) e zeram ao subir.
class SightProgress {
  const SightProgress({
    this.level = 1,
    this.sub = 0,
    this.clean = 0,
    this.earHits = 0,
    this.earTotal = 0,
  });

  /// Lê o JSON guardado; valores fora da faixa são cortados, e o que não
  /// for número volta ao início. Sem os campos de ouvido (progresso antigo),
  /// eles começam em zero.
  factory SightProgress.fromJson(Map<String, Object?> json) {
    int read(String key) => json[key] is int ? json[key]! as int : 0;
    final level = read('level');
    final sub = read('sub');
    final clean = read('clean');
    final earTotal = max(0, read('earTotal'));
    return SightProgress(
      level: level.clamp(1, sightLastLevel),
      sub: sub.clamp(0, sightSubLevels - 1),
      clean: clean.clamp(0, sightCleanToAdvance - 1),
      earHits: read('earHits').clamp(0, earTotal),
      earTotal: earTotal,
    );
  }

  final int level;
  final int sub;

  /// Rodadas limpas no passo atual, de 0 a 2.
  final int clean;

  /// Perguntas de ouvido no passo atual: certas de primeira, e no total.
  final int earHits;
  final int earTotal;

  SightStep get step => sightStep(level, sub);

  /// Rodadas limpas que faltam para o próximo subnível.
  int get remaining => sightCleanToAdvance - clean;

  /// O começo de [step]: sem rodadas limpas nem perguntas de ouvido, que
  /// contam só no passo em que foram feitas.
  factory SightProgress.startOf(SightStep step) =>
      SightProgress(level: step.level, sub: step.sub);

  /// Se [step] ficou para trás: o aluno já está num passo depois dele.
  bool isBehind(SightStep step) =>
      step.level < level || (step.level == level && step.sub < sub);

  /// Conta uma pergunta de ouvido: [hit] diz se foi certa de primeira.
  SightProgress withEar({required bool hit}) => SightProgress(
    level: level,
    sub: sub,
    clean: clean,
    earHits: earHits + (hit ? 1 : 0),
    earTotal: earTotal + 1,
  );

  /// O progresso depois de uma rodada: [wasClean] diz se ela saiu sem erro.
  /// Os contadores de ouvido seguem enquanto o passo é o mesmo.
  SightProgress afterRound({required bool wasClean}) {
    if (!wasClean) return this;
    final next = clean + 1;
    if (next < sightCleanToAdvance) {
      return SightProgress(
        level: level,
        sub: sub,
        clean: next,
        earHits: earHits,
        earTotal: earTotal,
      );
    }
    if (sub < sightSubLevels - 1) {
      return SightProgress(level: level, sub: sub + 1);
    }
    if (level < sightLastLevel) {
      return SightProgress(level: level + 1);
    }
    // 20d é o fim: o treino continua nele, sem subir mais.
    return SightProgress(
      level: sightLastLevel,
      sub: sightSubLevels - 1,
      earHits: earHits,
      earTotal: earTotal,
    );
  }

  Map<String, Object?> toJson() => {
    'level': level,
    'sub': sub,
    'clean': clean,
    'earHits': earHits,
    'earTotal': earTotal,
  };
}

/// Guarda o progresso do treino de leitura no aparelho. Sem armazenamento
/// (modo privado, plataforma sem suporte), o aluno começa do 1a.
///
/// Guarda também a chave "Ouvido depois de cada leitura" e o progresso do
/// "só ouvido", que é separado do da leitura.
class SightReadingStore {
  SightReadingStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const key = 'sight_reading_progress';
  static const earOnKey = 'sight_reading_ear_on';
  static const listenKey = 'sight_listen_progress';

  final SharedPreferencesAsync _prefs;

  Future<SightProgress> load() => _load(key);

  Future<void> save(SightProgress progress) => _save(key, progress);

  /// O progresso do "só ouvido" (os campos de ouvido não são usados ali).
  Future<SightProgress> loadListen() => _load(listenKey);

  Future<void> saveListen(SightProgress progress) => _save(listenKey, progress);

  /// Ouvido depois de cada leitura: ligado se nada foi guardado.
  Future<bool> loadEarOn() async {
    try {
      return await _prefs.getBool(earOnKey) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> saveEarOn(bool on) async {
    try {
      await _prefs.setBool(earOnKey, on);
    } on Object {
      // Sem gravar, vale o padrão (ligado) na próxima vez.
    }
  }

  Future<SightProgress> _load(String key) async {
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

  Future<void> _save(String key, SightProgress progress) async {
    try {
      await _prefs.setString(key, jsonEncode(progress.toJson()));
    } on Object {
      // Sem gravar, o progresso vale só nesta sessão.
    }
  }
}
