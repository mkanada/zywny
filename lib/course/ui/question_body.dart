// I07 — corpo da rodada de perguntas: a pergunta atual (nome grande,
// partitura com destaque ou texto da `choice`) e os botões grandes.
//
// Sem teclado conectado, `name-note`, `count-beats` e `choice` abrem e
// rodam; `find-key` pede o teclado (a porta é da `ExerciseScreen`).
// Teclado do computador também responde no desktop/Web (1–7 e C–B).
// E07 — `listen-score`: cada pergunta tem a sua partitura, a frase toca
// sozinha e, depois da resposta, a revelação mostra o que mudou.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:score_bridge/score_bridge.dart';

import 'package:zywny_audio/sound_engine.dart';
import 'package:zywny_midi/midi_input_service.dart';

import '../../render/score_renderer.dart';
import '../../settings/app_settings.dart';
import '../../ui/theme.dart';
import '../exercise/cue_player.dart';
import '../exercise/exercise_round.dart';
import '../exercise/question_session.dart';

import 'package:zywny_course_format/course_files.dart';
import 'package:zywny_course_format/course_model.dart';

import 'package:zywny_music/note_name.dart';
import 'package:zywny_music/note_names.dart';

import '../score/lesson_score.dart';
import 'course_chrome.dart';
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
    this.ensureEngine,
  });

  final ExerciseSpec spec;
  final QuestionRound round;
  final CourseFiles files;
  final AppSettings settings;
  final MidiInputService midiInput;
  final ScoreRenderer Function() rendererFactory;
  final ValueChanged<RoundResult> onDone;

  /// Abre o som (`listen-note`); `null` = sem som.
  final Future<SoundEngine?> Function()? ensureEngine;

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
  String? _scoreError;

  /// Os bytes da partitura pedida por último, e os da partitura desenhada
  /// (`_document`). São diferentes enquanto a pergunta nova ainda carrega.
  Uint8List? _requestedBytes;
  Uint8List? _documentBytes;

  SoundEngine? _engine;
  bool _engineStarted = false;
  bool _noSound = false;
  int? _playedIndex;
  Timer? _cueTimer;

  /// `listen-score` (E07): a pergunta em revelação, ou `null` quando a tela
  /// mostra a pergunta da sessão.
  int? _reviewIndex;

  /// A última pergunta já revelada (para não revelar duas vezes).
  int _reviewedUpTo = -1;

  bool get _isFindKey => widget.spec is FindKeySpec;
  bool get _isChoice => widget.spec is ChoiceSpec;
  bool get _isListenScore => widget.spec is ListenScoreSpec;
  bool get _isListen =>
      widget.spec is ListenNoteSpec ||
      widget.spec is ListenIntervalSpec ||
      _isListenScore;

  /// A pergunta mostrada: a da revelação, se houver; senão a da sessão.
  Question? get _shown => _reviewIndex != null
      ? widget.round.questions[_reviewIndex!]
      : _session.current;

  /// Respostas pelo teclado MIDI: `find-key` e `listen-note` com
  /// `input: keyboard`.
  bool get _usesKeyboard =>
      _isFindKey ||
      (widget.spec is ListenNoteSpec &&
          (widget.spec as ListenNoteSpec).input == AnswerInput.keyboard);

  @override
  void initState() {
    super.initState();
    if (_usesKeyboard) {
      _midiSub = widget.midiInput.notes.listen(_onMidi);
    }
    final limit = widget.spec.pass.timeLimit;
    if (limit != null) {
      _tickTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        // Na revelação do `listen-score` o tempo para (E07).
        if (_reviewIndex != null) return;
        // O estouro e o fim da revelação mudam a pergunta: o destaque da
        // partitura segue (sem isto a nota da vez ficava na pergunta velha
        // e a resposta certa da nota destacada contava como erro) e, se era
        // a última, a rodada termina (antes ficava girando para sempre).
        if (_session.tick()) _afterAnswer();
      });
    }
    if (_isListen) _scheduleCue(const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _midiSub?.cancel();
    _tickTimer?.cancel();
    _flashTimer?.cancel();
    _cueTimer?.cancel();
    _engine?.allNotesOff();
    _controller?.dispose();
    _viewController?.dispose();
    super.dispose();
  }

  /// Toca a pergunta atual depois de [delay].
  void _scheduleCue(Duration delay) {
    _cueTimer?.cancel();
    _cueTimer = Timer(delay, () => unawaited(_playCurrent()));
  }

  /// Toca a pergunta atual (de novo, se já tocou): os sons do `listen-note`
  /// ou a frase do `listen-score`.
  Future<void> _playCurrent() async {
    final question = _session.current;
    if (question == null ||
        (question.sound.isEmpty && question.compare == null)) {
      return;
    }
    final index = _session.index;
    final engine = await _openEngine();
    if (engine == null) return;
    // A pergunta mudou enquanto o motor abria: quem mudou já agendou.
    if (_session.index != index) return;
    final compare = question.compare;
    if (compare != null) {
      playTimed(engine, compare.played);
    } else {
      playCues(engine, question.sound);
    }
    _playedIndex = index;
  }

  /// O motor de som, aberto e iniciado na primeira vez; `null` quando não há
  /// saída de som (aí [_noSound] mostra o aviso).
  Future<SoundEngine?> _openEngine() async {
    var engine = _engine;
    if (engine == null) {
      engine = await widget.ensureEngine?.call();
      if (!mounted) return null;
      if (engine == null) {
        setState(() => _noSound = true);
        return null;
      }
      _engine = engine;
    }
    if (!_engineStarted) {
      _engineStarted = true;
      try {
        await engine.start();
      } on Object {
        // Já aberto: segue.
      }
      if (!mounted) return null;
    }
    if (_noSound) setState(() => _noSound = false);
    return engine;
  }

  /// Uma das versões da frase na revelação ("o que soou" ou "o escrito").
  Future<void> _playReview(List<TimedNote> notes) async {
    final engine = await _openEngine();
    if (engine == null || !mounted) return;
    playTimed(engine, notes);
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
      // Mais tempo que o botão errado: o aluno tira os olhos do teclado
      // para ler qual tecla tocou.
      _flashTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _wrongPitch = null);
      });
      setState(() {});
    }
  }

  void _answerButton(int index) {
    if (_session.done || _session.revealing || _reviewIndex != null) return;
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
    // `listen-score`: a pergunta que acabou (certa ou estourada) é revelada
    // antes da próxima. A sessão já avançou o índice, então a revelada é a
    // anterior à atual (ou a última, quando acabou).
    if (_isListenScore && _session.index - 1 > _reviewedUpTo) {
      _cueTimer?.cancel();
      _engine?.allNotesOff();
      setState(() => _reviewIndex = _session.index - 1);
      _applyHighlight();
      return; // `onDone` e a próxima pergunta esperam o "Próxima".
    }
    if (_session.done) {
      _tickTimer?.cancel();
      _cueTimer?.cancel();
      widget.onDone(_session.result());
    } else {
      if (_isListen && _session.index != _playedIndex) {
        // Espera a tecla do aluno soar antes da próxima pergunta.
        _scheduleCue(const Duration(milliseconds: 700));
      }
      setState(() {});
    }
  }

  /// "Próxima" (ou "Terminar"): sai da revelação e segue para a próxima
  /// pergunta.
  void _closeReview() {
    _reviewedUpTo = _reviewIndex!;
    setState(() => _reviewIndex = null);
    if (_session.done) {
      _tickTimer?.cancel();
      widget.onDone(_session.result());
      return;
    }
    _session.restartClock();
    _applyHighlight();
    _scheduleCue(const Duration(milliseconds: 400));
  }

  /// Teclas na revelação: Enter segue; espaço ou R toca "o que soou"; E toca
  /// "o escrito", quando houve mudança (como o botão).
  KeyEventResult _reviewKey(LogicalKeyboardKey key, Question question) {
    final compare = question.compare!;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _closeReview();
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyR) {
      unawaited(_playReview(compare.played));
    } else if (key == LogicalKeyboardKey.keyE && compare.measure != null) {
      unawaited(_playReview(compare.written));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _applyHighlight() {
    final controller = _controller;
    if (controller == null) return;
    controller.clearAll();
    final review = _reviewIndex;
    if (review != null) {
      // A revelação pinta só as notas que mudaram (E07).
      final changed =
          widget.round.questions[review].compare?.changedIds ??
          const <String>{};
      if (changed.isNotEmpty) {
        controller.setColors({
          for (final id in changed) id: widget.settings.practiceWrongColor,
        });
      }
      return;
    }
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

  /// A partitura de [question] (`listen-score`: a da pergunta; nos outros
  /// tipos, a da rodada). `null` quando não há partitura.
  ({Uint8List bytes, String fileName})? _scoreSourceOf(Question? question) {
    final compare = question?.compare;
    if (compare != null) {
      return (bytes: compare.scoreBytes, fileName: compare.fileName);
    }
    final bytes = widget.round.scoreBytes;
    final fileName = widget.round.fileName;
    if (bytes == null || fileName == null) return null;
    return (bytes: bytes, fileName: fileName);
  }

  /// Desenha a partitura da pergunta mostrada. Chamada a cada build, mas só
  /// pede ao renderizador quando a partitura é outra (E07).
  Future<void> _loadScore(double widthPx) async {
    final source = _scoreSourceOf(_shown);
    if (source == null) return;
    final bytes = source.bytes;
    if (identical(bytes, _requestedBytes)) return;
    _requestedBytes = bytes;
    _scoreError = null;
    try {
      final layout = lessonScoreLayout(widthPx);
      final rendered = await widget.rendererFactory().render(
        ScoreRenderRequest(
          source: bytes,
          fileName: source.fileName,
          pageWidth: layout.pageWidth,
          pageHeight: layout.pageHeight,
          options: layout.options,
        ),
      );
      // A pergunta mudou enquanto desenhava: esta partitura já não serve.
      if (!mounted || !identical(bytes, _requestedBytes)) return;
      final oldController = _controller;
      final oldViewController = _viewController;
      setState(() {
        _document = rendered.document;
        _documentBytes = bytes;
        _controller = ScoreController(document: rendered.document);
        _viewController = ScoreViewController();
      });
      oldController?.dispose();
      oldViewController?.dispose();
      _applyHighlight();
    } on Object catch (e) {
      if (!mounted || !identical(bytes, _requestedBytes)) return;
      setState(() => _scoreError = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewing = _reviewIndex != null;
    if (!reviewing && _session.done) {
      return const Center(child: CircularProgressIndicator());
    }
    final question = _shown!;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_reviewIndex != null) return _reviewKey(event.logicalKey, question);
        // Espaço ou R: "Ouvir de novo" (o botão também fica parado na revelação).
        if (_isListen &&
            !_session.revealing &&
            (event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.keyR)) {
          unawaited(_playCurrent());
          return KeyEventResult.handled;
        }
        final index = _keyToButton(event.logicalKey, question);
        if (index == null) return KeyEventResult.ignored;
        _answerButton(index);
        return KeyEventResult.handled;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final children = <Widget>[];
          if (reviewing) {
            children.add(_reviewPanel(question, constraints));
          } else if (_isFindKey) {
            children.add(_findKeyPrompt(question));
          } else if (_isChoice) {
            children.add(_choicePrompt(question));
          } else if (_isListenScore) {
            children.add(_scorePrompt(question, constraints));
          } else if (_isListen) {
            children.add(_listenPrompt(question));
          } else {
            children.add(_scoreView(constraints));
          }
          // A figura da `choice` (imagem ou partitura pequena).
          if (_isChoice) {
            final figure = _choiceFigure(constraints);
            if (figure != null) children.add(figure);
          }
          children.add(const SizedBox(height: 12));
          if (!_usesKeyboard && !reviewing) {
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
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _wrongMessage(question),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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

  /// "Você tocou Fá — tente de novo." (tecla errada no `find-key`); no
  /// botão errado o próprio botão já diz o que foi tocado.
  String _wrongMessage(Question question) {
    final played = _wrongPitch;
    if (played == null) return 'Tente de novo.';
    final naming = widget.settings.noteNaming;
    final expected = question.expectedPitch;
    final sameName =
        expected != null && (played - expected) % 12 == 0 && played != expected;
    final label = midiLabel(
      played,
      naming,
      withOctave: !question.anyOctave || sameName,
    );
    return sameName
        ? 'Você tocou $label — é a nota certa, em outra oitava.'
        : 'Você tocou $label — tente de novo.';
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
    final label = midiLabel(expected, naming, withOctave: !question.anyOctave);
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

  Widget _listenPrompt(Question question) {
    if (widget.spec is ListenIntervalSpec) return _intervalPrompt();
    final spec = widget.spec as ListenNoteSpec;
    final naming = widget.settings.noteNaming;
    final keyboard = spec.input == AnswerInput.keyboard;
    final reference = spec.reference;
    final expected = question.expectedPitch;
    final how = keyboard
        ? (question.anyOctave
              ? 'Toque a tecla (vale qualquer oitava).'
              : 'Toque a tecla na oitava certa.')
        : 'Escolha o nome.';
    return Column(
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.hearing, size: 56, color: kInkCaption),
        const SizedBox(height: 8),
        Text(
          'Que nota é esta?',
          textAlign: TextAlign.center,
          style: serifDisplay(fontSize: 28),
        ),
        if (reference != null) ...[
          const SizedBox(height: 4),
          Text(
            'Antes soa o ${noteLabel(reference, naming, withOctave: true)}, '
            'de referência.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: kInkCaption),
          ),
        ],
        // Estouro do tempo no teclado: mostra a nota certa.
        if (_session.revealing && keyboard && expected != null) ...[
          const SizedBox(height: 8),
          Text(
            midiLabel(expected, naming, withOctave: !question.anyOctave),
            style: serifDisplay(fontSize: 48)
                .copyWith(color: widget.settings.highlightColor),
          ),
        ],
        const SizedBox(height: 12),
        _listenAgainButton(),
        const SizedBox(height: 8),
        Text(
          how,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: kInkCaption),
        ),
        if (_noSound) _noSoundNote(),
        if (keyboard) ...[
          const SizedBox(height: 8),
          const Icon(Icons.piano, size: 28, color: kInkCaption),
        ],
      ],
    );
  }

  /// O `listen-interval`: ouvir de novo e escolher o nome do intervalo.
  Widget _intervalPrompt() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.hearing, size: 56, color: kInkCaption),
        const SizedBox(height: 8),
        Text(
          'Que intervalo é este?',
          textAlign: TextAlign.center,
          style: serifDisplay(fontSize: 28),
        ),
        const SizedBox(height: 12),
        _listenAgainButton(),
        const SizedBox(height: 8),
        const Text(
          'Escolha o intervalo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: kInkCaption),
        ),
        if (_noSound) _noSoundNote(),
      ],
    );
  }

  /// O `listen-score` (E07): ouve a frase (o acorde e depois a partitura) e
  /// diz em que compasso mudou, ou se soou igual ao escrito.
  Widget _scorePrompt(Question question, BoxConstraints constraints) {
    final spec = widget.spec as ListenScoreSpec;
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          spec.answer == ScoreAnswer.sameDifferent
              ? 'Soou igual ao escrito?'
              : 'Em que compasso soou diferente?',
          textAlign: TextAlign.center,
          style: serifDisplay(fontSize: 26),
        ),
        const SizedBox(height: 4),
        const Text(
          'Primeiro o acorde, depois a partitura.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: kInkCaption),
        ),
        const SizedBox(height: 12),
        _listenAgainButton(),
        if (_noSound) _noSoundNote(),
        const SizedBox(height: 12),
        _scoreView(constraints),
      ],
    );
  }

  /// A revelação do `listen-score` (E07): o título, a frase que diz o que
  /// mudou, a partitura com a nota pintada e os botões para ouvir as duas
  /// versões. "Próxima" segue (ou "Terminar", na última).
  Widget _reviewPanel(Question question, BoxConstraints constraints) {
    final index = _reviewIndex!;
    final compare = question.compare!;
    final changed = compare.measure != null;
    final first = _session.firstTry[index];
    final last = index == widget.round.questions.length - 1;
    final title = first ? 'Certo!' : (changed ? 'Era aqui.' : 'Era igual.');
    final sentence = changed
        ? 'Compasso ${compare.measure! + 1}: ${compare.description}.'
        : 'O que soou foi exatamente o escrito.';
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: serifDisplay(fontSize: 26)
              .copyWith(color: first ? widget.settings.highlightColor : kInk),
        ),
        const SizedBox(height: 4),
        Text(
          sentence,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 12),
        _scoreView(constraints),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => unawaited(_playReview(compare.played)),
              icon: const Icon(Icons.volume_up),
              label: const Text('Ouvir o que soou'),
            ),
            if (changed)
              OutlinedButton.icon(
                onPressed: () => unawaited(_playReview(compare.written)),
                icon: const Icon(Icons.music_note),
                label: const Text('Ouvir o escrito'),
              ),
            FilledButton(
              onPressed: _closeReview,
              child: Text(last ? 'Terminar' : 'Próxima'),
            ),
          ],
        ),
        if (_noSound) _noSoundNote(),
      ],
    );
  }

  /// "Ouvir de novo": repete o som, e fica parado na revelação.
  Widget _listenAgainButton() {
    return FilledButton.tonalIcon(
      onPressed: _session.revealing ? null : () => unawaited(_playCurrent()),
      icon: const Icon(Icons.volume_up),
      label: const Text('Ouvir de novo'),
    );
  }

  Widget _noSoundNote() {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text(
        'Sem som: confira a saída de som nas configurações.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kBadColor,
        ),
      ),
    );
  }

  Widget _choicePrompt(Question question) {
    return MarkdownView(text: question.prompt ?? '', files: widget.files);
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
        ? lessonScorePaperPx(context, constraints.maxWidth)
        : 1800.0;
    _loadScore(widthPx);
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
    // Só mostra a partitura desenhada para a pergunta atual: enquanto a nova
    // carrega, fica o quadro de espera (E07).
    final current = identical(_scoreSourceOf(_shown)?.bytes, _documentBytes);
    final document = current ? _document : null;
    final controller = current ? _controller : null;
    final viewController = current ? _viewController : null;
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
    final height = (total < 120.0 ? 120.0 : total).clamp(120.0, 420.0);
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
              child: Text(labels[i], style: const TextStyle(fontSize: 18)),
            ),
          ),
      ],
    );
  }

  String _buttonLabel(Question question, int index, NoteNaming naming) {
    // `name-note` e `listen-note` guardam as letras cruas (`C`…`B`); mostra o
    // nome.
    if (widget.spec is NameNoteSpec || widget.spec is ListenNoteSpec) {
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
