import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/sight_reading/sight_progress.dart';
import 'package:zywny/sight_reading/sight_steps.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('três rodadas limpas sobem o subnível; rodada com erro não conta', () {
    var p = const SightProgress();
    p = p.afterRound(wasClean: false);
    expect(p.step.name, '1a');
    expect(p.clean, 0);
    for (var i = 0; i < 2; i++) {
      p = p.afterRound(wasClean: true);
    }
    expect(p.step.name, '1a');
    expect(p.remaining, 1);
    p = p.afterRound(wasClean: true);
    expect(p.step.name, '1b');
    expect(p.clean, 0);
  });

  test('quatro subníveis sobem o nível; 20d é o fim do treino', () {
    var p = const SightProgress();
    for (var i = 0; i < 4 * 3; i++) {
      p = p.afterRound(wasClean: true);
    }
    expect(p.level, 2);
    expect(p.sub, 0);
    var last = const SightProgress(level: 20, sub: 3, clean: 2);
    last = last.afterRound(wasClean: true);
    expect(last.step.name, '20d');
    expect(last.clean, 0);
  });

  test('o progresso guardado volta igual e valores estranhos são cortados', () {
    const p = SightProgress(level: 7, sub: 2, clean: 1);
    final back = SightProgress.fromJson(p.toJson());
    expect(back.step.name, '7c');
    expect(back.clean, 1);

    final cut = SightProgress.fromJson({'level': 99, 'sub': -4, 'clean': 9});
    expect(cut.step.name, '20a');
    expect(cut.clean, 2);

    final junk = SightProgress.fromJson({'level': 'x'});
    expect(junk.step.name, '1a');
  });

  test('o store lê e grava; sem nada guardado, começa no 1a', () async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    expect((await store.load()).step.name, '1a');
    await store.save(const SightProgress(level: 4, sub: 1, clean: 2));
    final loaded = await store.load();
    expect(loaded.step.name, '4b');
    expect(loaded.clean, 2);
  });

  test('JSON corrompido não derruba o treino: começa no 1a', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(SightReadingStore.key, '{não é json');
    final store = SightReadingStore(prefs: prefs);
    expect((await store.load()).step.name, '1a');
  });

  test('o ouvido conta à parte: não mexe nas limpas e zera ao subir', () {
    var p = const SightProgress(clean: 1)
        .withEar(hit: true)
        .withEar(hit: false);
    expect(p.earHits, 1);
    expect(p.earTotal, 2);
    expect(p.clean, 1);
    expect(p.step.name, '1a');

    // Rodada com erro não mexe no ouvido; a limpa segue contando.
    expect(p.afterRound(wasClean: false).earTotal, 2);
    p = p.afterRound(wasClean: true);
    expect(p.earTotal, 2);

    final up = p.afterRound(wasClean: true);
    expect(up.step.name, '1b');
    expect(up.earHits, 0);
    expect(up.earTotal, 0);
  });

  test('progresso sem os campos de ouvido lê zero; valores estranhos são '
      'cortados', () {
    final antigo = SightProgress.fromJson({'level': 3, 'sub': 1, 'clean': 2});
    expect(antigo.earHits, 0);
    expect(antigo.earTotal, 0);

    final back = SightProgress.fromJson(
      const SightProgress(level: 4, earHits: 2, earTotal: 3).toJson(),
    );
    expect(back.earHits, 2);
    expect(back.earTotal, 3);

    final cortado = SightProgress.fromJson({'earHits': 9, 'earTotal': 2});
    expect(cortado.earHits, 2);
    expect(cortado.earTotal, 2);
    expect(SightProgress.fromJson({'earTotal': -3}).earTotal, 0);
  });

  test('a chave do ouvido liga por padrão e guarda a escolha', () async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    expect(await store.loadEarOn(), isTrue);
    await store.saveEarOn(false);
    expect(await store.loadEarOn(), isFalse);
  });

  test('o "só ouvido" tem progresso próprio, separado da leitura', () async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    await store.save(const SightProgress(level: 4));
    await store.saveListen(const SightProgress(level: 2, clean: 1));
    expect((await store.load()).step.name, '4a');
    expect((await store.loadListen()).step.name, '2a');
    expect((await store.loadListen()).clean, 1);
  });

  test(
    'voltar a um passo zera as rodadas e o ouvido; antes dele fica atrás',
    () {
      const p = SightProgress(
        level: 5,
        sub: 2,
        clean: 2,
        earHits: 3,
        earTotal: 4,
      );
      final back = SightProgress.startOf(sightStep(3, 1));
      expect(back.step.name, '3b');
      expect(back.clean, 0);
      expect(back.earTotal, 0);

      expect(p.isBehind(sightStep(5, 1)), isTrue);
      expect(p.isBehind(sightStep(1, 0)), isTrue);
      expect(p.isBehind(sightStep(5, 2)), isFalse);
      expect(p.isBehind(sightStep(5, 3)), isFalse);
      expect(const SightProgress().isBehind(sightSteps.first), isFalse);
    },
  );
}
