// I09 — dependências do fluxo de cursos: o que as telas de curso, lição e
// exercício recebem da biblioteca (ou de quem abre o curso).

import 'package:zywny_audio/sound_engine.dart';

import 'package:zywny_midi/midi_device_manager.dart';
import 'package:zywny_midi/midi_input_service.dart';

import '../../render/score_renderer.dart';
import '../../settings/app_settings.dart';
import '../course_progress.dart';
import 'markdown_view.dart' show LessonLinkOpener;
import 'lesson_audio.dart' show LessonAudioPlayer;

/// Tudo que as telas do curso precisam e não é o curso em si.
class CourseScreenDeps {
  const CourseScreenDeps({
    required this.settings,
    required this.deviceManager,
    required this.midiInput,
    required this.progress,
    required this.ensureEngine,
    this.rendererFactory = createScoreRenderer,
    this.openLink,
    this.audioPlayerFactory,
  });

  /// Configurações gerais (cores, tolerância, nomes das notas, saída de som).
  final AppSettings settings;

  /// O mesmo gerenciador da biblioteca (teclado conectado continua conectado).
  final MidiDeviceManager deviceManager;

  /// Entrada MIDI compartilhada do fluxo.
  final MidiInputService midiInput;

  /// Progresso a gravar (memória no rascunho, disco nos cursos de verdade).
  final CourseProgressStore progress;

  /// O motor de som resolvido para a saída escolhida (`null` sem áudio).
  /// Memoizado por quem abre o fluxo — um motor só para todas as telas.
  final Future<SoundEngine?> Function() ensureEngine;

  final ScoreRenderer Function() rendererFactory;
  final LessonLinkOpener? openLink;

  /// Para teste: tocador de áudio falso das marcas `zywny-audio`.
  final LessonAudioPlayer Function()? audioPlayerFactory;

  CourseScreenDeps copyWith({CourseProgressStore? progress}) =>
      CourseScreenDeps(
        settings: settings,
        deviceManager: deviceManager,
        midiInput: midiInput,
        progress: progress ?? this.progress,
        ensureEngine: ensureEngine,
        rendererFactory: rendererFactory,
        openLink: openLink,
        audioPlayerFactory: audioPlayerFactory,
      );
}
