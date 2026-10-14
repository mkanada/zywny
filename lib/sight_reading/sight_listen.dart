// E05 — a pergunta de ouvido sobre a partitura do treino de leitura: o zywny
// toca a frase escrita, com uma diferença (ou nenhuma) e o aluno diz onde.

import 'dart:math';

import '../course/exercise/exercise_round.dart';
import '../course/score/abc_source.dart' show utf8Bytes;
import 'sight_change.dart';
import 'sight_generator.dart';
import 'sight_phrase.dart';
import 'sight_score.dart';
import 'sight_steps.dart';

/// Como o aluno responde a pergunta de ouvido: o compasso da mudança, ou
/// "igual" ou "diferente".
enum SightAnswer { measure, sameDifferent }

/// A pergunta de ouvido sobre a partitura de [step] sorteada com [seed]. A
/// partitura é a mesma que o treino de leitura monta com essa semente. [change]
/// `null` sorteia entre `sightChangesFor(step)`. Com [SightAnswer.sameDifferent],
/// metade das vezes nada muda. [bpm] `null` usa `sightListenBpm`.
Question sightListenQuestion(
  SightStep step,
  int seed, {
  SightChange? change,
  SightAnswer answer = SightAnswer.measure,
  int? bpm,
}) {
  final tempo = bpm ?? sightListenBpm(step);
  final kinds = sightChangesFor(step);
  for (var attempt = 0; attempt < 50; attempt++) {
    final s = seed + attempt;
    final ex = generateSight(step, Random(s));
    final written = sightEvents(ex);
    final rng = Random(s ^ 0x5eed);
    final same = answer == SightAnswer.sameDifferent && rng.nextBool();
    SightChanged? changed;
    if (!same) {
      final kind = change ?? kinds[rng.nextInt(kinds.length)];
      changed = changeSight(step, written, kind, rng);
      if (changed == null) continue;
    }
    final compare = ScoreComparison(
      scoreBytes: utf8Bytes(sightScoreXml(ex)),
      fileName: 'ouvido-${step.name}.musicxml',
      played: sightTimedNotes(step, changed?.played ?? written, bpm: tempo),
      written: sightTimedNotes(step, written, bpm: tempo),
      changedIds: changed?.changedIds ?? const <String>{},
      measure: changed?.measure,
      description: changed?.description,
    );
    return switch (answer) {
      SightAnswer.measure => Question(
        answers: [for (var m = 1; m <= sightMeasures; m++) '$m'],
        correct: changed!.measure,
        compare: compare,
      ),
      SightAnswer.sameDifferent => Question(
        answers: const ['Igual', 'Diferente'],
        correct: changed == null ? 0 : 1,
        compare: compare,
      ),
    };
  }
  throw StateError('nenhuma mudança cabe no passo ${step.name}');
}
