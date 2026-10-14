import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny/sight_reading/sight_generator.dart';
import 'package:zywny/sight_reading/sight_score.dart';
import 'package:zywny/sight_reading/sight_steps.dart';

import 'support/render_helper.dart';

/// Um exercício escrito à mão: [right] e [left] são um compasso por lista.
SightExercise _exercise(
  SightStep step,
  List<List<SightNote>> right,
  List<List<SightNote>> left,
) => SightExercise(step: step, right: right, left: left);

List<SightNote> _silent(SightStep step) => [SightNote(step.unitsPerMeasure)];

void main() {
  test('a partitura traz armadura, compasso, andamento e duas pautas', () {
    final step = sightStep(11, 0); // sol maior, semibreves, mão direita
    final xml = sightScoreXml(
      _exercise(
        step,
        [
          for (var m = 0; m < 4; m++) [SightNote(16, 1)],
        ],
        [for (var m = 0; m < 4; m++) _silent(step)],
      ),
    );
    expect(xml, startsWith('<?xml'));
    expect(xml, contains('<fifths>1</fifths>'));
    expect(xml, contains('<staves>2</staves>'));
    expect(xml, contains('<per-minute>35</per-minute>'));
    expect(RegExp('<measure ').allMatches(xml), hasLength(4));
  });

  test('a escala sobe a partir da tônica: em sol, o dó é o 4º grau, uma oitava acima', () {
    // O ftrain põe os graus 4 a 7 na oitava da tônica, então o dó sai abaixo
    // de sol. Aqui o grau sobe: G4 A4 B4 C5 D5 E5 F#5 G5.
    final step = sightStep(11, 0);
    final degrees = [1, 2, 3, 4, 5, 6, 7, 8];
    final xml = sightScoreXml(
      _exercise(
        step,
        [
          for (var m = 0; m < 4; m++)
            [for (final d in degrees.skip(m * 2).take(2)) SightNote(8, d)],
        ],
        [for (var m = 0; m < 4; m++) _silent(step)],
      ),
    );
    expect(xml, contains('<step>C</step>\n          <octave>5</octave>'));
    expect(
      xml,
      contains('<step>F</step>\n          <alter>1</alter>'),
      reason: 'o fá de sol é sustenido',
    );
  });

  test(
    'colcheias de um tempo saem ligadas; semicolcheias ganham segunda barra',
    () {
      final step = sightStep(10, 0);
      final xml = sightScoreXml(
        _exercise(
          step,
          [
            [
              SightNote(2, 1),
              SightNote(2, 2),
              SightNote(4, 3),
              SightNote(4, 4),
              SightNote(4, 5),
            ],
            [
              SightNote(1, 1),
              SightNote(1, 2),
              SightNote(1, 3),
              SightNote(1, 4),
              SightNote(4, 5),
              SightNote(4, 6),
              SightNote(4, 7),
            ],
            [for (var i = 0; i < 4; i++) SightNote(4, 1)],
            [for (var i = 0; i < 4; i++) SightNote(4, 2)],
          ],
          [for (var m = 0; m < 4; m++) _silent(step)],
        ),
      );
      expect(xml, contains('<beam number="1">begin</beam>'));
      expect(xml, contains('<beam number="1">end</beam>'));
      expect(xml, contains('<beam number="2">begin</beam>'));
      expect(xml, contains('<type>16th</type>'));
    },
  );

  test('o Verovio lê a partitura e toca as alturas certas (sol maior, mão direita)', () async {
    final step = sightStep(11, 0);
    final xml = sightScoreXml(
      _exercise(
        step,
        [
          [SightNote(16, 1)],
          [SightNote(16, 4)],
          [SightNote(16, 7)],
          [SightNote(16, 8)],
        ],
        [for (var m = 0; m < 4; m++) _silent(step)],
      ),
    );
    final doc = await renderBytes(
      Uint8List.fromList(xml.codeUnits),
      'leitura.musicxml',
    );
    expect(
      doc.midi!.notes.map((n) => n.pitch).toList(),
      [67, 72, 78, 79], // G4 C5 F#5 G5
    );
  }, skip: verovioAvailable ? false : 'libverovio.so do bridge ausente');

  test('mão esquerda: o dó grave de dó maior sai na oitava 3', () async {
    final step = sightStep(2, 0);
    final xml = sightScoreXml(
      _exercise(
        step,
        [for (var m = 0; m < 4; m++) _silent(step)],
        [
          [SightNote(16, 1)],
          [SightNote(16, 5)],
          [SightNote(16, 8)],
          [SightNote(16, 1)],
        ],
      ),
    );
    final doc = await renderBytes(
      Uint8List.fromList(xml.codeUnits),
      'leitura.musicxml',
    );
    expect(
      doc.midi!.notes.map((n) => n.pitch).toList(),
      [48, 55, 60, 48], // C3 G3 C4 C3
    );
  }, skip: verovioAvailable ? false : 'libverovio.so do bridge ausente');

  // E05 — ids e alturas para a pergunta de ouvido.

  test('cada nota tem id (pauta, compasso e posição); a pausa não tem', () {
    final step = sightStep(11, 0);
    final xml = sightScoreXml(
      _exercise(
        step,
        [
          [SightNote(4, 1), SightNote(4), SightNote(8, 3)],
        ],
        [_silent(step)],
      ),
    );
    expect(xml, contains('<note id="s1-m1-n1">'));
    expect(xml, contains('<note>\n        <rest/>'));
    expect(xml, contains('<note id="s1-m1-n3">'));
    expect(
      xml,
      isNot(contains('id="s2-')),
      reason: 'a pauta de fá só tem pausas',
    );
  });

  test('o XML do 1a tem id s1-m1-n1 e nenhum id da pauta de fá', () {
    final xml = sightScoreXml(generateSight(sightStep(1, 0), Random(1)));
    expect(xml, contains('id="s1-m1-n1"'));
    expect(xml, isNot(contains('id="s2-')));
  });

  test('sightNoteId conta de 1 em 1 e nomeia a pauta e o compasso', () {
    expect(sightNoteId(2, 0, 0), 's2-m1-n1');
    expect(sightNoteId(1, 3, 6), 's1-m4-n7');
  });

  test('sightMidi confere com a altura que o XML escreve, em C, G e Bb', () {
    const semitones = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    for (final tonic in ['C', 'G', 'Bb']) {
      final step = SightStep(
        level: 1,
        sub: 0,
        hands: SightHands.both,
        durations: const [2],
        patterns: const [],
        bpm: 60,
        label: 'teste',
        high: 8,
        tonic: tonic,
      );
      final degrees = [for (var d = 1; d <= 8; d++) SightNote(2, d)];
      final xml = sightScoreXml(_exercise(step, [degrees], [degrees]));
      // Um `<note>` com altura: a pauta de sol vem antes da de fá.
      final written =
          RegExp(
            r'<step>([A-G])</step>(?:\s*<alter>(-?1)</alter>)?\s*'
            r'<octave>(\d)</octave>',
          ).allMatches(xml).map((m) {
            final alter = m.group(2) == null ? 0 : int.parse(m.group(2)!);
            final octave = int.parse(m.group(3)!);
            return 12 * (octave + 1) + semitones[m.group(1)]! + alter;
          }).toList();
      expect(written, hasLength(16), reason: tonic);
      for (var d = 1; d <= 8; d++) {
        expect(
          sightMidi(step, d, staff: 1),
          written[d - 1],
          reason: '$tonic, grau $d, sol',
        );
        expect(
          sightMidi(step, d, staff: 2),
          written[8 + d - 1],
          reason: '$tonic, grau $d, fá',
        );
      }
    }
  });
}
