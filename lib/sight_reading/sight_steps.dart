// Treino de leitura à primeira vista: os 80 passos (20 níveis, 4 subníveis
// cada) e o que cada um sorteia.
//
// As ideias (a ordem dos passos, as figuras e os padrões de graus) vêm do
// ftrain/sightreading, licenciado sob LGPL-3.0. O código aqui é escrito de
// novo, em Dart, sem copiar o texto do original.
//
// Figuras em dezesseis avos: 1 semicolcheia, 2 colcheia, 3 colcheia pontuada,
// 4 semínima, 6 semínima pontuada, 8 mínima, 12 mínima pontuada, 16 semibreve.

/// Que mãos o aluno toca: a pauta de sol, a de fá ou as duas.
enum SightHands { right, left, both }

/// Um passo do treino: o que o sorteio de `generateSight` usa para montar
/// uma rodada.
class SightStep {
  const SightStep({
    required this.level,
    required this.sub,
    required this.hands,
    required this.durations,
    required this.patterns,
    required this.bpm,
    required this.label,
    required this.high,
    this.restChance = 0,
    this.threeFour = false,
    this.tonic = 'C',
  });

  /// Nível, de 1 a 20.
  final int level;

  /// Subnível, de 0 (a) a 3 (d).
  final int sub;

  final SightHands hands;

  /// Figuras que o sorteio pode usar, em dezesseis avos.
  final List<int> durations;

  /// Padrões de graus (1 = tônica) que a melodia segue, na ordem.
  final List<List<int>> patterns;

  /// Andamento do passo, em semínimas por minuto.
  final int bpm;

  /// Texto que a tela mostra, em português.
  final String label;

  /// Grau mais agudo sorteado (1 é a tônica, 8 é a oitava).
  final int high;

  /// Chance de uma figura virar pausa (só depois da primeira figura do compasso).
  final double restChance;

  final bool threeFour;

  /// Tonalidade, como em `kKeyNames`: `C`, `G`, `Bb`…
  final String tonic;

  /// Nome curto do passo: `1a`, `7c`, `20d`.
  String get name => '$level${'abcd'[sub]}';

  /// Dezesseis avos por compasso.
  int get unitsPerMeasure => threeFour ? 12 : 16;
}

/// Subníveis por nível.
const sightSubLevels = 4;

/// O último nível: depois de 20d, o treino continua no mesmo passo.
const sightLastLevel = 20;

