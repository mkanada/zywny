import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:score_bridge/score_bridge.dart';
import 'package:verovio/verovio.dart';

/// Verovio's `pageWidth`/`pageHeight` are the **physical paper size in
/// tenths of a millimetre** (the defaults, 2100x2970, are A4), not a
/// resolution: the scene is vector, and the `.vsb` carries the viewBox in
/// hundredths of a millimetre (`DEFINITION_FACTOR = 10`) plus the page fit,
/// so generating it for a bigger page changes nothing on screen except how
/// much music lands on each page.
///
/// That makes the page size the knob for **how large the notation is
/// displayed**: a smaller page holds fewer systems, so it reflows onto more
/// pages and each staff gets more pixels in the same widget.
const int kVerovioMinPageWidth = 500;
const int kVerovioMaxPageWidth = 10000;
const int kVerovioMinPageHeight = 300;
const int kVerovioMaxPageHeight = 6000;

/// Page size for callers with no widget to measure (tests, headless
/// renders). The app derives its own from the score box instead — see
/// `_pageWidth` in `lib/main.dart`.
const int kFallbackPageWidth = 1250;
const int kFallbackPageHeight = 456;

/// All inputs for one render job: the whole score as a single `.vsb`
/// (Verovio Score Bridge package: `scene.json` + `glyphs.json` +
/// `timemap.json` in a zip), written to [outputPath]. Transferable across
/// isolates as a Map.
class VsbRenderRequest {
  VsbRenderRequest({
    required this.inputPath,
    required this.outputPath,
    required this.libraryPath,
    required this.resourcePath,
    required this.pageWidth,
    required this.pageHeight,
  });

  final String inputPath;
  final String outputPath;
  final String libraryPath;
  final String resourcePath;
  final int pageWidth;
  final int pageHeight;

  Map<String, Object?> toJson() => {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'libraryPath': libraryPath,
        'resourcePath': resourcePath,
        'pageWidth': pageWidth,
        'pageHeight': pageHeight,
      };
}

/// Renders the whole score to a single `.vsb` in a worker isolate — so the
/// UI thread never blocks on the native call — and parses the result.
///
/// A [VerovioToolkit] wraps a native pointer and must be constructed, used
/// and disposed inside the same isolate — hence everything native happens
/// in [_renderInIsolate], which only hands back a file path. The parse runs
/// here, on the caller's isolate: the model it builds (`ui.Rect`/`ui.Offset`
/// and the glyph cache's `ui.Path`s) belongs to the isolate that paints it.
Future<VsbDocument> renderScoreToVsb(VsbRenderRequest request) async {
  await Isolate.run(() => _renderInIsolate(request.toJson()));
  final bytes = await File(request.outputPath).readAsBytes();
  _assertVsbPackage(request.outputPath, bytes);
  return VsbDocument.fromBytes(bytes);
}

void _renderInIsolate(Map<String, Object?> json) {
  final inputPath = json['inputPath'] as String;
  final outputPath = json['outputPath'] as String;
  final libraryPath = json['libraryPath'] as String;
  final resourcePath = json['resourcePath'] as String;
  final pageWidth = json['pageWidth'] as int;
  final pageHeight = json['pageHeight'] as int;

  final toolkit = VerovioToolkit.withResourcePath(
    resourcePath,
    libraryPath: libraryPath,
  );
  try {
    // Options must be set BEFORE loading: page size only takes effect
    // on the layout triggered by the load.
    final optionsSet = toolkit.setOptions(jsonEncode({
      'pageWidth': pageWidth,
      'pageHeight': pageHeight,
      // No "MEI rendered with Verovio" footer: it wastes the bottom strip
      // of every page and shrinks the usable notation area.
      'footer': 'none',
    }));
    if (!optionsSet) {
      throw StateError('Verovio rejected the layout options');
    }
    if (!toolkit.loadFile(inputPath)) {
      throw StateError(
        'Verovio could not load $inputPath\n${toolkit.getLog()}',
      );
    }
    // Whole score: every page in one package, timemap included (-t vsb).
    if (!toolkit.renderToBridgeFile(outputPath)) {
      throw StateError(
        'Verovio could not render $outputPath\n${toolkit.getLog()}',
      );
    }
  } finally {
    toolkit.dispose();
  }
}

void _assertVsbPackage(String path, Uint8List bytes) {
  // The renderer only signals success/failure; verify the artifact is really
  // a `.vsb` (zip) package so a broken file fails here with a clear message
  // instead of deep inside the parser.
  if (bytes.length < 4 ||
      bytes[0] != 0x50 ||
      bytes[1] != 0x4B ||
      bytes[2] != 0x03 ||
      bytes[3] != 0x04) {
    throw StateError(
      'Render produced ${bytes.length} bytes without the zip/.vsb '
      'magic (PK\\x03\\x04): $path',
    );
  }
}
