import 'dart:math';

import 'sight_steps.dart';

/// Compassos por exercício.
const sightMeasures = 4;

/// Uma figura numa pauta: uma nota no [degree] (1 é a tônica), ou uma pausa
/// quando [degree] é nulo. [units] está em dezesseis avos.
class SightNote {
  const SightNote(this.units, [this.degree]);

  final int units;
  final int? degree;

  bool get isRest => degree == null;
}

/// Como as duas mãos tocam juntas num passo de duas mãos.
enum SightTexture {
  /// A esquerda acompanha com acordes e baixos; a direita toca em cima deles.
  acompanhamento,

  /// A esquerda repete a direita uma terça abaixo, com o mesmo ritmo.
  tercas,

  /// A esquerda repete a direita uma sexta abaixo, com o mesmo ritmo.
  sextas,

  /// A esquerda faz o movimento contrário: sobe quando a direita desce.
  contrario,

  /// A direita pergunta num compasso e a esquerda responde no seguinte, uma
  /// quinta abaixo; a direita pergunta de novo, e assim até o fim.
  perguntaResposta,
}

/// O exercício sorteado: as duas pautas, compasso a compasso.
class SightExercise {
  const SightExercise({
    required this.step,
    required this.right,
    required this.left,
    this.texture,
  });

  final SightStep step;

  /// Pauta de sol, por compasso.
  final List<List<SightNote>> right;

  /// Pauta de fá, por compasso.
  final List<List<SightNote>> left;

  /// Como as duas mãos tocam; `null` quando só uma mão toca.
  final SightTexture? texture;
}

typedef _Pautas = (List<List<SightNote>>, List<List<SightNote>>);

/// Sorteia um exercício do [step]. Com um [Random] de semente fixa, a mesma
/// rodada sai sempre.
SightExercise generateSight(SightStep step, Random rng) {
  final silent = [
    for (var m = 0; m < sightMeasures; m++) [SightNote(step.unitsPerMeasure)],
  ];
  return switch (step.hands) {
    SightHands.right => SightExercise(
      step: step,
      right: _cadence(_melody(step, rng)),
      left: silent,
    ),
    SightHands.left => SightExercise(
      step: step,
      right: silent,
      left: _cadence(_melody(step, rng)),
    ),
    SightHands.both => _both(step, rng),
  };
}

/// As duas mãos juntas: a maneira é sorteada entre as que o nível libera.
SightExercise _both(SightStep step, Random rng) {
  final textures = _texturesOf(step);
  final texture = textures[rng.nextInt(textures.length)];
  final (right, left) = switch (texture) {
    SightTexture.acompanhamento => _accompanied(step, rng),
    SightTexture.perguntaResposta => _answered(step, rng),
    _ => _voiced(step, rng, texture),
  };
  return SightExercise(
    step: step,
    right: _cadence(right),
    left: _cadence(left),
    texture: texture,
  );
}

/// As maneiras de as duas mãos tocarem no passo: o acompanhamento sempre; as
/// vozes paralelas e o movimento contrário a partir de [_voicesFromLevel]; a
/// pergunta e resposta a partir de [_answerFromLevel].
List<SightTexture> _texturesOf(SightStep step) => [
  SightTexture.acompanhamento,
  if (step.level >= _voicesFromLevel) ...[
    SightTexture.tercas,
    SightTexture.sextas,
    SightTexture.contrario,
  ],
  if (step.level >= _answerFromLevel) SightTexture.perguntaResposta,
];

/// Níveis em que as vozes entram (as tonalidades novas) e em que entra a
/// pergunta e resposta.
const _voicesFromLevel = 11;
const _answerFromLevel = 15;

/// A esquerda acompanha, e a direita é sorteada por cima dos acordes dela.
_Pautas _accompanied(SightStep step, Random rng) {
  final left = _accompaniment(step, rng);
  return (_melody(step, rng, harmony: left), left);
}

/// A direita é a melodia, e a esquerda a repete na voz de [texture].
_Pautas _voiced(SightStep step, Random rng, SightTexture texture) {
  final right = _melody(step, rng);
  return (right, _mapDegrees(right, (d) => _voiceDegree(d, texture)));
}

/// A direita pergunta nos compassos pares (0 e 2) e a esquerda responde nos
/// ímpares (1 e 3), repetindo o último compasso uma quinta abaixo. Quem não
/// toca fica em pausa de compasso inteiro.
_Pautas _answered(SightStep step, Random rng) {
  final call = _melody(step, rng);
  final silent = [SightNote(step.unitsPerMeasure)];
  final right = [
    for (var m = 0; m < sightMeasures; m++) m.isEven ? call[m] : silent,
  ];
  final left = [
    for (var m = 0; m < sightMeasures; m++)
      m.isOdd
          ? _mapDegrees([call[m - 1]], (d) => _toBass(d + 3)).single
          : silent,
  ];
  return (right, left);
}

