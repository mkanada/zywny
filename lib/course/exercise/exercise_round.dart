import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../practice/hand.dart';
import '../format/course_model.dart';

/// Uma rodada de exercício, já sorteada e pronta para rodar. Duas famílias:
/// as de **partitura** (o aluno toca no teclado MIDI) e as de **pergunta**
/// (botões).
sealed class ExerciseRound {
  const ExerciseRound();
}

/// Rodada de partitura: os bytes que o `ScoreRenderer` desenha e o modo em
/// que o treino conduz o tempo.
class ScoreRound extends ExerciseRound {
  const ScoreRound({
    required this.bytes,
    required this.fileName,
    required this.mode,
    required this.hand,
    this.speed = 1.0,
    this.pitches = const [],
    this.noteIds = const [],
  });

  /// MusicXML ou ABC (a **extensão** de [fileName] informa o formato).
  final Uint8List bytes;
  final String fileName;

  /// `wait` (modo espera) ou `realtime` (tempo real, I08).
  final PlayMode mode;

  /// Que pautas o aluno toca. `Hand` só escolhe pautas (pauta 1 = direita):
  /// não importa qual mão a pessoa usa de fato.
  final Hand hand;

  /// Andamento da rodada (1,0 = o escrito). No modo espera não vale.
  final double speed;

  /// Alturas MIDI que soam, na ordem em que o aluno as toca, quando o app
  /// sorteou a rodada (vazio numa partitura do autor). É o que o aluno
  /// simulado e os testes comparam com o `midi.json`.
  final List<int> pitches;

  /// `xml:id` da i-ésima nota (`roundNoteId`), quando a rodada é sorteada.
  final List<String> noteIds;
}

/// Rodada de perguntas (I07 preenche: `find-key`, `name-note`,
/// `count-beats`, `choice`).
class QuestionRound extends ExerciseRound {
  const QuestionRound(this.questions);

  final List<Question> questions;
}

/// Uma pergunta da rodada. Os campos que cada tipo usa ficam para o I07.
@immutable
class Question {
  const Question({
    this.prompt,
    this.answers = const [],
    this.correct,
    this.expectedPitch,
    this.highlightId,
  });

  /// O que a tela mostra (texto), se houver.
  final String? prompt;

  /// Botões de resposta, na ordem da tela.
  final List<String> answers;

  /// A resposta certa entre [answers] (índice), nas perguntas de botão.
  final int? correct;

  /// A altura MIDI esperada, nas perguntas respondidas no teclado.
  final int? expectedPitch;

  /// A nota da partitura em destaque (`xml:id`), se houver.
  final String? highlightId;
}

/// O resultado de uma rodada: [hits] de [total] e o andamento em que foi
/// tocada ([speed]: 1,0 = o escrito).
@immutable
class RoundResult {
  const RoundResult({
    required this.hits,
    required this.total,
    this.speed = 1.0,
  });

  final int hits;
  final int total;
  final double speed;

  /// Porcentagem inteira, arredondada **para baixo** (89,9% não vira 90),
  /// como o `StageResult.percent`. Nada a tocar (`total == 0`) conta 100.
  int get percent => total == 0 ? 100 : hits * 100 ~/ total;

  /// O andamento em % inteira, para baixo (com folga contra o erro de
  /// binário: 0,75 × 100 é 75).
  int get speedPercent => (speed * 100 + 1e-6).floor();

  @override
  String toString() => 'RoundResult($hits/$total, $percent%, $speedPercent%)';
}
