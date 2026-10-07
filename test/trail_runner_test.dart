// R11: a trilha (lib/app/trail_runner.dart) sem a tela. A partitura é a
// Gymnopédie pronta (sem Verovio), o som é um [FakeSoundEngine] com o
// relógio andado pelo teste, e o aluno toca pelo [FakeMidiInput] — a
// primeira etapa é "notas da direita", no modo espera.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:archive/archive.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:score_bridge/score_bridge.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/app/playback_controller.dart';
import 'package:zywny/app/score_render_session.dart';
import 'package:zywny/app/sound_output_controller.dart';
import 'package:zywny/app/trail_runner.dart';
import 'package:zywny_library/library_keys.dart' show progressIdFor;
import 'package:zywny_library/library_package.dart' show LibraryTerm;
import 'package:zywny_midi/midi_device_manager.dart';
import 'package:zywny_music/transposition.dart';
import 'package:zywny/practice/shift_detector.dart';
import 'package:zywny/settings/app_settings.dart';
import 'package:zywny/settings/piece_settings.dart';
import 'package:zywny/trail/stage_result.dart';
import 'package:zywny/trail/trail_progress.dart';
import 'package:zywny/trail/trail_widgets.dart' show StageSummaryAction;

import 'support/practice_fakes.dart';
import 'support/score_page_fakes.dart';

class _NoDevicesMidiCommandPlatform extends MidiCommandPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<MidiDevice>?> get devices async => const <MidiDevice>[];

  @override
  Stream<MidiPacket>? get onMidiDataReceived => null;

  @override
  Stream<MidiSetupChange>? get onMidiSetupChanged => null;
}

/// Um resumo de etapa que a tela teria mostrado.
typedef _Summary = ({String stageRef, StageResult result, List<int> bad});

/// A composição da tela de partitura, sem a tela: sessão, som, transporte e
/// trilha, com um teclado conectado.
class _Harness {
  _Harness._();

  late final AppSettings settings;
  late final MidiDeviceManager devices;
  final FakeMidiInput input = FakeMidiInput();
  final ScoreController scores = ScoreController();
  final GhostController ghosts = GhostController();
  late final TrailProgressStore store;
  late final ScoreRenderSession session;
  late final SoundOutputController sound;
  late final PlaybackController playback;
  late final TrailRunner runner;
  final List<FakeSoundEngine> engines = [];
  final List<_Summary> summaries = [];
  final RecordingRenderer renderer = RecordingRenderer();

  FakeSoundEngine get engine => engines.single;

