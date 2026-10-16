import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/sight_reading/sight_levels_screen.dart';
import 'package:zywny/sight_reading/sight_progress.dart';
import 'package:zywny/sight_reading/sight_steps.dart';

Future<void> _pumpLevels(WidgetTester tester, SightReadingStore store) async {
  await tester.pumpWidget(MaterialApp(home: SightLevelsScreen(store: store)));
  // O progresso guardado chega de forma assíncrona; a lista aparece depois.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('lista os 20 níveis com a descrição de cada passo', (
    tester,
  ) async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    await tester.runAsync(
      () => store.save(const SightProgress(level: 2, sub: 1, clean: 1)),
    );
    await _pumpLevels(tester, store);

    expect(find.text('Nível 1'), findsOneWidget);
    expect(find.text(sightStep(1, 0).label), findsOneWidget);
    expect(
      find.text('Você está no 2b: ${sightStep(2, 1).label}.'),
      findsOneWidget,
    );
    expect(find.text('agora · 1 de 3 limpas'), findsOneWidget);
    expect(find.text('feito · toque para voltar aqui'), findsWidgets);
    expect(find.text('depois'), findsWidgets);

    // A lista é preguiçosa: o fim só aparece rolando.
    await tester.scrollUntilVisible(find.text('Nível 20'), 500);
    expect(find.text('Nível 20'), findsOneWidget);
    expect(find.text(sightStep(20, 3).label), findsOneWidget);
  });

  testWidgets('voltar a um passo feito pede confirmação e grava o passo', (
    tester,
  ) async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    await tester.runAsync(
      () => store.save(const SightProgress(level: 3, sub: 2, clean: 2)),
    );
    await _pumpLevels(tester, store);

    await tester.ensureVisible(find.text(sightStep(2, 1).label));
    await tester.pump();
    await tester.tap(find.text(sightStep(2, 1).label));
    await tester.pumpAndSettle();
    expect(find.text('Voltar ao 2b?'), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(store.load);
    expect(saved!.step.name, '2b');
    expect(saved.clean, 0);
    expect(find.text('agora · 0 de 3 limpas'), findsOneWidget);
  });

  testWidgets('cancelar a volta não muda o progresso', (tester) async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    await tester.runAsync(
      () => store.save(const SightProgress(level: 3, sub: 2)),
    );
    await _pumpLevels(tester, store);

    await tester.ensureVisible(find.text(sightStep(2, 1).label));
    await tester.pump();
    await tester.tap(find.text(sightStep(2, 1).label));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(store.load);
    expect(saved!.step.name, '3c');
  });

  testWidgets('um passo à frente não se abre', (tester) async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    await _pumpLevels(tester, store);

    await tester.ensureVisible(find.text(sightStep(2, 0).label));
    await tester.pump();
    await tester.tap(find.text(sightStep(2, 0).label));
    await tester.pumpAndSettle();
    expect(find.text('Voltar ao 2a?'), findsNothing);
  });

  testWidgets('reiniciar a leitura leva ao 1a', (tester) async {
    final store = SightReadingStore(prefs: SharedPreferencesAsync());
    await tester.runAsync(
      () => store.save(const SightProgress(level: 7, sub: 1, clean: 2)),
    );
    await _pumpLevels(tester, store);

    await tester.scrollUntilVisible(find.text('Reiniciar a leitura'), 500);
    await tester.tap(find.text('Reiniciar a leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Reiniciar a leitura?'), findsOneWidget);
    await tester.tap(find.text('Reiniciar'));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(store.load);
    expect(saved!.step.name, '1a');
    expect(saved.clean, 0);
  });
}
