// I09, critério 1 — `test/course_progress_test.dart`: aprovação e `streak`
// gravados e relidos; `lessonOpen` com `requires`; órfão ignorado e
// recuperado; aprovado continua aprovado após reprovar.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/exercise/exercise_round.dart';
import 'package:zywny/course/format/course_files.dart';
import 'package:zywny/course/format/course_model.dart';
import 'package:zywny/course/format/course_reader.dart';

MemoryCourseFiles _twoLessons() => MemoryCourseFiles({
  'course.md':
      '---\nformat: 1\nid: t\ntitle: T\nauthor: a\nversion: "1"\n'
      'lessons: [a, b]\n---\n\nOi.\n',
  'lessons/01-a.md':
      '---\nid: a\ntitle: Primeira\n---\n\n'
      '```zywny-exercise\nid: ex-a\ntype: play-notes\ntitle: Toque A\n'
      'clef: treble\nnotes: {random: C4-G4, count: 12}\npass: {accuracy: 90}\n```\n',
  'lessons/02-b.md':
      '---\nid: b\ntitle: Segunda\nrequires: [a]\n---\n\n'
      '```zywny-exercise\nid: ex-b\ntype: play-notes\ntitle: Toque B\n'
      'clef: treble\nnotes: {random: C4-G4, count: 12}\n'
      'pass: {accuracy: 90, rounds: 3}\n```\n',
});

Future<Course> _course() async {
  final result = await readCourse(_twoLessons());
  expect(result.course, isNotNull, reason: result.issues.join('\n'));
  return result.course!;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('aprovação e streak gravados e relidos', () async {
    final course = await _course();
    final spec = course.lessons.first.exercises.single;
    final store = CourseProgressStore();
    await store.recordAttempt('t', spec, const RoundResult(hits: 12, total: 12));
    final progress = store['t'];
    expect(progress.records['ex-a']?.passed, isTrue);
    expect(progress.records['ex-a']?.streak, 1);
    expect(progress.records['ex-a']?.bestPercent, 100);
    expect(progress.lessonDone(course.lessons.first), isTrue);

    final reloaded = CourseProgressStore();
    await reloaded.ensureLoaded('t');
    expect(reloaded['t'], progress);
  });

  test('lessonOpen com requires de duas lições', () async {
    final course = await _course();
    final store = CourseProgressStore();
    final a = course.lessons[0];
    final b = course.lessons[1];
    expect(store['t'].lessonOpen(a, course), isTrue);
    expect(store['t'].lessonOpen(b, course), isFalse);
    expect(store['t'].missingFor(b, course), ['Primeira']);
    await store.recordAttempt(
      't',
      a.exercises.single,
      const RoundResult(hits: 12, total: 12),
    );
    expect(store['t'].lessonOpen(b, course), isTrue);
    expect(store['t'].missingFor(b, course), isEmpty);
  });

  test('rounds: 3 só aprova na terceira seguida', () async {
    final course = await _course();
    final spec = course.lessons[1].exercises.single;
    final store = CourseProgressStore();
    const good = RoundResult(hits: 12, total: 12);
    await store.recordAttempt('t', spec, good);
    await store.recordAttempt('t', spec, good);
    expect(store['t'].records['ex-b']?.passed, isFalse);
    expect(store['t'].records['ex-b']?.streak, 2);
    await store.recordAttempt('t', spec, good);
    expect(store['t'].records['ex-b']?.passed, isTrue);
    expect(store['t'].records['ex-b']?.streak, 3);
  });

  test('registro órfão ignorado e recuperado', () async {
    final course = await _course();
    final spec = course.lessons.first.exercises.single;
    final store = CourseProgressStore();
    await store.recordAttempt('t', spec, const RoundResult(hits: 12, total: 12));
    // O exercício sai do curso: some das contas, mas fica guardado.
    final orphan = store['t'].records['ex-a'];
    expect(orphan?.passed, isTrue);
    final counts = store['t'].lessonCounts(
      Course(
        format: 1,
        id: 't',
        title: 'T',
        author: 'a',
        version: '1',
        intro: '',
        lessons: [course.lessons[1]],
      ),
    );
    expect(counts.done, 0);
    // Relido do disco, o órfão continua lá — e volta a valer com o id.
    final reloaded = CourseProgressStore();
    await reloaded.ensureLoaded('t');
    expect(reloaded['t'].records['ex-a'], orphan);
    expect(reloaded['t'].lessonDone(course.lessons.first), isTrue);
  });

  test('aprovado continua aprovado após reprovar', () async {
    final course = await _course();
    final spec = course.lessons.first.exercises.single;
    final store = CourseProgressStore();
    await store.recordAttempt('t', spec, const RoundResult(hits: 12, total: 12));
    await store.recordAttempt('t', spec, const RoundResult(hits: 0, total: 12));
    final record = store['t'].records['ex-a']!;
    expect(record.passed, isTrue);
    expect(record.streak, 0);
    expect(record.bestPercent, 100);
    expect(store['t'].lessonDone(course.lessons.first), isTrue);
  });

  test('lição sem exercício: Concluir e último toque', () async {
    final store = MemoryCourseProgressStore();
    await store.touchLesson('t', 'aula');
    expect(store['t'].lastLessonId, 'aula');
    const lesson = Lesson(
      id: 'aula',
      title: 'Texto',
      requires: [],
      fileName: 'lessons/01-aula.md',
      blocks: [],
    );
    expect(store['t'].lessonDone(lesson), isFalse);
    await store.markLessonDone('t', 'aula');
    expect(store['t'].lessonDone(lesson), isTrue);
  });
}
