// Snapshots das telas no celular (`docs/telas/celular/`): percorre o app de
// verdade num aparelho ou emulador Android e fotografa cada tela — a
// biblioteca em retrato e a partitura em paisagem, como o aluno as vê.
//
// Não é um teste de regressão (não compara nada): é o roteiro que gera as
// imagens. Rode com `just telas` (ver o justfile); quem grava os PNGs é o
// `test_driver/telas_celular.dart`, do lado do computador.
//
// Duas passagens:
//   1. primeiro uso — sem histórico e sem teclado MIDI;
//   2. com histórico e teclado — o teclado é falso ([_FakeKeyboard]): entra
//      no lugar do plugin MIDI e toca as notas que a etapa espera, para
//      chegar às telas de treino e aos resumos.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart'
    show MidiCommand;
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zywny/course/built_in_course.dart';
import 'package:zywny/course/course_progress.dart';
import 'package:zywny/course/ui/exercise_card.dart';
import 'package:zywny/library/library_keys.dart';
import 'package:zywny/library/library_screen.dart';
import 'package:zywny/library/library_store.dart';
import 'package:zywny/library/piece.dart';
import 'package:zywny/main.dart';
import 'package:zywny/music/performance_track.dart';
import 'package:zywny/practice/count_in_overlay.dart';
import 'package:zywny/practice/hand.dart';
import 'package:zywny/settings/general_settings_panel.dart';
import 'package:zywny/trail/trail_plan.dart';
import 'package:zywny/trail/trail_stage.dart';
import 'package:zywny/trail/trail_widgets.dart';
import 'package:zywny/ui/phone_chrome.dart';

/// O hino do roteiro: música de Beethoven (domínio público), nível 1 e
/// logo no começo da lista.
const _kHymnId = '005';
const _kHymnTitle = 'Jubilosos Te Adoramos';

/// Teclado MIDI de mentira: um dispositivo com fio que aparece quando
/// [plug] é chamado e "toca" o que o roteiro mandar.
class _FakeKeyboard extends MidiCommandPlatform {
  final MidiDevice _device = MidiDevice(
    'telas-usb-1',
    'Teclado digital',
    MidiDeviceType.serial,
    false,
  );
  final StreamController<MidiPacket> _packets =
      StreamController<MidiPacket>.broadcast();
  final StreamController<MidiSetupChange> _setup =
      StreamController<MidiSetupChange>.broadcast();
  bool _plugged = false;

  void plug() {
    _plugged = true;
    _setup.add(MidiSetupChange.deviceAppeared);
  }

  void unplug() {
    _plugged = false;
    _device.connected = false;
    _setup.add(MidiSetupChange.deviceDisappeared);
  }

  void noteOn(int pitch, [int velocity = 80]) => _send([0x90, pitch, velocity]);

  void noteOff(int pitch) => _send([0x80, pitch, 0]);

  void _send(List<int> bytes) =>
      _packets.add(MidiPacket(Uint8List.fromList(bytes), 0, _device));

  @override
  Future<List<MidiDevice>?> get devices async =>
      _plugged ? [_device] : const <MidiDevice>[];

  @override
  Future<void> connectToDevice(
    MidiDevice device, {
    List<MidiPort>? ports,
  }) async {
    device.connected = true;
  }

  @override
  void disconnectDevice(MidiDevice device) => device.connected = false;

  @override
  void teardown() {}

  @override
  void sendData(Uint8List data, {int? timestamp, String? deviceId}) {}

  @override
  Stream<MidiPacket>? get onMidiDataReceived => _packets.stream;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => _setup.stream;
}

final _keyboard = _FakeKeyboard();
final _shotKey = GlobalKey();

/// Nome do arquivo -> PNG em base64, na ordem em que foram tiradas. Vai
/// para o computador pelo `reportData` do binding.
final Map<String, String> _shots = {};

/// Plano da trilha do hino do roteiro, lido da gaveta na 1ª passagem: a 2ª
/// monta o histórico com os ids e o total de verdade.
TrailPlan? _plan;

bool _has(Finder finder) => finder.evaluate().isNotEmpty;

bool _landscape(WidgetTester tester) =>
    tester.view.physicalSize.width > tester.view.physicalSize.height;

/// `--dart-define=ZYWNY_TELAS_ORIENTACAO=retrato|paisagem` fotografa todas
/// as telas numa orientação só, mesmo as que o app trava na outra (a
/// partitura só vira paisagem): o tamanho da tela é fixado no Flutter, não
/// no Android. Vazio, cada tela sai na orientação em que o app a mostra.
const _kForcedOrientation = String.fromEnvironment('ZYWNY_TELAS_ORIENTACAO');

/// Na passagem em retrato, as telas da partitura não saem (ver
/// [_forceOrientation]).
bool _skipShots = false;

/// A tela está na orientação [landscape] — sempre, com a orientação forçada.
bool _oriented(WidgetTester tester, {required bool landscape}) =>
    _kForcedOrientation.isNotEmpty || _landscape(tester) == landscape;

