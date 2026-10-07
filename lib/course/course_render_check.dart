// I12 — o que o `--render` confere: toda partitura escrita pelo autor.
//
// Junta, para cada `zywny-score`, `choice` com `abc` e exercício com
// `abc`/`file`, os bytes prontos para o Verovio (com o cabeçalho do I02
// quando for corpo de ABC) e o `measures` quando houver. Dart puro, sem
// Flutter e sem FFI: quem renderiza (a linha de comando ou os testes) passa
// o `render` — o Verovio de verdade — e recebe os problemas no formato do
// validador (`arquivo:linha: erro: mensagem`).

import 'dart:convert';

import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/course_issue.dart';
import 'package:zywny_course_format/course_model.dart';

import 'score/abc_source.dart';

/// Uma partitura escrita pelo autor, pronta para o Verovio.
class CourseScoreRef {
  const CourseScoreRef({
    required this.file,
    required this.line,
    required this.data,
    required this.fileName,
    this.measures,
  });

  /// Arquivo da lição (`lessons/02-pauta.md`).
  final String file;

  /// Linha da marca no arquivo.
  final int line;

  /// O texto para o Verovio (`loadData`): ABC completo ou MusicXML.
  final String data;

  /// Só para mensagens e para o arquivo temporário do nativo.
  final String fileName;

  /// Só no `play-score`: os compassos escritos pedidos.
  final MeasureRange? measures;
}

/// Todas as partituras escritas pelo autor em [course], na ordem das lições.
/// `file:` é lido de [files]; ABC de corpo ganha o cabeçalho do I02.
Future<List<CourseScoreRef>> collectCourseScores(
  Course course,
  CourseFiles files,
) async {
  final refs = <CourseScoreRef>[];
  for (final lesson in course.lessons) {
    for (final block in lesson.blocks) {
      switch (block) {
        case ScoreMark(
          line: final line,
          source: final source,
          clef: final clef,
          key: final key,
          time: final time,
        ):
          final data = await _scoreData(
            source,
            files,
            clef: clef,
            key: key,
            time: time,
          );
          if (data == null) continue;
          refs.add(
            CourseScoreRef(
              file: lesson.fileName,
              line: line,
              data: data.$1,
              fileName: data.$2,
            ),
          );
        case ExerciseMark(:final spec):
          final ref = await _exerciseScore(spec, lesson.fileName, files);
          if (ref != null) refs.add(ref);
        case TextBlock():
        case KeyboardMark():
        case AudioMark():
        case VideoMark():
          break;
      }
    }
  }
  return refs;
}

Future<CourseScoreRef?> _exerciseScore(
  ExerciseSpec spec,
  String file,
  CourseFiles files,
) async {
  switch (spec) {
    case PlayScoreSpec(source: final source, measures: final measures):
      final String data;
      final String fileName;
      switch (source) {
        case AbcSource(:final abc):
          data = abcIsComplete(abc) ? abc : abcSource(abc);
          fileName = 'lesson.abc';
        case FileSource(:final path):
          final bytes = await _readBytes(files, path);
          if (bytes == null) return null;
          try {
            data = utf8.decode(bytes);
          } on FormatException {
            return null;
          }
          fileName = path.split('/').last;
      }
      return CourseScoreRef(
        file: file,
        line: spec.line,
        data: data,
        fileName: fileName,
        measures: measures,
      );
    case RhythmSpec(abc: final abc, time: final time):
      if (abc == null) return null;
      final data = abcIsComplete(abc) ? abc : abcSource(abc, time: time);
      return CourseScoreRef(
        file: file,
        line: spec.line,
        data: data,
        fileName: 'lesson.abc',
      );
    case ChoiceSpec(abc: final abc):
      if (abc == null) return null;
      return CourseScoreRef(
        file: file,
        line: spec.line,
        data: abcSource(abc),
        fileName: 'lesson.abc',
      );
    case FindKeySpec():
    case PlayNotesSpec():
    case NameNoteSpec():
    case CountBeatsSpec():
      return null;
  }
}

