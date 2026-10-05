// I07 — corpo da rodada de perguntas: a pergunta atual (nome grande,
// partitura com destaque ou texto da `choice`) e os botões grandes.
//
// Sem teclado conectado, `name-note`, `count-beats` e `choice` abrem e
// rodam; `find-key` pede o teclado (a porta é da `ExerciseScreen`).
// Teclado do computador também responde no desktop/Web (1–7 e C–B).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';

import '../../midi/midi_input_service.dart';
import '../../render/score_renderer.dart';
import '../../settings/app_settings.dart';
import '../../ui/theme.dart';
import '../exercise/exercise_round.dart';
import '../exercise/question_session.dart';
import '../format/course_files.dart';
import '../format/course_model.dart';
import '../format/note_name.dart';
import '../note_names.dart';
import '../score/lesson_score.dart';
import 'keyboard_mark_view.dart';
import 'markdown_view.dart';

/// Corpo de uma `QuestionRound`: conduz a [session] até o fim e devolve o
/// resultado por [onDone]. Um corpo por rodada (a `ExerciseScreen` monta de
/// novo a cada "Outra rodada").
class QuestionBody extends StatefulWidget {
  const QuestionBody({
    super.key,
    required this.spec,
    required this.round,
    required this.files,
    required this.settings,
    required this.midiInput,
    required this.rendererFactory,
    required this.onDone,
  });

  final ExerciseSpec spec;
  final QuestionRound round;
  final CourseFiles files;
  final AppSettings settings;
  final MidiInputService midiInput;
  final ScoreRenderer Function() rendererFactory;
  final ValueChanged<RoundResult> onDone;

  @override
  State<QuestionBody> createState() => _QuestionBodyState();
}

class _QuestionBodyState extends State<QuestionBody> {
  late final QuestionSession _session = QuestionSession(
    widget.round.questions,
    timeLimit: widget.spec.pass.timeLimit,
  );
  StreamSubscription<PlayedNote>? _midiSub;
  Timer? _tickTimer;
  Timer? _flashTimer;
  int? _wrongButton;
  int? _wrongPitch;

  VsbDocument? _document;
  ScoreController? _controller;
  ScoreViewController? _viewController;
  bool _loadingScore = false;
  String? _scoreError;
  double? _scoreWidthPx;

  bool get _isFindKey => widget.spec is FindKeySpec;
  bool get _isChoice => widget.spec is ChoiceSpec;

