import 'package:meta/meta.dart';

const _sharpOrder = 'FCGDAEB';
const _flatOrder = 'BEADGCF';

const _fifthsByKey = <String, int>{
  'C': 0, 'G': 1, 'D': 2, 'A': 3, 'E': 4, 'B': 5, 'F#': 6, 'C#': 7, //
  'F': -1, 'Bb': -2, 'Eb': -3, 'Ab': -4, 'Db': -5, 'Gb': -6, 'Cb': -7,
  'Am': 0, 'Em': 1, 'Bm': 2, 'F#m': 3, 'C#m': 4, 'G#m': 5, 'D#m': 6, //
  'A#m': 7, 'Dm': -1, 'Gm': -2, 'Cm': -3, 'Fm': -4, 'Bbm': -5, 'Ebm': -6,
  'Abm': -7,
};

/// A armadura de um tom do formato (`G`, `Bb`, `Am`…): só ela importa, o
/// modo não muda o desenho.
@immutable
class KeySignature {
  const KeySignature(this.fifths, {this.minor = false});

  /// O tom [name] (um de `kKeyNames`); `null` é Dó maior/Lá menor.
  factory KeySignature.parse(String? name) {
    if (name == null) return none;
    final fifths = _fifthsByKey[name];
    if (fifths == null) {
      throw ArgumentError.value(name, 'name', 'tom desconhecido');
    }
    return KeySignature(fifths, minor: name.endsWith('m'));
  }

  static const none = KeySignature(0);

  /// Sustenidos (+) ou bemóis (−) na armadura, de −7 a 7.
  final int fifths;
  final bool minor;

  /// Alteração que a armadura põe na letra [step] (`C`…`B`): −1, 0 ou 1.
  int alterOf(String step) {
    if (fifths > 0 && _sharpOrder.indexOf(step) < fifths) return 1;
    if (fifths < 0 && _flatOrder.indexOf(step) < -fifths) return -1;
    return 0;
  }
}