/// Os 80 passos, do 1a ao 20d, na ordem do treino.
final List<SightStep> sightSteps = List.unmodifiable([
  // Nível 1: semibreves, mão direita, em dó maior.
  _s(
    1,
    0,
    SightHands.right,
    [16],
    [
      [1, 5],
      [5, 1],
      [1, 1, 5],
      [5, 5, 1],
    ],
    30,
    'Dó e sol · semibreves · mão direita',
    high: 5,
  ),
  _s(
    1,
    1,
    SightHands.right,
    [16],
    [
      [1, 3, 5],
      [5, 3, 1],
      [1, 3],
      [3, 5],
    ],
    30,
    'Dó, mi e sol · semibreves · mão direita',
    high: 5,
  ),
  _s(
    1,
    2,
    SightHands.right,
    [16],
    [
      [1, 2, 3],
      [3, 2, 1],
      [1, 2, 3, 4, 5],
    ],
    30,
    'Dó a sol · semibreves · mão direita',
    high: 5,
  ),
  _s(
    1,
    3,
    SightHands.right,
    [16],
    stepwisePatterns,
    30,
    'Graus conjuntos · semibreves · mão direita',
    high: 5,
  ),
  // Nível 2: as mesmas figuras, na pauta de fá.
  _s(
    2,
    0,
    SightHands.left,
    [16],
    [
      [1, 5],
      [5, 1],
      [1, 1, 5],
      [5, 5, 1],
    ],
    30,
    'Dó e sol · semibreves · mão esquerda',
    high: 5,
  ),
  _s(
    2,
    1,
    SightHands.left,
    [16],
    [
      [1, 3, 5],
      [5, 3, 1],
      [1, 3],
      [3, 5],
    ],
    30,
    'Dó, mi e sol · semibreves · mão esquerda',
    high: 5,
  ),
  _s(
    2,
    2,
    SightHands.left,
    [16],
    [
      [1, 2, 3],
      [3, 2, 1],
      [1, 2, 3, 4, 5],
    ],
    30,
    'Dó a sol · semibreves · mão esquerda',
    high: 5,
  ),
  _s(
    2,
    3,
    SightHands.left,
    [16],
    stepwisePatterns,
    30,
    'Graus conjuntos · semibreves · mão esquerda',
    high: 5,
  ),
  // Nível 3: semibreves, as duas mãos.
  _s(
    3,
    0,
    SightHands.both,
    [16],
    [
      [1, 5],
      [5, 1],
    ],
    30,
    'Coordenação simples · semibreves · as duas mãos',
    high: 5,
  ),
  _s(
    3,
    1,
    SightHands.both,
    [16],
    triadicPatterns.sublist(0, 3),
    30,
    'Tríades · semibreves · as duas mãos',
    high: 5,
  ),
  _s(
    3,
    2,
    SightHands.both,
    [16],
    stepwisePatterns.sublist(0, 5),
    30,
    'Graus conjuntos · semibreves · as duas mãos',
    high: 5,
  ),
  _s(
    3,
    3,
    SightHands.both,
    [16],
    [...stepwisePatterns, ...triadicPatterns],
    30,
    'Padrões completos · semibreves · as duas mãos',
    high: 5,
  ),
  // Nível 4: mínimas, depois semibreves e mínimas.
  _s(
    4,
    0,
    SightHands.right,
    [8],
    [
      [1, 5],
      [5, 1],
      [1, 3, 5],
    ],
    30,
    'Mínimas · mão direita',
    high: 5,
  ),
  _s(
    4,
    1,
    SightHands.left,
    [8],
    [
      [1, 5],
      [5, 1],
      [1, 3, 5],
    ],
    30,
    'Mínimas · mão esquerda',
    high: 5,
  ),
  _s(
    4,
    2,
    SightHands.right,
    [16, 8],
    [...stepwisePatterns.sublist(0, 5), ...triadicPatterns.sublist(0, 3)],
    30,
    'Semibreves e mínimas · mão direita',
    high: 5,
  ),
  _s(
    4,
    3,
    SightHands.both,
    [16, 8],
    [...stepwisePatterns, ...triadicPatterns],
    30,
    'Semibreves e mínimas · as duas mãos',
    high: 5,
  ),
  // Nível 5: semínimas.
  _s(
    5,
    0,
    SightHands.right,
    [4],
    stepwisePatterns,
    40,
    'Semínimas em graus conjuntos · mão direita',
    high: 6,
  ),
  _s(
    5,
    1,
    SightHands.left,
    [4],
    stepwisePatterns,
    40,
    'Semínimas em graus conjuntos · mão esquerda',
    high: 6,
  ),
  _s(
    5,
    2,
    SightHands.right,
    [4, 8],
    folkPatterns.sublist(0, 3),
    40,
    'Semínimas e mínimas · mão direita',
    high: 6,
  ),
  _s(
    5,
    3,
    SightHands.both,
    [4, 8],
    folkPatterns.sublist(0, 5),
    40,
    'Semínimas e mínimas · as duas mãos',
    high: 6,
  ),
  // Nível 6: pausas e compasso de 3/4.
  _s(
    6,
    0,
    SightHands.right,
    [8, 4],
    stepwisePatterns,
    40,
    'Pausas de semínima · mão direita',
    high: 6,
    restChance: 0.15,
  ),
  _s(
    6,
    1,
    SightHands.left,
    [8, 4],
    stepwisePatterns,
    40,
    'Pausas de semínima · mão esquerda',
    high: 6,
    restChance: 0.15,
  ),
  _s(
    6,
    2,
    SightHands.right,
    [8, 4],
    [...folkPatterns.sublist(0, 5), ...triadicPatterns],
    40,
    'Compasso de 3/4 · mão direita',
    high: 6,
    restChance: 0.1,
    threeFour: true,
  ),
  _s(
    6,
    3,
    SightHands.both,
    [16, 8, 4],
    folkPatterns,
    40,
    'Compasso de 3/4 · as duas mãos',
    high: 6,
    restChance: 0.1,
    threeFour: true,
  ),
  // Nível 7: mínima pontuada e intervalos maiores.
  _s(
    7,
    0,
    SightHands.right,
    [12, 8, 4],
    stepwisePatterns,
    50,
    'Mínima pontuada · mão direita',
    high: 8,
  ),
  _s(
    7,
    1,
    SightHands.left,
    [12, 8, 4],
    stepwisePatterns,
    50,
    'Mínima pontuada · mão esquerda',
    high: 8,
  ),
  _s(
    7,
    2,
    SightHands.right,
    [8, 4],
    [
      [1, 6],
      [6, 1],
      [1, 3, 5],
      [3, 8],
      ...triadicPatterns,
    ],
    50,
    'Intervalos de sexta · mão direita',
    high: 8,
  ),
  _s(
    7,
    3,
    SightHands.both,
    [12, 8, 4],
    [...folkPatterns, ..._sixths],
    50,
    'Extensão toda · as duas mãos',
    high: 8,
  ),
  // Nível 8: colcheias.
  _s(
    8,
    0,
    SightHands.right,
    [2],
    stepwisePatterns,
    55,
    'Colcheias em graus conjuntos · mão direita',
    high: 8,
  ),
  _s(
    8,
    1,
    SightHands.left,
    [2],
    stepwisePatterns,
    55,
    'Colcheias em graus conjuntos · mão esquerda',
    high: 8,
  ),
  _s(
    8,
    2,
    SightHands.right,
    [2, 4],
    [...stepwisePatterns, ...folkPatterns.sublist(0, 3)],
    55,
    'Colcheias e semínimas · mão direita',
    high: 8,
  ),
  _s(
    8,
    3,
    SightHands.both,
    [2, 4],
    [...stepwisePatterns, ...folkPatterns.sublist(0, 5)],
    55,
    'Colcheias e semínimas · as duas mãos',
    high: 8,
  ),
  // Nível 9: colcheia pontuada.
  _s(
    9,
    0,
    SightHands.right,
    [3, 2, 4],
    stepwisePatterns,
    50,
    'Colcheia pontuada · mão direita',
    high: 8,
  ),
  _s(
    9,
    1,
    SightHands.left,
    [3, 2, 4],
    stepwisePatterns,
    50,
    'Colcheia pontuada · mão esquerda',
    high: 8,
  ),
  _s(
    9,
    2,
    SightHands.right,
    [3, 2, 4, 8],
    [...folkPatterns, ...triadicPatterns],
    50,
    'Síncopas · mão direita',
    high: 8,
  ),
  _s(
    9,
    3,
    SightHands.both,
    [3, 2, 4],
    [...folkPatterns, ...classicalPatterns.sublist(0, 5)],
    50,
    'Colcheia pontuada · as duas mãos',
    high: 8,
  ),
  // Nível 10: semicolcheias.
  _s(
    10,
    0,
    SightHands.right,
    [1],
    stepwisePatterns.sublist(0, 5),
    45,
    'Semicolcheias em graus conjuntos · mão direita',
    high: 8,
  ),
  _s(
    10,
    1,
    SightHands.left,
    [1],
    stepwisePatterns.sublist(0, 5),
    45,
    'Semicolcheias em graus conjuntos · mão esquerda',
    high: 8,
  ),
  _s(
    10,
    2,
    SightHands.right,
    [1, 2, 4],
    [...stepwisePatterns, ...folkPatterns.sublist(0, 3)],
    45,
    'Figuras mistas · mão direita',
    high: 8,
  ),
  _s(
    10,
    3,
    SightHands.both,
    [1, 2, 4],
    [...stepwisePatterns, ...folkPatterns.sublist(0, 5)],
    45,
    'Semicolcheias · as duas mãos',
    high: 8,
  ),
  // Níveis 11 a 20: uma tonalidade nova por nível, começando do básico.
  for (var level = 11; level <= 20; level++) ..._newKey(level),
]);