/// Fixa o tamanho da tela na orientação forçada (nada, sem ela). As barras
/// do sistema viram margens fixas: a de status no topo em retrato; nada em
/// paisagem, como a partitura imersiva.
void _forceOrientation(WidgetTester tester, {bool score = false}) {
  if (_kForcedOrientation.isEmpty) return;
  final size = tester.view.physicalSize;
  final long = size.longestSide;
  final short = size.shortestSide;
  final dpr = tester.view.devicePixelRatio;
  // A partitura no celular só existe em paisagem (não grava a página numa
  // caixa em retrato): na passagem em retrato ela abre deitada e não é
  // fotografada.
  _skipShots = score && _kForcedOrientation == 'retrato';
  final portrait = _kForcedOrientation == 'retrato' && !score;
  tester.view.physicalSize = portrait ? Size(short, long) : Size(long, short);
  final padding = portrait
      ? FakeViewPadding(top: 24 * dpr, bottom: 16 * dpr)
      : FakeViewPadding.zero;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
}

/// Deixa o app andar por [ms] de relógio de verdade, quadro a quadro.
Future<void> _wait(WidgetTester tester, [int ms = 600]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  do {
    await tester.pump(const Duration(milliseconds: 40));
  } while (DateTime.now().isBefore(end));
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  required String what,
  int seconds = 60,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ready()) {
    if (DateTime.now().isAfter(end)) fail('não chegou a: $what');
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder, {int ms = 700}) async {
  await _until(tester, () => _has(finder), what: '$finder', seconds: 20);
  await tester.tap(finder.first, warnIfMissed: false);
  await _wait(tester, ms);
}

/// Abre o exercício [title] pelo botão do próprio cartão (o "Começar"
/// genérico pegaria o primeiro da lista, que é de outro exercício).
Future<void> _startExercise(WidgetTester tester, String title) async {
  await _scrollTo(tester, find.text(title));
  final cards = find.byType(ExerciseCard);
  final n = cards.evaluate().length;
  for (var i = 0; i < n; i++) {
    final card = cards.at(i);
    if (find
        .descendant(of: card, matching: find.text(title))
        .evaluate()
        .isNotEmpty) {
      await _tap(
        tester,
        find.descendant(of: card, matching: find.text('Começar')),
      );
      return;
    }
  }
  fail('cartão de exercício não encontrado: $title');
}

/// Rola a lista da tela até [finder] aparecer. O `Scrollable` é o mais
/// externo (a lição e o curso têm roláveis aninhados e o padrão do
/// `scrollUntilVisible` exige um só); se o mesmo texto sair duas vezes,
/// vale o primeiro. Sem rolável na tela, falha explicando o que procurava.
Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, [
  double dy = 400,
]) async {
  if (find.byType(Scrollable).evaluate().isEmpty) {
    fail('sem rolável na tela ao procurar $finder');
  }
  final n = finder.evaluate().length;
  // Só mira o primeiro quando há duplicada: com zero, o original deixa o
  // `dragUntilVisible` rolar até construir a linha (`ListView.builder`).
  final target = n == 1 ? finder : (n > 1 ? finder.first : finder);
  final scrollable = find.byType(Scrollable).first;
  try {
    await tester.scrollUntilVisible(target, dy, scrollable: scrollable);
  } on StateError {
    // A tela voltou rolada para além do alvo (a lição guarda a posição):
    // procura no outro sentido.
    await tester.scrollUntilVisible(target, -dy, scrollable: scrollable);
  }
  await _wait(tester, 800);
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (_skipShots) return;
  await tester.pump();
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final png = await tester.runAsync(() async {
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  _shots[name] = base64Encode(png!);
  debugPrint('tela: $name');
}

/// Escreve [text] na busca como o teclado virtual faria: o `enterText`
/// não chega ao campo no aparelho (o binding de integração não registra o
/// teclado de teste), e o `onChanged` da biblioteca só ouve digitação.
Future<void> _typeSearch(WidgetTester tester, String text) async {
  tester
      .state<EditableTextState>(find.byType(EditableText).first)
      .updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
  await tester.pump();
}

Future<void> _launch(WidgetTester tester, {required bool splash}) =>
    tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: MyApp(splash: splash),
      ),
    );

Future<void> _libraryReady(WidgetTester tester) async {
  await _until(
    tester,
    () =>
        _oriented(tester, landscape: false) &&
        _has(find.textContaining(' hinos')),
    what: 'biblioteca',
  );
  // As fontes do google_fonts chegam pela rede na primeira vez.
  await _wait(tester, 3000);
}

/// Toca na pastilha de ordenação [label], rolando a fila até ela (as
/// últimas ficam fora da tela, e a fila só constrói o que está perto).
Future<void> _sortBy(WidgetTester tester, String label) async {
  final chip = find.textContaining(label);
  final row = find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    ),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    chip,
    label == 'Número' ? -120 : 120,
    scrollable: row,
  );
  await _wait(tester, 300);
  await _tap(tester, chip);
}

Future<void> _openPieceFromList(WidgetTester tester) async {
  // Em paisagem a lista da biblioteca fica sem altura (o topo é fixo): o
  // toque no hino só cabe em retrato.
  if (_kForcedOrientation == 'paisagem') {
    final size = tester.view.physicalSize;
    tester.view.physicalSize = Size(size.shortestSide, size.longestSide);
    await _wait(tester, 800);
  }
  await _until(tester, () => _has(find.text(_kHymnTitle)), what: 'o hino');
  await tester.tap(find.text(_kHymnTitle).last, warnIfMissed: false);
  _forceOrientation(tester, score: true);
}

Future<void> _scoreReady(WidgetTester tester) async {
  await _until(
    tester,
    () =>
        _oriented(tester, landscape: true) &&
        _has(find.byType(ScoreView)) &&
        _has(find.byType(TrailTitleChip)),
    what: 'partitura com a trilha',
    seconds: 90,
  );
  await _wait(tester, 1500);
}

