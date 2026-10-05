// I12 — a tela do rascunho: a lista de problemas (com erros) ou o curso
// (com a faixa e o Recarregar). O progresso é sempre o da sessão
// (`controller.progress`, só memória); nada chega ao `shared_preferences`
// nem ao blob store.

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../ui/course_flow.dart';
import '../ui/course_screen.dart';
import 'course_draft.dart';
import 'course_issues_screen.dart';

/// Abre o rascunho com as dependências do fluxo. Ponto único da lista, das
/// configurações e do `just curso`.
class CourseDraftScreen extends StatelessWidget {
  const CourseDraftScreen({
    super.key,
    required this.controller,
    required this.deps,
  });

  final CourseDraftController controller;
  final CourseScreenDeps deps;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final loaded = controller.loaded;
        if (controller.loading && loaded == null && controller.issues.isEmpty) {
          return Scaffold(
            backgroundColor: kLibraryBg,
            appBar: AppBar(
              backgroundColor: kPanelSideBg,
              surfaceTintColor: Colors.transparent,
              title: const Text('Rascunho'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.hasErrors || loaded == null) {
          return CourseIssuesScreen(
            label: controller.label,
            issues: controller.issues,
            onReload: controller.reload,
            loading: controller.loading,
          );
        }
        final progress = controller.progress;
        final courseDeps = deps.copyWith(progress: progress);
        return CourseScreen(
          loaded: loaded,
          progress: progress,
          deps: courseDeps,
          draftLabel: controller.label,
          draftWarnings: controller.warnings,
          draftLoading: controller.loading,
          onDraftReload: controller.reload,
          onLessonOpen: controller.selectLesson,
        );
      },
    );
  }
}
