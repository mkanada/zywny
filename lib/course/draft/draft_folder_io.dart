// I12 — abrir a pasta do rascunho no desktop (Linux, Windows, macOS).
//
// `file_selector` tem `getDirectoryPath()` no Linux e no Windows (e no
// macOS); no Android/iOS e na Web, não — ver `draft_folder_web.dart`.

import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/directory_course_files.dart';

/// O seletor de pasta existe aqui? (desktop; no Android/iOS, não.)
bool get draftPickerAvailable => !Platform.isAndroid && !Platform.isIOS;

/// Pede a pasta ao usuário. `null` se cancelou.
Future<CourseFiles?> pickDraftCourseFiles() async {
  if (!draftPickerAvailable) return null;
  final path = await getDirectoryPath();
  if (path == null || path.isEmpty) return null;
  return DirectoryCourseFiles(Directory(path));
}

/// Abre a pasta do `just curso <pasta>` (linha de comando, desktop).
Future<CourseFiles> openDraftFolder(String path) async =>
    DirectoryCourseFiles(Directory(path));
