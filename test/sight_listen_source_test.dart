import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/sight_reading/sight_listen_source.dart';
import 'package:zywny/sight_reading/sight_progress.dart';
import 'package:zywny_course_format/course_model.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  SightListenSource source({
    SightReadingStore? store,
    SightProgress progress = const SightProgress(),
  }) => SightListenSource(
    store: store ?? SightReadingStore(),
    progress: progress,
  );

  test('cada rodada tem 5 perguntas "Onde mudou?", sem teclado', () async {
    final s = source();
    final round = await s.nextRound(Random(1)) as QuestionRound;
    expect(round.questions, hasLength(kSightListenCount));
    expect(s.needsMidi, isFalse);
    expect(s.isQuestion, isTrue);
    expect(s.canRepeatRound, isFalse);
    expect(s.title, 'Ouvido 1a');
    expect(s.goal, '3 limpas para subir');

    final spec = s.questionSpec as ListenScoreSpec;
    expect(spec.count, 5);
    expect(spec.pass.accuracy, 80);
    expect(spec.answer, ScoreAnswer.measure);
  });

  test('até o nível 6, a resposta é o compasso, com botões (E10)', () async {
    final s = source(progress: const SightProgress(level: 6));
    final round = await s.nextRound(Random(1)) as QuestionRound;
    for (final q in round.questions) {
      expect(q.answers, hasLength(4));
      expect(q.correct, isNotNull);
    }
    expect((s.questionSpec as ListenScoreSpec).answer, ScoreAnswer.measure);
  });

  test('do nível 7, a resposta é a nota tocada: sem botões, com os '
      'changedIds (E10)', () async {
    final s = source(progress: const SightProgress(level: 7));
    final round = await s.nextRound(Random(1)) as QuestionRound;
    expect(round.questions, hasLength(kSightListenCount));
    for (final q in round.questions) {
      expect(q.answers, isEmpty);
      expect(q.correct, isNull);
      expect(q.compare!.changedIds, isNotEmpty);
    }
    final spec = s.questionSpec as ListenScoreSpec;
    expect(spec.answer, ScoreAnswer.note);
    expect(spec.count, kSightListenCount);
  });

  test('4 de 5 de primeira contam como limpa; 3 não', () {
    final limpa = source().verdict([const RoundResult(hits: 4, total: 5)]);
    expect(limpa.roundPassed, isTrue);
    expect(limpa.reason, '1 de 3 rodadas limpas');

    final erro = source().verdict([const RoundResult(hits: 3, total: 5)]);
    expect(erro.roundPassed, isFalse);
    expect(
      erro.reason,
      'menos de 4 de primeira: a rodada não conta para subir',
    );
  });

  test('três rodadas limpas sobem um passo; as outras não contam', () async {
    final store = SightReadingStore();
    final s = source(store: store);
    await s.nextRound(Random(1));
    await s.recordRound(const RoundResult(hits: 3, total: 5));
    expect(s.progress.clean, 0);
    for (var i = 0; i < 3; i++) {
      await s.recordRound(const RoundResult(hits: 4, total: 5));
    }
    expect(s.progress.step.name, '1b');
    expect((await store.loadListen()).step.name, '1b');
  });

  test('grava no progresso do só ouvido, sem mexer no da leitura', () async {
    final store = SightReadingStore();
    final s = source(store: store);
    await s.nextRound(Random(1));
    await s.recordRound(const RoundResult(hits: 5, total: 5));
    expect((await store.loadListen()).clean, 1);
    expect(
      await SharedPreferencesAsync().getString(SightReadingStore.key),
      isNull,
    );
  });
}