Future<void> _openOptions(WidgetTester tester) async {
  await _tap(tester, find.byTooltip('Mais opções'));
  await _until(
    tester,
    () => _has(find.text('Opções de estudo')),
    what: 'gaveta de opções',
  );
}

/// Um toque no texto da trilha, na barra do título, abre a gaveta com as etapas.
Future<void> _openTrailDrawer(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byType(TrailTitleChip)));
  await _until(
    tester,
    () => _has(find.byType(TrailDrawer)),
    what: 'gaveta da trilha',
    seconds: 20,
  );
  await _wait(tester);
}

/// Toca no item [label] da gaveta de opções, rolando até ele.
Future<void> _optionsItem(WidgetTester tester, String label) async {
  final item = find.text(label);
  await tester.ensureVisible(item.first);
  await _wait(tester, 300);
  await _tap(tester, item);
}

Future<void> _scrollOptions(WidgetTester tester, double dy) async {
  await tester.drag(
    find.descendant(
      of: find.byType(PhoneOptionsDrawer),
      matching: find.byType(SingleChildScrollView),
    ),
    Offset(0, dy),
  );
  await _wait(tester, 500);
}

/// Rola o painel de configurações gerais até a linha [label] (a lista só
/// constrói o que está perto da tela).
Future<void> _settingsRow(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    120,
    scrollable: find
        .descendant(
          of: find.byType(GeneralSettingsPanel),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await _wait(tester, 400);
}

void _popRoute(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();

Future<void> _backToLibrary(WidgetTester tester) async {
  await _tap(tester, find.byTooltip('Voltar à biblioteca'));
  _forceOrientation(tester);
  await _libraryReady(tester);
}

/// Fotografa a contagem no começo de um tempo: o número nasce nítido e
/// some crescendo e desfocando até o tempo seguinte.
Future<void> _shotCountIn(WidgetTester tester, String name) async {
  final opacity = find.descendant(
    of: find.byType(CountInOverlay),
    matching: find.byType(Opacity),
  );
  final end = DateTime.now().add(const Duration(seconds: 8));
  // Passa do primeiro número (o toque no play cai no meio dele)...
  var seenFaded = false;
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 8));
    if (!_has(opacity)) continue;
    final value = tester.widget<Opacity>(opacity.first).opacity;
    if (value < 0.25) seenFaded = true;
    // ...e pega o seguinte assim que ele acende (no celular a opacidade
    // máxima é 0,5 — U09).
    if (seenFaded && value > 0.45) break;
  }
  await _shot(tester, name);
}

bool _summaryOpen() =>
    _has(find.textContaining('Aprovado')) ||
    _has(find.textContaining('Precisa de'));

/// A etapa selecionada, lida da gaveta da trilha (que precisa estar aberta).
TrailStage _selectedStage(WidgetTester tester) {
  final drawer = tester.widget<TrailDrawer>(find.byType(TrailDrawer));
  return drawer.plan.stages.firstWhere((s) => s.id == drawer.selectedId);
}

/// Toca uma etapa do modo espera: os acordes das [staves] dentro do
/// intervalo da etapa, um por vez. No 4º passo erra uma tecla de propósito
/// (e fotografa a nota errada); para quando o resumo abre.
Future<void> _playWaitStage(
  WidgetTester tester,
  TrailStage stage, {
  required Set<int> staves,
  String? wrongNoteShot,
}) async {
  final view = tester.widget<ScoreView>(find.byType(ScoreView));
  final track = PerformanceTrack.fromDocument(view.document);
  final byOnMs = <double, Set<int>>{};
  for (final chord in track.chords(staves: staves)) {
    if (chord.onMs < stage.startMs || chord.onMs >= stage.endMs) continue;
    final pitches = {
      for (final e in chord.notes)
        if (!e.ornament) e.pitch,
    };
    if (pitches.isEmpty) continue;
    byOnMs.putIfAbsent(chord.onMs, () => {}).addAll(pitches);
  }
  final onsets = byOnMs.keys.toList()..sort();
  for (var i = 0; i < onsets.length && !_summaryOpen(); i++) {
    final pitches = byOnMs[onsets[i]]!;
    if (i == 3 && wrongNoteShot != null) {
      final wrong = pitches.first + 1;
      _keyboard.noteOn(wrong);
      await _wait(tester, 400);
      await _shot(tester, wrongNoteShot);
      _keyboard.noteOff(wrong);
      await _wait(tester, 150);
    }
    for (final p in pitches) {
      _keyboard.noteOn(p);
    }
    await _wait(tester, 160);
    for (final p in pitches) {
      _keyboard.noteOff(p);
    }
    await _wait(tester, 160);
  }
}

