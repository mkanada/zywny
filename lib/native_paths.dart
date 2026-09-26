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
    // Dev fallback: built in verovio_flutter_bridge via tool/build_verovio_linux.sh.
    '/home/mauricio/rust_projects/verovio_flutter_bridge/verovio/bindings/dart/libverovio.so',
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

/// Locates the native `libzywny_audio.so` (K02/K03).
///
/// Search order: explicit env override, the installed Linux bundle layout,
/// then the project source tree (covers `flutter run` from the project
/// root). Mirrors [findVerovioLibrary]; unlike Verovio, this crate lives
/// inside this repo (`native/zywny_audio/`), not an external one.
String findAudioLibrary() {
  final env = Platform.environment['ZYWNY_AUDIO_LIBRARY_PATH'];
  if (env != null && env.isNotEmpty && File(env).existsSync()) return env;

  final candidates = <String>[
    // Installed bundle: <bundle>/zywny -> <bundle>/lib/libzywny_audio.so
    // (linux/CMakeLists.txt installs it there; RPATH is $ORIGIN/lib).
    '${File(Platform.resolvedExecutable).parent.path}/lib/libzywny_audio.so',
    // Dev fallback: built in this repo via tool/build_audio_linux.sh, from
    // the project root (how `flutter run`/`just run` are normally invoked).
    'native/zywny_audio/target/release/libzywny_audio.so',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  throw StateError(
    'libzywny_audio.so not found. Tried:\n'
    '${candidates.join('\n')}\n'
    'Build it with tool/build_audio_linux.sh or set ZYWNY_AUDIO_LIBRARY_PATH.',
  );
}