/// O texto para o Verovio de um `ScoreMark`: ABC com cabeçalho ou o
/// `.musicxml` da pasta. `null` se o arquivo não abre (o `readCourse` já
/// deu o erro; o `--render` não repete).
Future<(String, String)?> _scoreData(
  ScoreSource source,
  CourseFiles files, {
  required Clef clef,
  String? key,
  String? time,
}) async {
  switch (source) {
    case AbcSource(:final abc):
      if (abcIsComplete(abc)) return (abc, 'lesson.abc');
      return (abcSource(abc, clef: clef, key: key, time: time), 'lesson.abc');
    case FileSource(:final path):
      final bytes = await _readBytes(files, path);
      if (bytes == null) return null;
      try {
        return (utf8.decode(bytes), path.split('/').last);
      } on FormatException {
        return null;
      }
  }
}

Future<List<int>?> _readBytes(CourseFiles files, String path) async {
  try {
    return await files.read(path);
  } on Object {
    return null;
  }
}

/// O que o Verovio disse de uma partitura: o mínimo que o `--render`
/// precisa para decidir sem o `score_bridge` (que puxa Flutter e não roda
/// no `dart run`).
class ScoreRenderOutcome {
  const ScoreRenderOutcome({
    required this.loaded,
    required this.log,
    required this.hasNotes,
    required this.midiEmpty,
    required this.measureCount,
  });

  /// O `loadData` aceitou.
  final bool loaded;

  /// O `getLog()` da tentativa (uma linha, pode ser vazio).
  final String log;

  /// O `timemap` tem ao menos uma nota (`"on"`).
  final bool hasNotes;

  /// O MIDI veio vazio (só o cabeçalho).
  final bool midiEmpty;

  /// Compassos escritos (`<measure` no MEI).
  final int measureCount;
}

/// Confere [refs] com o [render] do chamador e devolve os problemas no
/// formato do validador. Erro na linha da marca:
///
///   `A partitura não renderiza (o Verovio disse: …).`
///
/// e, com `measures` fora da partitura:
///
///   `` `measures` "5-12" fora da partitura (a peça tem 4 compassos). ``
Future<List<CourseIssue>> checkCourseScores(
  List<CourseScoreRef> refs,
  Future<ScoreRenderOutcome> Function(CourseScoreRef ref) render,
) async {
  final issues = <CourseIssue>[];
  for (final ref in refs) {
    final ScoreRenderOutcome outcome;
    try {
      outcome = await render(ref);
    } on Object catch (e) {
      issues.add(
        CourseIssue(
          severity: IssueSeverity.error,
          file: ref.file,
          line: ref.line,
          message: 'A partitura não renderiza (o Verovio disse: $e).',
        ),
      );
      continue;
    }
    if (!outcome.loaded || !outcome.hasNotes || outcome.midiEmpty) {
      final detail = outcome.log.trim().isEmpty
          ? 'MIDI vazio'
          : outcome.log.trim().split('\n').first.trim();
      // Sem detalhe do Verovio (o caso do ABC sem notas: carrega, mas o
      // timemap vem vazio e o MIDI só com o cabeçalho): a mensagem leva o
      // motivo em vez de um parêntese vazio.
      issues.add(
        CourseIssue(
          severity: IssueSeverity.error,
          file: ref.file,
          line: ref.line,
          message: 'A partitura não renderiza (o Verovio disse: $detail).',
        ),
      );
      continue;
    }
    final measures = ref.measures;
    if (measures != null) {
      final count = outcome.measureCount;
      if (measures.from < 1 ||
          measures.to < measures.from ||
          measures.to > count) {
        issues.add(
          CourseIssue(
            severity: IssueSeverity.error,
            file: ref.file,
            line: ref.line,
            message:
                '`measures` "${measures.from == measures.to ? '${measures.from}' : '${measures.from}-${measures.to}'}" '
                'fora da partitura (a peça tem $count '
                '${count == 1 ? 'compasso' : 'compassos'}).',
          ),
        );
      }
    }
  }
  issues.sort();
  return issues;
}