/// O passo do [level] (1 a 20) no subnível [sub] (0 a 3).
SightStep sightStep(int level, int sub) =>
    sightSteps[(level - 1) * sightSubLevels + sub];

/// Tonalidades dos níveis 11 a 20, na ordem em que aparecem.
const _newKeys = ['G', 'F', 'D', 'Bb', 'A', 'Eb', 'E', 'Ab', 'B', 'Db'];

/// Nome em português de cada tonalidade de [_newKeys] e do dó maior.
const _keyNames = {
  'C': 'Dó',
  'G': 'Sol',
  'F': 'Fá',
  'D': 'Ré',
  'Bb': 'Si bemol',
  'A': 'Lá',
  'Eb': 'Mi bemol',
  'E': 'Mi',
  'Ab': 'Lá bemol',
  'B': 'Si',
  'Db': 'Ré bemol',
};

List<SightStep> _newKey(int level) {
  final tonic = _newKeys[level - 11];
  final name = '${_keyNames[tonic]} maior';
  return [
    _s(
      level,
      0,
      SightHands.right,
      [16],
      stepwisePatterns,
      35,
      '$name · semibreves · mão direita',
      high: 8,
      tonic: tonic,
    ),
    _s(
      level,
      1,
      SightHands.left,
      [16],
      stepwisePatterns,
      35,
      '$name · semibreves · mão esquerda',
      high: 8,
      tonic: tonic,
    ),
    _s(
      level,
      2,
      SightHands.right,
      [4, 8],
      [...folkPatterns.sublist(0, 5), ...triadicPatterns],
      45,
      '$name · semínimas e mínimas · mão direita',
      high: 8,
      restChance: 0.1,
      tonic: tonic,
    ),
    _s(
      level,
      3,
      SightHands.both,
      [4, 8],
      [...folkPatterns, ...classicalPatterns],
      50,
      '$name · semínimas e mínimas · as duas mãos',
      high: 8,
      restChance: 0.1,
      tonic: tonic,
    ),
  ];
}

