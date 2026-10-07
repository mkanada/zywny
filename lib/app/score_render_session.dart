// R09: a gravura da partitura aberta — pedir o render, a fila de renders,
// a transposição com que foi gravada, o tamanho da caixa e o layout do
// hino. Saiu de `_ScoreHomePageState` (achado 5 da revisão); a tela ouve a
// sessão e, a cada documento novo ([ScoreRenderSession.onDocument]), monta
// o que toca.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:score_bridge/score_bridge.dart' show VsbDocument;

import 'package:zywny_library/piece.dart';

import 'package:zywny_audio/performance_track.dart';

import 'package:zywny_music/transposition.dart';

import '../render/layout_options.dart';
import '../render/score_renderer.dart';
import '../settings/app_settings.dart';
import '../settings/effective_transposition.dart';
import '../settings/piece_settings.dart';

/// Uma gravura nova chegou: [document] e a [track] tocável dela. A sessão
/// já trocou o seu estado (documento, transposição, página) quando chama.
typedef ScoreDocumentCallback = void Function(
  VsbDocument document,
  PerformanceTrack track,
);

/// A gravura da partitura aberta e o que muda nela: o tamanho da caixa
/// ([setBox]), o layout deste hino e o tom (fase Q).
///
/// Um render por vez: o que for pedido durante um fica na fila e sai, um
/// só, quando ele acaba, com as opções da hora. A página anterior continua
/// na tela enquanto isso.
class ScoreRenderSession extends ChangeNotifier {
  ScoreRenderSession({
    required ScoreRenderer renderer,
    required Uint8List scoreXml,
    required Piece piece,
    required AppSettings settings,
    required PieceSettings stored,
    required this.name,
    this.phone = false,
    this.debugMode = false,
    this.onDocument,
    this.resizeDebounce = const Duration(milliseconds: 400),
  }) : _renderer = renderer, // ignore: prefer_initializing_formals
       _scoreXml = scoreXml, // ignore: prefer_initializing_formals
       _piece = piece, // ignore: prefer_initializing_formals
       _settings = settings, // ignore: prefer_initializing_formals
       _transposeChoice = stored.transpose,
       _layout = stored.layoutOver(initialLayoutValues(phone: phone)),
       _pageFitsBox = stored.pageFitsBox {
    _settings.addListener(_onSettingsChanged);
  }

  final ScoreRenderer _renderer;
  final Uint8List _scoreXml;
  final Piece _piece;
  final AppSettings _settings;

  /// Como a partitura é chamada no status ("13 · Hino").
  final String name;

  /// Celular de verdade: o layout começa com [kPhoneUnit], e uma caixa em
  /// retrato é só o aparelho girando (ver [setBox]).
  final bool phone;

  /// `--debug`: pede ao Verovio o `.vsb` com as opções e a fonte embutidas.
  final bool debugMode;

  /// Chamado a cada gravura nova; ver [ScoreDocumentCallback].
  ScoreDocumentCallback? onDocument;

  /// O respiro entre a caixa mudar e a partitura ser gravada de novo.
  final Duration resizeDebounce;

  bool _disposed = false;

  VsbDocument? _document;
  PerformanceTrack? _track;
  int _pageIndex = 0;
  String _status = 'nenhuma partitura';
  String? _error;
  bool _busy = false;
  bool _renderQueued = false;
  Transposition? _renderedTransposition;
  ({int lowest, int highest})? _originalRange;
  Size? _box;
  Timer? _resizeTimer;
  String? _transposeChoice;
  Map<String, Object> _layout;
  bool _pageFitsBox;

  /// A gravura na tela; `null` até a primeira.
  VsbDocument? get document => _document;

  /// As notas tocáveis de [document].
  PerformanceTrack? get track => _track;

  int get pageIndex => _pageIndex;
  int get pageCount => _document?.pages.length ?? 0;
  String get status => _status;

  /// A última gravação falhou — o celular não tem linha de status, então
  /// o motivo aparece no lugar da partitura.
  String? get error => _error;

  /// Um render em curso.
  bool get busy => _busy;

  /// A transposição com que [document] foi gravado (`null` = no tom
  /// original).
  Transposition? get renderedTransposition => _renderedTransposition;

  /// A faixa da música **original** lida do `midi.json` da última gravura,
  /// em MIDI. Antes da primeira gravura é `null` e vale a do catálogo; com
  /// ela, a direção da transposição é conferida contra o teclado (Q03).
  ({int lowest, int highest})? get originalRange => _originalRange;

  /// A escolha de transposição deste hino: `null` = a pessoa não escolheu
  /// (vale a chave geral), [kTransposeNone] = "Não", ou um intervalo.
  String? get transposeChoice => _transposeChoice;

