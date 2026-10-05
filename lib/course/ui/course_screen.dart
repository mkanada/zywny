// I09 — tela do curso: a apresentação (recolhível) e a lista de lições na
// ordem, cada uma com estado: feita ✓, aberta (com "X de Y exercícios"),
// bloqueada 🔒 com "Depois de: <títulos que faltam>". Tocar numa bloqueada
// mostra o motivo e oferece abrir assim mesmo (só ler — a trava é de
// sequência sugerida, não de acesso).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/theme.dart';
import '../course_progress.dart';
import '../draft/course_issues_screen.dart' show DraftBanner;
import '../format/course_files.dart';
import '../format/course_issue.dart';
import '../format/course_model.dart';
import '../loaded_course.dart';
import 'course_flow.dart';
import 'lesson_screen.dart';
import 'markdown_view.dart';

class CourseScreen extends StatelessWidget {
  const CourseScreen({
    super.key,
    required this.loaded,
    required this.progress,
    required this.deps,
    this.draftLabel,
    this.draftWarnings = const [],
    this.draftLoading = false,
    this.onDraftReload,
    this.onLessonOpen,
  });

  final LoadedCourse loaded;
  final CourseProgressStore progress;
  final CourseScreenDeps deps;

  /// I12: com rascunho, a faixa fixa com Recarregar (`null` = curso de
  /// verdade, sem faixa de rascunho além do aviso antigo).
  final String? draftLabel;
  final List<CourseIssue> draftWarnings;
  final bool draftLoading;
  final VoidCallback? onDraftReload;

  /// I12: avisa qual lição abriu (o rascunho mantém a tela no Recarregar).
  final ValueChanged<String?>? onLessonOpen;

  bool get _isDraft => loaded.isDraft || draftLabel != null;

  @override
  Widget build(BuildContext context) {
    final course = loaded.course;
    final reload = onDraftReload;
    Widget scaffold = Scaffold(
      backgroundColor: kLibraryBg,
      appBar: AppBar(
        backgroundColor: kPanelSideBg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          course.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: serifDisplay(fontSize: 20),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListenableBuilder(
            listenable: progress,
            builder: (context, _) {
              final state = progress[course.id];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_isDraft && reload != null)
                    DraftBanner(
                      label: draftLabel ?? loaded.files.label,
                      onReload: reload,
                      loading: draftLoading,
                    )
                  else if (loaded.isDraft)
                    const _DraftBanner(),
                  if (_isDraft &&
                      draftWarnings.isNotEmpty &&
                      reload != null)
                    _WarningsStrip(warnings: draftWarnings),
                  _IntroCard(course: course, files: loaded.files),
                  const SizedBox(height: 12),
                  for (final lesson in course.lessons)
                    _LessonRow(
                      lesson: lesson,
                      course: course,
                      progress: state,
                      onOpen: ({lockedTitles}) {
                        onLessonOpen?.call(lesson.id);
                        openLessonScreen(
                          context,
                          loaded,
                          lesson,
                          deps: deps,
                          lockedTitles: lockedTitles,
                          draftLabel: draftLabel,
                          draftLoading: draftLoading,
                          onDraftReload: reload,
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    // Atalho do autor no desktop (I12): Ctrl+R = Recarregar.
    if (_isDraft && reload != null && !kIsWeb) {
      final platform = defaultTargetPlatform;
      final desktop =
          platform == TargetPlatform.linux ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.macOS;
      if (desktop) {
        scaffold = CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyR, control: true):
                reload,
          },
          child: scaffold,
        );
      }
    }
    return scaffold;
  }
}

/// Abre a `LessonScreen` (ponto único da tela do curso e do cartão inicial).
void openLessonScreen(
  BuildContext context,
  LoadedCourse loaded,
  Lesson lesson, {
  required CourseScreenDeps deps,
  List<String>? lockedTitles,
  String? draftLabel,
  bool draftLoading = false,
  VoidCallback? onDraftReload,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => LessonScreen(
        loaded: loaded,
        lessonId: lesson.id,
        progress: deps.progress,
        deps: deps,
        lockedTitles: lockedTitles,
        draftLabel: draftLabel,
        draftLoading: draftLoading,
        onDraftReload: onDraftReload,
      ),
    ),
  );
}

/// Faixa do modo rascunho (I12): "rascunho, não verificado".
class _DraftBanner extends StatelessWidget {
  const _DraftBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kOkColor.withValues(alpha: 0.12),
        border: Border.all(color: kOkColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Rascunho, não verificado — o progresso aqui não é guardado.',
        style: TextStyle(fontSize: 13, color: kInk),
      ),
    );
  }
}

/// Só avisos (sem erros): o curso abre e uma tira recolhível mostra
/// "N avisos" (I12).
class _WarningsStrip extends StatelessWidget {
  const _WarningsStrip({required this.warnings});

  final List<CourseIssue> warnings;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorderSoft),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.warning_amber, color: kInkCaption),
        title: Text(
          '${warnings.length} ${warnings.length == 1 ? 'aviso' : 'avisos'}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        children: [
          for (final w in warnings)
            ListTile(
              dense: true,
              title: Text(
                '${w.file}:${w.line}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(w.message),
            ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.course, required this.files});

  final Course course;
  final CourseFiles files;

  @override
  Widget build(BuildContext context) {
    if (course.intro.trim().isEmpty) return const SizedBox.shrink();
    return Card(
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBorderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text(
          'Apresentação',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: MarkdownView(text: course.intro, files: files),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.course,
    required this.progress,
    required this.onOpen,
  });

  final Lesson lesson;
  final Course course;
  final CourseProgress progress;
  final void Function({List<String>? lockedTitles}) onOpen;

  @override
  Widget build(BuildContext context) {
    final done = progress.lessonDone(lesson);
    final open = progress.lessonOpen(lesson, course);
    final counts = progress.exerciseCounts(lesson);
    final missing = open ? const <String>[] : progress.missingFor(lesson, course);
    final subtitle = done
        ? 'concluída'
        : counts != null
        ? '${counts.done} de ${counts.total} exercícios'
        : 'para ler';
    return Card(
      color: kSurface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          done
              ? Icons.check_circle
              : open
              ? Icons.play_circle_outline
              : Icons.lock,
          color: done
              ? kGoodColor
              : open
              ? kAccentDark
              : kInkCaption,
        ),
        title: Text(
          lesson.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          open ? subtitle : 'Depois de: ${missing.join(', ')}',
          style: const TextStyle(fontSize: 13, color: kInkCaption),
        ),
        onTap: () {
          if (open || done) {
            onOpen();
            return;
          }
          _showBlocked(context, missing);
        },
      ),
    );
  }

  Future<void> _showBlocked(BuildContext context, List<String> missing) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson.title),
        content: Text(
          'Esta lição vem depois de ${missing.join(', ')}. '
          'Você pode ler assim mesmo — a ordem é só uma sugestão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir assim mesmo'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) onOpen(lockedTitles: missing);
  }
}
