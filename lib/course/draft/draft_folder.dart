// I12 — abrir a pasta do rascunho, no desktop e na Web.
//
// Import condicional: `dart:io` e `file_selector.getDirectoryPath()` não
// existem na Web; `dart:js_interop` não existe no desktop. Quem chama usa
// só esta fachada.

import 'draft_folder_web.dart'
    if (dart.library.io) 'draft_folder_io.dart'
    as impl;

import '../format/course_files.dart';

/// O seletor de rascunho existe aqui? (desktop e Web; no Android, não.)
bool get draftPickerAvailable => impl.draftPickerAvailable;

/// Pede a pasta (desktop/Web com a API) ou o `.zip` (Web sem a API) ao
/// usuário. `null` se cancelou ou sem suporte.
Future<CourseFiles?> pickDraftCourseFiles() => impl.pickDraftCourseFiles();

/// Abre a pasta do `just curso <pasta>` (linha de comando, desktop).
Future<CourseFiles> openDraftFolder(String path) => impl.openDraftFolder(path);
