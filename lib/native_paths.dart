import 'dart:io';

/// Locates the native `libverovio.so`.
///
/// Search order: explicit env override (CI / custom installs), then the
/// installed Linux bundle layout, then the project source tree (covers
/// `flutter run` from the project root). The engraving resources
/// (`resourcePath`) come from [verovioResourcePath] in
/// `lib/verovio_resources.dart` instead.
String findVerovioLibrary() {
  final env = Platform.environment['VEROVIO_LIBRARY_PATH'];
  if (env != null && env.isNotEmpty && File(env).existsSync()) return env;

  final candidates = <String>[
    // Installed bundle: <bundle>/zywny -> <bundle>/lib/libverovio.so
    // (linux/CMakeLists.txt installs it there; RPATH is $ORIGIN/lib).
    '${File(Platform.resolvedExecutable).parent.path}/lib/libverovio.so',
    // Dev fallback: built from the submodule via tool/build_verovio_linux.sh.
    '${Directory.current.path}/third_party/verovio_flutter_bridge'
        '/verovio/bindings/dart/libverovio.so',
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
