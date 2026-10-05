// I12 — abrir a pasta do rascunho na Web.
//
// Chrome/Edge: a pasta pelo `showDirectoryPicker()` (o handle fica na
// sessão; Recarregar não pede de novo). Firefox/Safari (sem a API): um
// `.zip` da pasta, sem envelope — Recarregar pede o arquivo de novo. Esse
// `.zip` só vale no rascunho; o instalador continua recusando pacote sem
// assinatura (o teste do I04 não pode regredir).

import 'package:file_selector/file_selector.dart';

import '../format/course_files.dart';
import '../format/web_directory_course_files.dart';

/// Na Web há sempre um caminho: a pasta (Chrome/Edge) ou o `.zip`
/// (Firefox/Safari).
bool get draftPickerAvailable => true;

/// Pede a pasta (ou o `.zip`) ao usuário. `null` se cancelou.
Future<CourseFiles?> pickDraftCourseFiles() async {
  if (webDirectoryPickerAvailable) {
    final dir = await pickWebDirectory();
    if (dir != null) return dir;
    // Cancelou o seletor de pasta: cai para o `.zip` abaixo? Não — cancelar
    // é desistir. Só usa o `.zip` onde não há a API.
    return null;
  }
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'pasta em zip', extensions: ['zip']),
    ],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return ZipCourseFiles(bytes, label: file.name);
}

/// Sem linha de comando na Web.
Future<CourseFiles> openDraftFolder(String path) =>
    throw UnsupportedError('o modo rascunho por pasta é só no desktop');
