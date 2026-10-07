import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zywny_course_format/course_model.dart';
import 'package:zywny_course_format/figure_rules.dart';
import 'package:zywny_music/note_name.dart';
import 'package:zywny_course_format/vocabulary.dart';
import 'package:zywny/course/score/lesson_score.dart';
import 'package:zywny/course/score/round_score.dart';

import 'support/render_helper.dart';

const _noLib = 'libverovio.so ausente';

List<Pitch> _pick(
  String range, {
  int count = 12,
  OnlyOn? only,
  Accidentals accidentals = Accidentals.none,
  String? key,
  int seed = 1,
}) => pickNotes(
  NoteRange.parse(range),
  count: count,
  only: only,
  accidentals: accidentals,
  key: key,
  rng: Random(seed),
);

void main() {
  group('pickNotes', () {
    test('mesma semente, mesma rodada; outra semente, outra', () {
      expect(_pick('C4-G5'), _pick('C4-G5'));
      expect(_pick('C4-G5', seed: 2), isNot(_pick('C4-G5', seed: 1)));
    });

    test(
      'só notas da faixa, quantas foram pedidas, sem repetir em seguida',
      () {
        for (var seed = 0; seed < 40; seed++) {
          final notes = _pick('C4-G4', count: 20, seed: seed);
          expect(notes, hasLength(20));
          final range = NoteRange.parse('C4-G4');
          expect(notes.every(range.contains), isTrue);
          for (var i = 1; i < notes.length; i++) {
            expect(notes[i].midi, isNot(notes[i - 1].midi), reason: '$seed/$i');
          }
          expect(notes.every((p) => p.isNatural), isTrue);
        }
      },
    );

    test('only: lines só dá linhas, only: spaces só espaços', () {
      for (var seed = 0; seed < 30; seed++) {
        expect(
          _pick('C4-G5', only: OnlyOn.lines, seed: seed).every((p) => p.onLine),
          isTrue,
        );
        expect(
          _pick(
            'C4-G5',
            only: OnlyOn.spaces,
            seed: seed,
          ).every((p) => !p.onLine),
          isTrue,
        );
      }
      // Linhas do sol: E4 G4 B4 D5 F5; espaços: F4 A4 C5 E5 (e C4 é linha).
      final lines = {
        for (var s = 0; s < 30; s++)
          ..._pick('C4-G5', only: OnlyOn.lines, seed: s).map((p) => '$p'),
      };
      expect(lines, {'C4', 'E4', 'G4', 'B4', 'D5', 'F5'});
    });

    test('com tom, a letra já sai com a armadura (F vira F# em Sol)', () {
      final notes = _pick('C4-C5', count: 40, key: 'G');
      expect(
        notes.where((p) => p.step == 'F').every((p) => p.alter == 1),
        isTrue,
      );
      expect(
        notes.where((p) => p.step != 'F').every((p) => p.isNatural),
        isTrue,
      );
      final flat = _pick('C4-C5', count: 40, key: 'F');
      expect(
        flat.where((p) => p.step == 'B').every((p) => p.alter == -1),
        isTrue,
      );
    });

    test('accidentals: sustenidos, bemóis, misturado; nada de E#/B#/Cb/Fb', () {
      for (final mode in [
        Accidentals.sharps,
        Accidentals.flats,
        Accidentals.mixed,
      ]) {
        final notes = _pick('C4-C5', count: 200, accidentals: mode);
        final altered = notes.where((p) => !p.isNatural).toList();
        expect(altered, isNotEmpty, reason: '$mode');
        expect(notes.any((p) => p.isNatural), isTrue);
        for (final p in altered) {
          if (mode == Accidentals.sharps) expect(p.alter, 1);
          if (mode == Accidentals.flats) expect(p.alter, -1);
          expect([
            'E#',
            'B#',
            'Cb',
            'Fb',
          ], isNot(contains('${p.step}${p.alter > 0 ? '#' : 'b'}')));
        }
        if (mode == Accidentals.mixed) {
          expect(altered.any((p) => p.alter == 1), isTrue);
          expect(altered.any((p) => p.alter == -1), isTrue);
        }
      }
    });

    test('faixa sem o que sortear lança', () {
      expect(() => _pick('C4-D4', only: OnlyOn.lines), throwsArgumentError);
    });
  });

  group('pickFigures', () {
    int eighthsOf(List<Figure> figures) =>
        figures.fold(0, (sum, f) => sum + f.eighths);

    test('compassos completos, colcheias em pares, sempre há nota', () {
      const all = [
        Figure.whole,
        Figure.half,
        Figure.quarter,
        Figure.eighth,
        Figure.quarterRest,
        Figure.dottedHalf,
        Figure.dottedQuarter,
        Figure.eighthRest,
      ];
      for (final time in ['4/4', '3/4', '2/4', '6/8']) {
        final usable = [
          for (final f in all)
            if (f.eighths <= measureEighths(time)) f,
        ];
        if (!figuresTileMeasure(usable, time)) continue;
        for (var seed = 0; seed < 30; seed++) {
          final figures = pickFigures(
            usable,
            measures: 4,
            time: time,
            rng: Random(seed),
          );
          expect(eighthsOf(figures), 4 * measureEighths(time), reason: time);
          // Cada compasso fecha exatamente e tem ao menos uma nota.
          var filled = 0;
          var hasNote = false;
          for (final f in figures) {
            filled += f.eighths;
            hasNote |= !f.rest;
            if (filled == measureEighths(time)) {
              expect(hasNote, isTrue, reason: '$time/$seed');
              filled = 0;
              hasNote = false;
            }
            expect(filled <= measureEighths(time), isTrue);
          }
          // Colcheias vêm em pares.
          var run = 0;
          for (final f in [...figures, Figure.whole]) {
            if (f.eighths == 1) {
              run++;
            } else {
              expect(run.isEven, isTrue, reason: '$time/$seed');
              run = 0;
            }
          }
        }
      }
    });

    test('mesma semente, mesmo ritmo', () {
      const set = [Figure.half, Figure.quarter, Figure.eighth];
      expect(
        pickFigures(set, measures: 3, rng: Random(5)),
        pickFigures(set, measures: 3, rng: Random(5)),
      );
    });

    test('figuras que não fecham o compasso, ou só pausas, lançam', () {
      expect(figuresTileMeasure([Figure.dottedHalf], '4/4'), isFalse);
      expect(
        figuresTileMeasure([Figure.dottedHalf, Figure.halfRest], '4/4'),
        isFalse,
      );
      expect(
        figuresTileMeasure([Figure.quarterRest, Figure.halfRest], '4/4'),
        isFalse,
      );
      expect(figuresTileMeasure([Figure.dottedHalf], '3/4'), isTrue);
      expect(figuresTileMeasure([Figure.eighth], '4/4'), isTrue);
      expect(
        () => pickFigures([Figure.dottedHalf], measures: 1),
        throwsArgumentError,
      );
    });
  });

  group('notesScore (MusicXML)', () {
    test('vale até a barra: o acidente só reaparece quando muda', () {
      final xml = notesScore([
        Pitch.parse('F#4'),
        Pitch.parse('F#4'), // repetido no compasso: sem acidente
        Pitch.parse('F4'), // volta ao natural: bequadro
        Pitch.parse('F4'),
        Pitch.parse('F#4'), // novo compasso: sustenido de novo
        Pitch.parse('F#5'), // outra oitava: não valeu a de baixo
      ]);
      final accidentals = RegExp('<accidental>(\\w+)</accidental>')
          .allMatches(xml)
          .map((m) => m.group(1))
          .toList();
      expect(accidentals, ['sharp', 'natural', 'sharp', 'sharp']);
    });

    test('a armadura já vale: F# em Sol não escreve sustenido', () {
      final xml = notesScore([
        Pitch.parse('F#4'),
        Pitch.parse('F4'),
        Pitch.parse('B4'),
      ], key: 'G');
      expect(xml, contains('<fifths>1</fifths>'));
      expect(
        RegExp('<accidental>(\\w+)</accidental>')
            .allMatches(xml)
            .map((m) => m.group(1)),
        ['natural'],
      );
    });

    test('ids estáveis das notas e quatro notas por compasso', () {
      final xml = notesScore(_pick('C4-G4', count: 9));
      for (var i = 0; i < 9; i++) {
        expect(xml, contains('id="${roundNoteId(i)}"'));
      }
      expect(RegExp('<measure ').allMatches(xml), hasLength(3));
    });

    test('duas pautas: abaixo do dó central vai para a pauta 2', () {
      final xml = notesScore([
        Pitch.parse('C4'),
        Pitch.parse('B3'),
        Pitch.parse('E5'),
      ], clef: Clef.grand);
      expect(xml, contains('<staves>2</staves>'));
      expect(xml, contains('<forward>'));
      expect(xml, contains('<backup>'));
    });
  });

  group('lesson_score', () {
    test('layout: página limitada e opções de partitura pequena', () {
      final layout = lessonScoreLayout(1800);
      expect(layout.pageWidth, 1800);
      expect(layout.options['adjustPageHeight'], isTrue);
      expect(layout.options['header'], 'none');
      expect(lessonScoreLayout(10).pageWidth, kLessonMinWidth);
      expect(lessonScoreLayout(1e9).pageWidth, kLessonMaxWidth);
    });

    test('com a altura da caixa, a página não passa dela', () {
      expect(lessonScoreLayout(1800).pageHeight, kLessonPageHeight);
      expect(lessonScoreLayout(1800, heightPx: 540).pageHeight, 540);
      expect(lessonScoreLayout(1800, heightPx: 10).pageHeight, 300);
      expect(
        lessonScoreLayout(1800, heightPx: 1e9).pageHeight,
        kLessonPageHeight,
      );
    });

    // A Ode do curso (duas pautas, 8 compassos) num celular deitado: antes
    // cabia numa página alta que a tela encolhia; agora vira páginas, como
    // os hinos, e cada uma cabe na caixa sem encolher.
    test(
      'a Ode no celular deitado sai em páginas da altura da caixa',
      () async {
        final bytes = File(
          'assets/cursos/iniciacao/media/ode-a-alegria.musicxml',
        ).readAsBytesSync();
        // Caixa de ~780×270 pt a 2,75 de densidade, com o zoom 1,3 do curso.
        final layout = lessonScoreLayout(1650, heightPx: 571, phone: true);
        final doc = await renderBytes(
          bytes,
          'ode.musicxml',
          pageWidth: layout.pageWidth,
          pageHeight: layout.pageHeight,
          options: layout.options,
        );
        expect(doc.pages.length, greaterThan(1));
        for (final page in doc.pages) {
          expect(page.heightPx, lessThanOrEqualTo(571));
        }
      },
      skip: verovioAvailable ? false : _noLib,
    );
  });

  // O MusicXML gerado renderiza pela libverovio e o midi.json bate com o
  // sorteio — o que o exercício vai cobrar do aluno.
  group('render (libverovio)', () {
    Future<List<({int pitch, int staff, double on, double off, String id})>>
    render(String xml) async {
      final source = fromMusicXml(xml);
      final doc = await renderBytes(source.bytes, source.fileName);
      return [
        for (final n in doc.midi!.notes)
          (pitch: n.pitch, staff: n.staff, on: n.onMs, off: n.offMs, id: n.id),
      ];
    }

    for (final (label, range, clef, key) in [
      ('sol', 'C4-G5', Clef.treble, null),
      ('fá', 'G2-C4', Clef.bass, null),
      ('duas pautas', 'C3-C5', Clef.grand, null),
      ('tom de sol', 'C4-C5', Clef.treble, 'G'),
      ('tom de fá', 'C4-C5', Clef.treble, 'F'),
      ('tom de Mi♭', 'C4-C5', Clef.treble, 'Eb'),
    ]) {
      test('notas sorteadas ($label): alturas e ids na ordem', () async {
        final notes = _pick(range, count: 14, key: key, seed: 3);
        final rendered = await render(notesScore(notes, clef: clef, key: key));
        expect(
          [for (final n in rendered) n.pitch],
          [for (final p in notes) p.midi],
        );
        expect(
          [for (final n in rendered) n.id],
          [for (var i = 0; i < notes.length; i++) roundNoteId(i)],
        );
        if (clef == Clef.grand) {
          expect(
            [for (final n in rendered) n.staff],
            [for (final p in notes) p.diatonic < 28 ? 2 : 1],
          );
        } else {
          expect({for (final n in rendered) n.staff}, {1});
        }
      }, skip: verovioAvailable ? false : _noLib);
    }

    test('acidentes sorteados: o que soa é o que foi sorteado', () async {
      for (final mode in [
        Accidentals.sharps,
        Accidentals.flats,
        Accidentals.mixed,
      ]) {
        final notes = _pick('C4-C5', count: 16, accidentals: mode, seed: 9);
        final rendered = await render(notesScore(notes));
        expect(
          [for (final n in rendered) n.pitch],
          [for (final p in notes) p.midi],
        );
      }
    }, skip: verovioAvailable ? false : _noLib);

    for (final (time, bpm) in [
      ('4/4', 70),
      ('3/4', 90),
      ('2/4', 60),
      ('6/8', 60),
    ]) {
      test('ritmo $time a $bpm: tempos e durações em ms', () async {
        final figures = pickFigures(
          const [
            Figure.half,
            Figure.quarter,
            Figure.eighth,
            Figure.quarterRest,
            Figure.dottedQuarter,
          ].where((f) => f.eighths <= measureEighths(time)).toList(),
          measures: 4,
          time: time,
          rng: Random(4),
        );
        final rendered = await render(
          rhythmScore(figures, time: time, pitch: Pitch.parse('C4'), bpm: bpm),
        );
        // `bpm` conta o tempo da fórmula: semínima, ou semínima pontuada em 6/8.
        final eighthMs = time == '6/8' ? 60000 / bpm / 3 : 60000 / bpm / 2;
        final expected = <(double, double)>[];
        var at = 0;
        for (final f in figures) {
          if (!f.rest) {
            expected.add((at * eighthMs, (at + f.eighths) * eighthMs));
          }
          at += f.eighths;
        }
        expect(rendered, hasLength(expected.length));
        for (var i = 0; i < expected.length; i++) {
          expect(rendered[i].on, closeTo(expected[i].$1, 1), reason: 'nota $i');
          expect(
            rendered[i].off,
            closeTo(expected[i].$2, 1),
            reason: 'nota $i',
          );
          expect(rendered[i].pitch, 60);
          expect(rendered[i].id, roundNoteId(i));
        }
      }, skip: verovioAvailable ? false : _noLib);
    }
  });
}
