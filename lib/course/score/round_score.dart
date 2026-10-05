import 'dart:math';

import '../format/course_model.dart';
import '../format/figure_rules.dart';
import '../format/note_name.dart';
import '../format/vocabulary.dart';
import 'key_signature.dart';

// Gerador de MusicXML 4.0 das rodadas sorteadas (play-notes, name-note,
// find-key, rhythm, count-beats): uma parte, 1 ou 2 pautas, Dart puro.
//
// Convenções:
// - `divisions` = 2 por semínima, então 1 colcheia = 1 unidade
//   (`Figure.eighths`).
// - Uma `Pitch` é a nota **que soa**: o sorteio com `key` já devolve F# na
//   armadura de Sol. O acidente **escrito** só aparece quando a nota difere
//   do que a armadura e o compasso já valem ("vale até a barra").

/// O id (`xml:id`) da i-ésima nota (base 0) escrita nas partituras daqui.
/// O Verovio o preserva no `.vsb` — é por ele que o I07 destaca a nota da vez.
String roundNoteId(int index) => 'zn${index + 1}';

/// Pausas e notas são eventos de uma pauta; o gerador agrupa em compassos.
class _Event {
  _Event({
    required this.duration,
    required this.type,
    this.dots = 0,
    this.pitch,
    this.staff = 1,
    this.noteIndex,
  });

  /// Em unidades de `divisions` (colcheia = 1).
  final int duration;
  final String type;
  final int dots;

  /// `null` é pausa.
  final Pitch? pitch;
  final int staff;
  String? beam;

  /// Posição entre as **notas** (pausas não contam), para o [roundNoteId].
  final int? noteIndex;
}

({int beats, int beatType}) _timeParts(String time) => switch (time) {
  '3/4' => (beats: 3, beatType: 4),
  '2/4' => (beats: 2, beatType: 4),
  '6/8' => (beats: 6, beatType: 8),
  _ => (beats: 4, beatType: 4),
};

/// Partitura de [notes], uma nota por tempo (semínimas; em 6/8, semínimas
/// pontuadas — dois tempos por compasso), com barras de compasso. Em
/// `Clef.grand`, a nota abaixo do dó central vai para a pauta de fá e as
/// demais para a de sol; na outra pauta fica um espaço.
String notesScore(
  List<Pitch> notes, {
  Clef clef = Clef.treble,
  String? key,
  String time = '4/4',
}) {
  final compound = time == '6/8';
  final unit = compound ? 3 : 2;
  final perMeasure = compound ? 2 : _timeParts(time).beats;
  final events = [
    for (var i = 0; i < notes.length; i++)
      _Event(
        duration: unit,
        type: 'quarter',
        dots: compound ? 1 : 0,
        pitch: notes[i],
        staff: clef == Clef.grand ? (notes[i].diatonic < 28 ? 2 : 1) : 1,
        noteIndex: i,
      ),
  ];
  final measures = [
    for (var i = 0; i < events.length; i += perMeasure)
      events.sublist(i, min(i + perMeasure, events.length)),
  ];
  return _score(measures, clef: clef, key: key, time: time);
}

/// Partitura de ritmo: [figures] numa altura só ([pitch]), em compassos
/// completos de [time]. Colcheias seguidas saem ligadas por barra (em pares;
/// em 6/8, em grupos de três). [bpm] vira a indicação de andamento.
String rhythmScore(
  List<Figure> figures, {
  String time = '4/4',
  Pitch? pitch,
  int? bpm,
}) {
  final note = pitch ?? Pitch.parse('C4');
  final length = measureEighths(time);
  final group = time == '6/8' ? 3 : 2;
  final measures = <List<_Event>>[];
  var current = <_Event>[];
  var filled = 0;
  var noteIndex = 0;
  for (final figure in figures) {
    if (filled + figure.eighths > length) {
      throw ArgumentError(
        'a figura ${figure.wire} atravessa a barra do compasso $time',
      );
    }
    current.add(
      _Event(
        duration: figure.eighths,
        type: switch (figure) {
          Figure.whole || Figure.wholeRest => 'whole',
          Figure.half || Figure.halfRest || Figure.dottedHalf => 'half',
          Figure.quarter ||
          Figure.quarterRest ||
          Figure.dottedQuarter => 'quarter',
          Figure.eighth || Figure.eighthRest => 'eighth',
        },
        dots: figure == Figure.dottedHalf || figure == Figure.dottedQuarter
            ? 1
            : 0,
        pitch: figure.rest ? null : note,
        noteIndex: figure.rest ? null : noteIndex++,
      ),
    );
    filled += figure.eighths;
    if (filled == length) {
      measures.add(current);
      current = [];
      filled = 0;
    }
  }
  if (current.isNotEmpty) {
    throw ArgumentError('o último compasso de $time ficou incompleto');
  }
  for (final measure in measures) {
    _beamEighths(measure, group);
  }
  return _score(
    measures,
    clef: note.midi >= 57 ? Clef.treble : Clef.bass,
    key: null,
    time: time,
    bpm: bpm,
  );
}