/// Acompanha a música em tempo real: aperta cada nota das [staves] assim
/// que ela acende na partitura. [skipEvery] deixa passar uma a cada tantas
/// (erros de verdade no resumo); [shots] fotografa aos tantos ms.
Future<void> _playAlong(
  WidgetTester tester, {
  required Set<int> staves,
  required bool Function() stop,
  int maxMs = 60000,
  int skipEvery = 0,
  Map<int, String> shots = const {},
}) async {
  final view = tester.widget<ScoreView>(find.byType(ScoreView));
  final track = PerformanceTrack.fromDocument(view.document);
  final byId = {
    for (final e in track.events)
      if (staves.contains(e.staff) && !e.ornament) e.id: e,
  };
  final sent = <String>{};
  final held = <int, DateTime>{};
  final pending = Map.of(shots);
  final start = DateTime.now();
  var count = 0;
  while (!stop()) {
    final now = DateTime.now();
    final elapsed = now.difference(start).inMilliseconds;
    if (elapsed > maxMs) break;
    for (final id in view.controller!.highlightedIds.toList()) {
      final event = byId[id];
      if (event == null || !sent.add(id)) continue;
      count++;
      if (skipEvery > 0 && count % skipEvery == 0) continue;
      _keyboard.noteOn(event.pitch);
      held[event.pitch] = now;
    }
    held.removeWhere((pitch, at) {
      if (now.difference(at).inMilliseconds < 180) return false;
      _keyboard.noteOff(pitch);
      return true;
    });
    for (final at in pending.keys.toList()) {
      if (elapsed >= at) await _shot(tester, pending.remove(at)!);
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  for (final pitch in held.keys) {
    _keyboard.noteOff(pitch);
  }
}

/// Toca uma rodada de espera do curso (play-notes): os acordes da partitura
/// em ordem, um por vez, até o painel de resultado aparecer.
Future<void> _playCourseWait(WidgetTester tester) async {
  final view = tester.widget<ScoreView>(find.byType(ScoreView));
  final track = PerformanceTrack.fromDocument(view.document);
  final byOnMs = <double, Set<int>>{};
  for (final chord in track.chords(staves: {1, 2})) {
    final pitches = {
      for (final e in chord.notes)
        if (!e.ornament) e.pitch,
    };
    if (pitches.isEmpty) continue;
    byOnMs.putIfAbsent(chord.onMs, () => {}).addAll(pitches);
  }
  final onsets = byOnMs.keys.toList()..sort();
  bool done() =>
      _has(find.text('Exercício aprovado!')) ||
      _has(find.textContaining('Precisa de')) ||
      _has(find.textContaining('Tente de novo'));
  for (final onMs in onsets) {
    if (done()) break;
    for (final p in byOnMs[onMs]!) {
      _keyboard.noteOn(p);
    }
    await _wait(tester, 160);
    for (final p in byOnMs[onMs]!) {
      _keyboard.noteOff(p);
    }
    await _wait(tester, 160);
  }
}

/// O app não traz música nenhuma (fase B): o roteiro instala a biblioteca de
/// hinos que `just telas` recebe em `--dart-define=ZYWNY_TEST_LIBRARY=<caminho
/// no aparelho>` (um `dist/hinos.zywny` posto lá com `adb push`, de preferência
/// em `/sdcard/Android/data/<id do app>/files/`, que o app lê sem permissão).
/// O histórico (`_seedHistory`) já usa as chaves da biblioteca `hinos`.
Future<void> _installTestLibrary() async {
  const path = String.fromEnvironment('ZYWNY_TEST_LIBRARY');
  if (path.isEmpty) {
    throw StateError(
      'Passe --dart-define=ZYWNY_TEST_LIBRARY=<dist/hinos.zywny no aparelho>',
    );
  }
  await LibraryStore().install(await File(path).readAsBytes());
}

/// Histórico de quem já estuda há umas semanas: hinos abertos, pontuações
/// e trilhas em vários pontos — a do hino do roteiro com o 1º trecho feito.
Future<void> _seedHistory() async {
  final prefs = SharedPreferencesAsync();
  await prefs.clear();
  final now = DateTime.now();
  int daysAgo(int days) =>
      now.subtract(Duration(days: days)).millisecondsSinceEpoch;

  await prefs.setString(
    progressKeyFor('hinos'),
    jsonEncode({
      _kHymnId: {'t': daysAgo(0), 's': 78},
      '001': {'t': daysAgo(1), 's': 94},
      '004': {'t': daysAgo(3), 's': 88},
      '012': {'t': daysAgo(9), 's': 61},
      '002': {'t': daysAgo(20), 's': 43},
      '023': {'t': daysAgo(45)},
    }),
  );

  Map<String, Object?> record(String state, int best) => {
    's': state,
    'b': best,
  };

  // Hino 1: trilha concluída. Hino 4: no meio, com duas etapas puladas.
  await prefs.setString(
    trailKeyFor('hinos', '001'),
    jsonEncode({
      'v': 1,
      'n': 5,
      'total': 51,
      'records': {
        for (var i = 0; i < 48; i++) 'e$i': record('aprovada', 96),
        'final.50': record('aprovada', 97),
        'final.75': record('aprovada', 95),
        'final.100': record('aprovada', 92),
      },
    }),
  );
  await prefs.setString(
    trailKeyFor('hinos', '004'),
    jsonEncode({
      'v': 1,
      'n': 5,
      'total': 51,
      'records': {
        for (var i = 0; i < 17; i++) 'e$i': record('aprovada', 93),
        'e17': record('pulada', 70),
        'e18': record('pulada', 0),
      },
      'resume': {
        'id': 't1.tempoE.75',
        'label': 'Esquerda no ritmo 75%',
        'seg': 1,
        'segs': 6,
      },
    }),
  );

  // O hino do roteiro: o 1º trecho feito (uma etapa pulada), parado no
  // começo do 2º (uma espera, que o roteiro toca com o teclado falso). Os
  // ids vêm do plano real da 1ª passagem — o corte muda com o N e as fases
  // já se chamaram `ritmoD` um dia.
  final plan = _plan;
  final seg0 = [
    for (final s in plan?.stages ?? const [])
      if (s.segment == 0) s,
  ];
  final seg1 = [
    for (final s in plan?.stages ?? const [])
      if (s.segment == 1) s,
  ];
  final List<String> first;
  final String resumeId;
  final String resumeLabel;
  if (seg0.isNotEmpty && seg1.isNotEmpty) {
    first = [for (final s in seg0) s.id];
    resumeId = seg1.first.id;
    resumeLabel = seg1.first.label;
  } else {
    first = [
      't0.notasD',
      't0.notasE',
      't0.notasJ',
      for (final phase in ['tempoD', 'tempoE', 'junto'])
        for (final pct in [50, 75, 100]) 't0.$phase.$pct',
    ];
    resumeId = 't1.notasD';
    resumeLabel = 'Notas da direita';
  }
  const bests = [100, 96, 93, 100, 95, 91, 97, 94, 82, 98, 92, 90];
  await prefs.setString(
    trailKeyFor('hinos', _kHymnId),
    jsonEncode({
      'v': 1,
      'n': plan?.n ?? kTrailDefaultMeasures,
      'total': plan?.stages.length ?? first.length,
      'records': {
        for (var i = 0; i < first.length; i++)
          first[i]: record(
            i == 8 ? 'pulada' : 'aprovada',
            bests[i % bests.length],
          ),
      },
      'resume': {
        'id': resumeId,
        'label': resumeLabel,
        'seg': 1,
        'segs': plan?.segmentCount ?? 6,
      },
    }),
  );
  await _installTestLibrary();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // O app anda sozinho (animações, render em isolate, áudio): os quadros
  // não esperam um `pump`.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.reportData = {'telas': _shots};
  // `setPlatformOverride` e não `MidiCommandPlatform.instance`: este aceita
  // um falso só em build de debug, e o roteiro roda em profile.
  MidiCommand.setPlatformOverride(_keyboard);
  // Sem a faixa "DEBUG" no canto: as telas saem como as de uma versão final.
  WidgetsApp.debugAllowBannerOverride = false;

  testWidgets('primeiro uso, sem teclado', (tester) async {
    _forceOrientation(tester);
    await SharedPreferencesAsync().clear();
    // Emulador limpo não tem biblioteca instalada (o app não traz música):
    // garante a de teste antes de abrir, como as passagens seguintes fazem.
    try {
      await _installTestLibrary();
    } on Object catch (e) {
      debugPrint('telas: sem biblioteca de teste ($e)');
      // Sem o arquivo no aparelho, segue sem biblioteca (o roteiro mostra
      // a tela de instalar).
    }
    await _launch(tester, splash: true);
    await _wait(tester, 500);
    await _shot(tester, '01-abertura');

    await _libraryReady(tester);
    await _shot(tester, '02-biblioteca-primeiro-uso');

    await _typeSearch(tester, 'santo');
    await _wait(tester);
    await _shot(tester, '03-biblioteca-busca');
    await _typeSearch(tester, 'chopin');
    await _wait(tester);
    await _shot(tester, '04-biblioteca-busca-sem-resultado');
    await _typeSearch(tester, '');
    FocusManager.instance.primaryFocus?.unfocus();
    await _wait(tester);

    await _sortBy(tester, 'Dificuldade');
    await _shot(tester, '05-biblioteca-por-dificuldade');
    await _sortBy(tester, 'Número');

    await _tap(tester, find.byTooltip('Conectar teclado MIDI'));
    await _shot(tester, '06-teclado-midi-nenhum');
    await _tap(tester, find.text('Fechar'));

    await _tap(tester, find.byTooltip('Configurações gerais'));
    await _until(
      tester,
      () => _has(find.text('o app toca a música')),
      what: 'configurações gerais',
    );
    await _shot(tester, '07-configuracoes');
    // Mudar o corte da trilha pede confirmação: recomeça as trilhas. O painel
    // cresceu (Bibliotecas e Cursos das fases B/I): rola até a seção.
    await _settingsRow(tester, 'Trilha de estudo');
    await _tap(tester, find.byTooltip('Mais compassos por trecho'));
    await _shot(tester, '08-configuracoes-mudar-o-padrao');
    await _tap(tester, find.text('Cancelar'));
    await _settingsRow(tester, 'Cores');
    await _tap(tester, find.text('Nota certa'));
    await _shot(tester, '09-seletor-de-cor');
    await _tap(tester, find.text('Cancelar'));
    await _tap(tester, find.byTooltip('Fechar'));

    // Abre o hino: a tela vira para paisagem e o Verovio grava a página.
    await _openPieceFromList(tester);
    await _until(
      tester,
      () =>
          _oriented(tester, landscape: true) &&
          _has(find.byType(PhoneTitleBar)),
      what: 'tela da partitura',
    );
    await tester.pump(const Duration(milliseconds: 60));
    await _shot(tester, '10-hino-abrindo');

    await _scoreReady(tester);
    await _shot(tester, '11-trilha-sem-teclado');

    // Sem teclado o play ouve o trecho (U03): o botão grande e o da barra
    // lateral têm o mesmo tooltip.
    await _tap(tester, find.byTooltip('Ouvir o trecho').first);
    await _until(
      tester,
      () => _has(find.byTooltip('Parar de ouvir')),
      what: 'ouvindo o trecho',
      seconds: 30,
    );
    await _wait(tester, 800);
    await _shot(tester, '12-ouvindo-o-trecho');
    await _tap(tester, find.byTooltip('Parar de ouvir').first);
    await _wait(tester);

    await _openTrailDrawer(tester);
    _plan = tester.widget<TrailDrawer>(find.byType(TrailDrawer)).plan;
    await _shot(tester, '13-gaveta-da-trilha');
    await _tap(tester, find.byTooltip('Fechar'));

    await _openOptions(tester);
    await _shot(tester, '14-opcoes-de-estudo');
    await _scrollOptions(tester, -300);
    await _shot(tester, '15-opcoes-de-estudo-meio');
    await _scrollOptions(tester, -600);
    await _shot(tester, '16-opcoes-de-estudo-fim');

    await _optionsItem(tester, 'Ajustes da partitura (avançado)');
    await _shot(tester, '17-layout-do-hino');
    await _tap(tester, find.byTooltip('Fechar'));

    await _openOptions(tester);
    await _optionsItem(tester, 'Configurações gerais');
    await _shot(tester, '18-configuracoes-na-partitura');
    await _tap(tester, find.byTooltip('Fechar'));

    await _tap(tester, find.byTooltip('Ir para compasso'));
    await _until(
      tester,
      () => _has(find.textContaining('Ir para o compasso')),
      what: 'ir para compasso',
    );
    await _shot(tester, '19-ir-para-compasso');
    _popRoute(tester);
    await _wait(tester);

    // Treino livre (os modos de antes da trilha, num menu secundário). Na
    // trilha a gaveta não oferece "Repetir um trecho" (U11): vem depois.
    await _openOptions(tester);
    await _optionsItem(tester, 'Treino livre');
    await _wait(tester);

    await _openOptions(tester);
    await _optionsItem(tester, 'Repetir um trecho');
    await _until(
      tester,
      () => _has(find.text('Repetir este trecho')),
      what: 'repetir um trecho',
    );
    await _shot(tester, '20-repetir-um-trecho');
    _popRoute(tester);
    await _wait(tester);
    await _shot(tester, '21-treino-livre');

    await tester.tap(find.byTooltip('Tocar'), warnIfMissed: false);
    await _shotCountIn(tester, '22-contagem');
    await _wait(tester, 6500);
    await _shot(tester, '23-tocando');
    await _tap(tester, find.byTooltip('Pausar'));

    await _openOptions(tester);
    await _tap(tester, find.text('Espera'));
    await _shot(tester, '24-opcoes-modo-espera');
    await _tap(tester, find.byTooltip('Fechar'));
    await _shot(tester, '25-espera-sem-teclado');

    await _backToLibrary(tester);
    await _shot(tester, '26-biblioteca-continuar');
  }, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('com histórico e teclado MIDI', (tester) async {
    _forceOrientation(tester);
    await _seedHistory();
    _keyboard.plug();
    await _launch(tester, splash: false);
    await _libraryReady(tester);
    await _until(
      tester,
      () => _has(find.byTooltip('Teclado MIDI: Teclado digital')),
      what: 'teclado conectado',
    );
    await _shot(tester, '27-biblioteca-com-historico');

    await _sortBy(tester, 'Pontuação');
    await _shot(tester, '28-biblioteca-por-pontuacao');
    await _sortBy(tester, 'Número');

    await _tap(tester, find.byTooltip('Teclado MIDI: Teclado digital'));
    await _shot(tester, '29-teclado-midi-conectado');
    await _tap(tester, find.text('Fechar'));

    _forceOrientation(tester, score: true);
    await tester.tap(find.byTooltip('Continuar estudo'), warnIfMissed: false);
    await _scoreReady(tester);
    await _shot(tester, '30-trilha-retomada');

    await _openTrailDrawer(tester);
    final waitStage = _selectedStage(tester);
    await _shot(tester, '31-gaveta-da-trilha-com-progresso');
    await _tap(tester, find.byTooltip('Fechar'));

    // Etapa do modo espera (notas da direita): o tempo espera o aluno.
    await _tap(tester, find.byTooltip('Começar etapa'));
    await _until(
      tester,
      () => _has(find.byType(PhoneScorePill)),
      what: 'etapa rodando',
    );
    await _wait(tester, 800);
    await _shot(tester, '32-etapa-espera');
    await _playWaitStage(
      tester,
      waitStage,
      staves: waitStage.phase.hand == Hand.esquerda ? {2} : {1},
      wrongNoteShot: '33-etapa-nota-errada',
    );
    await _until(tester, _summaryOpen, what: 'resumo da etapa', seconds: 20);
    await _wait(tester);
    await _shot(tester, '34-resumo-da-etapa');
    await _tap(tester, find.text('Próxima etapa'));
    await _shot(tester, '35-proxima-etapa');

    // Refaz uma etapa com tempo do trecho já concluído (tudo junto a 50%):
    // contagem, metrônomo e avaliação nota a nota.
    await _openTrailDrawer(tester);
    await _tap(tester, find.textContaining('Trecho 1 ·'));
    await _shot(tester, '36-gaveta-etapas-concluidas');
    final timed = find.text('Tudo junto no ritmo 50%');
    await tester.ensureVisible(timed.first);
    await _wait(tester, 300);
    await _tap(tester, timed);
    await tester.tap(
      find.byTooltip('Começar etapa').first,
      warnIfMissed: false,
    );
    await _shotCountIn(tester, '37-etapa-contagem');
    await _playAlong(
      tester,
      staves: {1, 2},
      stop: _summaryOpen,
      skipEvery: 4,
      shots: {9000: '38-etapa-tempo-real'},
    );
    await _until(tester, _summaryOpen, what: 'resumo da etapa', seconds: 30);
    await _wait(tester);
    await _shot(tester, '39-resumo-da-etapa-reprovada');
    _popRoute(tester);
    await _wait(tester);

    // Treino livre em tempo real, com o resumo de precisão ao parar.
    await _openOptions(tester);
    await _optionsItem(tester, 'Treino livre');
    await _openOptions(tester);
    await _tap(tester, find.text('Tempo real'));
    await _shot(tester, '40-opcoes-treino-em-tempo-real');
    await _tap(tester, find.byTooltip('Fechar'));
    await _tap(tester, find.byTooltip('Praticar'), ms: 300);
    await _playAlong(
      tester,
      staves: {1},
      stop: () => false,
      maxMs: 16000,
      skipEvery: 5,
      shots: {11000: '41-treino-livre-tempo-real'},
    );
    await _tap(tester, find.byTooltip('Pausar'));
    await _until(
      tester,
      () => _has(find.textContaining('Precisão')),
      what: 'resumo do treino',
      seconds: 15,
    );
    await _shot(tester, '42-resumo-do-treino');
    await _tap(tester, find.text('Fechar'));

    // O que só aparece nas configurações com o teclado ligado.
    await _openOptions(tester);
    await _optionsItem(tester, 'Configurações gerais');
    await _settingsRow(tester, 'Atraso do teclado');
    await _shot(tester, '43-configuracoes-com-teclado');
    await _tap(tester, find.text('Atraso do teclado'));
    await _shot(tester, '44-calibrar-latencia');
    await _tap(tester, find.text('Cancelar'));

    await _openOptions(tester);
    await _optionsItem(tester, 'Configurações gerais');
    await _settingsRow(tester, 'Ver as teclas que chegam');
    await _tap(tester, find.text('Ver as teclas que chegam'));
    for (final pitch in [60, 64, 67]) {
      _keyboard.noteOn(pitch);
    }
    await _wait(tester);
    await _shot(tester, '45-monitor-midi');
    for (final pitch in [60, 64, 67]) {
      _keyboard.noteOff(pitch);
    }
    await _tap(tester, find.byTooltip('Fechar'));

    await _backToLibrary(tester);
    await _shot(tester, '46-biblioteca-depois-do-estudo');
  }, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('cursos da fase I', (tester) async {
    _forceOrientation(tester);
    // Sem biblioteca (não mexe no blob instalado): a tela direto com o
    // catálogo vazio mostra o cartão do curso inicial.
    _keyboard.unplug();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: MaterialApp(
          home: LibraryScreen(
            loadCatalog: () async => PieceCatalog.none(),
            loadScore: (piece) async => Uint8List(0),
            loadCourses: loadBuiltInCourses,
            scoreBuilder: (context, o) =>
                const Scaffold(body: Text('partitura')),
          ),
        ),
      ),
    );
    await _until(
      tester,
      () => _has(find.text('Comece pelo curso inicial')),
      what: 'cartão do curso inicial sem biblioteca',
      seconds: 60,
    );
    await _wait(tester, 2000);
    await _shot(tester, '47-curso-inicial-sem-biblioteca');

    await _tap(tester, find.text('Começar'));
    await _until(
      tester,
      () => _has(find.text('O teclado')),
      what: 'lição 1 do curso',
      seconds: 30,
    );
    await _wait(tester, 1500);
    await _shot(tester, '48-licao-1-pelo-cartao');

    // Com biblioteca: o app de verdade, com a lição 1 feita (uma feita, uma
    // aberta, o resto bloqueado). Não limpa o blob: só o progresso de curso.
    final prefs = SharedPreferencesAsync();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(
      CourseProgressStore.keyFor('iniciacao'),
      jsonEncode({
        'v': 1,
        'course': 'iniciacao',
        'records': {
          'l1-achar-do': {'p': true, 's': 1, 'b': 100, 't': now},
          'l1-achar-brancas': {'p': true, 's': 1, 'b': 100, 't': now},
        },
        'doneLessons': [],
        'lastLessonId': 'pauta-e-clave-de-sol',
      }),
    );
    try {
      await _installTestLibrary();
    } on Object {
      // Já instalada: segue.
    }
    await _launch(tester, splash: false);
    await _libraryReady(tester);
    await _until(
      tester,
      () => _has(find.textContaining('Cursos ·')),
      what: 'linha Cursos na biblioteca',
      seconds: 30,
    );
    await _shot(tester, '49-biblioteca-com-cursos');

    await _tap(tester, find.textContaining('Cursos ·'));
    await _until(
      tester,
      () =>
          _has(find.text('Cursos')) &&
          _has(find.text('Primeiros passos ao piano')),
      what: 'lista de cursos',
      seconds: 30,
    );
    await _wait(tester, 1000);
    await _shot(tester, '50-lista-de-cursos');

    await _tap(tester, find.text('Primeiros passos ao piano'));
    await _until(
      tester,
      () => _has(find.text('Apresentação')) && _has(find.text('O teclado')),
      what: 'tela do curso',
      seconds: 30,
    );
    await _wait(tester, 1000);
    await _shot(tester, '51-tela-do-curso');

    // Lição 2 em retrato: topo, partitura e cartão do exercício. O corpo da
    // lição é RichText (markdown), não Text.
    await _scrollTo(tester, find.text('A pauta e a clave de sol'));
    await _tap(tester, find.text('A pauta e a clave de sol'));
    await _until(
      tester,
      () => find
          .textContaining('Cinco linhas', findRichText: true)
          .evaluate()
          .isNotEmpty,
      what: 'lição 2',
      seconds: 30,
    );
    await _wait(tester, 1500);
    await _shot(tester, '52-licao-2-topo');
    await _scrollTo(tester, find.text('Do Dó ao Sol na clave de sol'));
    await _shot(tester, '53-licao-2-partitura');
    await _scrollTo(tester, find.text('Toque do Dó ao Sol'));
    await _shot(tester, '54-licao-2-exercicio');

    // O cartão sem teclado deixa o Começar desabilitado ("Precisa do
    // teclado", foto 54): a porta "Conecte o teclado" do exercício só
    // aparece se o teclado cair com o exercício abrindo. Liga, abre pelo
    // botão do cartão e despluga em seguida — a rodada carrega devagar no
    // emulador, então a porta chega antes da partitura.
    _keyboard.plug();
    await _wait(tester, 1500);
    await _startExercise(tester, 'Toque do Dó ao Sol');
    _keyboard.unplug();
    // Se a rodada já começou, o exercício não se reconstrói ao perder o
    // teclado e a porta não aparece: sem ela, segue sem a foto 55.
    final gateUntil = DateTime.now().add(const Duration(seconds: 30));
    while (!_has(find.text('Conecte o teclado')) &&
        DateTime.now().isBefore(gateUntil)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (_has(find.text('Conecte o teclado'))) {
      await _wait(tester, 800);
      await _shot(tester, '55-exercicio-conecte-o-teclado');
    } else {
      debugPrint('telas: sem a porta do teclado (55)');
    }
    // De volta à lição, religa para as telas com partitura.
    _popRoute(tester);
    await _wait(tester);
    _keyboard.plug();
    await _wait(tester, 1500);

    // name-note (botões, sem MIDI): abre pelo botão do cartão.
    await _startExercise(tester, 'Que nota é esta');
    await _until(
      tester,
      () => _has(find.byType(ScoreView)) || _has(find.textContaining('Dó')),
      what: 'exercício name-note',
      seconds: 60,
    );
    await _wait(tester, 1000);
    await _shot(tester, '56-exercicio-name-note');

    // Volta e abre o choice da lição 8 (precisa liberar a lição: abre assim
    // mesmo pela tela do curso). A lista volta onde estava (lição 2 no
    // topo), então rola até a lição 8 em vez de só esperar.
    _popRoute(tester);
    await _wait(tester);
    _popRoute(tester);
    await _wait(tester);
    await _until(
      tester,
      () =>
          _has(find.text('Apresentação')) ||
          _has(find.text('A pauta e a clave de sol')),
      what: 'tela do curso depois dos pops',
      seconds: 30,
    );
    await _scrollTo(tester, find.text('Acidentes'), 200);
    await _wait(tester, 300);
    await tester.tap(find.text('Acidentes'), warnIfMissed: false);
    await _wait(tester, 800);
    if (_has(find.text('Abrir assim mesmo'))) {
      await _tap(tester, find.text('Abrir assim mesmo'));
    }
    await _until(
      tester,
      () => _has(find.text('Para que serve o bequadro')),
      what: 'choice do bequadro',
      seconds: 30,
    );
    await _scrollTo(tester, find.text('Para que serve o bequadro'));
    await _shot(tester, '57-licao-8-choice-cartao');
    await _startExercise(tester, 'Para que serve o bequadro');
    await _until(
      tester,
      () =>
          _has(find.textContaining('bequadro')) &&
          _has(find.textContaining('Anula')),
      what: 'exercício choice',
      seconds: 30,
    );
    await _shot(tester, '58-exercicio-choice');
    _popRoute(tester);
    await _wait(tester);
    _popRoute(tester);
    await _wait(tester);

    // play-notes com teclado: antes e depois da rodada (a lista está na
    // lição 8; rola de volta, para cima, até a lição 2).
    await _scrollTo(tester, find.text('A pauta e a clave de sol'), -400);
    // Rolando para cima, a linha para rente ao cabeçalho: centraliza antes
    // do toque.
    await Scrollable.ensureVisible(
      tester.element(find.text('A pauta e a clave de sol').first),
      alignment: 0.5,
    );
    await _wait(tester, 500);
    await tester.tap(
      find.text('A pauta e a clave de sol'),
      warnIfMissed: false,
    );
    await _wait(tester, 1500);
    await _startExercise(tester, 'Toque do Dó ao Sol');
    await _until(
      tester,
      () => _has(find.byType(ScoreView)),
      what: 'partitura do play-notes',
      seconds: 90,
    );
    await _wait(tester, 1200);
    await _shot(tester, '59-exercicio-play-notes-antes');
    await _playCourseWait(tester);
    await _until(
      tester,
      () =>
          _has(find.text('Exercício aprovado!')) ||
          _has(find.textContaining('Precisa de')) ||
          _has(find.textContaining('Tente de novo')),
      what: 'resultado do play-notes',
      seconds: 60,
    );
    await _wait(tester, 800);
    await _shot(tester, '60-exercicio-play-notes-depois');
  }, timeout: const Timeout(Duration(minutes: 12)));
}
