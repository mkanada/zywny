import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/score/abc_source.dart' show utf8Bytes;
import 'package:zywny/practice/hand.dart';
import 'package:zywny/sight_reading/sight_generator.dart';
import 'package:zywny/sight_reading/sight_listen.dart';
import 'package:zywny/sight_reading/sight_progress.dart';
import 'package:zywny/sight_reading/sight_reading_source.dart';
import 'package:zywny/sight_reading/sight_score.dart';
import 'package:zywny/sight_reading/sight_steps.dart';
import 'package:zywny_course_format/course_model.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  SightReadingSource source([SightProgress progress = const SightProgress()]) =>
      SightReadingSource(store: SightReadingStore(), progress: progress);

  test(
    'cada rodada é uma partitura em tempo real, com a mão do passo',
    () async {
      final round = await source(const SightProgress(level: 3))
          .nextRound(Random(1));
      expect(round, isA<ScoreRound>());
      final score = round as ScoreRound;
      expect(score.mode, PlayMode.realtime);
      expect(score.hand, Hand.ambas);
      expect(score.speed, 1.0);
      expect(utf8.decode(score.bytes), startsWith('<?xml'));
      expect(
        (await source(
          const SightProgress(level: 2),
        ).nextRound(Random(1)) as ScoreRound).hand,
        Hand.esquerda,
      );
    },
  );

  test('título, meta e identificador seguem o passo atual', () {
    final s = source(const SightProgress(level: 7, sub: 2, clean: 1));
    expect(s.title, 'Leitura 7c');
    expect(s.id, '7c');
    expect(s.goal, '2 limpas para subir');
    expect(s.needsMidi, isTrue);
    expect(s.isRealtime, isTrue);
  });

  test('o veredito diz o que a rodada faz pelo progresso', () {
    final clean = source().verdict([const RoundResult(hits: 4, total: 4)]);
    expect(clean.roundPassed, isTrue);
    expect(clean.reason, '1 de 3 rodadas limpas');
    expect(clean.exercisePassed, isFalse);

    final erro = source().verdict([const RoundResult(hits: 3, total: 4)]);
    expect(erro.roundPassed, isFalse);
    expect(erro.reason, 'com erro: a rodada não conta para subir');

    final concluido = source(const SightProgress(clean: 2))
        .verdict([const RoundResult(hits: 4, total: 4)]);
    expect(concluido.reason, 'passo 1a concluído');
  });

  test('gravar a rodada avança o progresso e guarda', () async {
    final store = SightReadingStore();
    final s = SightReadingSource(store: store, progress: const SightProgress());
    for (var i = 0; i < 3; i++) {
      await s.recordRound(const RoundResult(hits: 4, total: 4));
    }
    expect(s.progress.step.name, '1b');
    expect((await store.load()).step.name, '1b');

    await s.recordRound(const RoundResult(hits: 2, total: 4));
    expect(s.progress.step.name, '1b');
    expect(s.progress.clean, 0);
  });

  test(
    'tocar de novo refaz a mesma partitura, mesmo com o progresso andado',
    () async {
      final s = source(const SightProgress(level: 5));
      expect(s.canRepeatRound, isFalse);

      final first = await s.nextRound(Random(4)) as ScoreRound;
      expect(s.canRepeatRound, isTrue);
      final again = await s.repeatRound() as ScoreRound;
      expect(again.bytes, equals(first.bytes));
      expect(again.fileName, first.fileName);

      // Depois de uma rodada gravada o passo pode mudar; a repetição segue
      // a rodada que foi tocada.
      await s.recordRound(const RoundResult(hits: 4, total: 4));
      s.progress = const SightProgress(level: 9);
      final stillSame = await s.repeatRound() as ScoreRound;
      expect(stillSame.bytes, equals(first.bytes));
    },
  );

  SightReadingSource withEar({
    SightProgress progress = const SightProgress(),
    bool earOn = true,
  }) => SightReadingSource(
    store: SightReadingStore(),
    progress: progress,
    earOn: earOn,
  );

  test('a pergunta de ouvido toca a partitura que a leitura mostra, em todos '
      'os passos', () {
    for (final step in sightSteps) {
      for (var seed = 1; seed <= 20; seed++) {
        final reading = utf8Bytes(
          sightScoreXml(generateSight(step, Random(seed))),
        );
        final ear = sightListenQuestion(step, seed);
        expect(
          ear.compare!.scoreBytes,
          equals(reading),
          reason: '${step.name}, semente $seed',
        );
      }
    }
  });

  test(
    'depois de uma leitura, a pergunta de ouvido é a mesma partitura',
    () async {
      final s = withEar();
      final reading = await s.nextRound(Random(3)) as ScoreRound;
      expect(s.canRepeatRound, isTrue);
      await s.recordRound(const RoundResult(hits: 4, total: 4));
      expect(s.nextRoundLabel, 'Agora, de ouvido');

      final ear = await s.nextRound(Random(99)) as QuestionRound;
      expect(ear.questions, hasLength(1));
      expect(ear.questions.single.compare!.scoreBytes, equals(reading.bytes));
      expect(s.chainsNextRound, isTrue);
      expect(s.canRepeatRound, isFalse);
      expect(s.questionSpec, isA<ListenScoreSpec>());
      expect(s.questionFiles, isNotNull);
    },
  );

  test(
    'pedir a pergunta de ouvido de novo, antes de gravar, devolve a mesma',
    () async {
      final s = withEar();
      await s.nextRound(Random(3));
      await s.recordRound(const RoundResult(hits: 4, total: 4));
      final a = await s.nextRound(Random(1)) as QuestionRound;
      final b = await s.nextRound(Random(2)) as QuestionRound;
      expect(
        b.questions.single.compare!.scoreBytes,
        equals(a.questions.single.compare!.scoreBytes),
      );
      expect(b.questions.single.correct, a.questions.single.correct);
    },
  );

  test(
    'depois da pergunta de ouvido, a próxima rodada é leitura de novo',
    () async {
      final s = withEar();
      await s.nextRound(Random(3));
      await s.recordRound(const RoundResult(hits: 4, total: 4));
      await s.nextRound(Random(3));
      await s.recordRound(const RoundResult(hits: 1, total: 1));
      expect(s.nextRoundLabel, 'Outra rodada');
      expect(await s.nextRound(Random(4)), isA<ScoreRound>());
      expect(s.chainsNextRound, isFalse);
    },
  );

  test('com a chave desligada, leitura segue leitura', () async {
    final s = withEar(earOn: false);
    await s.nextRound(Random(3));
    await s.recordRound(const RoundResult(hits: 4, total: 4));
    expect(s.nextRoundLabel, 'Outra rodada');
    expect(await s.nextRound(Random(3)), isA<ScoreRound>());
  });

  test(
    'a pergunta de ouvido não muda passo nem limpas; conta à parte',
    () async {
      final store = SightReadingStore();
      final s = SightReadingSource(
        store: store,
        progress: const SightProgress(level: 3, sub: 1, clean: 1),
      );
      await s.nextRound(Random(5));
      await s.recordRound(const RoundResult(hits: 4, total: 4));
      expect(s.progress.clean, 2);

      await s.nextRound(Random(5));
      await s.recordRound(const RoundResult(hits: 1, total: 1));
      expect(s.progress.clean, 2);
      expect(s.progress.step.name, '3b');
      expect(s.progress.earHits, 1);
      expect(s.progress.earTotal, 1);
      expect(s.goal, '1 limpa para subir · ouvido 1 de 1');
      expect((await store.load()).earTotal, 1);
    },
  );

  test('o veredito da pergunta de ouvido diz se foi de primeira', () async {
    final s = withEar();
    await s.nextRound(Random(3));
    await s.recordRound(const RoundResult(hits: 4, total: 4));
    await s.nextRound(Random(3));
    final erro = s.verdict([const RoundResult(hits: 0, total: 1)]);
    expect(erro.roundPassed, isFalse);
    expect(erro.reason, 'ouvido: não foi de primeira');
    expect(
      s.verdict([const RoundResult(hits: 1, total: 1)]).reason,
      'ouvido: certo de primeira',
    );
  });
}
