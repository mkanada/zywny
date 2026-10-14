// E05 — a mudança sorteada: uma nota da frase soa diferente do que está
// escrito. Uma mudança por pergunta, e a primeira nota da frase nunca muda.

import 'dart:math';

import 'sight_phrase.dart';
import 'sight_score.dart';
import 'sight_steps.dart';

/// O que muda entre o escrito e o que soa.
enum SightChange { pitch, rhythm, accidental }

/// As mudanças que cabem no [step]: `pitch` e `rhythm` sempre; `accidental`
/// só com armadura.
List<SightChange> sightChangesFor(SightStep step) => [
  SightChange.pitch,
  SightChange.rhythm,
  if (step.tonic != 'C') SightChange.accidental,
];

/// O que soa depois da mudança.
class SightChanged {
  const SightChanged({
    required this.played,
    required this.measure,
    required this.changedIds,
    required this.description,
  });

  /// Os eventos que soam, em ordem.
  final List<SightEvent> played;

  /// O compasso (base 0) onde a mudança caiu.
  final int measure;

  /// As notas escritas que soam diferente (para destacar na revelação).
  final Set<String> changedIds;

  /// O que mudou, para a revelação.
  final String description;
}

/// Um lugar onde a mudança cabe: o compasso e a figura [index] da frase. Em
/// `juntar`, [partner] é a figura seguinte, que vira uma só com ela.
class _Spot {
  const _Spot(this.measure, this.index, {this.partner});

  final int measure;
  final int index;
  final int? partner;
}

/// As somas que uma figura junta pode dar (uma figura só).
const _figures = {2, 3, 4, 6, 8, 12, 16};

/// Aplica uma mudança de [change] a [written]. `null` quando não há nota onde
/// aplicá-la (por exemplo, `accidental` sem nenhuma nota alterada pela
/// armadura).
SightChanged? changeSight(
  SightStep step,
  List<SightEvent> written,
  SightChange change,
  Random rng,
) {
  var spots = _spots(step, written, change);
  if (change == SightChange.rhythm) {
    // Dividir e juntar com a mesma chance. Se o sorteado não cabe em lugar
    // nenhum, os lugares que sobram são todos do outro tipo.
    final join = rng.nextBool();
    final preferred = [
      for (final s in spots)
        if ((s.partner != null) == join) s,
    ];
    if (preferred.isNotEmpty) spots = preferred;
  }
  if (spots.isEmpty) return null;

  // Primeiro o compasso, depois a nota dentro dele: os quatro compassos saem
  // com chance parecida, mesmo que um tenha mais notas.
  final measures = {for (final s in spots) s.measure}.toList()..sort();
  final measure = measures[rng.nextInt(measures.length)];
  final inMeasure = [
    for (final s in spots)
      if (s.measure == measure) s,
  ];
  final spot = inMeasure[rng.nextInt(inMeasure.length)];
  return switch (change) {
    SightChange.pitch => _pitch(step, written, spot.index, rng),
    SightChange.accidental => _accidental(step, written, spot.index),
    SightChange.rhythm =>
      spot.partner == null
          ? _divide(written, spot.index)
          : _join(written, spot.index, spot.partner!),
  };
}

/// Os lugares onde [change] cabe. A primeira figura nunca entra.
List<_Spot> _spots(
  SightStep step,
  List<SightEvent> written,
  SightChange change,
) {
  final spots = <_Spot>[];
  for (var i = 1; i < written.length; i++) {
    final e = written[i];
    switch (change) {
      case SightChange.pitch:
        spots.add(_Spot(e.measure, i));
      case SightChange.accidental:
        if (sightAlter(step, e.degree) != 0) spots.add(_Spot(e.measure, i));
      case SightChange.rhythm:
        if (e.units >= 2) spots.add(_Spot(e.measure, i));
        final partner = _joinPartner(step, written, i);
        if (partner != null) spots.add(_Spot(e.measure, i, partner: partner));
    }
  }
  return spots;
}