/// O grau da pauta de fá que faz a voz [texture] com o grau [d] da de sol. A
/// de fá soa uma oitava abaixo, então a terça abaixo de [d] é `d + 5` (e não
/// `d - 2`), a sexta é `d + 2`; o espelho é em torno do dó da pauta de sol.
int _voiceDegree(int d, SightTexture texture) => _toBass(switch (texture) {
  SightTexture.tercas => d + 5,
  SightTexture.sextas => d + 2,
  SightTexture.contrario => 9 - d,
  _ => throw ArgumentError.value(texture, 'texture', 'não é uma voz'),
});

/// Traz o grau para a faixa de 1 a 8 da pauta de fá, sete graus de cada vez
/// (uma oitava). O intervalo, contado em graus, não muda.
int _toBass(int degree) {
  var d = degree;
  while (d < 1) {
    d += 7;
  }
  while (d > 8) {
    d -= 7;
  }
  return d;
}

/// A pauta com cada grau trocado por [toLeft]; as pausas continuam pausas.
List<List<SightNote>> _mapDegrees(
  List<List<SightNote>> pauta,
  int Function(int) toLeft,
) => [
  for (final measure in pauta)
    [
      for (final n in measure)
        SightNote(n.units, n.isRest ? null : toLeft(n.degree!)),
    ],
];

/// A cadência: o último compasso da pauta, se tiver som, termina na tônica.
/// Compasso mudo fica mudo.
List<List<SightNote>> _cadence(List<List<SightNote>> pauta) {
  final last = pauta.last;
  if (last.every((n) => n.isRest)) return pauta;
  return [
    ...pauta.take(pauta.length - 1),
    [...last.take(last.length - 1), SightNote(last.last.units, 1)],
  ];
}

/// Chance de uma nota ganhar um desvio de grau (um passo acima ou abaixo).
const _variationChance = 0.2;

const _variations = [-1, 0, 0, 1];

/// A partir deste nível, às vezes uma nota foge do padrão e dá um salto: o
/// curso já introduz os intervalos maiores no nível 7.
const _leapFromLevel = 7;

/// Chance de uma nota fugir do padrão, nos níveis a partir de
/// [_leapFromLevel].
const _leapChance = 0.15;

/// A linha melódica: um padrão sorteado no início do exercício, seguido sem
/// pular, com pausas, desvios de grau e, nos níveis altos, saltos de vez em
/// quando. Com a [harmony] da outra mão, as notas nos tempos fortes são notas
/// do acorde dela.
List<List<SightNote>> _melody(
  SightStep step,
  Random rng, {
  List<List<SightNote>>? harmony,
}) {
  final pattern = step.patterns[rng.nextInt(step.patterns.length)];
  final leap = step.level >= _leapFromLevel ? _leapChance : 0.0;
  var next = 0;
  var prev = 1;
  final measures = <List<SightNote>>[];
  for (var m = 0; m < sightMeasures; m++) {
    final notes = <SightNote>[];
    var pos = 0;
    while (pos < step.unitsPerMeasure) {
      final units = _figure(step.durations, pos, step.unitsPerMeasure, rng);
      final start = pos;
      pos += units;
      if (notes.isNotEmpty && rng.nextDouble() < step.restChance) {
        notes.add(SightNote(units));
        continue;
      }
      var degree = pattern[next % pattern.length];
      next++;
      if (notes.isNotEmpty && leap > 0 && rng.nextDouble() < leap) {
        degree = _leapFrom(prev, step.high, rng);
      } else if (notes.isNotEmpty && rng.nextDouble() < _variationChance) {
        degree += _variations[rng.nextInt(_variations.length)];
      }
      degree = _inRange(degree, step);
      final bass = harmony == null ? null : _degreeAt(harmony, m, start);
      if (bass != null && _strongBeats(step.unitsPerMeasure).contains(start)) {
        degree = _chordTone(degree, bass, step.high);
      }
      notes.add(SightNote(units, degree));
      prev = degree;
    }
    measures.add(notes);
  }
  return measures;
}

/// Um grau sorteado de 1 a [high], pesando os vizinhos de [prev]: grau igual
/// ou perto pesa mais, e o salto grande existe, mas é raro.
int _leapFrom(int prev, int high, Random rng) {
  final weights = [
    for (var d = 1; d <= high; d++) _distanceWeight((d - prev).abs()),
  ];
  var r = rng.nextDouble() * weights.reduce((a, b) => a + b);
  for (var i = 0; i < weights.length; i++) {
    r -= weights[i];
    if (r < 0) return i + 1;
  }
  return high;
}

