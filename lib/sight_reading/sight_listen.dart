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
/// "igual" ou "diferente", ou a nota que soou diferente, tocada na partitura
/// (E10: sem botões; a resposta são os `changedIds`).
enum SightAnswer { measure, sameDifferent, note }

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
      // Sem lugar para o sorteado (um ritmo sem figura para dividir ou juntar),
      // outro dos sorteáveis na mesma partitura: a leitura e a pergunta têm de
      // tocar a mesma. Só com [change] fixa a semente passa à próxima.
      if (changed == null && change == null) {
        for (final other in kinds) {
          if (other == kind) continue;
          changed = changeSight(step, written, other, rng);
          if (changed != null) break;
        }
      }
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
      reference: sightChordMidis(step),
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
      // Sem botões: a resposta é a nota tocada (`QuestionSession.answerNote`).
      SightAnswer.note => Question(compare: compare),
    };
  }
  throw StateError('nenhuma mudança cabe no passo ${step.name}');
}

/// As perguntas de um ditado de [step] com [seed] (E09, `answer: dictation`):
/// uma por nota da pauta ditada, menos a primeira, que vem escrita. A pauta é
/// a de sol, ou a de fá num passo `left`; num passo de duas mãos, a de fá
/// soa junto. Todas levam a mesma [ScoreComparison]: a frase toca uma vez e a
/// revelação mostra a partitura de verdade. [bpm] `null` usa `sightListenBpm`.
List<Question> sightDictationQuestions(SightStep step, int seed, {int? bpm}) {
  final ex = generateSight(step, Random(seed));
  final staff = step.hands == SightHands.left ? 2 : 1;
  final events = sightEvents(ex);
  final notes = sightTimedNotes(step, events, bpm: bpm ?? sightListenBpm(step));
  final compare = ScoreComparison(
    scoreBytes: utf8Bytes(sightScoreXml(ex)),
    fileName: 'ditado-${step.name}.musicxml',
    promptBytes: utf8Bytes(sightRhythmXml(ex, staff: staff)),
    played: notes,
    written: notes,
    changedIds: const {},
    reference: sightChordMidis(step),
  );
  return [
    // `sightEvents` está em ordem de começo, então a primeira da pauta é a
    // primeira que sai dela: essa vem escrita e não é perguntada.
    for (final e in events.where((e) => e.staff == staff).skip(1))
      Question(
        expectedPitch: e.midi,
        anyOctave: true,
        highlightId: e.ids.single,
        compare: compare,
      ),
  ];
}
