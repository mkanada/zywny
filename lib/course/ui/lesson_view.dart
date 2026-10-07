// I05 — `LessonView(lesson, files)`: a lição inteira numa coluna rolável.
//
// No celular em retrato (como a biblioteca), na Web e no desktop: título da
// lição, blocos na ordem, espaçamento do tema, largura máxima de leitura
// (~640 dp) centralizada no desktop/Web. Texto pelo `MarkdownView`, imagens
// da pasta, partituras pequenas com toque para ouvir, teclado desenhado,
// tocador de áudio, cartão de vídeo e cartões de exercício (o que acontece
// ao tocar neles é do I09: aqui `onStart` só chega como callback).

import 'package:flutter/material.dart';

import '../../audio/sound_engine.dart';
import '../../render/score_renderer.dart';
import '../../ui/theme.dart';
import '../format/course_files.dart';
import '../format/course_model.dart';
import '../../music/note_names.dart';
import 'audio_mark_view.dart';
import 'exercise_card.dart';
import 'keyboard_mark_view.dart';
import 'lesson_audio.dart';
import 'markdown_view.dart';
import 'score_mark_view.dart';
import 'video_mark_view.dart';

/// Largura máxima de leitura: centralizada no desktop/Web (I05).
const double kLessonMaxWidth = 640;

/// A lição desenhada.
class LessonView extends StatelessWidget {
  const LessonView({
    super.key,
    required this.lesson,
    required this.files,
    this.highlightColor = kAccent,
    this.naming = NoteNaming.latin,
    this.engine,
    this.renderer,
    this.hasKeyboard = true,
    this.exerciseStates = const {},
    this.onExerciseStart,
    this.openLink,
    this.audioPlayerFactory,
    this.audioCoordinator,
    this.exerciseNotice,
  });

  final Lesson lesson;
  final CourseFiles files;

  /// Cor de destaque das configurações para o `highlight` da partitura.
  final Color highlightColor;
  final NoteNaming naming;

  /// Motor já resolvido para a saída escolhida; `null` = partituras mudas.
  final SoundEngine? engine;

  /// Para teste: renderizador falso das partituras.
  final ScoreRenderer? renderer;

  /// Sem teclado MIDI conectado: os tipos MIDI mostram "Precisa do teclado".
  final bool hasKeyboard;

  /// Estado por id de exercício (o progresso guardado é do I09).
  final Map<String, ExerciseCardState> exerciseStates;

  /// Chamado com o `spec` ao tocar "Começar" (o I09 navega; aqui é callback).
  final void Function(ExerciseSpec spec)? onExerciseStart;

  /// Para teste: abre links/vídeos sem o navegador.
  final LessonLinkOpener? openLink;

  /// Para teste: tocador de áudio falso.
  final LessonAudioPlayer Function()? audioPlayerFactory;

  /// Para teste ou para dividir a coordenação "um só por vez" com o pai.
  final SingleAudioPlay? audioCoordinator;

  /// Aviso de lição bloqueada, repassado aos cartões de exercício (I09).
  final String? exerciseNotice;

  @override
  Widget build(BuildContext context) {
    final coordinator = audioCoordinator ?? SingleAudioPlay();
    return LayoutBuilder(
      builder: (context, constraints) {
        final centered = constraints.maxWidth > kLessonMaxWidth + 32;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                lesson.title,
                style: serifDisplay(fontSize: 26).copyWith(height: 1.2),
              ),
            ),
            for (final block in lesson.blocks) _block(block, coordinator),
            const SizedBox(height: 24),
          ],
        );
        if (!centered) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: content,
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kLessonMaxWidth),
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _block(LessonBlock block, SingleAudioPlay coordinator) {
    switch (block) {
      case TextBlock():
        return MarkdownView(
          text: block.markdown,
          files: files,
          openLink: openLink,
        );
      case ScoreMark():
        return ScoreMarkView(
          mark: block,
          files: files,
          highlightColor: highlightColor,
          engine: engine,
          renderer: renderer,
        );
      case KeyboardMark():
        return KeyboardMarkView(mark: block, naming: naming);
      case AudioMark():
        return AudioMarkView(
          mark: block,
          files: files,
          coordinator: coordinator,
          playerFactory: audioPlayerFactory,
        );
      case VideoMark():
        return VideoMarkView(mark: block, openLink: openLink);
      case ExerciseMark():
        return ExerciseCard(
          spec: block.spec,
          state:
              exerciseStates[block.spec.id] ??
              const ExerciseCardState(passed: false),
          hasKeyboard: hasKeyboard,
          notice: exerciseNotice,
          onStart: () => onExerciseStart?.call(block.spec),
        );
    }
  }
}
