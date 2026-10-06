import 'package:flutter/foundation.dart';

import '../../layout_options.dart' show kPhoneUnit;
import '../format/course_files.dart';
import '../format/course_model.dart';
import 'abc_source.dart';

/// Uma partitura pronta para o `ScoreRenderRequest`: os bytes e o nome do
/// arquivo (a **extensão** informa o formato nos logs; o Verovio detecta
/// pelo conteúdo, nativo e Web).
class LessonScoreSource {
  const LessonScoreSource(this.bytes, this.fileName);

  final Uint8List bytes;
  final String fileName;
}

/// De onde sai toda partitura de uma lição: marca `zywny-score`, exercício
/// com `abc:`/`file:` ou rodada sorteada ([fromMusicXml]).
///
/// - `abc:` sem `X:` ganha o cabeçalho de [abcSource] (`clef`, `key`,
///   `time`); com `X:` passa intacto.
/// - `file:` lê o `.musicxml` da pasta e passa direto.
Future<LessonScoreSource> scoreSourceFor(
  ScoreSource source,
  CourseFiles files, {
  Clef clef = Clef.treble,
  String? key,
  String? time,
}) async {
  switch (source) {
    case AbcSource():
      final abc = abcSource(source.abc, clef: clef, key: key, time: time);
      return LessonScoreSource(utf8Bytes(abc), 'lesson.abc');
    case FileSource():
      final bytes = await files.read(source.path);
      final name = source.path.split('/').last;
      return LessonScoreSource(bytes, name);
  }
}

/// O MusicXML de uma rodada sorteada (`round_score.dart`).
LessonScoreSource fromMusicXml(String xml) =>
    LessonScoreSource(utf8Bytes(xml), 'round.musicxml');

/// Tamanho de página e opções do Verovio para uma partitura pequena de
/// lição ou de exercício: sem cabeçalho nem rodapé, altura ajustada ao
/// conteúdo e margens enxutas.
///
/// [widthPx] é a largura em pixels do dispositivo da caixa da partitura: o
/// papel do Verovio é medido em décimos de milímetro e o app desenha 1:1
/// (ver `kFallbackPageWidth` em `render/page_size.dart`). [pageHeight] é um
/// teto — `adjustPageHeight` encolhe a página ao que a música ocupa; se o
/// conteúdo não couber, o Verovio abre mais sistemas/páginas.
///
/// No celular ([phone], padrão: Android/iOS) a notação usa o mesmo `unit`
/// dos hinos ([kPhoneUnit]): com o `unit` do desktop as notas saíam miúdas
/// na tela pequena.
class LessonScoreLayout {
  const LessonScoreLayout({
    required this.pageWidth,
    required this.pageHeight,
    required this.options,
  });

  final int pageWidth;
  final int pageHeight;
  final Map<String, Object> options;
}

LessonScoreLayout lessonScoreLayout(double widthPx, {bool? phone}) =>
    LessonScoreLayout(
      pageWidth: widthPx.round().clamp(kLessonMinWidth, kLessonMaxWidth),
      pageHeight: kLessonPageHeight,
      options: (phone ?? _isPhone)
          ? {...lessonScoreOptions, 'unit': kPhoneUnit}
          : lessonScoreOptions,
    );

bool get _isPhone =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

const kLessonMinWidth = 500;
const kLessonMaxWidth = 10000;
const kLessonPageHeight = 2000;

/// As opções do Verovio de [lessonScoreLayout] no desktop (a página vai à
/// parte; no celular o `unit` vira [kPhoneUnit]).
const lessonScoreOptions = <String, Object>{
  'adjustPageHeight': true,
  'header': 'none',
  'footer': 'none',
  'breaks': 'auto',
  'pageMarginTop': 40,
  'pageMarginBottom': 40,
  'pageMarginLeft': 40,
  'pageMarginRight': 40,
  'unit': 6,
};
