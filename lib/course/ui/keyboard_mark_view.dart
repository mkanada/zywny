// I05 — `zywny-keyboard`: o teclado desenhado, com teclas marcadas.
//
// Generaliza o `PianoKeyboardPainter` (faixa `lowest`/`highest`, `marked` com
// cor própria, `names` com `noteLabel`); o monitor MIDI continua chamando com
// 88 teclas, sem mudança visível. Altura proporcional à largura, como um
// teclado real.

import 'package:flutter/material.dart';

import '../../midi/piano_keyboard.dart';
import '../../ui/theme.dart';
import '../format/course_model.dart';
import '../../music/note_names.dart';

/// A marca `zywny-keyboard` desenhada: faixa com marcas e legenda.
class KeyboardMarkView extends StatelessWidget {
  const KeyboardMarkView({
    super.key,
    required this.mark,
    this.markedColor = kAccent,
    this.naming = NoteNaming.latin,
  });

  final KeyboardMark mark;
  final Color markedColor;
  final NoteNaming naming;

  @override
  Widget build(BuildContext context) {
    final lowest = mark.from.midi;
    final highest = mark.to.midi;
    final marked = {for (final p in mark.mark) p.midi};
    final whites = _whiteCount(lowest, highest);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Tecla branca real: ~23,6 mm × 150 mm (altura/largura ≈ 6,35).
              // A altura sai da largura da coluna, como num teclado de verdade.
              final width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 640.0;
              final height = (width * 6.35 / whites.clamp(1, 88)).clamp(
                72.0,
                220.0,
              );
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: CustomPaint(
                  size: Size(width, height),
                  painter: PianoKeyboardPainter(
                    held: const {},
                    heldColor: markedColor,
                    lowest: lowest,
                    highest: highest,
                    marked: marked,
                    markedColor: markedColor,
                    names: mark.names,
                    naming: naming,
                  ),
                ),
              );
            },
          ),
          if (mark.caption != null && mark.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                mark.caption!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kInkCaption),
              ),
            ),
        ],
      ),
    );
  }

  static int _whiteCount(int lowest, int highest) {
    const black = {1, 3, 6, 8, 10};
    var count = 0;
    for (var n = lowest; n <= highest; n++) {
      if (!black.contains(n % 12)) count++;
    }
    return count;
  }
}
