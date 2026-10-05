// I07 — sessão de perguntas, Dart puro (sem widgets, sem MIDI de verdade).
//
// Regra comum (I00/I07): a pergunta fica na tela até a resposta certa.
// Errou: não conta como de primeira e segue esperando. `time-limit`
// estourou: conta como erro, a resposta certa aparece por 1,5 s e passa
// para a próxima. `RoundResult(hits: de primeira, total: perguntas).
//
// O relógio é injetável (teste sem espera real): [now] devolve segundos.
// [tick] recebe o agora (ou lê do relógio) e cuida do estouro e do avanço
// depois do 1,5 s de revelação. Durante a revelação as respostas são
// ignoradas (as teclas apertadas no pisca não valem).

import 'exercise_round.dart';

/// Quanto a resposta certa fica à mostra depois do estouro do `time-limit`.
const double kAnswerRevealSeconds = 1.5;

class QuestionSession {
  QuestionSession(
    this.questions, {
    this.timeLimit,
    double Function()? now,
  }) : _now = now ?? _wallNow,
       firstTry = List<bool>.filled(questions.length, true) {
    _startAt = _now();
  }

  final List<Question> questions;

  /// Segundos por pergunta; `null` = sem limite.
  final int? timeLimit;

  final double Function() _now;
  static double _wallNow() =>
      DateTime.now().millisecondsSinceEpoch / 1000.0;

  /// De primeira até agora, por pergunta (falso depois do primeiro erro ou
  /// do estouro).
  final List<bool> firstTry;

  int index = 0;
  double _startAt = 0;

  /// Último `now` explícito de [tick] (teste sem espera real): as respostas
  /// certas recomeçam o cronômetro daqui, não do relógio de parede, para o
  /// `time-limit` valer com tempos simulados.
  double? _lastTick;

  /// Revelando a resposta certa depois do estouro (1,5 s).
  bool revealing = false;
  double _revealUntil = 0;

  /// Pergunta atual, ou `null` quando acabou.
  Question? get current => done ? null : questions[index];

  bool get done => index >= questions.length;

  /// Acertos de primeira entre as concluídas (e a em revelação, já perdida).
  int get _hits {
    var hits = 0;
    for (var i = 0; i < questions.length; i++) {
      if (i < index && firstTry[i]) hits++;
      // Em revelação a atual já perdeu, não conta.
    }
    return hits;
  }

  RoundResult result() =>
      RoundResult(hits: _hits, total: questions.length);

  void _markWrong() {
    if (index < firstTry.length) firstTry[index] = false;
  }

  /// Resposta por botão ([choiceIndex] em `answers`). Devolve `true` se
  /// acertou e avançou, `false` se errou (segue na mesma), `null` se
  /// ignorada (revelando ou terminou).
  bool? answerChoice(int choiceIndex) {
    if (done || revealing) return null;
    final question = questions[index];
    final correct = question.correct;
    if (correct == null) return null;
    if (choiceIndex == correct) {
      index++;
      revealing = false;
      if (!done) _startAt = _lastTick ?? _now();
      return true;
    }
    _markWrong();
    return false;
  }

  /// Resposta no teclado MIDI ([midi] 0–127). Com [anyOctave] (`octave:
  /// any`), vale a classe de altura (`% 12`); senão, só a altura exata.
  /// Mesma convenção de retorno de [answerChoice].
  bool? answerPitch(int midi) {
    if (done || revealing) return null;
    final question = questions[index];
    final expected = question.expectedPitch;
    if (expected == null) return null;
    final ok = question.anyOctave
        ? (midi % 12 + 12) % 12 == (expected % 12 + 12) % 12
        : midi == expected;
    if (ok) {
      index++;
      revealing = false;
      if (!done) _startAt = _lastTick ?? _now();
      return true;
    }
    _markWrong();
    return false;
  }

  /// Avança o relógio: estouro vira revelação de 1,5 s, e o fim da revelação
  /// avança para a próxima. Devolve `true` se algo mudou (entrou ou saiu da
  /// revelação).
  bool tick([double? now]) {
    if (done) return false;
    final at = now ?? _now();
    if (now != null) _lastTick = now;
    if (revealing) {
      if (at >= _revealUntil) {
        revealing = false;
        index++;
        if (!done) _startAt = at;
        return true;
      }
      return false;
    }
    final limit = timeLimit;
    if (limit == null) return false;
    if (at - _startAt >= limit) {
      _markWrong();
      revealing = true;
      _revealUntil = at + kAnswerRevealSeconds;
      return true;
    }
    return false;
  }
}
