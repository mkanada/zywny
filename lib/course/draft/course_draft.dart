// ignore_for_file: prefer_initializing_formals — o parâmetro é público
// (`loadFiles`), o campo é privado (`_loadFiles`); `this._loadFiles` não
// funciona entre bibliotecas.
// I12 — o rascunho do professor: uma pasta aberta sem pacote nem assinatura.
//
// O professor escreve a pasta num editor e vê o resultado no app, sem
// instalar: "Abrir pasta de curso…" carrega a pasta como rascunho — faixa
// "Rascunho · não verificado", botão Recarregar, nada instalado, progresso
// só na memória. Fechar o app (ou a aba) apaga o curso.
//
// Só memória: o progresso fica num `MemoryCourseProgressStore` (nunca no
// `shared_preferences`) e os bytes nunca passam pelo blob store — o teste
// `course_draft_test.dart` confere os dois.

import 'package:flutter/foundation.dart';

import '../course_progress.dart';

import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/course_model.dart';
import 'package:zywny_course_format/course_reader.dart';

import '../loaded_course.dart';

/// Uma pasta aberta como rascunho: o último `readCourse` mais o progresso da
/// sessão (que o Recarregar mantém) e a lição selecionada (idem, se ela
/// ainda existir).
class CourseDraftController extends ChangeNotifier {
  CourseDraftController({
    required Future<CourseFiles> Function() loadFiles,
    MemoryCourseProgressStore? progress,
  }) : _loadFiles = loadFiles,
       _progress = progress ?? MemoryCourseProgressStore();

  final Future<CourseFiles> Function() _loadFiles;
  final MemoryCourseProgressStore _progress;

  /// Progresso da sessão: o mesmo objeto do primeiro ao último Recarregar.
  MemoryCourseProgressStore get progress => _progress;

  CourseFiles? _files;
  Course? _course;
  List<CourseIssue> _issues = const [];

  /// A lição aberta (para o Recarregar manter a tela, se ela ainda existir).
  String? _lessonId;
  String? get lessonId => _lessonId;

  bool _loading = false;
  bool get loading => _loading;

  Course? get course => _course;
  List<CourseIssue> get issues => _issues;
  CourseFiles? get files => _files;

  /// Nome para a faixa ("Rascunho · não verificado · <label>").
  String get label => _files?.label ?? 'rascunho';

  bool get hasErrors => _issues.any((i) => i.isError);
  List<CourseIssue> get errors => [
    for (final i in _issues)
      if (i.isError) i,
  ];
  List<CourseIssue> get warnings => [
    for (final i in _issues)
      if (!i.isError) i,
  ];

  /// O curso pronto para as telas do I09, com `origin: draft`. `null` com
  /// erro (aí vale a lista de problemas).
  LoadedCourse? get loaded {
    final course = _course;
    final files = _files;
    if (course == null || files == null) return null;
    return LoadedCourse(
      course: course,
      files: files,
      origin: CourseOrigin.draft,
    );
  }

  /// A lição que a tela mostra (a selecionada, se ainda existir).
  void selectLesson(String? id) {
    if (_lessonId == id) return;
    _lessonId = id;
    notifyListeners();
  }

  /// Lê de novo e atualiza: o progresso da sessão fica, a lição fica se ela
  /// ainda existir no curso novo (senão volta para `null`, a lista).
  Future<void> reload() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final files = await _loadFiles();
      final result = await readCourse(files);
      _files = files;
      _course = result.course;
      _issues = [...result.issues]..sort();
      final id = _lessonId;
      if (id != null &&
          (result.course == null ||
              result.course!.lessons.every((l) => l.id != id))) {
        _lessonId = null;
      }
    } on Object catch (e) {
      _files = null;
      _course = null;
      _issues = [
        CourseIssue(
          severity: IssueSeverity.error,
          file: 'curso',
          line: 1,
          message: 'Não consegui ler a pasta: $e',
        ),
      ];
      _lessonId = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
