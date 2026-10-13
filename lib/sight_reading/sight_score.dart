import '../course/score/key_signature.dart';
import 'sight_generator.dart';
import 'sight_steps.dart';

// MusicXML 4.0 do exercício sorteado: duas pautas (sol e fá), uma voz por
// pauta, figuras em dezesseis avos (`divisions` = 4 por semínima) e o andamento
// escrito, para o treino tocar no tempo do passo.

const _letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

/// As alturas de cada pauta: a sol começa na oitava 4 e a fá na oitava 3,
/// como o ftrain.
const _rightOctave = 4;
const _leftOctave = 3;

/// A partitura de [ex] em MusicXML.
String sightScoreXml(SightExercise ex) {
  final step = ex.step;
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
    ..writeln('<score-partwise version="4.0">')
    ..writeln(
      '  <part-list><score-part id="P1"><part-name>Piano</part-name>'
      '</score-part></part-list>',
    )
    ..writeln('  <part id="P1">');
  for (var m = 0; m < ex.right.length; m++) {
    out.writeln('    <measure number="${m + 1}">');
    if (m == 0) _writeHeader(out, step);
    _writeStaff(out, ex.right[m], step, staff: 1, octave: _rightOctave);
    out.writeln(
      '      <backup><duration>${step.unitsPerMeasure}</duration></backup>',
    );
    _writeStaff(out, ex.left[m], step, staff: 2, octave: _leftOctave);
    out.writeln('    </measure>');
  }
  out
    ..writeln('  </part>')
    ..writeln('</score-partwise>');
  return out.toString();
}

void _writeHeader(StringBuffer out, SightStep step) {
  final key = KeySignature.parse(step.tonic);
  final beats = step.threeFour ? 3 : 4;
  out
    ..writeln('      <attributes>')
    ..writeln('        <divisions>4</divisions>')
    ..writeln('        <key><fifths>${key.fifths}</fifths></key>')
    ..writeln(
      '        <time><beats>$beats</beats><beat-type>4</beat-type></time>',
    )
    ..writeln('        <staves>2</staves>')
    ..writeln('        <clef number="1"><sign>G</sign><line>2</line></clef>')
    ..writeln('        <clef number="2"><sign>F</sign><line>4</line></clef>')
    ..writeln('      </attributes>')
    ..writeln('      <direction placement="above">')
    ..writeln('        <direction-type><metronome>')
    ..writeln('          <beat-unit>quarter</beat-unit>')
    ..writeln('          <per-minute>${step.bpm}</per-minute>')
    ..writeln('        </metronome></direction-type>')
    ..writeln('        <sound tempo="${step.bpm}"/>')
    ..writeln('      </direction>');
}

/// Escreve as figuras de um compasso numa pauta (voz própria por pauta).
void _writeStaff(
  StringBuffer out,
  List<SightNote> notes,
  SightStep step, {
  required int staff,
  required int octave,
}) {
  final key = KeySignature.parse(step.tonic);
  final starts = <int>[];
  var at = 0;
  for (final n in notes) {
    starts.add(at);
    at += n.units;
  }
  final beams = _beams(notes, starts);
  for (var i = 0; i < notes.length; i++) {
    final note = notes[i];
    final (type, dots) = _figure(note.units);
    out.writeln('      <note>');
    if (note.isRest) {
      out.writeln('        <rest/>');
    } else {
      final degree = note.degree!;
      final n = (_letters.indexOf(step.tonic[0]) + degree - 1);
      final letter = _letters[n % 7];
      final alter = key.alterOf(letter);
      out
        ..writeln('        <pitch>')
        ..writeln('          <step>$letter</step>');
      if (alter != 0) out.writeln('          <alter>$alter</alter>');
      out
        ..writeln('          <octave>${octave + n ~/ 7}</octave>')
        ..writeln('        </pitch>');
    }
    out
      ..writeln('        <duration>${note.units}</duration>')
      ..writeln('        <voice>$staff</voice>')
      ..writeln('        <type>$type</type>');
    for (var d = 0; d < dots; d++) {
      out.writeln('        <dot/>');
    }
    out.writeln('        <staff>$staff</staff>');
    for (final mark in beams[i]) {
      out.writeln('        $mark');
    }
    out.writeln('      </note>');
  }
}

/// O tipo e os pontos de uma figura, em dezesseis avos.
(String, int) _figure(int units) => switch (units) {
  16 => ('whole', 0),
  12 => ('half', 1),
  8 => ('half', 0),
  6 => ('quarter', 1),
  4 => ('quarter', 0),
  3 => ('eighth', 1),
  2 => ('eighth', 0),
  1 => ('16th', 0),
  _ => throw ArgumentError.value(units, 'units', 'figura sem tipo'),
};

/// As barras de cada figura: colcheias e semicolcheias ligadas dentro de um
/// tempo; semicolcheias seguidas numa segunda barra.
List<List<String>> _beams(List<SightNote> notes, List<int> starts) {
  final marks = List.generate(notes.length, (_) => <String>[]);
  bool beamable(int i) => !notes[i].isRest && notes[i].units <= 3;
  var i = 0;
  while (i < notes.length) {
    if (!beamable(i)) {
      i++;
      continue;
    }
    final beat = starts[i] ~/ 4;
    var j = i;
    while (j + 1 < notes.length &&
        beamable(j + 1) &&
        starts[j + 1] ~/ 4 == beat) {
      j++;
    }
    if (j > i) {
      _barra(marks, [for (var k = i; k <= j; k++) k], 1);
      var a = i;
      while (a <= j) {
        if (notes[a].units != 1) {
          a++;
          continue;
        }
        var b = a;
        while (b + 1 <= j && notes[b + 1].units == 1) {
          b++;
        }
        if (b > a) _barra(marks, [for (var k = a; k <= b; k++) k], 2);
        a = b + 1;
      }
    }
    i = j + 1;
  }
  return marks;
}

void _barra(List<List<String>> marks, List<int> idx, int level) {
  for (var k = 0; k < idx.length; k++) {
    final kind = k == 0
        ? 'begin'
        : k == idx.length - 1
        ? 'end'
        : 'continue';
    marks[idx[k]].add('<beam number="$level">$kind</beam>');
  }
}
