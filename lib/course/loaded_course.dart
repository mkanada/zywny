// I09 — um curso aberto, de onde quer que tenha vindo.
//
// A tela recebe isto e não sabe a origem, salvo para a faixa de rascunho e
// para não guardar progresso de rascunho: o curso inicial vem embutido (I10),
// o instalado vem do pacote (I04), o rascunho de uma pasta (I12).

import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/course_model.dart';

/// De onde veio o curso aberto.
enum CourseOrigin {
  /// Embutido no app (o curso inicial, I10).
  builtIn,

  /// Instalado de um pacote `.zywny` (I04).
  installed,

  /// Pasta aberta no modo rascunho (I12): faixa "rascunho, não verificado",
  /// progresso só na memória.
  draft,
}

/// Um curso pronto para as telas: o modelo lido mais os arquivos dele.
class LoadedCourse {
  const LoadedCourse({
    required this.course,
    required this.files,
    required this.origin,
  });

  final Course course;
  final CourseFiles files;
  final CourseOrigin origin;

  String get id => course.id;

  bool get isDraft => origin == CourseOrigin.draft;
}
