import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/ui/courses_screen.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('a lista de cursos abre com o treino de leitura', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CoursesScreen(
          courses: const [],
          progress: CourseProgressStore(prefs: SharedPreferencesAsync()),
          onOpen: (context, course) {},
          onSightReading: (context) async {
            opened++;
          },
        ),
      ),
    );
    expect(find.text('Leitura à primeira vista'), findsOneWidget);
    await tester.tap(find.text('Leitura à primeira vista'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('sem o treino, a lista não mostra o cartão', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoursesScreen(
          courses: const [],
          progress: CourseProgressStore(prefs: SharedPreferencesAsync()),
          onOpen: (context, course) {},
        ),
      ),
    );
    expect(find.text('Leitura à primeira vista'), findsNothing);
  });
}