  static Future<_Harness> create(
    WidgetTester tester, {
    int? fifths,
    String? transpose,
  }) async {
    MidiCommandPlatform.instance = _NoDevicesMidiCommandPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final h = _Harness._();
    h.settings = AppSettings();
    await h.settings.load();
    h.devices = MidiDeviceManager();
    h.store = TrailProgressStore();
    await tester.pump();
    h.devices.connected.value = MidiDevice(
      'k',
      'Teclado',
      MidiDeviceType.serial,
      true,
    );
    final piece = fakePiece(fifths: fifths);
    h.session = ScoreRenderSession(
      renderer: h.renderer,
      scoreXml: Uint8List(1),
      piece: piece,
      settings: h.settings,
      stored: PieceSettings(transpose: transpose),
      name: 'Hino',
    );
    h.sound = SoundOutputController(
      settings: h.settings,
      devices: h.devices,
      input: h.input,
      monitorPitch: (r, {required midiKeyboard}) => r,
      playback: SoundOutputPlayback(
        hasTrack: () => h.playback.track != null,
        attach: (engine, {required always}) =>
            h.playback.attachSound(engine, always: always),
        detach: () => h.playback.detachSound(),
        endPractice: () => h.runner.endPractice(),
      ),
      appEngineFactory: () async {
        final engine = FakeSoundEngine();
        h.engines.add(engine);
        return engine;
      },
    );
    h.playback = PlaybackController(
      sound: h.sound,
      settings: h.settings,
      controller: h.scores,
      onEnded: () => h.runner.endPractice(),
      wakelock: (_) {},
    );
    h.runner = TrailRunner(
      store: h.store,
      playback: h.playback,
      session: h.session,
      sound: h.sound,
      settings: h.settings,
      devices: h.devices,
      midiInput: h.input,
      piece: piece,
      term: const LibraryTerm(
        singular: 'hino',
        plural: 'hinos',
        feminine: false,
      ),
      scores: h.scores,
      ghosts: h.ghosts,
      shiftDetector: ShiftDetector(enabled: () => false),
      onShift: (_) {},
      writtenFromReceived: (r) => r,
      inputLatency: () async => 0,
      host: TrailRunnerHost(
        stageSummary:
            ({
              required stageRef,
              required result,
              required badLogical,
              required isLast,
              blockCount,
            }) async {
              h.summaries.add((
                stageRef: stageRef,
                result: result,
                bad: badLogical,
              ));
              return StageSummaryAction.next;
            },
        conclusion: () async => null,
        backToLibrary: () {},
        practiceReport: (_) {},
      ),
    );
    h.session.onDocument = h.runner.attachDocument;
    h.session.setBox(const Size(1000, 700));
    // O render sai num `Timer` de zero: o `pump` precisa andar o relógio.
    for (var i = 0; i < 10 && h.runner.trail == null; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(
      h.runner.trail,
      isNotNull,
      reason:
          "a trilha foi montada (${h.session.status}, ${h.runner.unavailable})",
    );
    return h;
  }

  /// Toca a etapa selecionada até o resumo: cada passo na hora dele, com
  /// uma tecla errada antes de cada [wrongEvery]-ésimo.
  Future<_Summary> playStage(WidgetTester tester, {int? wrongEvery}) async {
    final before = summaries.length;
    await runner.startStage();
    expect(runner.practice, isNotNull, reason: 'a etapa começou');
    var stepNumber = 0;
    var guard = 0;
    while (summaries.length == before) {
      if (guard++ > 20000) throw StateError('a etapa não terminou');
      final step = runner.practice?.currentStep.value;
      final scheduler = playback.scheduler!;
      if (step == null || scheduler.positionMs < step.onMs - 0.5) {
        engine.now += 0.02;
        await tester.pump(const Duration(milliseconds: 20));
        continue;
      }
      stepNumber++;
      if (wrongEvery != null && stepNumber % wrongEvery == 0) {
        input.press(22, atSeconds: engine.now);
        await tester.pump();
        input.release(22, atSeconds: engine.now);
        await tester.pump();
      }
      final wanted = {for (final e in step.notes) e.pitch};
      for (final p in wanted) {
        input.press(p, atSeconds: engine.now);
      }
      await tester.pump();
      for (final p in wanted) {
        input.release(p, atSeconds: engine.now);
      }
      await tester.pump();
    }
    return summaries.last;
  }

  void dispose() {
    runner.dispose();
    playback.dispose();
    sound.dispose();
    session.dispose();
    scores.dispose();
    ghosts.dispose();
    input.dispose();
    devices.dispose();
    store.dispose();
    settings.dispose();
  }
}

/// A gravura [vsb] com cada id de [ids] trocado por outro, em todos os
/// arquivos — o que uma gravura nova da mesma música faz.
VsbDocument _withRenamedIds(List<int> vsb, Set<String> ids) {
  final out = Archive();
  for (final file in ZipDecoder().decodeBytes(vsb)) {
    var text = utf8.decode(file.content);
    for (final id in ids) {
      text = text.replaceAll('"$id"', '"$id-novo"');
    }
    final bytes = utf8.encode(text);
    out.addFile(ArchiveFile(file.name, bytes.length, bytes));
  }
  return VsbDocument.fromBytes(Uint8List.fromList(ZipEncoder().encode(out)));
}

void main() {
  testWidgets('uma etapa passada avança para a seguinte', (tester) async {
    final h = await _Harness.create(tester);
    final trail = h.runner.trail!;
    final first = trail.selected!;

    final summary = await h.playStage(tester);
    expect(summary.result.passed, isTrue);
    expect(summary.bad, isEmpty);
    await tester.pump();
    expect(trail.progress.stateOf(first.id), StageState.aprovada);
    expect(trail.selected!.id, isNot(first.id));
    expect(h.runner.practice, isNull);
    expect(h.playback.playing, isFalse);
    expect(h.runner.errorMeasureIds, isEmpty);
    h.dispose();
  });

  testWidgets('uma etapa com erro marca os compassos na pauta', (tester) async {
    final h = await _Harness.create(tester);

    final summary = await h.playStage(tester, wrongEvery: 2);
    expect(summary.result.badMeasures, isNotEmpty);
    expect(summary.bad, isNotEmpty);
    expect(h.runner.errorMeasureIds, isNotEmpty);
    // Os compassos marcados são os do trecho da etapa.
    final marked = h.runner.markedIds().toSet();
    expect(h.runner.errorMeasureIds.difference(marked), isEmpty);
    h.dispose();
  });

  testWidgets('as notas erradas da etapa ficam para a revisão na partitura', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    // A partitura do harness não tem as posições de altura; a da fantasma
    // tem, e é a mesma peça.
    h.ghosts.attachDocument(
      VsbDocument.fromBytes(
        File('test/fixtures/satie-fantasma.vsb').readAsBytesSync(),
      ),
    );

    await h.playStage(tester, wrongEvery: 2);
    final marks = h.runner.wrongMarks;
    expect(marks, isNotEmpty);
    expect(marks.every((m) => m.pitch == 22), isTrue);
    // Modo espera: não há tempo certo para errar, então sem lado.
    expect(marks.every((m) => m.side == 0), isTrue);
    expect(h.runner.reviewing, isFalse);
    expect(h.ghosts.review, isEmpty);

    h.runner.startReview();
    expect(h.runner.reviewing, isTrue);
    expect(h.ghosts.review, isNotEmpty);
    expect(h.ghosts.review.every((g) => g.key == 22), isTrue);

    // A revisão não tem fechar: acaba quando o próximo treino começa.
    await h.runner.startStage();
    expect(h.runner.wrongMarks, isEmpty);
    expect(h.runner.reviewing, isFalse);
    expect(h.ghosts.review, isEmpty);
    h.runner.abandonStage();
    h.dispose();
  });

