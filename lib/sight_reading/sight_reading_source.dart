import 'dart:math';

import 'package:flutter/material.dart';
import 'package:zywny_course_format/course_model.dart';

import 'package:zywny_course_format/course_files.dart';

import '../course/exercise/exercise_round.dart';
import '../course/exercise/pass_check.dart';
import '../course/score/abc_source.dart' show utf8Bytes;
import '../course/ui/course_flow.dart';
import '../course/ui/exercise_screen.dart';
import '../course/ui/exercise_source.dart';
import '../practice/hand.dart';
import 'sight_generator.dart';
import 'sight_listen.dart';
import 'sight_progress.dart';
import 'sight_score.dart';
import 'sight_steps.dart';

/// O treino de leitura à primeira vista como fonte da tela de exercício. Cada
/// rodada é uma partitura nova do passo atual, tocada em tempo real no
/// andamento do passo.
///
/// Com [earOn] (E08), cada leitura é seguida de uma pergunta de ouvido sobre
/// a mesma partitura ("Onde mudou?"). A pergunta não conta para subir de passo.
class SightReadingSource implements ExerciseSource {
  SightReadingSource({
    required this.store,
    required this.progress,
    this.earOn = true,
  });

  final SightReadingStore store;

  /// O progresso até a última rodada gravada.
  SightProgress progress;

  /// Depois de cada leitura, a pergunta de ouvido (D-LEI-ONDE).
  final bool earOn;

  /// A próxima rodada é a de ouvido sobre a última leitura.
  bool _earNext = false;

  /// A última rodada entregue foi a de ouvido.
  bool _lastWasEar = false;

  @override
  String get title => 'Leitura ${progress.step.name}';

  @override
  String get id => progress.step.name;

  /// Quantas rodadas limpas faltam para o próximo subnível, e (com perguntas
  /// de ouvido) quantas foram certas de primeira.
  @override
  String get goal {
    final left = progress.remaining;
    final base = '$left ${left == 1 ? 'limpa' : 'limpas'} para subir';
    final p = progress;
    return p.earTotal > 0
        ? '$base · ouvido ${p.earHits} de ${p.earTotal}'
        : base;
  }

  @override
  double get startSpeed => 1.0;

  @override
  bool get needsMidi => true;

  @override
  bool get isQuestion => false;

  @override
  bool get isRealtime => true;

  /// Não há melhor % guardado: o progresso é por passo, não por rodada.
  @override
  int? get bestPercent => null;

  /// O passo e a semente da última rodada sorteada: [repeatRound] refaz a
  /// mesma partitura a partir deles, mesmo que o progresso já tenha andado.
  SightStep? _lastStep;
  int? _lastSeed;

  /// Com [_earNext], a pergunta de ouvido sobre a última leitura. Ela fica
  /// pronta até [recordRound]: se a tela pedir de novo antes (a caixa da
  /// partitura mudou de tamanho), a mesma pergunta volta.
  @override
  Future<ExerciseRound> nextRound(Random rng) async {
    if (_earNext) {
      _lastWasEar = true;
      return QuestionRound([sightListenQuestion(_lastStep!, _lastSeed!)]);
    }
    _lastWasEar = false;
    _lastStep = progress.step;
    _lastSeed = rng.nextInt(1 << 31);
    return _round(_lastStep!, _lastSeed!);
  }

  /// Não se repete a pergunta de ouvido: a leitura é que se refaz.
  @override
  bool get canRepeatRound => _lastSeed != null && !_lastWasEar;

  @override
  Future<ExerciseRound> repeatRound() => _round(_lastStep!, _lastSeed!);

  /// O `spec` da pergunta de ouvido, montado com o passo da última leitura.
  @override
  ExerciseSpec? get questionSpec {
    final step = _lastStep;
    if (step == null) return null;
    return ListenScoreSpec(
      id: 'leitura-ouvido',
      title: 'Onde mudou?',
      pass: const PassCriteria(accuracy: 100),
      line: 0,
      step: step.name,
      change: ScoreChange.pitch,
      answer: ScoreAnswer.measure,
      count: 1,
      bpm: null,
    );
  }

  @override
  CourseFiles get questionFiles => MemoryCourseFiles(const {});

  /// A pergunta de ouvido emenda na próxima leitura, sem painel.
  @override
  bool get chainsNextRound => _lastWasEar;

  @override
  String get nextRoundLabel => _earNext ? 'Agora, de ouvido' : 'Outra rodada';

  Future<ExerciseRound> _round(SightStep step, int seed) async {
    final xml = sightScoreXml(generateSight(step, Random(seed)));
    return ScoreRound(
      bytes: utf8Bytes(xml),
      fileName: 'leitura-${step.name}.musicxml',
      mode: PlayMode.realtime,
      hand: _handOf(step.hands),
    );
  }

  /// A rodada conta se saiu sem erro. O veredito descreve o que a rodada
  /// faz pelo progresso, antes de gravar.
  @override
  PassVerdict verdict(List<RoundResult> history) {
    final last = history.last;
    final clean = last.hits >= last.total;
    if (_lastWasEar) {
      return PassVerdict(
        roundPassed: clean,
        streak: progress.clean,
        exercisePassed: false,
        reason: clean
            ? 'ouvido: certo de primeira'
            : 'ouvido: não foi de primeira',
      );
    }
    final next = progress.afterRound(wasClean: clean);
    final String reason;
    if (!clean) {
      reason = 'com erro: a rodada não conta para subir';
    } else if (next.clean == 0) {
      reason = 'passo ${progress.step.name} concluído';
    } else {
      reason = '${next.clean} de $sightCleanToAdvance rodadas limpas';
    }
    return PassVerdict(
      roundPassed: clean,
      streak: next.clean,
      exercisePassed: false,
      reason: reason,
    );
  }

  @override
  Future<void> recordRound(RoundResult result) async {
    final clean = result.hits >= result.total;
    if (_lastWasEar) {
      progress = progress.withEar(hit: clean);
      _earNext = false;
    } else {
      progress = progress.afterRound(wasClean: clean);
      _earNext = earOn;
    }
    await store.save(progress);
  }
}

Hand _handOf(SightHands hands) => switch (hands) {
  SightHands.right => Hand.direita,
  SightHands.left => Hand.esquerda,
  SightHands.both => Hand.ambas,
};

/// Abre o treino de leitura à primeira vista no passo em que o aluno parou.
Future<void> openSightReading(
  BuildContext context,
  CourseScreenDeps deps, {
  SightReadingStore? store,
}) async {
  final reading = store ?? SightReadingStore();
  final progress = await reading.load();
  final earOn = await reading.loadEarOn();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExerciseScreen.source(
        source: SightReadingSource(
          store: reading,
          progress: progress,
          earOn: earOn,
        ),
        deps: deps,
      ),
    ),
  );
}
