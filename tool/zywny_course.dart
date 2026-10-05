// Validador de curso do zywny.
//
//   dart run tool/zywny_course.dart validate <pasta> [--render]
//   dart run tool/zywny_course.dart --render <pasta>
//
// Imprime `arquivo:linha: erro|aviso: mensagem`, um por linha, e sai com
// código 1 se houver erro. Não usa Flutter: roda com `dart run`. O `--render`
// usa direto os bindings `package:verovio` (FFI, só `ffi`, sem Flutter —
// conferido no pubspec do pacote): carrega cada partitura escrita pelo autor
// e confere que tem ao menos uma nota, que o MIDI não está vazio e que o
// `measures` cabe na partitura. Sem a `libverovio.so` (ou sem os dados):
// aviso único "--render indisponível" e código 0.
import 'dart:convert';
import 'dart:io';

import 'package:verovio/verovio.dart';
import 'package:zywny/course/format/course_model.dart';
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/format/course_render_check.dart';
import 'package:zywny/course/format/directory_course_files.dart';

Future<void> main(List<String> args) async {
  final render = args.contains('--render');
  final rest = [for (final a in args) if (a != '--render') a];
  final String folder;
  if (render && rest.length == 1 && rest.first != 'validate') {
    // `just curso-validar --render <pasta>`: atalho para validar com render.
    folder = rest.first;
  } else if (rest.length == 2 && rest.first == 'validate') {
    folder = rest[1];
  } else {
    stderr.writeln(
      'Uso: dart run tool/zywny_course.dart validate <pasta> [--render]',
    );
    exitCode = 64;
    return;
  }
  final directory = Directory(folder);
  if (!directory.existsSync()) {
    stderr.writeln('A pasta `$folder` não existe.');
    exitCode = 66;
    return;
  }
  final files = DirectoryCourseFiles(directory);
  final result = await readCourse(files);
  final issues = [...result.issues];
  if (render && result.course != null) {
    final renderIssues = await _renderIssues(result.course!, files);
    // `null` = Verovio indisponível: aviso único e código 0 (I12).
    if (renderIssues == null) {
      for (final issue in issues) {
        stdout.writeln(issue);
      }
      stderr.writeln('--render indisponível (sem a libverovio.so).');
      return;
    }
    issues.addAll(renderIssues);
    issues.sort();
  }
  for (final issue in issues) {
    stdout.writeln(issue);
  }
  if (issues.any((i) => i.isError)) exitCode = 1;
}

/// As partituras do curso pelo Verovio, ou `null` sem a `.so`/dados.
Future<List<CourseIssue>?> _renderIssues(
  Course course,
  DirectoryCourseFiles files,
) async {
  final VerovioToolkit toolkit;
  try {
    toolkit = _openToolkit();
  } on Object {
    return null;
  }
  try {
    final refs = await collectCourseScores(course, files);
    return await checkCourseScores(refs, (ref) async => _renderOne(toolkit, ref));
  } on Object {
    return null;
  } finally {
    try {
      toolkit.dispose();
    } on Object {
      // Nada a fazer: o aviso já saiu.
    }
  }
}

VerovioToolkit _openToolkit() {
  final resource = _findResource();
  if (resource == null) throw StateError('sem dados do Verovio');
  final library = _findLibrary();
  return VerovioToolkit.withResourcePath(resource, libraryPath: library);
}

/// A `libverovio.so`: `VEROVIO_LIBRARY_PATH`, o build do bridge ou o nome
/// puro (o próprio binding procura no cwd e no pacote). `null` = tenta sem
/// caminho explícito.
String? _findLibrary() {
  final env = Platform.environment['VEROVIO_LIBRARY_PATH'];
  if (env != null && env.isNotEmpty && File(env).existsSync()) return env;
  const bridge =
      '/home/mauricio/rust_projects/verovio_flutter_bridge/verovio/bindings/dart/libverovio.so';
  if (File(bridge).existsSync()) return File(bridge).absolute.path;
  return null;
}

/// Os dados do Verovio (a pasta com o Bravura etc.): `VEROVIO_RESOURCE_PATH`
/// ou o checkout do bridge. `null` = indisponível.
String? _findResource() {
  final env = Platform.environment['VEROVIO_RESOURCE_PATH'];
  if (env != null && env.isNotEmpty && Directory(env).existsSync()) {
    return Directory(env).absolute.path;
  }
  const bridge = '/home/mauricio/rust_projects/verovio_flutter_bridge/verovio/data';
  if (Directory(bridge).existsSync()) {
    return Directory(bridge).absolute.path;
  }
  return null;
}

Future<ScoreRenderOutcome> _renderOne(
  VerovioToolkit toolkit,
  CourseScoreRef ref,
) async {
  toolkit.resetOptions();
  if (!toolkit.setOptions(
    jsonEncode({'pageWidth': 800, 'pageHeight': 1000}),
  )) {
    throw StateError(toolkit.getLog().trim());
  }
  final loaded = toolkit.loadData(ref.data);
  final log = toolkit.getLog().trim();
  if (!loaded) {
    final detail = log.isEmpty ? 'não carregou' : log.split('\n').first.trim();
    return ScoreRenderOutcome(
      loaded: false,
      log: detail,
      hasNotes: false,
      midiEmpty: true,
      measureCount: 0,
    );
  }
  String timemap;
  String midi;
  String mei;
  try {
    timemap = toolkit.renderToTimemap();
    midi = toolkit.renderToMIDI();
    mei = toolkit.getMEI();
  } on Object catch (e) {
    final detail = log.isEmpty ? '$e' : log.split('\n').first.trim();
    return ScoreRenderOutcome(
      loaded: true,
      log: detail,
      hasNotes: false,
      midiEmpty: true,
      measureCount: 0,
    );
  }
  final hasNotes = timemap.contains('"on"');
  final midiEmpty = _midiIsEmpty(midi);
  final measureCount = RegExp(r'<measure[\s>]').allMatches(mei).length;
  return ScoreRenderOutcome(
    loaded: true,
    log: log,
    hasNotes: hasNotes,
    midiEmpty: midiEmpty,
    measureCount: measureCount,
  );
}

/// O MIDI vazio do Verovio é só o cabeçalho (base64 curto, ~27 bytes
/// decodificados). Acima de ~40 bytes há ao menos um evento.
bool _midiIsEmpty(String midi) {
  final text = midi.trim();
  if (text.isEmpty) return true;
  try {
    final bytes = base64.decode(text.replaceAll(RegExp(r'\s+'), ''));
    return bytes.length <= 40;
  } on FormatException {
    return text.length < 50;
  }
}
