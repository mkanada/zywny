// I04 — cursos instalados de pacotes `.zywny` assinados.
//
// Como o `LibraryStore` (fase B), mas sem "em uso": vários cursos instalados
// ao mesmo tempo. Os bytes dos pacotes (o envelope) ficam no mesmo
// `LibraryBlobStore` das bibliotecas, com o prefixo `course:` no id; a lista,
// em `shared_preferences` (`course_installed`). O progresso fica por id de
// curso (`CourseProgressStore`) e não é tocado aqui: substituir ou remover
// mantém o que o aluno fez.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../library/library_blob_store.dart';
import '../library/library_envelope.dart';
import '../library/library_package.dart' show LibraryFormatException;
import 'format/course_files.dart';
import 'format/course_model.dart';
import 'format/course_reader.dart';
import 'loaded_course.dart';

/// O id do curso inicial embutido (D-LIC-INICIAL): pacote com esse id é
/// recusado ("Este curso já vem no app").
const kBuiltInCourseId = 'iniciacao';

/// Que tipo de pacote o zip de dentro descreve.
enum PackageKind { library, course }

/// Separa curso de biblioteca pelo zip **aberto** (sem envelope). Os dois
/// juntos ou nenhum dos dois viram [LibraryFormatException] com a mensagem
/// pronta para a tela. O mesmo caminho do `CourseStore` e do despacho no
/// instalador.
PackageKind packageKindOfZip(Uint8List zip) {
  final Archive archive;
  try {
    if (zip.length < 4 || zip[0] != 0x50 || zip[1] != 0x4B) {
      throw const FormatException('sem assinatura de zip');
    }
    archive = ZipDecoder().decodeBytes(zip);
  } on Object {
    throw const LibraryFormatException(
      'Este arquivo não é um pacote do zywny (não é um .zip válido).',
    );
  }
  final names = {
    for (final f in archive.files)
      if (f.isFile) f.name,
  };
  final hasCourse = names.contains('course.md');
  final hasLibrary = names.contains('manifest.json');
  if (hasCourse && hasLibrary) {
    throw const LibraryFormatException(
      'Este arquivo tem curso e biblioteca ao mesmo tempo: não vou instalar.',
    );
  }
  if (hasCourse) return PackageKind.course;
  if (hasLibrary) return PackageKind.library;
  throw const LibraryFormatException(
    'Este arquivo não é um pacote do zywny (nem curso, nem biblioteca).',
  );
}

/// O que o app lembra de cada curso instalado, para a lista mostrar sem
/// abrir cada pacote.
@immutable
class InstalledCourse {
  const InstalledCourse({
    required this.id,
    required this.title,
    required this.author,
    required this.version,
    required this.installedAt,
  });

  factory InstalledCourse.fromCourse(Course course) => InstalledCourse(
    id: course.id,
    title: course.title,
    author: course.author,
    version: course.version,
    installedAt: DateTime.now().millisecondsSinceEpoch,
  );

  factory InstalledCourse.fromJson(Map<String, dynamic> json) =>
      InstalledCourse(
        id: json['id'] as String,
        title: json['titulo'] as String,
        author: json['autor'] as String,
        version: json['versao'] as String,
        installedAt: (json['data'] as num?)?.round() ?? 0,
      );

  final String id;
  final String title;
  final String author;

  /// Texto livre; só se mostra, o app não compara.
  final String version;

  /// Quando instalou, ms desde a época.
  final int installedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': title,
    'autor': author,
    'versao': version,
    'data': installedAt,
  };
}

/// Os cursos instalados. Os bytes ficam num [LibraryBlobStore] (arquivo,
/// IndexedDB ou memória) por `course:<id>`; a lista, em `shared_preferences`
/// (`course_installed`). Avisa quem escuta a cada mudança.
class CourseStore extends ChangeNotifier {
  CourseStore({
    LibraryBlobStore? blobs,
    SharedPreferencesAsync? prefs,
    Uint8List? publicKey,
  }) : _blobs = blobs ?? createLibraryBlobStore(),
       _prefs = prefs ?? SharedPreferencesAsync(),
       _publicKey = publicKey ?? libraryKeyFromEnvironment();

  static const listKey = 'course_installed';

  /// A chave do pacote no blob store (o mesmo das bibliotecas, com prefixo).
  static String blobId(String courseId) => 'course:$courseId';

  final LibraryBlobStore _blobs;
  final SharedPreferencesAsync _prefs;
  final Uint8List? _publicKey;
  final List<InstalledCourse> _installed = [];

  /// A chave pública que abre os pacotes (`null` sem chave no build): o
  /// despacho do instalador usa esta ou a das bibliotecas (a mesma pessoa
  /// assina os dois, D-LIC-CONFIANCA).
  Uint8List? get publicKey => _publicKey;

  /// Em ordem de instalação.
  List<InstalledCourse> get installed => List.unmodifiable(_installed);

