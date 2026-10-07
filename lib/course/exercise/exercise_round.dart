import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../practice/hand.dart';

import 'package:zywny_course_format/course_model.dart';

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
    this.measures,
    this.bpm,
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

  /// Só estes compassos **escritos** (`play-score` com `measures`): `5` ou
  /// `5-12`, base 1, inclusivos. `null` é a partitura toda.
  final MeasureRange? measures;

  /// Andamento escrito que vale como 1,0 (`play-score` com `bpm`): o som
  /// sai neste `bpm`, convertido para a velocidade relativa ao andamento
  /// do arquivo. `null` é o andamento da partitura.
  final int? bpm;

  ScoreRound copyWith({double? speed}) => ScoreRound(
    bytes: bytes,
    fileName: fileName,
    mode: mode,
    hand: hand,
    speed: speed ?? this.speed,
    pitches: pitches,
    noteIds: noteIds,
    measures: measures,
    bpm: bpm,
  );
}

/// Rodada de perguntas (I07 preenche: `find-key`, `name-note`,
/// `count-beats`, `choice`).
class QuestionRound extends ExerciseRound {
  const QuestionRound(
    this.questions, {
    this.scoreBytes,
    this.fileName,
    this.imagePath,
  });

  final List<Question> questions;

  /// Partitura da rodada, quando há (`name-note`, `count-beats` e `choice`
  /// com `abc`): os bytes que o `ScoreRenderer` desenha.
  final Uint8List? scoreBytes;

  /// Nome do arquivo da partitura (a extensão informa o formato).
  final String? fileName;

  /// Imagem da pergunta (`choice` com `image`): caminho na pasta do curso.
  final String? imagePath;
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
    this.anyOctave = false,
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

  /// `find-key` com `octave: any`: qualquer oitava serve (compara a classe
  /// de altura, `pitch % 12`). Com `false` (`exact`), só a altura exata.
  final bool anyOctave;
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
