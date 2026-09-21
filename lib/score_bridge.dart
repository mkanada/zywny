/// Modelo e parser do formato `.vsb` (Verovio Score Bridge).
///
/// Ver docs/formato/especificacao-v1.md na raiz do repositório.
library;

export 'src/model.dart';
export 'src/geometry.dart';
export 'src/dash.dart';
export 'src/glyph_cache.dart';
export 'src/scene_painter.dart';
export 'src/scene_walk.dart' show SceneVisitor, walkScene;
export 'src/segmentation.dart';
export 'src/text_font.dart';
export 'src/text_run.dart';
export 'src/parser.dart'
    show
        parseManifestDocument,
        parseMetaDocument,
        parseGlyphsDocument,
        parseSceneDocument,
        parseTimemapDocument;
