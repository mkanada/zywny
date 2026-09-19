/// Modelo e parser do formato `.vsb` (Verovio Score Bridge).
///
/// Ver docs/formato/especificacao-v1.md na raiz do repositório.
library;

export 'src/model.dart';
export 'src/geometry.dart';
export 'src/scene_painter.dart';
export 'src/parser.dart'
    show
        parseManifestDocument,
        parseGlyphsDocument,
        parseSceneDocument,
        parseTimemapDocument;
