// R09: a gravura sem a tela — a fila de renders e o respiro da caixa.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart' show VsbDocument;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/app/score_render_session.dart';
import 'package:zywny/render/score_renderer.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/settings/piece_settings.dart';

import 'support/score_page_fakes.dart';

/// Segura cada render até o teste soltar ([release]); guarda o pedido.
class _GatedRenderer implements ScoreRenderer {
  _GatedRenderer()
    : document = VsbDocument.fromBytes(
        File('test/fixtures/erik-satie.vsb').readAsBytesSync(),
      );

  final VsbDocument document;
  final List<ScoreRenderRequest> requests = [];
  final List<Completer<RenderedScore>> _pending = [];

  int get waiting => _pending.length;

  @override
  Future<RenderedScore> render(ScoreRenderRequest request) {
    requests.add(request);
    final c = Completer<RenderedScore>();
    _pending.add(c);
    return c.future;
  }

  /// Solta o render mais antigo, com [doc] ou a partitura do fixture.
  Future<void> release([VsbDocument? doc]) async {
    _pending.removeAt(0).complete(RenderedScore(doc ?? document));
    await pumpEventQueue();
  }
}

void main() {
  late AppSettings settings;
  late _GatedRenderer renderer;
  late ScoreRenderSession session;
  late List<VsbDocument> shown;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = AppSettings();
    renderer = _GatedRenderer();
    shown = [];
    session = ScoreRenderSession(
      renderer: renderer,
      scoreXml: Uint8List(1),
      piece: fakePiece(),
      settings: settings,
      stored: const PieceSettings(),
      name: '13 · Hino',
      resizeDebounce: const Duration(milliseconds: 20),
      onDocument: (document, track) => shown.add(document),
    );
  });

  tearDown(() {
    session.dispose();
    settings.dispose();
  });

  /// A primeira caixa e a primeira gravura, já mostrada.
  Future<void> firstRender() async {
    expect(session.setBox(const Size(1000, 700)), isTrue);
    await pumpEventQueue();
    expect(renderer.waiting, 1);
    await renderer.release();
    expect(session.document, isNotNull);
  }

  test('a primeira caixa pede a primeira gravura, que vai à tela', () async {
    expect(session.status, 'nenhuma partitura');
    await firstRender();
    expect(shown, [session.document]);
    expect(session.track, isNotNull);
    expect(session.busy, isFalse);
    expect(renderer.requests.single.pageWidth, 1000);
    expect(renderer.requests.single.pageHeight, 700);
  });

  test('dois pedidos durante um render dão um render só depois, com as '
      'opções da hora', () async {
    await firstRender();

    unawaited(session.render());
    expect(session.busy, isTrue);
    session.setLayoutValue('unit', 6.0);
    unawaited(session.render());
    session.setLayoutValue('unit', 7.5);
    unawaited(session.render());
    expect(renderer.waiting, 1, reason: 'um render por vez');

    await renderer.release();
    expect(renderer.waiting, 1, reason: 'a fila sai num render só');
    expect(renderer.requests.last.options['unit'], 7.5);

    await renderer.release();
    expect(renderer.waiting, 0);
    expect(renderer.requests, hasLength(3));
    expect(session.busy, isFalse);
  });

  test('a caixa: tremida de 1% não grava; duas mudanças seguidas dão uma '
      'gravura, depois do respiro', () async {
    await firstRender();

    expect(session.setBox(const Size(1005, 700)), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(renderer.waiting, 0);

    session.setBox(const Size(900, 700));
    session.setBox(const Size(800, 700));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(renderer.waiting, 0, reason: 'ainda no respiro');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(renderer.waiting, 1);
    expect(renderer.requests.last.pageWidth, 800);
  });

  test('página fixa: mudar a caixa não grava de novo', () async {
    await firstRender();
    session.setPageFitsBox(false);
    session.setBox(const Size(600, 500));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(renderer.waiting, 0);
  });

  test('gravura sem páginas: erro, e a partitura de antes continua', () async {
    await firstRender();
    final before = session.document;

    unawaited(session.render());
    await renderer.release(
      VsbDocument(
        manifest: renderer.document.manifest,
        glyphs: renderer.document.glyphs,
        pages: const [],
      ),
    );
    expect(session.error, contains('sem páginas'));
    expect(session.document, same(before));
    expect(shown, hasLength(1));
    expect(session.busy, isFalse);
  });

  test('descartada, a sessão não grava nem avisa', () async {
    session.setBox(const Size(1000, 700));
    session.dispose();
    await pumpEventQueue();
    expect(renderer.waiting, 0);
    // O `tearDown` descarta de novo: uma sessão nova no lugar.
    session = ScoreRenderSession(
      renderer: renderer,
      scoreXml: Uint8List(1),
      piece: fakePiece(),
      settings: settings,
      stored: const PieceSettings(),
      name: 'x',
    );
  });
}