  testWidgets('a pauta da etapa segue a gravura nova (ids novos)', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    final stage = h.runner.trail!.selected!;
    final before = h.runner.markedIds();
    expect(before, isNotEmpty);

    // Gravar de novo (caixa nova, tom...) dá outros ids aos compassos: o
    // Verovio continua o contador de ids de uma gravura para a outra. A
    // etapa é a mesma.
    h.renderer.next = _withRenamedIds(
      File('test/fixtures/erik-satie.vsb').readAsBytesSync(),
      {for (final m in h.playback.player!.measures) m.id},
    );
    final oldPlayer = h.playback.player;
    await h.session.render();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    final player = h.playback.player!;
    expect(identical(player, oldPlayer), isFalse);
    expect(h.runner.trail!.selected!.id, stage.id);
    final ids = {for (final m in player.measures) m.id};
    expect(
      ids.containsAll(before),
      isFalse,
      reason: 'a gravura do teste precisa ter outros ids',
    );
    final after = h.runner.markedIds();
    expect(after, isNotEmpty);
    expect(
      ids.containsAll(after),
      isTrue,
      reason: 'os compassos marcados são os da gravura na tela',
    );
    h.dispose();
  });

  testWidgets('uma etapa sem erro não oferece revisão', (tester) async {
    final h = await _Harness.create(tester);
    await h.playStage(tester);
    expect(h.runner.wrongMarks, isEmpty);
    h.runner.startReview();
    expect(h.runner.reviewing, isFalse);
    h.dispose();
  });

  testWidgets('o progresso é gravado no tom da partitura', (tester) async {
    final none = Transposition.toNoAccidentals(-3, lowest: 40, highest: 80)!;
    final h = await _Harness.create(
      tester,
      fifths: -3,
      transpose: none.interval,
    );
    expect(h.session.renderedTransposition, none);
    final piece = fakePiece(fifths: -3);
    final transposedId = progressIdFor(piece.id, none);
    expect(h.runner.trail!.pieceId, transposedId);

    await h.playStage(tester);
    await tester.pump();
    expect(h.store[transposedId].done, 1);
    expect(h.store[piece.id].done, 0, reason: 'o tom original não mudou');
    h.dispose();
  });
}
