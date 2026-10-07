// I09 — lista de cursos (retrato): um cartão por curso com título, autor,
// "X de Y lições", barra e "Continuar: <lição>". O embutido primeiro
// (a ordem da lista recebida); nesta etapa, o embutido (I10) e cursos de
// fixture nos testes.

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../course_progress.dart';

import 'package:zywny_course_format/course_model.dart';

import '../loaded_course.dart';
import 'course_flow.dart';
import 'course_screen.dart';

/// Para onde a lista navega: empilha a tela do curso com as dependências.
typedef OpenCourse = void Function(BuildContext context, LoadedCourse course);

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({
    super.key,
    required this.courses,
    required this.progress,
    required this.onOpen,
    this.onInstall,
  });

  final List<LoadedCourse> courses;
  final CourseProgressStore progress;
  final OpenCourse onOpen;

  /// I04: instalar outro curso de um `.zywny` (aceita biblioteca também: é o
  /// mesmo instalador); `null` esconde o cartão.
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final onInstall = this.onInstall;
    return Scaffold(
      backgroundColor: kLibraryBg,
      appBar: AppBar(
        backgroundColor: kPanelSideBg,
        surfaceTintColor: Colors.transparent,
        title: Text('Cursos', style: serifDisplay(fontSize: 22)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            // O fim da lista fica acima da barra de botões do Android.
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: courses.length + (onInstall == null ? 0 : 1),
            itemBuilder: (context, i) {
              if (i >= courses.length) {
                return _InstallCard(onTap: onInstall!);
              }
              final loaded = courses[i];
              return _CourseCard(
                loaded: loaded,
                progress: progress[loaded.id],
                onTap: () => onOpen(context, loaded),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Cartão "Instalar curso…" no fim da lista (I04).
class _InstallCard extends StatelessWidget {
  const _InstallCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBorderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Icon(Icons.add, color: kAccentDark),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instalar curso…',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'abre um arquivo .zywny',
                      style: TextStyle(fontSize: 13, color: kInkCaption),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.loaded,
    required this.progress,
    required this.onTap,
  });

  final LoadedCourse loaded;
  final CourseProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final course = loaded.course;
    final (done: done, total: total) = progress.lessonCounts(course);
    final cont = _continueLesson(course, progress);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBorderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(course.title, style: serifDisplay(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                loaded.isDraft
                    ? 'rascunho · por ${course.author}'
                    : 'por ${course.author}',
                style: const TextStyle(fontSize: 13, color: kInkCaption),
              ),
              const SizedBox(height: 10),
              _ProgressLine(done: done, total: total),
              if (cont != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Continuar: ${cont.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kAccentDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A lição para continuar: a última aberta ainda não feita, senão a
  /// primeira não feita; `null` com o curso concluído.
  static Lesson? _continueLesson(Course course, CourseProgress progress) {
    final last = progress.lastLessonId;
    if (last != null) {
      for (final lesson in course.lessons) {
        if (lesson.id == last && !progress.lessonDone(lesson)) return lesson;
      }
    }
    for (final lesson in course.lessons) {
      if (!progress.lessonDone(lesson)) return lesson;
    }
    return null;
  }
}

/// "3 de 10 lições" com a barra fina do U13.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = total <= 0 ? 1 : total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$done de $total ${total == 1 ? 'lição' : 'lições'}',
          style: const TextStyle(fontSize: 13, color: kInkCaption),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                if (done > 0)
                  Expanded(
                    flex: done,
                    child: const ColoredBox(color: kAccent),
                  ),
                if (t - done > 0)
                  Expanded(
                    flex: t - done,
                    child: const ColoredBox(color: kBorderSoft),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Abre a `CourseScreen` com as dependências do fluxo de cursos. Ponto único
/// de navegação da lista, da biblioteca e do cartão inicial.
void openCourseScreen(
  BuildContext context,
  LoadedCourse loaded, {
  required CourseProgressStore progress,
  required CourseScreenDeps deps,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          CourseScreen(loaded: loaded, progress: progress, deps: deps),
    ),
  );
}