  InstalledCourse? operator [](String? id) {
    for (final course in _installed) {
      if (course.id == id) return course;
    }
    return null;
  }

  /// Lê a lista das preferências. O que está na lista mas não tem pacote
  /// (arquivo apagado, dados do site limpos) sai dela.
  Future<void> load() async {
    _installed.clear();
    final text = await _prefs.getString(listKey);
    if (text != null) {
      try {
        for (final e in jsonDecode(text) as List<dynamic>) {
          final course = InstalledCourse.fromJson(e as Map<String, dynamic>);
          if (await _blobs.contains(blobId(course.id))) _installed.add(course);
        }
      } on Object {
        // Lista estragada: recomeça vazia em vez de travar o app.
        _installed.clear();
      }
    }
    notifyListeners();
  }

  /// Abre o curso de [id] (assinatura, cifra e conteúdo) ou `null` se não
  /// está instalado ou não abre mais.
  Future<LoadedCourse?> open(String id) async {
    final bytes = await _blobs.get(blobId(id));
    if (bytes == null) return null;
    try {
      final course = await _readCourse(bytes);
      return LoadedCourse(
        course: course,
        files: ZipCourseFiles(await openEnvelope(bytes)),
        origin: CourseOrigin.installed,
      );
    } on Object {
      return null;
    }
  }

  /// Todos os instalados que ainda abrem, na ordem da lista.
  Future<List<LoadedCourse>> openAll() async {
    final result = <LoadedCourse>[];
    for (final installed in _installed) {
      final loaded = await open(installed.id);
      if (loaded != null) result.add(loaded);
    }
    return result;
  }

  /// Os bytes do pacote de [id], como foram instalados (o envelope).
  Future<Uint8List?> read(String id) => _blobs.get(blobId(id));

  /// Valida [bytes] (assinatura, cifra e conteúdo) sem gravar nada: a tela
  /// usa isto para conferir o pacote e perguntar antes de substituir um
  /// curso instalado. Qualquer problema vira [LibraryFormatException] com a
  /// mensagem pronta para a tela.
  Future<Course> inspect(Uint8List bytes) => _readCourse(bytes);

  /// Valida [bytes] (assinatura, cifra e conteúdo) **antes de gravar**; se
  /// falhar, nada muda. Um `id` já instalado é substituído — quem pergunta
  /// ao usuário antes é a tela. O progresso **fica** (é por id de curso, no
  /// `CourseProgressStore`, que este store nem toca).
  Future<InstalledCourse> install(Uint8List bytes, {Course? inspected}) async {
    final course = inspected ?? await inspect(bytes);
    final installed = InstalledCourse.fromCourse(course);
    await _blobs.put(blobId(installed.id), bytes);
    final i = _installed.indexWhere((e) => e.id == installed.id);
    if (i >= 0) {
      _installed[i] = installed;
    } else {
      _installed.add(installed);
    }
    await _saveList();
    notifyListeners();
    return installed;
  }

  /// Apaga o pacote e tira da lista; o progresso fica (para o caso de
  /// reinstalar).
  Future<void> remove(String id) async {
    if (this[id] == null) return;
    await _blobs.delete(blobId(id));
    _installed.removeWhere((e) => e.id == id);
    await _saveList();
    notifyListeners();
  }

  /// Abre o envelope (assinatura e cifra) e devolve os bytes do zip, sem
  /// validar o conteúdo: o despacho do instalador usa isto para separar
  /// curso de biblioteca antes de chamar cada fluxo.
  Future<Uint8List> openEnvelope(Uint8List sealed) =>
      LibraryEnvelope.open(sealed, _requireKey());

  /// Abre o envelope, separa curso de biblioteca e lê o curso. O despacho
  /// (`manifest.json` × `course.md`) mora aqui para o instalador e os testes
  /// usarem o mesmo caminho.
  Future<Course> _readCourse(Uint8List sealed) async {
    final zip = await openEnvelope(sealed);
    if (packageKindOfZip(zip) != PackageKind.course) {
      throw const LibraryFormatException(
        'Este arquivo é uma biblioteca, não um curso.',
      );
    }
    final result = await readCourse(ZipCourseFiles(zip));
    if (result.hasErrors) {
      final first = result.issues
          .where((i) => i.isError)
          .take(3)
          .map((i) => i.toString())
          .join('\n');
      throw LibraryFormatException(
        'Este curso tem erros e não pode ser instalado:\n$first',
      );
    }
    final course = result.course!;
    if (course.id == kBuiltInCourseId) {
      throw const LibraryFormatException(
        'Este curso já vem no app: não precisa instalar.',
      );
    }
    return course;
  }

  Future<void> _saveList() => _prefs.setString(
    listKey,
    jsonEncode([for (final course in _installed) course.toJson()]),
  );

  Uint8List _requireKey() =>
      _publicKey ??
      (throw const LibraryFormatException(
        'Este app foi compilado sem a chave das bibliotecas: não consigo '
        'abrir nenhum pacote.',
      ));
}