/// Liga por barra colcheias **notas** seguidas dentro do mesmo grupo de
/// tempo; pausa desfaz a ligação.
void _beamEighths(List<_Event> measure, int group) {
  var offset = 0;
  final runs = <List<_Event>>[];
  var run = <_Event>[];
  int? runGroup;
  for (final event in measure) {
    final isBeamable = event.type == 'eighth' && event.pitch != null;
    final eventGroup = offset ~/ group;
    if (isBeamable && (runGroup == null || runGroup == eventGroup)) {
      run.add(event);
      runGroup = eventGroup;
    } else {
      if (run.length > 1) runs.add(run);
      run = isBeamable ? [event] : [];
      runGroup = isBeamable ? eventGroup : null;
    }
    offset += event.duration;
  }
  if (run.length > 1) runs.add(run);
  for (final r in runs) {
    for (var i = 0; i < r.length; i++) {
      r[i].beam = i == 0
          ? 'begin'
          : i == r.length - 1
          ? 'end'
          : 'continue';
    }
  }
}

String _score(
  List<List<_Event>> measures, {
  required Clef clef,
  required String? key,
  required String time,
  int? bpm,
}) {
  final signature = KeySignature.parse(key);
  final grand = clef == Clef.grand;
  final parts = _timeParts(time);
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<score-partwise version="4.0">')
    ..writeln(
      '<part-list><score-part id="P1"><part-name></part-name>'
      '</score-part></part-list>',
    )
    ..writeln('<part id="P1">');

  for (var m = 0; m < measures.length; m++) {
    final events = measures[m];
    out.writeln('<measure number="${m + 1}">');
    if (m == 0) {
      out
        ..writeln('<attributes>')
        ..writeln('<divisions>2</divisions>')
        ..writeln(
          '<key><fifths>${signature.fifths}</fifths>'
          '<mode>${signature.minor ? 'minor' : 'major'}</mode></key>',
        )
        ..writeln(
          '<time${time == 'C' ? ' symbol="common"' : ''}>'
          '<beats>${parts.beats}</beats>'
          '<beat-type>${parts.beatType}</beat-type></time>',
        );
      if (grand) out.writeln('<staves>2</staves>');
      if (grand) {
        out
          ..writeln('<clef number="1"><sign>G</sign><line>2</line></clef>')
          ..writeln('<clef number="2"><sign>F</sign><line>4</line></clef>');
      } else if (clef == Clef.bass) {
        out.writeln('<clef><sign>F</sign><line>4</line></clef>');
      } else {
        out.writeln('<clef><sign>G</sign><line>2</line></clef>');
      }
      out.writeln('</attributes>');
      if (bpm != null) _writeTempo(out, bpm, time);
    }

    // "Vale até a barra": o que cada (letra, oitava) vale agora no compasso.
    final inEffect = <String, int>{};
    final total = events.fold<int>(0, (sum, e) => sum + e.duration);
    if (grand) {
      for (final staff in [1, 2]) {
        _writeStaff(out, events, staff, signature, inEffect);
        if (staff == 1) {
          out.writeln('<backup><duration>$total</duration></backup>');
        }
      }
    } else {
      _writeStaff(out, events, 1, signature, inEffect, single: true);
    }
    out.writeln('</measure>');
  }
  out
    ..writeln('</part>')
    ..writeln('</score-partwise>');
  return out.toString();
}

