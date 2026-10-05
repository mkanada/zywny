// I05, critérios 1 e 3 — `test/lesson_view_test.dart`: uma lição de fixture
// com todos os elementos do markdown e as quatro marcas de conteúdo.
//
// A fixture mora em `test/fixtures/cursos/licao-i05/` (válida no validador,
// com um aviso de HTML de propósito). Todo IO de disco acontece no `setUpAll`
// (fora do relógio falso do `testWidgets`) e os widgets leem de
// `MemoryCourseFiles`; a partitura é pré-renderizada de verdade pela
// `libverovio.so` (sem ela, a caixa de erro — como o `vsb_render_test.dart`).
// O áudio usa um tocador falso e o link um abridor falso (nada toca de
// verdade, nada abre o navegador).

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart';

import 'package:zywny/course/format/course_files.dart';
import 'package:zywny/course/format/course_model.dart';
import 'package:zywny/course/format/course_reader.dart';
import 'package:zywny/course/format/directory_course_files.dart';
import 'package:zywny/course/score/lesson_score.dart';
import 'package:zywny/course/ui/exercise_card.dart';
import 'package:zywny/course/ui/lesson_audio.dart';
import 'package:zywny/course/ui/lesson_view.dart';
import 'package:zywny/midi/piano_keyboard.dart';
import 'package:zywny/render/score_renderer.dart';
import 'support/practice_fakes.dart';
import 'support/render_helper.dart';

class _FakeAudioPlayer implements LessonAudioPlayer {
  final _state = StreamController<PlayerState>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();

  int plays = 0;
  int pauses = 0;

  @override
  Future<void> setBytes(LessonAudioBytes audio) async {}