double _distanceWeight(int distance) => switch (distance) {
  0 => 0.25,
  <= 2 => 3.0,
  <= 4 => 1.4,
  <= 7 => 0.5,
  _ => 0.1,
};

/// O grau que soa no compasso [m] da pauta, no [pos] (em dezesseis avos);
/// `null` se é pausa.
int? _degreeAt(List<List<SightNote>> pauta, int m, int pos) {
  var at = 0;
  for (final n in pauta[m]) {
    if (pos < at + n.units) return n.degree;
    at += n.units;
  }
  return null;
}

/// O grau mais perto de [degree] que está no acorde da [bass]: a tríade que
/// se arma sobre o grau, com a terça e a quinta contadas na escala.
int _chordTone(int degree, int bass, int high) {
  final chord = {
    for (final s in const [0, 2, 4]) (bass - 1 + s) % 7,
  };
  var best = degree;
  var bestDistance = 1 << 30;
  for (var d = 1; d <= high; d++) {
    if (!chord.contains((d - 1) % 7)) continue;
    final distance = (d - degree).abs();
    if (distance < bestDistance) {
      best = d;
      bestDistance = distance;
    }
  }
  return best;
}

/// Os acordes da mão esquerda quando as duas tocam: a figura é a mais longa
/// que cabe, e o padrão é de acompanhamento (mais simples nos primeiros
/// níveis, mais melódico depois).
List<List<SightNote>> _accompaniment(SightStep step, Random rng) {
  final patterns = step.level <= 5
      ? _harmonic
      : step.level <= 6
      ? _bassLines
      : _fullBass;
  final pattern = patterns[rng.nextInt(patterns.length)];
  final durations = step.level <= 4
      ? [step.unitsPerMeasure]
      : step.level <= 6
      ? const [8, 4]
      : step.durations;
  var next = 0;
  final measures = <List<SightNote>>[];
  for (var m = 0; m < sightMeasures; m++) {
    final notes = <SightNote>[];
    var pos = 0;
    while (pos < step.unitsPerMeasure) {
      final units = _figures(
        durations,
        pos,
        step.unitsPerMeasure,
      ).reduce((a, b) => max(a, b));
      pos += units;
      if (notes.isNotEmpty && rng.nextDouble() < step.restChance * 0.5) {
        notes.add(SightNote(units));
        continue;
      }
      final degree = pattern[next % pattern.length];
      next++;
      notes.add(SightNote(units, _inRange(degree, step)));
    }
    measures.add(notes);
  }
  return measures;
}

/// Uma figura sorteada entre as que [_figures] liberou a partir de [pos].
int _figure(List<int> durations, int pos, int measure, Random rng) {
  final options = _figures(durations, pos, measure);
  return options[rng.nextInt(options.length)];
}

/// As figuras de [durations] que cabem a partir de [pos] e não atrapalham o
/// tempo ([_onTime]). Se nenhuma serve, valem todas as que cabem.
List<int> _figures(List<int> durations, int pos, int measure) {
  final left = measure - pos;
  final ok = [
    for (final d in durations)
      if (d <= left && _onTime(pos, d, measure)) d,
  ];
  if (ok.isNotEmpty) return ok;
  final fits = [
    for (final d in durations)
      if (d <= left) d,
  ];
  return fits.isEmpty ? [left] : fits;
}

/// Os tempos fortes do compasso, em dezesseis avos: o primeiro e, no 4/4, o
/// terceiro.
List<int> _strongBeats(int measure) => measure == 16 ? const [0, 8] : const [0];

/// Se a figura de [units] que começa em [pos] não atrapalha o tempo. Quem
/// começa fora do tempo tem que terminar nele; quem começa num tempo fraco não
/// pode atravessar o tempo forte seguinte. Quem começa no tempo forte pode ser
/// tão longa quanto couber.
bool _onTime(int pos, int units, int measure) {
  if (pos % 4 != 0) return pos % 4 + units <= 4;
  final strong = _strongBeats(measure);
  if (strong.contains(pos)) return true;
  final next = strong.firstWhere((s) => s > pos, orElse: () => measure);
  return pos + units <= next;
}

int _inRange(int degree, SightStep step) => min(max(degree, 1), step.high);

final List<List<int>> _harmonic = [
  [1],
  [1, 5],
  [1, 3, 5],
  [1, 5, 1, 5],
  [1, 3, 5, 3],
];

final List<List<int>> _bassLines = [
  [1, 2, 3, 2],
  [1, 3, 5, 3],
  [5, 4, 3, 2, 1],
  [1, 2, 3, 4, 5],
  ...classicalPatterns.sublist(0, 3),
];

final List<List<int>> _fullBass = [
  ...stepwisePatterns.sublist(0, 5),
  ...classicalPatterns,
  [1, 5, 8, 5],
  [8, 7, 6, 5],
];
