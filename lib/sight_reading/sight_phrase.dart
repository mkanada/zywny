// E05 — a frase que soa: as notas escritas de um exercício como eventos com
// hora marcada, e as notas que o zywny toca (acorde da tônica antes).

import 'dart:math';

import '../course/exercise/exercise_round.dart';
import 'sight_generator.dart';
import 'sight_score.dart';
import 'sight_steps.dart';

/// Uma nota escrita da frase: a pauta, o compasso (base 0) e a posição, em
/// dezesseis avos desde o começo do exercício. [ids] são as notas escritas que
/// ela representa (uma, ou duas quando a mudança juntou figuras).
class SightEvent {
  const SightEvent({
    required this.staff,
    required this.measure,
    required this.start,
    required this.units,
    required this.degree,
    required this.midi,
    required this.ids,
  });

  final int staff;
  final int measure;
  final int start;
  final int units;

  /// O grau escrito (1 é a tônica), para fazer a conta de uma mudança.
  final int degree;
  final int midi;
  final List<String> ids;

  SightEvent copyWith({
    int? start,
    int? units,
    int? degree,
    int? midi,
    List<String>? ids,
  }) => SightEvent(
    staff: staff,
    measure: measure,
    start: start ?? this.start,
    units: units ?? this.units,
    degree: degree ?? this.degree,
    midi: midi ?? this.midi,
    ids: ids ?? this.ids,
  );
}

/// A ordem da frase: pelo começo e, no mesmo instante, a pauta de sol antes da
/// de fá.
int sightEventOrder(SightEvent a, SightEvent b) => a.start != b.start
    ? a.start.compareTo(b.start)
    : a.staff.compareTo(b.staff);

/// As notas de [ex], das duas pautas, em ordem de começo. Pausas não entram.
List<SightEvent> sightEvents(SightExercise ex) {
  final out = <SightEvent>[];
  for (final staff in [1, 2]) {
    final measures = staff == 1 ? ex.right : ex.left;
    for (var m = 0; m < measures.length; m++) {
      final notes = measures[m];
      var at = m * ex.step.unitsPerMeasure;
      for (var i = 0; i < notes.length; i++) {
        final note = notes[i];
        if (!note.isRest) {
          final degree = note.degree!;
          out.add(
            SightEvent(
              staff: staff,
              measure: m,
              start: at,
              units: note.units,
              degree: degree,
              midi: sightMidi(ex.step, degree, staff: staff),
              ids: [sightNoteId(staff, m, i)],
            ),
          );
        }
        at += note.units;
      }
    }
  }
  out.sort(sightEventOrder);
  return out;
}

/// Andamento em que a frase soa (D-LEI-ANDAMENTO): o do passo, nunca abaixo
/// de 72.
int sightListenBpm(SightStep step) => max(step.bpm, 72);

/// Segundos em que o acorde da tônica soa antes da frase, e o silêncio depois.
const kSightChordSeconds = 1.2;
const kSightChordGap = 0.6;

/// As alturas do acorde da tônica, que soa antes da frase: os graus 1, 3 e 5
/// na pauta de sol e o grau 1 na de fá.
List<int> sightChordMidis(SightStep step) => [
  for (final (staff, degree) in const [(1, 1), (1, 3), (1, 5), (2, 1)])
    sightMidi(step, degree, staff: staff),
];

/// [events] como notas com hora marcada, em [bpm] semínimas por minuto. Com
/// [withTonic], o acorde da tônica (graus 1, 3 e 5 na pauta de sol e o grau 1
/// na de fá) soa antes, por [kSightChordSeconds]. Cada nota soa por 95% do seu
/// valor, para as repetidas se separarem.
List<TimedNote> sightTimedNotes(
  SightStep step,
  List<SightEvent> events, {
  required int bpm,
  bool withTonic = true,
}) {
  final secondsPerUnit = 60 / bpm / 4;
  final offset = withTonic ? kSightChordSeconds + kSightChordGap : 0.0;
  return [
    if (withTonic)
      for (final midi in sightChordMidis(step))
        TimedNote(midi, 0, kSightChordSeconds),
    for (final e in events)
      TimedNote(
        e.midi,
        offset + e.start * secondsPerUnit,
        e.units * secondsPerUnit * 0.95,
      ),
  ];
}
