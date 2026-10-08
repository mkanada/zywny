// I04 — instalar pacotes `.zywny`: bibliotecas ou cursos.
//
// O mesmo "Abrir arquivo…" instala os dois: o zip de dentro diz o tipo
// (`manifest.json` = biblioteca, `course.md` = curso; os dois = erro).
// O fluxo da biblioteca continua em `library_installer.dart`; aqui mora o
// fluxo do curso e o despacho [`installPackageFromFile`].

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:zywny_library/library_envelope.dart';
import 'package:zywny_library/library_installer.dart'
    show installLibraryFromFile, pickLibraryBytes;
import 'package:zywny_library/library_package.dart' show LibraryFormatException;
import 'package:zywny_library/library_store.dart';

import '../incoming/incoming_packages.dart';
import 'course_store.dart';

import 'package:zywny_course_format/course_model.dart';

/// Escolher → validar → (perguntar, se o `id` já está instalado) → gravar →
/// avisar. Devolve o curso instalado, ou `null` se o usuário cancelou ou deu
/// erro (que o diálogo já explicou); nesse caso nada foi gravado.
Future<InstalledCourse?> installCourseFromFile(
  BuildContext context,
  CourseStore store, {
  Future<Uint8List?> Function() pick = pickLibraryBytes,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);

  Future<void> showError(
    String message, {
    String title = 'Não deu para instalar',
  }) => showDialog<void>(
    context: navigator.context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  final Uint8List? bytes;
  try {
    bytes = await pick();
  } on Object catch (e) {
    await showError('Não consegui abrir o seletor de arquivos: $e');
    return null;
  }
  if (bytes == null) return null;
  if (!navigator.mounted) return null;
  return _installCourseBytes(navigator.context, store, bytes);
}

/// O mesmo fluxo, com os bytes já escolhidos (o despacho já abriu o seletor).
Future<InstalledCourse?> _installCourseBytes(
  BuildContext context,
  CourseStore store,
  Uint8List bytes,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  Future<T> whileBusy<T>(String message, Future<T> Function() work) async {
    unawaited(
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => _BusyDialog(message),
      ),
    );
    try {
      return await work();
    } finally {
      navigator.pop();
    }
  }

  Future<void> showError(
    String message, {
    String title = 'Não deu para instalar',
  }) => showDialog<void>(
    context: navigator.context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  try {
    final Course course;
    try {
      course = await whileBusy('Lendo o curso…', () => store.inspect(bytes));
    } on LibraryFormatException catch (e) {
      await showError(e.message);
      return null;
    }

    final installed = store[course.id];
    if (installed != null) {
      if (!navigator.mounted) return null;
      if (installed.version == course.version) {
        await showError(
          '"${course.title}" (versão ${course.version}) já está instalado.',
          title: 'Já instalado',
        );
        return null;
      }
      final replace = await showDialog<bool>(
        context: navigator.context,
        builder: (context) => _ReplaceCourseDialog(
          installed: installed,
          incomingVersion: course.version,
        ),
      );
      if (replace != true) return null;
    }

    final InstalledCourse done;
    try {
      done = await whileBusy(
        'Instalando…',
        () => store.install(bytes, inspected: course),
      );
    } on Object catch (e) {
      await showError(
        e is LibraryFormatException
            ? e.message
            : 'Não consegui guardar o curso: $e',
      );
      return null;
    }
    final count = course.lessons.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${done.title} instalado ($count ${count == 1 ? 'lição' : 'lições'})',
        ),
      ),
    );
    return done;
  } on Object {
    // A tela saiu do ar no meio (o diálogo já tinha sido fechado).
    return null;
  }
}

/// O instalador genérico (I04): o mesmo seletor aceita biblioteca **ou**
/// curso; o zip de dentro decide. Devolve o instalado (`InstalledLibrary` ou
/// `InstalledCourse`), ou `null` se cancelou ou deu erro.
Future<Object?> installPackageFromFile(
  BuildContext context,
  LibraryStore libraryStore,
  CourseStore courseStore, {
  Future<Uint8List?> Function() pick = pickLibraryBytes,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);

  Future<void> showError(String message) => showDialog<void>(
    context: navigator.context,
    builder: (context) => AlertDialog(
      title: const Text('Não deu para instalar'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  final Uint8List? bytes;
  try {
    bytes = await pick();
  } on Object catch (e) {
    await showError('Não consegui abrir o seletor de arquivos: $e');
    return null;
  }
  if (bytes == null) return null;

  // O despacho: abre o envelope e lê o zip. Biblioteca → fluxo de hoje;
  // curso → fluxo do curso; erro → o diálogo já explica e nada é gravado.
  // A chave é a mesma nos dois stores (D-LIC-CONFIANCA); vale qualquer uma
  // que existir (nos testes, cada store tem a sua).
  final PackageKind kind;
  try {
    final key = courseStore.publicKey ?? libraryStore.publicKey;
    if (key == null) {
      throw const LibraryFormatException(
        'Este app foi compilado sem a chave das bibliotecas: não consigo '
        'abrir nenhum pacote.',
      );
    }
    kind = packageKindOfZip(await LibraryEnvelope.open(bytes, key));
  } on LibraryFormatException catch (e) {
    await showError(e.message);
    return null;
  }
  if (!navigator.mounted) return null;
  return switch (kind) {
    PackageKind.library => installLibraryFromFile(
      navigator.context,
      libraryStore,
      pick: () async => bytes,
    ),
    PackageKind.course => _installCourseBytes(
      navigator.context,
      courseStore,
      bytes,
    ),
  };
}

/// O pacote que o sistema entregou ao app (B11: clique duplo, "Abrir com…"):
/// o mesmo fluxo do "Abrir arquivo…", sem o seletor. Se o arquivo não pôde ser
/// lido, o diálogo diz qual.
Future<Object?> installIncomingPackage(
  BuildContext context,
  LibraryStore libraryStore,
  CourseStore courseStore,
  IncomingPackage package,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final Uint8List bytes;
  try {
    bytes = await package.read();
  } on Object catch (e) {
    if (!navigator.mounted) return null;
    await showDialog<void>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: const Text('Não deu para abrir o arquivo'),
        content: Text('Não consegui ler "${package.name}": $e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return null;
  }
  if (!navigator.mounted) return null;
  return installPackageFromFile(
    navigator.context,
    libraryStore,
    courseStore,
    pick: () async => bytes,
  );
}

class _BusyDialog extends StatelessWidget {
  const _BusyDialog(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ReplaceCourseDialog extends StatelessWidget {
  const _ReplaceCourseDialog({
    required this.installed,
    required this.incomingVersion,
  });

  final InstalledCourse installed;
  final String incomingVersion;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Substituir ${installed.title}?'),
      content: Text(
        'Instalado: versão ${installed.version}.\n'
        'Do arquivo: versão $incomingVersion.\n\n'
        'Seu progresso fica guardado: se você reinstalar, tudo volta.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Substituir'),
        ),
      ],
    );
  }
}
