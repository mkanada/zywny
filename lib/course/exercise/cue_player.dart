// E02 — toca os sons de uma pergunta (`Question.sound`) num SoundEngine.
// E05 — `playTimed` toca notas com hora marcada (a frase de `listen-score`).

import 'dart:math';

import 'package:zywny_audio/sound_engine.dart';

import 'exercise_round.dart';

/// Silêncio entre um [SoundCue] e o seguinte.
const double kCueGapSeconds = 0.3;

/// Cala o que estiver soando e agenda [cues], um depois do outro, a partir
/// de `engine.earliestScheduleSeconds`. Devolve quanto tudo dura, em
/// segundos (0 sem sons).
double playCues(SoundEngine engine, List<SoundCue> cues, {int velocity = 90}) {
  engine.allNotesOff();
  if (cues.isEmpty) return 0;
  final start = engine.earliestScheduleSeconds;
  var at = start;
  final events = <ScheduledMidi>[];
  for (final cue in cues) {
    for (final pitch in cue.pitches) {
      events.add(ScheduledMidi(at, 0x90, pitch, velocity));
    }
    for (final pitch in cue.pitches) {
      events.add(ScheduledMidi(at + cue.seconds, 0x80, pitch, 0));
    }
    at += cue.seconds + kCueGapSeconds;
  }
  engine.schedule(events);
  return at - kCueGapSeconds - start;
}

/// Cala o que estiver soando e agenda [notes], cada uma na sua hora, a partir
/// de `engine.earliestScheduleSeconds`. Devolve quanto tudo dura, em segundos
/// (0 sem notas).
double playTimed(
  SoundEngine engine,
  List<TimedNote> notes, {
  int velocity = 90,
}) {
  engine.allNotesOff();
  if (notes.isEmpty) return 0;
  final start = engine.earliestScheduleSeconds;
  final events = <ScheduledMidi>[];
  var end = 0.0;
  for (final note in notes) {
    final on = start + note.start;
    events
      ..add(ScheduledMidi(on, 0x90, note.pitch, velocity))
      ..add(ScheduledMidi(on + note.seconds, 0x80, note.pitch, 0));
    end = max(end, note.start + note.seconds);
  }
  engine.schedule(events);
  return end;
}