/// A figura que segue `written[i]` e pode juntar-se a ela: na mesma pauta, sem
/// pausa entre as duas, no mesmo compasso, com uma soma que é figura e (em 4/4)
/// sem cruzar a metade do compasso. `null` quando não há.
int? _joinPartner(SightStep step, List<SightEvent> written, int i) {
  final a = written[i];
  final end = a.start + a.units;
  final j = written.indexWhere((b) => b.staff == a.staff && b.start == end);
  if (j < 0) return null;
  final b = written[j];
  final sum = a.units + b.units;
  if (b.measure != a.measure || !_figures.contains(sum)) return null;
  if (!step.threeFour) {
    final half = step.unitsPerMeasure ~/ 2;
    final at = a.start - a.measure * step.unitsPerMeasure;
    if ((at < half) != (at + sum <= half)) return null;
  }
  return j;
}

/// Troca a altura de `written[i]` por outro grau da mesma pauta: 2 ou 3 graus
/// até o nível 6, 1 ou 2 do 7 em diante (D-LEI-MUDANCA). Se o grau novo sair
/// da faixa, o deslocamento vai para o lado contrário.
SightChanged _pitch(
  SightStep step,
  List<SightEvent> written,
  int i,
  Random rng,
) {
  final e = written[i];
  final top = e.staff == 1 ? max(step.high, 5) : 8;
  final sizes = step.level <= 6 ? const [2, 3] : const [1, 2];
  final size = sizes[rng.nextInt(sizes.length)] * (rng.nextBool() ? 1 : -1);
  var degree = e.degree + size;
  if (degree < 1 || degree > top) degree = e.degree - size;
  final moved = e.copyWith(
    degree: degree,
    midi: sightMidi(step, degree, staff: e.staff),
  );
  return SightChanged(
    played: _replace(written, {i}, [moved]),
    measure: e.measure,
    changedIds: e.ids.toSet(),
    description: degree > e.degree
        ? 'uma nota soou mais aguda'
        : 'uma nota soou mais grave',
  );
}

/// Tira o acidente da armadura de `written[i]`: a altura perde a alteração, e
/// a nota soa natural (em Sol, o Fá♯ escrito soa Fá).
SightChanged _accidental(SightStep step, List<SightEvent> written, int i) {
  final e = written[i];
  final natural = e.copyWith(midi: e.midi - sightAlter(step, e.degree));
  return SightChanged(
    played: _replace(written, {i}, [natural]),
    measure: e.measure,
    changedIds: e.ids.toSet(),
    description: 'a nota soou sem o acidente da armadura',
  );
}

/// Divide `written[i]` em duas figuras da mesma altura: ao meio, ou, nas
/// pontuadas (3, 6, 12), em 2/3 e o resto (2+1, 4+2, 8+4).
SightChanged _divide(List<SightEvent> written, int i) {
  final e = written[i];
  final first = e.units % 3 == 0 ? e.units * 2 ~/ 3 : e.units ~/ 2;
  final halves = [
    e.copyWith(units: first),
    e.copyWith(start: e.start + first, units: e.units - first),
  ];
  return SightChanged(
    played: _replace(written, {i}, halves),
    measure: e.measure,
    changedIds: e.ids.toSet(),
    description: 'uma nota soou dividida em duas',
  );
}

/// Junta `written[i]` com a figura seguinte, `written[j]`, numa figura só da
/// altura da primeira.
SightChanged _join(List<SightEvent> written, int i, int j) {
  final a = written[i];
  final b = written[j];
  final joined = a.copyWith(
    units: a.units + b.units,
    ids: [...a.ids, ...b.ids],
  );
  return SightChanged(
    played: _replace(written, {i, j}, [joined]),
    measure: a.measure,
    changedIds: {...a.ids, ...b.ids},
    description: 'duas notas soaram como uma só',
  );
}

/// A frase sem as figuras de [drop] e com as de [add], em ordem.
List<SightEvent> _replace(
  List<SightEvent> written,
  Set<int> drop,
  List<SightEvent> add,
) {
  final out = [
    for (var k = 0; k < written.length; k++)
      if (!drop.contains(k)) written[k],
    ...add,
  ];
  return out..sort(sightEventOrder);
}