void _writeTempo(StringBuffer out, int bpm, String time) {
  final compound = time == '6/8';
  // `bpm` conta o tempo da fórmula (a semínima pontuada em 6/8); o
  // `sound tempo` do MusicXML conta semínimas por minuto.
  final quarters = compound ? bpm * 3 / 2 : bpm.toDouble();
  out
    ..writeln('<direction placement="above"><direction-type><metronome>')
    ..writeln('<beat-unit>quarter</beat-unit>')
    ..writeln(compound ? '<beat-unit-dot/>' : '')
    ..writeln('<per-minute>$bpm</per-minute>')
    ..writeln('</metronome></direction-type>')
    ..writeln('<sound tempo="$quarters"/></direction>');
}

/// Escreve as notas de uma pauta; os eventos de outra pauta viram `forward`
/// (um espaço, sem desenhar pausa).
void _writeStaff(
  StringBuffer out,
  List<_Event> events,
  int staff,
  KeySignature signature,
  Map<String, int> inEffect, {
  bool single = false,
}) {
  if (!single && !events.any((e) => e.staff == staff)) {
    // Pauta vazia no compasso inteiro: um `forward` puro faz o Verovio
    // atribuir as notas da outra pauta à pauta errada no `midi.json` (medido
    // no I02). Uma pausa de compasso invisível resolve e não desenha nada.
    final total = events.fold<int>(0, (sum, e) => sum + e.duration);
    out.writeln(
      '<note print-object="no"><rest measure="yes"/>'
      '<duration>$total</duration><voice>$staff</voice>'
      '<staff>$staff</staff></note>',
    );
    return;
  }
  var gap = 0;
  void flushGap() {
    if (gap > 0) {
      out.writeln(
        '<forward><duration>$gap</duration><voice>$staff</voice>'
        '<staff>$staff</staff></forward>',
      );
      gap = 0;
    }
  }

  for (final event in events) {
    if (!single && event.staff != staff) {
      gap += event.duration;
      continue;
    }
    flushGap();
    final pitch = event.pitch;
    final buffer = StringBuffer();
    if (pitch == null) {
      buffer.write('<note><rest/>');
    } else {
      final id = roundNoteId(event.noteIndex!);
      buffer.write('<note id="$id"><pitch><step>${pitch.step}</step>');
      if (pitch.alter != 0) buffer.write('<alter>${pitch.alter}</alter>');
      buffer.write('<octave>${pitch.octave}</octave></pitch>');
    }
    buffer
      ..write('<duration>${event.duration}</duration>')
      ..write('<voice>$staff</voice>')
      ..write('<type>${event.type}</type>');
    for (var i = 0; i < event.dots; i++) {
      buffer.write('<dot/>');
    }
    if (pitch != null) {
      final accidental = _writtenAccidental(pitch, signature, inEffect);
      if (accidental != null) {
        buffer.write('<accidental>$accidental</accidental>');
      }
    }
    buffer.write('<staff>$staff</staff>');
    if (event.beam != null) {
      buffer.write('<beam number="1">${event.beam}</beam>');
    }
    buffer.write('</note>');
    out.writeln(buffer);
  }
  flushGap();
}

/// O acidente a **escrever** para [pitch], ou `null` se a armadura ou um
/// acidente anterior do mesmo compasso (mesma letra e oitava) já vale.
String? _writtenAccidental(
  Pitch pitch,
  KeySignature signature,
  Map<String, int> inEffect,
) {
  final slot = '${pitch.step}${pitch.octave}';
  final current = inEffect[slot] ?? signature.alterOf(pitch.step);
  if (current == pitch.alter) return null;
  inEffect[slot] = pitch.alter;
  return switch (pitch.alter) {
    1 => 'sharp',
    -1 => 'flat',
    _ => 'natural',
  };
}

// ---------------------------------------------------------------------------
// Sorteio