  /// Opções do Verovio deste hino, por nome (ver `layout_options.dart`).
  Map<String, Object> get layout => _layout;

  /// O layout de um hino em que nada foi mexido.
  Map<String, Object> get layoutDefaults => initialLayoutValues(phone: phone);

  /// Se a página sai da caixa da partitura ou de `pageWidth`/`pageHeight`.
  bool get pageFitsBox => _pageFitsBox;

  /// A transposição com que este hino abre agora: a escolha dele, ou a
  /// chave geral. `null` = o tom original.
  Transposition? get transposition => transpositionFor(_transposeChoice);

  /// A transposição que [choice] daria a este hino.
  Transposition? transpositionFor(String? choice) {
    final range = _originalRange;
    return effectiveTransposition(
      _piece,
      PieceSettings(transpose: choice),
      _settings,
      lowest: range?.lowest ?? kCatalogLowestMidi,
      highest: range?.highest ?? kCatalogHighestMidi,
    );
  }

  /// "Sem acidentes" para este hino; `null` sem armadura ou já em Dó.
  Transposition? get noAccidentals {
    final fifths = _piece.fifths;
    if (fifths == null) return null;
    final range = _originalRange;
    return Transposition.toNoAccidentals(
      fifths,
      lowest: range?.lowest ?? kCatalogLowestMidi,
      highest: range?.highest ?? kCatalogHighestMidi,
    );
  }

  /// Paper size, in tenths of a millimetre, that makes one device pixel one
  /// unit — i.e. the page is engraved at 254 dpi and drawn 1:1, which is the
  /// configuration `compare` measured against the reference SVG. Anything
  /// larger would show the notation shrunk, pushing stroke widths below a
  /// pixel (a 0.13 mm staff line needs ~7.7 px/mm to survive).
  Size? get fittedPage {
    final box = _box;
    if (box == null) return null;
    return Size(
      box.width
          .round()
          .clamp(kVerovioMinPageWidth, kVerovioMaxPageWidth)
          .toDouble(),
      box.height
          .round()
          .clamp(kVerovioMinPageHeight, kVerovioMaxPageHeight)
          .toDouble(),
    );
  }

  int get _pageWidth =>
      _pageFitsBox ? fittedPage!.width.round() : _layout['pageWidth'] as int;

  int get _pageHeight =>
      _pageFitsBox ? fittedPage!.height.round() : _layout['pageHeight'] as int;

  /// Every option that reaches Verovio for the current state: the page size
  /// plus whatever differs from Verovio's defaults.
  Map<String, Object> get effectiveOptions => {
    'pageWidth': _pageWidth,
    'pageHeight': _pageHeight,
    ...layoutOptionsToSend(_layout),
    'transpose': ?transposition?.interval,
    if (debugMode) 'vsbDebug': true,
  };

  /// Records the score box (device pixels) and re-engraves when it really
  /// changed. Devolve `true` na primeira caixa (o painel de layout, montado
  /// antes dela, ainda não mostra o tamanho da página).
  ///
  /// Chamado do `build` da tela, então nunca avisa os ouvintes na hora: o
  /// render passa por um respiro, também porque arrastar a janela muda a
  /// caixa a cada quadro, e cada uma é um render pela FFI.
  bool setBox(Size devicePx) {
    final previous = _box;
    if (previous == devicePx) return false;
    _box = devicePx;
    // No celular a tela é travada em paisagem, mas abre a partir da
    // biblioteca em retrato: uma caixa mais alta que larga é só o aparelho
    // ainda girando, e gravar a partitura para ela seria trabalho jogado
    // fora (a caixa em paisagem chega logo depois).
    if (phone && devicePx.height > devicePx.width) return previous == null;
    if (_document == null && !_busy) {
      // Nada gravado ainda: a primeira gravura sai assim que há caixa.
      _resizeTimer?.cancel();
      _resizeTimer = Timer(Duration.zero, render);
      return previous == null;
    }
    // A fixed page size does not depend on the box, so a resize has nothing
    // to re-engrave.
    if (previous == null || !_pageFitsBox) return previous == null;
    // 2% of slack: a one-pixel wobble is not worth re-engraving the piece.
    final changed =
        (previous.width - devicePx.width).abs() / previous.width > 0.02 ||
        (previous.height - devicePx.height).abs() / previous.height > 0.02;
    if (!changed) return false;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(resizeDebounce, render);
    return false;
  }

  /// A página que a vista mostra mudou.
  void setPage(int target) {
    if (pageCount == 0) return;
    _pageIndex = target;
    _status = pageCount > 1 ? 'página ${target + 1} de $pageCount' : 'pronto ✓';
    notifyListeners();
  }