  @override
  void initState() {
    super.initState();
    if (_isFindKey) {
      _midiSub = widget.midiInput.notes.listen(_onMidi);
    }
    final limit = widget.spec.pass.timeLimit;
    if (limit != null) {
      _tickTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) {
          if (!mounted) return;
          if (_session.tick()) setState(() {});
        },
      );
    }
  }

  @override
  void dispose() {
    _midiSub?.cancel();
    _tickTimer?.cancel();
    _flashTimer?.cancel();
    _controller?.dispose();
    _viewController?.dispose();
    super.dispose();
  }

  void _onMidi(PlayedNote note) {
    if (!note.on || _isChoice) return;
    if (_session.done || _session.revealing) return;
    final result = _session.answerPitch(note.pitch);
    if (!mounted) return;
    if (result == null) return; // ignorada (revelando)
    if (result) {
      setState(() {
        _wrongPitch = null;
      });
      _afterAnswer();
    } else {
      setState(() => _wrongPitch = note.pitch);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongPitch = null);
      });
      setState(() {});
    }
  }

  void _answerButton(int index) {
    if (_session.done || _session.revealing) return;
    final result = _session.answerChoice(index);
    if (result == null) return;
    if (result) {
      setState(() => _wrongButton = null);
      _afterAnswer();
    } else {
      setState(() => _wrongButton = index);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongButton = null);
      });
      setState(() {});
    }
  }

  void _afterAnswer() {
    _applyHighlight();
    if (_session.done) {
      _tickTimer?.cancel();
      widget.onDone(_session.result());
    } else {
      setState(() {});
    }
  }

  void _applyHighlight() {
    final controller = _controller;
    if (controller == null) return;
    controller.clearAll();
    final questions = widget.round.questions;
    for (var i = 0; i < _session.index && i < questions.length; i++) {
      final id = questions[i].highlightId;
      if (id == null) continue;
      controller.setColors({
        id: _session.firstTry[i]
            ? widget.settings.highlightColor
            : widget.settings.practiceWrongColor,
      });
    }
    if (!_session.done) {
      final id = _session.current?.highlightId;
      if (id != null) {
        controller.setColors({id: widget.settings.practicePendingColor});
      }
    }
  }

  Future<void> _loadScore(double widthPx) async {
    final bytes = widget.round.scoreBytes;
    final fileName = widget.round.fileName;
    if (bytes == null || fileName == null) return;
    if (_document != null || _loadingScore) return;
    _loadingScore = true;
    try {
      final layout = lessonScoreLayout(widthPx);
      final rendered = await widget.rendererFactory().render(
        ScoreRenderRequest(
          source: bytes,
          fileName: fileName,
          pageWidth: layout.pageWidth,
          pageHeight: layout.pageHeight,
          options: layout.options,
        ),
      );
      if (!mounted) return;
      _controller?.dispose();
      _viewController?.dispose();
      final controller = ScoreController(document: rendered.document);
      setState(() {
        _document = rendered.document;
        _controller = controller;
        _viewController = ScoreViewController();
        _scoreError = null;
      });
      _applyHighlight();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _scoreError = '$e');
    } finally {
      _loadingScore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session.done) {
      return const Center(child: CircularProgressIndicator());
    }
    final question = _session.current!;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final index = _keyToButton(event.logicalKey, question);
        if (index == null) return KeyEventResult.ignored;
        _answerButton(index);
        return KeyEventResult.handled;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final children = <Widget>[];
          if (_isFindKey) {
            children.add(_findKeyPrompt(question));
          } else if (_isChoice) {
            children.add(_choicePrompt(question));
          } else {
            children.add(_scoreView(constraints));
          }
          // A figura da `choice` (imagem ou partitura pequena).
          if (_isChoice) {
            final figure = _choiceFigure(constraints);
            if (figure != null) children.add(figure);
          }
          children.add(const SizedBox(height: 12));
          if (!_isFindKey) {
            children.add(_buttons(question));
          }
          if (_session.revealing) {
            children.add(
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tempo esgotado — a certa está em verde.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: kInkCaption),
                ),
              ),
            );
          }
          if (_wrongPitch != null || _wrongButton != null) {
            children.add(
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Tente de novo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kBadColor,
                  ),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          );
        },
      ),
    );
  }

  int? _keyToButton(LogicalKeyboardKey key, Question question) {
    final digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
    ];
    for (var i = 0; i < 7 && i < question.answers.length; i++) {
      if (key == digits[i] || key == digits[i + 7]) return i;
    }
    // Letras C–B para o `name-note` (a letra do botão).
    final letters = [
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyG,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyB,
    ];
    const names = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    for (var i = 0; i < letters.length; i++) {
      if (key == letters[i]) {
        final at = question.answers.indexOf(_choiceLabel(names[i], question));
        if (at >= 0) return at;
        // `name-note` guarda as letras cruas (`C`…`B`).
        final raw = question.answers.indexOf(names[i]);
        if (raw >= 0) return raw;
      }
    }
    return null;
  }

  String _choiceLabel(String raw, Question question) {
    // `name-note`: os botões guardam as letras cruas; a tela mostra o nome
    // nas configurações. Aqui só repassa para achar o índice pela letra.
    return raw;
  }

  Widget _findKeyPrompt(Question question) {
    final naming = widget.settings.noteNaming;
    final expected = question.expectedPitch ?? 60;
    final label = midiLabel(
      expected,
      naming,
      withOctave: !question.anyOctave,
    );
    final showingAnswer = _session.revealing;
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          label,
          textAlign: TextAlign.center,
          style: serifDisplay(fontSize: 64).copyWith(
            color: showingAnswer
                ? widget.settings.highlightColor
                : (_wrongPitch != null ? kBadColor : kInk),
          ),
        ),
        if (!question.anyOctave) ...[
          const SizedBox(height: 8),
          const Text(
            'O dó central está marcado.',
            style: TextStyle(fontSize: 13, color: kInkCaption),
          ),
          SizedBox(
            width: 320,
            child: KeyboardMarkView(
              mark: KeyboardMark(
                line: 0,
                from: Pitch.parse('C3'),
                to: Pitch.parse('C5'),
                mark: [Pitch.parse('C4')],
                names: true,
              ),
              naming: naming,
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Toque a tecla (vale qualquer oitava).',
            style: TextStyle(fontSize: 13, color: kInkCaption),
          ),
        ],
        const SizedBox(height: 8),
        const Icon(Icons.piano, size: 28, color: kInkCaption),
      ],
    );
  }

  Widget _choicePrompt(Question question) {
    return MarkdownView(
      text: question.prompt ?? '',
      files: widget.files,
    );
  }

  Widget? _choiceFigure(BoxConstraints constraints) {
    final imagePath = widget.round.imagePath;
    if (imagePath != null) {
      return FutureBuilder(
        future: widget.files.read(imagePath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(snapshot.data!, fit: BoxFit.contain),
          );
        },
      );
    }
    final bytes = widget.round.scoreBytes;
    if (bytes == null) return null;
    return _scoreView(constraints, small: true);
  }

  Widget _scoreView(BoxConstraints constraints, {bool small = false}) {
    final widthPx = constraints.maxWidth.isFinite
        ? constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)
        : 1800.0;
    if (_scoreWidthPx == null) {
      _scoreWidthPx = widthPx;
      _loadScore(widthPx);
    }
    if (_scoreError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Não consegui desenhar esta partitura.',
          style: const TextStyle(fontSize: 14, color: kInkCaption),
        ),
      );
    }
    final document = _document;
    final controller = _controller;
    final viewController = _viewController;
    if (document == null || controller == null || viewController == null) {
      return Container(
        height: small ? 140 : 180,
        decoration: BoxDecoration(
          color: kChipBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final boxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : 640.0;
    var total = 0.0;
    for (final page in document.pages) {
      if (page.widthPx > 0) {
        total += boxWidth * page.heightPx / page.widthPx;
      }
    }
    final height = (total < 120.0 ? 120.0 : total).clamp(120.0, 320.0);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorderSoft),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: ScoreView(
          document: document,
          controller: controller,
          viewController: viewController,
          mode: ScorePageMode.continuousScroll,
        ),
      ),
    );
  }

  Widget _buttons(Question question) {
    final naming = widget.settings.noteNaming;
    final labels = [
      for (var i = 0; i < question.answers.length; i++)
        _buttonLabel(question, i, naming),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 72),
            child: FilledButton(
              style: _buttonStyle(question, i),
              onPressed: _session.revealing ? null : () => _answerButton(i),
              child: Text(
                labels[i],
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
      ],
    );
  }

  String _buttonLabel(Question question, int index, NoteNaming naming) {
    // `name-note` guarda as letras cruas (`C`…`B`); mostra o nome.
    if (widget.spec is NameNoteSpec) {
      final raw = question.answers[index];
      final pitch = Pitch.tryParse('${raw}4') ?? Pitch.parse('C4');
      return noteLabel(pitch, naming);
    }
    return question.answers[index];
  }

  ButtonStyle? _buttonStyle(Question question, int index) {
    final correct = question.correct;
    if (_session.revealing && correct != null && index == correct) {
      return FilledButton.styleFrom(
        backgroundColor: widget.settings.highlightColor,
      );
    }
    if (_wrongButton == index) {
      return FilledButton.styleFrom(backgroundColor: kBadColor);
    }
    return null;
  }
}