/// Sorteia [count] notas na faixa [range]; mesma [rng] semente, mesma rodada.
///
/// - Sem a mesma nota duas vezes seguidas.
/// - `only: lines|spaces` vale para a **letra** (igual nas duas claves).
/// - Com [key], a letra já sai com a armadura (F vira F# em Sol): as notas
///   são as que **soam**.
/// - [accidentals] ≠ `none`: metade das notas, em média, é uma tecla preta
///   escrita como sustenido (`sharps`), bemol (`flats`) ou qualquer dos dois
///   (`mixed`); o resto são as naturais da faixa — é o que faz o bequadro
///   aparecer ("vale até a barra"). Não sai E#, B#, Cb nem Fb.
List<Pitch> pickNotes(
  NoteRange range, {
  required int count,
  OnlyOn? only,
  Accidentals accidentals = Accidentals.none,
  String? key,
  Random? rng,
}) {
  final random = rng ?? Random();
  final signature = KeySignature.parse(key);
  final letters = [
    for (final p in range.naturals)
      if (only == null || (only == OnlyOn.lines) == p.onLine) p,
  ];
  if (letters.isEmpty) {
    throw ArgumentError('a faixa $range não tem notas para o sorteio');
  }
  final plain = [
    for (final p in letters) Pitch(p.step, signature.alterOf(p.step), p.octave),
  ];
  final altered = <Pitch>[];
  if (accidentals != Accidentals.none) {
    for (final p in letters) {
      final base = signature.alterOf(p.step);
      final sharp = base + 1;
      final flat = base - 1;
      if (accidentals != Accidentals.flats &&
          sharp <= 1 &&
          !'EB'.contains(p.step)) {
        altered.add(Pitch(p.step, sharp, p.octave));
      }
      if (accidentals != Accidentals.sharps &&
          flat >= -1 &&
          !'CF'.contains(p.step)) {
        altered.add(Pitch(p.step, flat, p.octave));
      }
    }
  }
  if (plain.length + altered.length < 2) {
    throw ArgumentError('a faixa $range tem uma nota só: não há o que sortear');
  }

  final result = <Pitch>[];
  for (var i = 0; i < count; i++) {
    Pitch pick() {
      final useAltered = altered.isNotEmpty && random.nextBool();
      final pool = useAltered ? altered : plain;
      return pool[random.nextInt(pool.length)];
    }

    var next = pick();
    for (
      var tries = 0;
      result.isNotEmpty && next.midi == result.last.midi && tries < 50;
      tries++
    ) {
      next = pick();
    }
    result.add(next);
  }
  return result;
}

/// Sorteia [measures] compassos completos de [time] com as figuras
/// [allowed]. Colcheias saem em pares; todo compasso tem ao menos uma nota
/// (não só pausas).
List<Figure> pickFigures(
  List<Figure> allowed, {
  required int measures,
  String time = '4/4',
  Random? rng,
}) {
  if (!figuresTileMeasure(allowed, time)) {
    throw ArgumentError(
      'as figuras ${allowed.map((f) => f.wire).join(', ')} não preenchem '
      'um compasso $time',
    );
  }
  final random = rng ?? Random();
  final length = measureEighths(time);
  final result = <Figure>[];
  for (var m = 0; m < measures; m++) {
    while (true) {
      final measure = <Figure>[];
      var remaining = length;
      var stuck = false;
      while (remaining > 0) {
        final fits = [
          for (final f in allowed)
            if (figureSlot(f) <= remaining &&
                _canFinish(allowed, remaining - figureSlot(f)))
              f,
        ];
        if (fits.isEmpty) {
          stuck = true;
          break;
        }
        final figure = fits[random.nextInt(fits.length)];
        if (figure.eighths == 1) {
          measure
            ..add(figure)
            ..add(figure);
        } else {
          measure.add(figure);
        }
        remaining -= figureSlot(figure);
      }
      if (!stuck && measure.any((f) => !f.rest)) {
        result.addAll(measure);
        break;
      }
    }
  }
  return result;
}

bool _canFinish(List<Figure> allowed, int remaining) {
  if (remaining == 0) return true;
  final reachable = List<bool>.filled(remaining + 1, false)..[0] = true;
  for (var n = 1; n <= remaining; n++) {
    for (final f in allowed) {
      final slot = figureSlot(f);
      if (slot <= n && reachable[n - slot]) reachable[n] = true;
    }
  }
  return reachable[remaining];
}
