import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:verovio/verovio.dart';

/// Page size (Verovio `pageWidth`/`pageHeight`) is the size knob for Lottie
/// output: staff size in absolute units is set by the engraving, so a
/// smaller page reflows the music onto more pages and shows larger on
/// screen. (Verovio `scale` is output zoom only and does not reflow Lottie
/// layout, so it is intentionally not exposed.)
const int kVerovioMinPageWidth = 500;
const int kVerovioMaxPageWidth = 10000;
const int kVerovioMinPageHeight = 300;
const int kVerovioMaxPageHeight = 6000;

/// Default page size, tuned for a ~1900px-wide monitor (see the render
/// tuning panel in the UI).
const int kDefaultPageWidth = 3700;
const int kDefaultPageHeight = 1350;

/// All inputs for one render job: the whole score as a single `.lottie`
/// (dotLottie package, one layer per page, note-highlight + page-turn
/// state machines), written to [outputPath]. Transferable across isolates
/// as a Map.
class VerovioRenderRequest {
  VerovioRenderRequest({
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

/// Renders the whole score to a single `.lottie` (dotLottie package: one
/// `score` composition, one layer per page, note-highlight + page-turn
/// state machines) in a worker isolate, so the UI thread never blocks.
///
/// A [VerovioToolkit] wraps a native pointer and must be constructed, used
/// and disposed inside the same isolate — hence everything happens in
/// [_renderInIsolate], not here.
Future<void> renderScoreToDotLottie(VerovioRenderRequest request) async {
  await Isolate.run(() => _renderInIsolate(request.toJson()));
  _assertDotLottie(
    request.outputPath,
    await File(request.outputPath).readAsBytes(),
  );
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
    // Whole score: one composition, one layer per page (-t dotlottie).
    if (!toolkit.renderToDotLottieFile(outputPath)) {
      throw StateError(
        'Verovio could not render $outputPath\n${toolkit.getLog()}',
      );
    }
  } finally {
    toolkit.dispose();
  }
}

void _assertDotLottie(String path, List<int> bytes) {
  // The renderer only signals success/failure; verify the artifact is really
  // a dotLottie (zip) package so a broken file fails here with a clear
  // message instead of crashing the player later.
  if (bytes.length < 4 ||
      bytes[0] != 0x50 ||
      bytes[1] != 0x4B ||
      bytes[2] != 0x03 ||
      bytes[3] != 0x04) {
    throw StateError(
      'Render produced ${bytes.length} bytes without the zip/dotLottie '
      'magic (PK\\x03\\x04): $path',
    );
  }
}
