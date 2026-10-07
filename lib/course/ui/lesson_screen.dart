// I09 — tela da lição: o `LessonView` do I05, com barra "‹ curso" e, no fim,
// "Próxima lição ›" quando houver. Os cartões mostram o estado do progresso
// e abrem a tela do exercício. Guarda `lastLessonId`. Lição sem exercício:
// feita ao ser lida até o fim ou ao tocar "Concluir".

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zywny_audio/sound_engine.dart';

import '../../ui/theme.dart';
import '../course_progress.dart';
import '../draft/course_issues_screen.dart' show DraftBanner;

import 'package:zywny_course_format/course_model.dart';

import '../loaded_course.dart';
import 'course_chrome.dart';
import 'course_flow.dart';
import 'exercise_card.dart';
import 'exercise_screen.dart';
import 'lesson_view.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.loaded,
    required this.lessonId,
    required this.progress,
    required this.deps,
    this.lockedTitles,
    this.draftLabel,
    this.draftLoading = false,
    this.onDraftReload,
  });

  final LoadedCourse loaded;
  final String lessonId;
  final CourseProgressStore progress;
  final CourseScreenDeps deps;

  /// Títulos que faltam (lição aberta "assim mesmo"): faixa de aviso e aviso
  /// nos cartões; o exercício roda normalmente.
  final List<String>? lockedTitles;

  /// I12: rascunho — faixa com Recarregar (mesma da tela do curso).
  final String? draftLabel;
  final bool draftLoading;
  final VoidCallback? onDraftReload;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _markedEnd = false;
  SoundEngine? _engine;

  Lesson get _lesson =>
      widget.loaded.course.lessons.firstWhere((l) => l.id == widget.lessonId);

  @override
  void initState() {
    super.initState();
    // O progresso guardado vale ao abrir (cartões com o selo certo).
    unawaited(widget.progress.ensureLoaded(widget.loaded.id));
    // Fora do `build`: o `touchLesson` avisa quem escuta (a própria tela).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.progress.touchLesson(widget.loaded.id, widget.lessonId);
    });
    // O toque-para-ouvir das partituras: o motor do fluxo (memoizado fora);
    // sem áudio, a lição abre muda.
    unawaited(
      widget.deps.ensureEngine().then((engine) {
        if (mounted) setState(() => _engine = engine);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.loaded.course;
    final lesson = _lesson;
    final locked = widget.lockedTitles;
    final next = _nextLesson(course, lesson);
    final reload = widget.onDraftReload;
    final isDraft = widget.loaded.isDraft || widget.draftLabel != null;
    Widget scaffold = ListenableBuilder(
      listenable: Listenable.merge([
        widget.progress,
        widget.deps.deviceManager.connected,
      ]),
      builder: (context, _) {
        final state = widget.progress[course.id];
        final hasKeyboard = widget.deps.deviceManager.connected.value != null;
        final states = {
          for (final spec in lesson.exercises)
            spec.id: ExerciseCardState(
              passed: state.records[spec.id]?.passed ?? false,
              bestPercent: state.records[spec.id]?.bestPercent,
            ),
        };
        return CourseScrollScaffold(
          settings: widget.deps.settings,
          backgroundColor: kLibraryBg,
          leading: IconButton(
            tooltip: 'Voltar ao curso',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left),
          ),
          title: Text(
            course.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15),
          ),
          actions: [CourseTextSizeButton(settings: widget.deps.settings)],
          onScroll: (notification) => _onScroll(notification, lesson),
          children: [
            if (isDraft && reload != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DraftBanner(
                  label: widget.draftLabel ?? widget.loaded.files.label,
                  onReload: reload,
                  loading: widget.draftLoading,
                ),
              )
            else if (widget.loaded.isDraft)
              const _DraftLine(),
            if (locked != null && locked.isNotEmpty)
              _LockedLine(titles: locked),
            LessonView(
              lesson: lesson,
              files: widget.loaded.files,
              highlightColor: widget.deps.settings.highlightColor,
              naming: widget.deps.settings.noteNaming,
              engine: _engine,
              hasKeyboard: hasKeyboard,
              exerciseStates: states,
              exerciseNotice: locked == null
                  ? null
                  : 'Depois de: ${locked.join(', ')}',
              onExerciseStart: (spec) => openExerciseScreen(
                context,
                widget.loaded,
                lesson,
                spec,
                deps: widget.deps,
              ),
              openLink: widget.deps.openLink,
              audioPlayerFactory: widget.deps.audioPlayerFactory,
            ),
            if (lesson.exercises.isEmpty)
              _ConcludeButton(
                done: state.lessonDone(lesson),
                onConclude: () =>
                    widget.progress.markLessonDone(widget.loaded.id, lesson.id),
              ),
            if (next != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: () => _goNext(context, next),
                  icon: const Icon(Icons.chevron_right),
                  label: Text('Próxima lição: ${next.title}'),
                ),
              ),
          ],
        );
      },
    );
    if (isDraft && reload != null && !kIsWeb) {
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

  /// Lição sem exercício lida até o fim: concluída sem tocar em nada.
  bool _onScroll(ScrollNotification notification, Lesson lesson) {
    if (_markedEnd || lesson.exercises.isNotEmpty) return false;
    final metrics = notification.metrics;
    if (notification is ScrollUpdateNotification && metrics.extentAfter <= 1) {
      _markedEnd = true;
      widget.progress.markLessonDone(widget.loaded.id, lesson.id);
    }
    return false;
  }

  Lesson? _nextLesson(Course course, Lesson lesson) {
    final lessons = course.lessons;
    final index = lessons.indexWhere((l) => l.id == lesson.id);
    if (index < 0 || index + 1 >= lessons.length) return null;
    return lessons[index + 1];
  }

  void _goNext(BuildContext context, Lesson next) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => LessonScreen(
          loaded: widget.loaded,
          lessonId: next.id,
          progress: widget.progress,
          deps: widget.deps,
          draftLabel: widget.draftLabel,
          draftLoading: widget.draftLoading,
          onDraftReload: widget.onDraftReload,
        ),
      ),
    );
  }
}

/// Abre a tela do exercício (ponto único da tela da lição).
void openExerciseScreen(
  BuildContext context,
  LoadedCourse loaded,
  Lesson lesson,
  ExerciseSpec spec, {
  required CourseScreenDeps deps,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ExerciseScreen(
        loaded: loaded,
        lesson: lesson,
        spec: spec,
        deps: deps,
      ),
    ),
  );
}

class _DraftLine extends StatelessWidget {
  const _DraftLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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

class _LockedLine extends StatelessWidget {
  const _LockedLine({required this.titles});

  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Lendo assim mesmo — a ordem sugere ${titles.join(', ')} antes.',
        style: const TextStyle(fontSize: 13, color: kInkCaption),
      ),
    );
  }
}

class _ConcludeButton extends StatelessWidget {
  const _ConcludeButton({required this.done, required this.onConclude});

  final bool done;
  final VoidCallback onConclude;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: kGoodColor),
            SizedBox(width: 6),
            Text(
              'Lição concluída',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kGoodColor,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: onConclude,
        icon: const Icon(Icons.check),
        label: const Text('Concluir a lição'),
      ),
    );
  }
}
