import 'dart:io';

/// Locates the native `libverovio.so` and the Verovio music-font resources.
///
/// Search order for each: explicit env override (CI / custom installs),
/// then the installed Linux bundle layout, then the project source tree
/// (covers `flutter run` from the project root).
String findVerovioLibrary() {
  final env = Platform.environment['VEROVIO_LIBRARY_PATH'];
  if (env != null && env.isNotEmpty && File(env).existsSync()) return env;

  final candidates = <String>[
    // Installed bundle: <bundle>/zywny -> <bundle>/lib/libverovio.so
    // (linux/CMakeLists.txt installs it there; RPATH is $ORIGIN/lib).
    '${File(Platform.resolvedExecutable).parent.path}/lib/libverovio.so',
    // Dev fallback: built from the submodule via tool/build_verovio_linux.sh.
    '${Directory.current.path}/third_party/verovio_lottie/verovio/bindings/dart/libverovio.so',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  throw StateError(
    'libverovio.so not found. Tried:\n'
    '${candidates.join('\n')}\n'
    'Build it with tool/build_verovio_linux.sh or set VEROVIO_LIBRARY_PATH.',
  );
}

/// Directory holding the Verovio music fonts (Bravura etc.).
///
/// Each candidate is checked for completeness (the Liberation text font must
/// exist): an incomplete directory — e.g. a Flutter-assets copy, whose
/// bundler silently drops subdirectories — makes the native renderer crash
/// instead of failing cleanly, so it must never be accepted here.
String findVerovioResources() {
  final env = Platform.environment['VEROVIO_RESOURCE_PATH'];
  if (env != null && env.isNotEmpty && _isCompleteVerovioData(env)) {
    return env;
  }

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final candidates = <String>[
    // Installed bundle: <bundle>/data/verovio_data
    // (copied recursively by linux/CMakeLists.txt).
    '$exeDir/data/verovio_data',
    // Dev fallback: fetched from the submodule (tool/fetch_verovio_assets.sh).
    '${Directory.current.path}/assets/verovio_data',
    // Last resort: straight from the submodule checkout.
    '${Directory.current.path}/third_party/verovio_lottie/verovio/data',
  ];
  for (final c in candidates) {
    if (_isCompleteVerovioData(c)) return c;
  }
  throw StateError(
    'Complete Verovio resources not found. Tried:\n'
    '${candidates.join('\n')}\n'
    'Run tool/fetch_verovio_assets.sh or set VEROVIO_RESOURCE_PATH.',
  );
}

bool _isCompleteVerovioData(String dir) =>
    File('$dir/text/LiberationSerif-Regular.ttf').existsSync();