  /// Uma opção de layout mudou (o slider andando): só o valor; a partitura
  /// é gravada de novo em [render], quando a mudança assenta.
  void setLayoutValue(String key, Object value) {
    _layout = {..._layout, key: value};
    notifyListeners();
  }

  void setPageFitsBox(bool value) {
    _pageFitsBox = value;
    notifyListeners();
  }

  /// Volta ao layout padrão do app — só neste hino. Não grava de novo.
  void resetLayout() {
    _layout = layoutDefaults;
    _pageFitsBox = true;
    notifyListeners();
  }

  /// Guarda a escolha de tom ([transposeChoice]) e grava a partitura de
  /// novo se o tom mudou. Devolve `false` se a escolha já era essa.
  bool chooseTranspose(String choice) {
    if (choice == _transposeChoice) return false;
    _transposeChoice = choice;
    notifyListeners();
    // Mesmo tom (ex.: "Não" quando a chave geral já está desligada): só
    // guarda a escolha, a partitura é a mesma.
    if (transposition != _renderedTransposition) unawaited(render());
    return true;
  }

  /// "Abrir as músicas já sem acidentes" mudou e este hino não tem escolha
  /// própria: a partitura é gravada de novo no outro tom.
  void _onSettingsChanged() {
    if (_document != null && transposition != _renderedTransposition) {
      unawaited(render());
    }
  }

  /// Grava a partitura com as opções de agora e a mostra. A página anterior
  /// fica na tela enquanto isso, para comparar o efeito de uma opção no
  /// mesmo zoom. Com um render em curso, entra na fila.
  Future<void> render() async {
    if (_box == null || _disposed) return;
    if (_busy) {
      _renderQueued = true;
      return;
    }

    final pageWidth = _pageWidth;
    final pageHeight = _pageHeight;
    final transposition = this.transposition;
    // A página vai à parte, em ScoreRenderRequest.
    final options = effectiveOptions
      ..remove('pageWidth')
      ..remove('pageHeight');

    _busy = true;
    _error = null;
    _status = 'renderizando $name ($pageWidth×$pageHeight)…';
    notifyListeners();

    var wrongDirection = false;
    try {
      final watch = Stopwatch()..start();
      final rendered = await _renderer.render(
        ScoreRenderRequest(
          source: _scoreXml,
          fileName: '${_piece.id}.musicxml',
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          options: options,
        ),
      );
      final document = rendered.document;
      debugPrint(
        'ScoreRenderSession: render($name) levou '
        '${watch.elapsedMilliseconds}ms',
      );
      if (_disposed) return;
      // Recusa antes de trocar o player: daqui em diante o estado é trocado
      // aos pedaços e precisa de ao menos uma página.
      if (document.pages.isEmpty) {
        throw StateError('a gravura veio sem páginas');
      }
      // Com a faixa real da música, a direção da transposição pode mudar (o
      // hino passaria do teclado): nesse caso grava de novo, no fim.
      _originalRange = _rangeOf(document, transposition) ?? _originalRange;
      wrongDirection = this.transposition != transposition;
      final track = PerformanceTrack.fromDocument(document);
      _document = document;
      _track = track;
      _renderedTransposition = transposition;
      // New options reflow the score: the page we were on may not exist
      // any more.
      _pageIndex = _pageIndex.clamp(0, document.pages.length - 1);
      _status = document.pages.length > 1
          ? 'página ${_pageIndex + 1} de ${document.pages.length}'
          : 'carregada ✓';
      if (rendered.debugCopyPath case final path?) {
        _status = '$_status — .vsb salvo em $path';
      }
      _busy = false;
      onDocument?.call(document, track);
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _status = 'erro: $e';
      _error = '$e';
      _busy = false;
      notifyListeners();
    }

    if (!_disposed && (_renderQueued || wrongDirection)) {
      _renderQueued = false;
      unawaited(render());
    }
  }

  /// A nota mais grave e a mais aguda da música **original** em [document],
  /// que foi gravado com [transposition] (as alturas do `midi.json` já saem
  /// transpostas). `null` sem notas.
  static ({int lowest, int highest})? _rangeOf(
    VsbDocument document,
    Transposition? transposition,
  ) {
    final notes = document.midi?.notes;
    if (notes == null || notes.isEmpty) return null;
    final shift = transposition?.semitones ?? 0;
    return (
      lowest: notes.map((n) => n.pitch).reduce(math.min) - shift,
      highest: notes.map((n) => n.pitch).reduce(math.max) - shift,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _resizeTimer?.cancel();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
