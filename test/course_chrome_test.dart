import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/score/lesson_score.dart';
import 'package:zywny/course/ui/course_chrome.dart';
import 'package:zywny/render/layout_options.dart' show kPhoneUnit;
import 'package:zywny/settings/app_settings.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('partitura da lição no celular usa o unit dos hinos', () {
    expect(lessonScoreLayout(800, phone: true).options['unit'], kPhoneUnit);
    expect(lessonScoreLayout(800, phone: false).options['unit'], 6);
  });

  test('tamanho do texto fica nos limites e sobrevive a reabrir', () async {
    final settings = AppSettings()..courseTextScale = 9;
    expect(settings.courseTextScale, kMaxCourseTextScale);
    settings.courseTextScale = 1.3;
    await Future<void>.delayed(Duration.zero);
    final again = AppSettings();
    await again.load();
    expect(again.courseTextScale, 1.3);
  });

  testWidgets('o "Aa" aumenta o texto e o cabeçalho some deitado', (
    tester,
  ) async {
    final settings = AppSettings();
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CourseScrollScaffold(
          settings: settings,
          backgroundColor: Colors.white,
          title: const Text('Curso'),
          actions: [CourseTextSizeButton(settings: settings)],
          children: [
            for (var i = 0; i < 40; i++) Text('linha $i', key: ValueKey(i)),
          ],
        ),
      ),
    );
    double scaleOf(Finder f) =>
        MediaQuery.textScalerOf(tester.element(f)).scale(10) / 10;
    expect(scaleOf(find.byKey(const ValueKey(0))), 1.0);

    await tester.tap(find.byTooltip('Tamanho do texto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar o texto'));
    await tester.pumpAndSettle();
    expect(find.text('115%'), findsOneWidget);
    expect(settings.courseTextScale, 1.15);
    Navigator.of(tester.element(find.text('115%'))).pop();
    await tester.pumpAndSettle();
    expect(scaleOf(find.byKey(const ValueKey(0))), closeTo(1.15, 1e-9));

    // Deitado (360 de altura): o cabeçalho é baixo e sai ao rolar.
    expect(tester.getSize(find.byType(AppBar)).height, lessThan(80));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Curso'), findsNothing);
  });
}
