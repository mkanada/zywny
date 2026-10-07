// I05, item 9 — entrada provisória para ver uma lição antes do I09.
//
// O mais barato (anotado no I05): um `main` próprio, fora do `main.dart`
// (que compila para a Web e não pode importar `dart:io`), rodado com:
//
//   flutter run -d linux --no-enable-impeller \
//     -t lib/lesson_debug_main.dart \
//     --dart-entrypoint-args="--licao <pasta> <id>"
//
// `<pasta>` é a raiz do curso (com `course.md`); `<id>` é o `id` da lição.
// Exemplo com a fixture do teste:
//
//   flutter run -d linux --no-enable-impeller -t lib/lesson_debug_main.dart \
//     --dart-entrypoint-args="--licao test/fixtures/cursos/licao-i05 um"
//
// O I09 troca isto pelas telas de verdade (navegação entre lições e
// progresso); aqui é só a `LessonView` com o motor de som resolvido pela
// saída escolhida nas configurações.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:score_bridge/score_bridge.dart' show loadScoreFonts;

import 'audio/sound_engine.dart';
import 'audio/sound_engine_factory.dart';
import 'audio/soundfont_store.dart';
import 'course/format/course_reader.dart';
import 'course/format/course_model.dart';
import 'course/format/directory_course_files.dart';
import 'music/note_names.dart' show NoteNaming;
import 'course/ui/lesson_view.dart';
import 'settings/app_settings.dart';
import 'ui/theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadScoreFonts();
  final parsed = _parseArgs(args);
  runApp(LessonDebugApp(folder: parsed.folder, lessonId: parsed.lessonId));
}

({String folder, String lessonId}) _parseArgs(List<String> args) {
  var folder = 'test/fixtures/cursos/licao-i05';
  var lessonId = 'um';
  final index = args.indexOf('--licao');
  if (index >= 0) {
    if (index + 1 < args.length) folder = args[index + 1];
    if (index + 2 < args.length) lessonId = args[index + 2];
  }
  return (folder: folder, lessonId: lessonId);
}

class LessonDebugApp extends StatefulWidget {
  const LessonDebugApp({
    super.key,
    required this.folder,
    required this.lessonId,
  });

  final String folder;
  final String lessonId;

  @override
  State<LessonDebugApp> createState() => _LessonDebugAppState();
}

class _LessonDebugAppState extends State<LessonDebugApp> {
  final AppSettings _settings = AppSettings();
  Lesson? _lesson;
  String? _error;
  SoundEngine? _engine;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    await _settings.load();
    if (kIsWeb) {
      if (mounted) {
        setState(() => _error = 'o modo rascunho é só no desktop (I12)');
      }
      return;
    }
    try {
      final files = DirectoryCourseFiles(Directory(widget.folder));
      final result = await readCourse(files);
      final course = result.course;
      if (course == null) {
        if (!mounted) return;
        setState(() {
          _error = result.issues.map((i) => i.toString()).join('\n');
        });
        return;
      }
      final lesson = [
        for (final l in course.lessons)
          if (l.id == widget.lessonId) l,
      ].firstOrNull;
      if (lesson == null) {
        if (!mounted) return;
        setState(() => _error = 'lição ${widget.lessonId} não achada');
        return;
      }
      final engine = await _openEngine();
      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        _engine = engine;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<SoundEngine?> _openEngine() async {
    // Mesmo caminho do `_pickEngineWithSoundFont` do `main.dart`: motor do
    // app com o `.sf2` padrão. Sem áudio (Web, sem dispositivo), `null` e a
    // lição abre muda.
    try {
      final engine = createSoundEngine();
      await engine.start();
      await engine.loadSoundFont(await const SoundFontStore().load());
      return engine;
    } on Object catch (e) {
      debugPrint('licao-debug: sem som ($e)');
      return null;
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lição (I05)',
      theme: buildAppTheme(),
      home: Scaffold(
        appBar: AppBar(title: Text('Lição ${widget.lessonId} (rascunho I05)')),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(_error!),
      );
    }
    final lesson = _lesson;
    if (lesson == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => LessonView(
        lesson: lesson,
        files: DirectoryCourseFiles(Directory(widget.folder)),
        highlightColor: _settings.highlightColor,
        naming: _settings.noteNaming == NoteNaming.letters
            ? NoteNaming.letters
            : NoteNaming.latin,
        engine: _settings.output == SoundOutput.midiKeyboard ? null : _engine,
      ),
    );
  }
}