  @override
  Future<void> play() async {
    plays++;
    _state.add(PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    pauses++;
    _state.add(PlayerState.paused);
  }

  @override
  Future<void> stop() async {
    _state.add(PlayerState.stopped);
  }

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration?> get duration => _duration.stream;

  @override
  Stream<PlayerState> get state => _state.stream;

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {
    await _state.close();
    await _position.close();
    await _duration.close();
  }
}

/// O primeiro `recognizer` com `onTap` na árvore de `RichText` — o do link.
void _tapFirstLink(WidgetTester tester) {
  var tapped = false;
  void walk(InlineSpan span) {
    if (tapped) return;
    if (span is TextSpan) {
      final recognizer = span.recognizer;
      if (recognizer is TapGestureRecognizer) {
        recognizer.onTap?.call();
        tapped = true;
        return;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    } else if (span is WidgetSpan) {
      // Imagem: sem link.
    }
  }

  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget as RichText;
    walk(widget.text);
    if (tapped) return;
  }
  fail('nenhum link tocável achado');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Tudo que é IO de disco/FFI mora aqui (relógio real): os `testWidgets`
  // só consomem memória.
  late Lesson fixtureLesson;
  late MemoryCourseFiles fixtureFiles;
  VsbDocument? cachedScore;
  setUpAll(() async {
    await loadScoreFonts();
    final dir = Directory('test/fixtures/cursos/licao-i05');
    final disk = DirectoryCourseFiles(dir);
    final paths = await disk.list();
    final entries = <String, Object>{};
    for (final path in paths) {
      entries[path] = await disk.read(path);
    }
    fixtureFiles = MemoryCourseFiles(entries, label: 'licao-i05');
    final result = await readCourse(fixtureFiles);
    expect(
      result.issues.where((i) => i.isError),
      isEmpty,
      reason: result.issues.join('\n'),
    );
    fixtureLesson = result.course!.lessons.singleWhere((l) => l.id == 'um');
    if (!verovioAvailable) return;
    final mark = fixtureLesson.blocks.whereType<ScoreMark>().single;
    final source = await scoreSourceFor(
      mark.source,
      fixtureFiles,
      clef: mark.clef,
      key: mark.key,
      time: mark.time,
    );
    final layout = lessonScoreLayout(800);
    final rendered = await LibverovioRenderer().render(
      ScoreRenderRequest(
        source: source.bytes,
        fileName: source.fileName,
        pageWidth: layout.pageWidth,
        pageHeight: layout.pageHeight,
        options: layout.options,
      ),
    );
    cachedScore = rendered.document;
  });

  test('a fixture valida com só o aviso de HTML', () {
    // A leitura já conferiu (sem erros) no `setUpAll`; aqui fica o registro.
    expect(fixtureLesson.id, 'um');
    expect(
      fixtureLesson.blocks.whereType<ScoreMark>(),
      hasLength(1),
    );
    expect(
      fixtureLesson.blocks.whereType<KeyboardMark>(),
      hasLength(1),
    );
    expect(
      fixtureLesson.blocks.whereType<AudioMark>(),
      hasLength(1),
    );
    expect(
      fixtureLesson.blocks.whereType<VideoMark>(),
      hasLength(1),
    );
  });

  testWidgets('a lição mostra tudo; HTML é texto; link chama o abridor falso', (
    tester,
  ) async {
    final opened = <Uri>[];
    final started = <ExerciseSpec>[];
    // O tocador é da vista (ela o descarta no `dispose`): o teste só conta.
    final audio = _FakeAudioPlayer();
    final score = cachedScore;
    final ScoreRenderer renderer = score != null
        ? _CachedRenderer(score)
        : _ThrowingRenderer();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonView(
            lesson: fixtureLesson,
            files: fixtureFiles,
            highlightColor: Colors.green,
            engine: FakeSoundEngine(),
            renderer: renderer,
            openLink: (uri) async {
              opened.add(uri);
            },
            audioPlayerFactory: () => audio,
            onExerciseStart: started.add,
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(ScoreView).evaluate().isNotEmpty) break;
    }

    // Markdown: títulos, parágrafo, negrito, itálico, código, listas, citação.
    expect(find.text('Título um', findRichText: true), findsOneWidget);
    expect(find.text('Título dois', findRichText: true), findsOneWidget);
    expect(find.text('Título três', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('negrito', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('itálico', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('código', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('link', findRichText: true), findsWidgets);
    expect(
      find.textContaining('item um', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('subitem dois', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('primeiro', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('Uma citação para o teste.', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('codigo em bloco', findRichText: true),
      findsWidgets,
    );

    // HTML aparece como texto, sem interpretar.
    expect(
      find.textContaining('isto é texto, não HTML'),
      findsWidgets,
    );
    expect(
      find.textContaining('<div>', findRichText: true),
      findsWidgets,
    );

    // Link chama o abridor falso (o `url_launcher` de verdade, nunca aqui).
    _tapFirstLink(tester);
    expect(opened, [Uri.parse('https://example.com')]);

    // Imagem da pasta, com a legenda = texto alternativo.
    expect(find.text('A figura'), findsOneWidget);

    if (cachedScore != null) {
      // Partitura pequena, com legenda e botão ouvir.
      expect(find.text('O Sol na segunda linha'), findsOneWidget);
      expect(find.byType(ScoreView), findsOneWidget);
      expect(find.text('ouvir'), findsOneWidget);
    } else {
      // Sem a `.so`, a caixa de erro no lugar (arquivo e linha, I05).
      expect(find.textContaining('Não consegui desenhar'), findsOneWidget);
    }

    // Teclado desenhado, com legenda.
    expect(find.text('O dó central'), findsOneWidget);

    // Áudio: play/pausa, tempos e legenda.
    expect(find.text('O Sol da segunda linha'), findsOneWidget);
    final playButton = find.byTooltip('Tocar');
    expect(playButton, findsOneWidget);
    await tester.ensureVisible(playButton);
    await tester.tap(playButton);
    await tester.pump();
    expect(audio.plays, 1);

    // Vídeo: cartão com legenda e domínio, sem miniatura de rede.
    expect(find.text('Contando em voz alta'), findsOneWidget);
    expect(find.text('youtube.com'), findsOneWidget);

    // Exercício: cartão com título, pedido, meta, estado e Começar.
    expect(find.text('Toque as notas'), findsOneWidget);
    expect(
      find.textContaining('Toque as notas · clave de sol'),
      findsOneWidget,
    );
    expect(find.textContaining('meta 90%'), findsOneWidget);
    expect(find.text('não feito'), findsOneWidget);
    final startButton = find.text('Começar');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump();
    expect(started, hasLength(1));
    expect(started.single.title, 'Toque as notas');
  });

  testWidgets('exercício MIDI sem teclado pede o teclado', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonView(
            lesson: fixtureLesson,
            files: fixtureFiles,
            hasKeyboard: false,
            openLink: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Precisa do teclado').evaluate().isNotEmpty) break;
    }
    expect(find.text('Precisa do teclado'), findsOneWidget);
    // Bloqueado: o botão não começa.
    final button = find.widgetWithText(FilledButton, 'Começar');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('a lição cabe no celular em retrato', (tester) async {
    // Retrato de celular (I05, critério 4 manual): sem estouro de layout.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final audio = _FakeAudioPlayer();
    final score = cachedScore;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonView(
            lesson: fixtureLesson,
            files: fixtureFiles,
            engine: FakeSoundEngine(),
            renderer: score != null
                ? _CachedRenderer(score)
                : _ThrowingRenderer(),
            openLink: (_) async {},
            audioPlayerFactory: () => audio,
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('o monitor MIDI desenha igual a antes', (tester) async {
    // Padrão: 88 teclas, sem marcas nem nomes — o caminho do monitor.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 64,
            child: CustomPaint(
              painter: PianoKeyboardPainter(
                held: {60, 64, 67},
                heldColor: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);

    const painter = PianoKeyboardPainter(
      held: {},
      heldColor: Colors.blue,
      lowest: 60,
      highest: 72,
      marked: {60},
      markedColor: Colors.blue,
      names: true,
    );
    expect(painter.lowest, 60);
    expect(painter.highest, 72);
    // Repinta quando a faixa, as marcas ou os nomes mudam.
    expect(
      painter.shouldRepaint(
        const PianoKeyboardPainter(held: {}, heldColor: Colors.blue),
      ),
      isTrue,
    );
    expect(
      const PianoKeyboardPainter(
        held: {},
        heldColor: Colors.blue,
      ).shouldRepaint(
        const PianoKeyboardPainter(held: {}, heldColor: Colors.blue),
      ),
      isFalse,
    );
  });

  test('um só áudio toca por vez na lição', () {
    final coordinator = SingleAudioPlay();
    var pausedA = 0;
    var pausedB = 0;
    coordinator.started(() => pausedA++);
    coordinator.started(() => pausedB++);
    expect(pausedA, 1);
    expect(pausedB, 0);
  });

  test('resumo e meta do cartão por tipo', () {
    final spec = fixtureLesson.exercises.single;
    expect(exerciseSummary(spec), contains('Toque as notas'));
    expect(exerciseSummary(spec), contains('clave de sol'));
    expect(exerciseGoal(spec), 'meta 90%');
    expect(exerciseNeedsMidi(spec), isTrue);
  });
}

/// Devolve um documento já renderizado (o FFI não roda no relógio falso).
class _CachedRenderer implements ScoreRenderer {
  _CachedRenderer(this.document);

  final VsbDocument document;

  @override
  Future<RenderedScore> render(ScoreRenderRequest request) async =>
      RenderedScore(document);
}

/// Sem a `.so`: falha como um render real falharia (caixa de erro, I05).
class _ThrowingRenderer implements ScoreRenderer {
  @override
  Future<RenderedScore> render(ScoreRenderRequest request) async {
    throw StateError('verovio ausente');
  }
}
