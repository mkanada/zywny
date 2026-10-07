// O que a tela de partitura (`ScoreHomePage`) precisa para abrir num teste
// sem tocar em nada nativo: um gravador que devolve uma partitura pronta e
// um `OpenedPiece` com os recursos que a biblioteca compartilharia.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_bridge/score_bridge.dart' show VsbDocument;
import 'package:zywny/app/library_screen.dart';
import 'package:zywny_library/piece.dart';
import 'package:zywny_midi/midi_device_manager.dart';
import 'package:zywny/render/score_renderer.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/settings/piece_settings.dart';
import 'package:zywny/trail/trail_progress.dart';

/// Guarda as opções de cada gravação pedida e devolve sempre a mesma
/// partitura pronta (`test/fixtures/erik-satie.vsb`), sem o Verovio: o que
/// importa é o que a tela pede.
class RecordingRenderer implements ScoreRenderer {
  RecordingRenderer()
    : _document = VsbDocument.fromBytes(
        File('test/fixtures/erik-satie.vsb').readAsBytesSync(),
      );

  final VsbDocument _document;
  final List<Map<String, Object>> options = [];

  /// Devolvido no lugar da gravura do fixture enquanto não for `null`.
  VsbDocument? next;

  /// A gravura do fixture sem nenhuma página.
  VsbDocument get empty => VsbDocument(
    manifest: _document.manifest,
    glyphs: _document.glyphs,
    pages: const [],
  );

  @override
  Future<RenderedScore> render(ScoreRenderRequest request) async {
    options.add(request.options);
    return RenderedScore(next ?? _document);
  }
}

/// Um hino de catálogo para os testes da tela.
Piece fakePiece({
  int? number = 13,
  String title = 'Hino',
  String composer = 'Autor',
  int? fifths,
}) => Piece(
  number: number,
  title: title,
  composer: composer,
  fifths: fifths,
  titleKey: foldForSearch(title),
  composerKey: foldForSearch(composer),
  searchKey: foldForSearch('${number ?? ''} $title'),
);

/// Um [OpenedPiece] como o que a biblioteca passa à tela. O que não vier
/// do teste é criado aqui — configurações (os padrões, como numa instalação
/// nova), progresso da trilha e gerenciador MIDI — e é descartado aqui
/// também, num `addTearDown`: chame dentro do teste. O que o teste passar é
/// dele para descartar.
///
/// Precisa das plataformas falsas de MIDI e de `SharedPreferences`
/// instaladas (o `setUp` de cada arquivo de teste).
OpenedPiece fakeOpenedPiece({
  Piece? piece,
  AppSettings? appSettings,
  PieceSettings pieceSettings = const PieceSettings(),
  ValueChanged<PieceSettings>? onPieceSettingsChanged,
  TrailProgressStore? trailProgress,
  PracticeScoreCallback? onPracticeScore,
}) {
  final settings = appSettings ?? AppSettings();
  final trail = trailProgress ?? TrailProgressStore();
  final midi = MidiDeviceManager();
  addTearDown(() {
    if (appSettings == null) settings.dispose();
    if (trailProgress == null) trail.dispose();
    midi.dispose();
  });
  return OpenedPiece(
    piece: piece ?? fakePiece(),
    scoreXml: Uint8List(1),
    midiDeviceManager: midi,
    onPracticeScore: onPracticeScore ?? (_, _) {},
    appSettings: settings,
    pieceSettings: pieceSettings,
    onPieceSettingsChanged: onPieceSettingsChanged ?? (_) {},
    trailProgress: trail,
  );
}