SightStep _s(
  int level,
  int sub,
  SightHands hands,
  List<int> durations,
  List<List<int>> patterns,
  int bpm,
  String label, {
  required int high,
  double restChance = 0,
  bool threeFour = false,
  String tonic = 'C',
}) => SightStep(
  level: level,
  sub: sub,
  hands: hands,
  durations: durations,
  patterns: patterns,
  bpm: bpm,
  label: label,
  high: high,
  restChance: restChance,
  threeFour: threeFour,
  tonic: tonic,
);

// Padrões de graus, como no ftrain: escalas, arpejos, trechos de canções
// conhecidas e saltos maiores.

final List<List<int>> stepwisePatterns = [
  [1, 2, 3],
  [3, 2, 1],
  [1, 2, 3, 2, 1],
  [5, 4, 3],
  [3, 4, 5],
  [1, 2, 3, 4, 5],
  [5, 4, 3, 2, 1],
  [1, 2, 1],
  [3, 2, 3],
  [5, 6, 5],
];

final List<List<int>> triadicPatterns = [
  [1, 3, 5],
  [5, 3, 1],
  [1, 3, 5, 3],
  [5, 3, 1, 3],
  [1, 5, 3],
  [3, 1, 5],
];

final List<List<int>> folkPatterns = [
  [3, 2, 1, 2, 3, 3, 3],
  [1, 1, 5, 5, 6, 6, 5],
  [3, 2, 1],
  [3, 2, 1, 2, 3, 3, 3],
  [3, 3, 4, 5, 5, 4, 3, 2],
  [1, 1, 1, 2, 3, 2, 1, 3, 2, 2, 1],
  [1, 2, 3, 1],
  [1, 1, 1, 2, 3],
  [5, 4, 3, 4, 5, 5, 5],
];

final List<List<int>> classicalPatterns = [
  [1, 5, 3, 5],
  [1, 3, 5, 3],
  [1, 5, 3, 5, 1, 5, 3, 5],
  [5, 4, 5, 4, 5, 2, 4, 3, 1],
  [1, 5, 3],
  [5, 4, 3, 2, 1],
];

final List<List<int>> _sixths = [
  [1, 6],
  [6, 1],
  [1, 6, 1],
  [3, 8],
  [8, 3],
];
