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

/// Um som da pergunta: as [pitches] (MIDI) soam juntas por [seconds].
@immutable
class SoundCue {
  const SoundCue(this.pitches, {this.seconds = 1.0});

  final List<int> pitches;
  final double seconds;
}

/// Uma nota com hora marcada: a altura MIDI [pitch] soa em [start] segundos
/// desde o começo, por [seconds] segundos (E05, `listen-score`).
@immutable
class TimedNote {
  const TimedNote(this.pitch, this.start, this.seconds);

  final int pitch;
  final double start;
  final double seconds;
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
    this.sound = const [],
    this.compare,
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

  /// O que soa ao mostrar a pergunta, um [SoundCue] depois do outro
  /// (`listen-note`). Vazio nos outros tipos.
  final List<SoundCue> sound;

  /// `listen-score` (E05): a partitura desta pergunta e as duas versões da
  /// frase. `null` nos outros tipos.
  final ScoreComparison? compare;
}

/// Uma pergunta de "onde mudou?" ou de ditado: a partitura escrita, o que soa,
/// o que está escrito e o que mudou (E05; o ditado, E09).
@immutable
class ScoreComparison {
  const ScoreComparison({
    required this.scoreBytes,
    required this.fileName,
    required this.played,
    required this.written,
    required this.changedIds,
    this.measure,
    this.description,
    this.promptBytes,
    this.reference,
  });

  /// A partitura completa, mostrada na revelação.
  final Uint8List scoreBytes;
  final String fileName;

  /// A partitura mostrada enquanto o aluno responde, quando é outra: no
  /// ditado (E09), só o ritmo. `null` nas de "onde mudou?", que mostram
  /// [scoreBytes] o tempo todo.
  final Uint8List? promptBytes;

  /// O que o zywny toca na pergunta (com a mudança, se houver).
  final List<TimedNote> played;

  /// A frase como está escrita (o botão "Ouvir o escrito" da revelação).
  final List<TimedNote> written;

  /// As notas escritas que soam diferente; vazio quando nada mudou.
  final Set<String> changedIds;

  /// O compasso da mudança (base 0); `null` quando nada mudou.
  final int? measure;

  /// O que mudou, em português, para a revelação; `null` quando nada mudou.
  final String? description;

  /// O acorde de referência que soa antes da frase, em alturas MIDI (o da
  /// tônica, no "onde mudou?" e no ditado). `null` quando não há. A tela o
  /// escreve na pergunta e na revelação.
  final List<int>? reference;
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
