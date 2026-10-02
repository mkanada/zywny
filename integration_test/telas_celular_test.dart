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
const _kHymnNumber = 5;
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

Future<void> _shot(WidgetTester tester, String name) async {
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
    () => !_landscape(tester) && _has(find.textContaining(' hinos')),
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

Future<void> _openHymnFromList(WidgetTester tester) async {
  await tester.tap(find.text(_kHymnTitle).last, warnIfMissed: false);
}

Future<void> _scoreReady(WidgetTester tester) async {
  await _until(
    tester,
    () =>
        _landscape(tester) &&
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

/// Histórico de quem já estuda há umas semanas: hinos abertos, pontuações
/// e trilhas em vários pontos — a do hino do roteiro com o 1º trecho feito.
Future<void> _seedHistory() async {
  final prefs = SharedPreferencesAsync();
  await prefs.clear();
  final now = DateTime.now();
  int daysAgo(int days) =>
      now.subtract(Duration(days: days)).millisecondsSinceEpoch;

  await prefs.setString(
    'hymn_progress',
    jsonEncode({
      '$_kHymnNumber': {'t': daysAgo(0), 's': 78},
      '1': {'t': daysAgo(1), 's': 94},
      '4': {'t': daysAgo(3), 's': 88},
      '12': {'t': daysAgo(9), 's': 61},
      '2': {'t': daysAgo(20), 's': 43},
      '23': {'t': daysAgo(45)},
    }),
  );

  Map<String, Object?> record(String state, int best) => {
    's': state,
    'b': best,
  };

  // Hino 1: trilha concluída. Hino 4: no meio, com duas etapas puladas.
  await prefs.setString(
    'trail_1',
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
    'trail_4',
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
        'id': 't1.ritmoE.75',
        'label': 'Ritmo da esquerda 75%',
        'seg': 1,
        'segs': 4,
      },
    }),
  );

  // O hino do roteiro: o 1º trecho feito (uma etapa pulada), parado no
  // começo do 2º.
  final plan = _plan;
  final first = [
    't0.notasD',
    't0.notasE',
    't0.notasJ',
    for (final phase in ['ritmoD', 'ritmoE', 'junto'])
      for (final pct in [50, 75, 100]) 't0.$phase.$pct',
  ];
  const bests = [100, 96, 93, 100, 95, 91, 97, 94, 82, 98, 92, 90];
  await prefs.setString(
    'trail_$_kHymnNumber',
    jsonEncode({
      'v': 1,
      'n': plan?.n ?? kTrailDefaultMeasures,
      'total': plan?.stages.length ?? 51,
      'records': {
        for (var i = 0; i < first.length; i++)
          first[i]: record(i == 8 ? 'pulada' : 'aprovada', bests[i]),
      },
      'resume': {
        'id': 't1.notasD',
        'label': 'Notas da direita',
        'seg': 1,
        'segs': plan?.segmentCount ?? 4,
      },
    }),
  );
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
    await SharedPreferencesAsync().clear();
    await _launch(tester, splash: true);
    await _wait(tester, 500);
    await _shot(tester, '01-abertura');

    await _libraryReady(tester);
    await _shot(tester, '02-biblioteca-primeiro-uso');

    await tester.enterText(find.byType(TextField), 'santo');
    await _wait(tester);
    await _shot(tester, '03-biblioteca-busca');
    await tester.enterText(find.byType(TextField), 'chopin');
    await _wait(tester);
    await _shot(tester, '04-biblioteca-busca-sem-resultado');
    await tester.enterText(find.byType(TextField), '');
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
    // Mudar o corte da trilha pede confirmação: recomeça as trilhas.
    await _tap(tester, find.byTooltip('Mais compassos por trecho'));
    await _shot(tester, '08-configuracoes-mudar-o-padrao');
    await _tap(tester, find.text('Cancelar'));
    await _tap(tester, find.text('Nota certa'));
    await _shot(tester, '09-seletor-de-cor');
    await _tap(tester, find.text('Cancelar'));
    await _tap(tester, find.byTooltip('Fechar'));

    // Abre o hino: a tela vira para paisagem e o Verovio grava a página.
    await _until(tester, () => _has(find.text(_kHymnTitle)), what: 'o hino');
    await _openHymnFromList(tester);
    await _until(
      tester,
      () => _landscape(tester) && _has(find.byType(PhoneTitleBar)),
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
}
