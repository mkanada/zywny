// I05 — cartão de exercício: título, o que se pede, meta e estado.
//
// O que acontece ao tocar é do I09; aqui `onStart` só chega como callback.

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../exercise/pass_check.dart';
import '../format/course_model.dart';

/// Tipos com entrada MIDI (D-LIC-SEM-TECLADO): pedem "Conecte o teclado" sem
/// teclado; os de botões funcionam sem MIDI (na Web sem Web MIDI, só eles).
bool exerciseNeedsMidi(ExerciseSpec spec) =>
    spec is FindKeySpec ||
    spec is PlayNotesSpec ||
    spec is RhythmSpec ||
    spec is PlayScoreSpec;

/// Estado resumido para o cartão (o progresso guardado é do I09).
class ExerciseCardState {
  const ExerciseCardState({required this.passed, this.bestPercent});

  /// Já aprovado (com a melhor % em [bestPercent], quando houver).
  final bool passed;
  final int? bestPercent;
}

/// Uma linha do que se pede ("Toque as notas · clave de sol · 12 notas").
String exerciseSummary(ExerciseSpec spec) {
  String countOf(NotesSpec notes, {int fallback = 12}) => switch (notes) {
    FixedNotes() => '${notes.notes.length} notas',
    RandomNotes() => '${notes.count} notas',
  };
  String clefName(Clef clef) => switch (clef) {
    Clef.treble => 'clave de sol',
    Clef.bass => 'clave de fá',
    Clef.grand => 'pauta dupla',
  };
  switch (spec) {
    case FindKeySpec():
      final octave = spec.octave == OctaveRule.any
          ? 'qualquer oitava'
          : 'oitava exata';
      return 'Ache a tecla · ${countOf(spec.notes, fallback: 10)} · $octave';
    case PlayNotesSpec():
      return 'Toque as notas · ${clefName(spec.clef)} · ${countOf(spec.notes)}';
    case NameNoteSpec():
      return 'Diga a nota · ${clefName(spec.clef)} · ${countOf(spec.notes)}';
    case RhythmSpec():
      return 'Toque no ritmo · ${spec.time} · ${spec.bpm} bpm';
    case CountBeatsSpec():
      return 'Conte os tempos · ${spec.time} · ${spec.count} perguntas';
    case PlayScoreSpec():
      final hand = switch (spec.hand) {
        HandChoice.right => 'mão direita',
        HandChoice.left => 'mão esquerda',
        HandChoice.both => 'as duas mãos',
      };
      final mode = spec.mode == PlayMode.wait ? 'espera' : 'tempo real';
      return 'Toque a partitura · $hand · $mode';
    case ChoiceSpec():
      return spec.question;
  }
}

/// A meta ("meta 90% · 3 rodadas seguidas").
String exerciseGoal(ExerciseSpec spec) {
  final pass = spec.pass;
  final parts = <String>['meta ${pass.accuracy}%'];
  if (pass.rounds > 1) parts.add('${pass.rounds} rodadas seguidas');
  if (PassCheck.speedApplies(spec)) parts.add('≥${pass.speed}% do andamento');
  if (pass.timeLimit != null) parts.add('${pass.timeLimit}s por pergunta');
  return parts.join(' · ');
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.spec,
    required this.state,
    required this.onStart,
    this.hasKeyboard = true,
    this.notice,
  });

  final ExerciseSpec spec;
  final ExerciseCardState state;
  final VoidCallback onStart;

  /// `false` sem teclado MIDI conectado: os tipos MIDI pedem o teclado.
  final bool hasKeyboard;

  /// Aviso de lição bloqueada ("Depois de: ..."): o exercício roda, mas o
  /// cartão avisa que a ordem sugerida pede outra lição antes (I09).
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final needsMidi = exerciseNeedsMidi(spec);
    final blocked = needsMidi && !hasKeyboard;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorderSoft),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            spec.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            exerciseSummary(spec),
            style: const TextStyle(fontSize: 14, color: kInkCaption),
          ),
          const SizedBox(height: 4),
          Text(
            exerciseGoal(spec),
            style: const TextStyle(fontSize: 13, color: kInkCaption),
          ),
          const SizedBox(height: 4),
          Text(
            state.passed
                ? (state.bestPercent == null
                      ? 'aprovado'
                      : 'aprovado · melhor ${state.bestPercent}%')
                : 'não feito',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: state.passed ? kGoodColor : kInkMuted,
            ),
          ),
          if (blocked) ...[
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.piano_outlined, size: 16, color: kOkColor),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Precisa do teclado',
                    style: TextStyle(fontSize: 13, color: kOkColor),
                  ),
                ),
              ],
            ),
          ],
          if (notice case final notice?) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 16, color: kInkCaption),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    notice,
                    style: const TextStyle(fontSize: 13, color: kInkCaption),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: blocked ? null : onStart,
            child: const Text('Começar'),
          ),
        ],
      ),
    );
  }
}
