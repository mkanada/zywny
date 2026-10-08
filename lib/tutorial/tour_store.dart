import 'package:shared_preferences/shared_preferences.dart';

/// Os passeios do tutorial. [version] sobe quando o passeio muda tanto que
/// vale mostrá-lo de novo a quem já o viu.
enum TourId {
  /// A biblioteca: busca, ordem, teclado, configurações.
  library(1),

  /// A partitura: voltar, som, treinar, andamento, opções.
  score(1);

  const TourId(this.version);

  final int version;
}

/// Quais passeios a pessoa já viu, guardado nas preferências (sobrevive a
/// fechar o app e a instalar uma versão nova por cima).
///
/// Vale "já viu" para quem terminou, para quem pulou e para quem fechou com
/// o "voltar": o passeio não pode reaparecer a cada abertura. Para rever, há
/// "Rever o tutorial" nas configurações.
class TourStore {
  TourStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static String _key(TourId id) => 'tutorial_seen_${id.name}';

  Future<bool> seen(TourId id) async {
    try {
      return (await _prefs.getInt(_key(id)) ?? 0) >= id.version;
    } on Object {
      // Sem preferências (navegador bloqueando o armazenamento): melhor não
      // insistir com o passeio do que mostrá-lo toda vez.
      return true;
    }
  }

  Future<void> markSeen(TourId id) async {
    try {
      await _prefs.setInt(_key(id), id.version);
    } on Object {
      // Ver `seen`.
    }
  }
}
