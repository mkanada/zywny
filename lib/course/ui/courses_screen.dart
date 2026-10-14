// I09 — lista de cursos (retrato): um cartão por curso com título, autor,
// "X de Y lições", barra e "Continuar: <lição>". O embutido primeiro
// (a ordem da lista recebida); nesta etapa, o embutido (I10) e cursos de
// fixture nos testes.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../sight_reading/sight_progress.dart';
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
    this.onSightReading,
    this.onSightListening,
    this.sightStore,
  });

  final List<LoadedCourse> courses;
  final CourseProgressStore progress;
  final OpenCourse onOpen;

  /// O treino de leitura à primeira vista, sempre no topo da lista (é uma
  /// opção a mais, como os cursos); `null` esconde o cartão.
  final Future<void> Function(BuildContext context)? onSightReading;

  /// O "só ouvido" do mesmo cartão (E08); `null` esconde só o botão.
  final Future<void> Function(BuildContext context)? onSightListening;

  /// Onde o cartão lê e grava a chave do ouvido (para os testes); `null`
  /// usa o armazenamento do aparelho.
  final SightReadingStore? sightStore;

  /// I04: instalar outro curso de um `.zywny` (aceita biblioteca também: é o
  /// mesmo instalador); `null` esconde o cartão.
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final onInstall = this.onInstall;
    final onSightReading = this.onSightReading;
    final onSightListening = this.onSightListening;
    final top = onSightReading == null ? 0 : 1;
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
            itemCount: top + courses.length + (onInstall == null ? 0 : 1),
            itemBuilder: (context, i) {
              if (onSightReading != null && i == 0) {
                return _SightReadingCard(
                  store: sightStore,
                  onRead: () => unawaited(onSightReading(context)),
                  onListen: onSightListening == null
                      ? null
                      : () => unawaited(onSightListening(context)),
                );
              }
              final j = i - top;
              if (j >= courses.length) {
                return _InstallCard(onTap: onInstall!);
              }
              final loaded = courses[j];
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

/// Cartão do treino de leitura, no topo da lista: "Ler e tocar" e "Só ouvido"
/// (E08), e a chave do ouvido depois de cada leitura. Os botões abrem o treino;
/// o toque no cartão não abre nada.
class _SightReadingCard extends StatefulWidget {
  const _SightReadingCard({
    required this.onRead,
    required this.onListen,
    this.store,
  });

  final VoidCallback onRead;

  /// `null` esconde o botão "Só ouvido".
  final VoidCallback? onListen;

  /// `null` usa o armazenamento do aparelho.
  final SightReadingStore? store;

  @override
  State<_SightReadingCard> createState() => _SightReadingCardState();
}

class _SightReadingCardState extends State<_SightReadingCard> {
  late final SightReadingStore _store = widget.store ?? SightReadingStore();

  /// Ligado por padrão, até a gravação ser lida.
  bool _earOn = true;

  @override
  void initState() {
    super.initState();
    unawaited(
      _store.loadEarOn().then((on) {
        if (mounted) setState(() => _earOn = on);
      }),
    );
  }

  void _setEarOn(bool on) {
    setState(() => _earOn = on);
    unawaited(_store.saveEarOn(on));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBorderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.piano, color: kAccentDark),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leitura à primeira vista',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'partituras novas, do 1a ao 20d, tocadas no andamento',
                        style: TextStyle(fontSize: 13, color: kInkCaption),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: widget.onRead,
                  child: const Text('Ler e tocar'),
                ),
                if (widget.onListen != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.onListen,
                    child: const Text('Só ouvido'),
                  ),
                ],
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Ouvido depois de cada leitura',
                style: TextStyle(fontSize: 14),
              ),
              value: _earOn,
              onChanged: _setEarOn,
            ),
          ],
        ),
      ),
    );
  }
}

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
