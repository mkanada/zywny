// `ScorePlayer` (A05a/A05b): o host simulado. Um relógio próprio lê o timemap
// embutido no `.vsb` e acende/apaga as notas no `ScoreController`; a haste de
// virada e a página corrente saem da posição, por função pura
// (`ScoreTimeline.curtainAt`).
//
// RELÓGIO: um `Ticker` em milissegundos musicais (`posição += delta * speed`),
// nunca `DateTime.now()` — o teste usa tempo simulado (`tester.pump`) ou chama
// [advance] direto. `pause`/`play` não movem a posição e não tocam nas
// animações em curso do controller (que têm o relógio delas).
//
// A CADA AVANÇO aplicam-se **todas** as entradas com `tstamp` ultrapassado
// desde o último tick, não só a próxima: com `speed` alto ou um frame perdido,
// pular entradas deixaria notas acesas para sempre. `seek` recalcula do zero:
// apaga os destaques (as cores fixas do host ficam) e acende exatamente as
// notas que o timemap diz estarem ativas no instante.
//
// LIGAÇÃO COM A VISTA: `curtain` é o `ValueListenable` para `ScoreView.curtain`.
// Sem haste, o player leva a vista à página de repouso (`goToPage`) só quando
// ela difere; em `continuousScroll` não há haste, e a rolagem acompanha o
// compasso corrente (`scrollToId`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/painting.dart' show Color;

import 'model.dart';
import 'score_controller.dart';
import 'score_timeline.dart';
import 'score_view.dart';

export 'score_timeline.dart' show MeasureInfo, ScoreTimeline;

/// Quanto tempo um destaque "sem fim conhecido" espera pelo `off`: acima de
/// qualquer peça.
const _kForever = Duration(days: 365);

class ScorePlayer {
  ScorePlayer({
    required this.document,
    required this.controller,
    this.view,
    this.release = const Duration(milliseconds: 300),
    this.highlightColor = kDefaultHighlightColor,
    this.maxSweepDuration,
    this.barWidth,
    this.scrollAlignment = 0.3,
    this.scrollDuration = const Duration(milliseconds: 300),
    this.singleNoteDelay = const Duration(milliseconds: 500),
    this.onEntry,
  }) : timeline = ScoreTimeline(document) {
    _measureIndex = ValueNotifier<int>(0);
    _tempo = ValueNotifier<double?>(null);
    _publish(force: true);
  }

  final VsbDocument document;
  final ScoreController controller;

  /// A vista a acompanhar (página de repouso e rolagem). Opcional: sem ela o
  /// player só destaca notas e publica a haste.
  final ScoreViewController? view;

  /// Duração do `release` de cada nota ao chegar o `off`.
  final Duration release;
  final Color highlightColor;

  /// Onde, na viewport, o compasso corrente fica no modo contínuo.
  final double scrollAlignment;
  final Duration scrollDuration;

  /// Atraso da conclusão da virada na página de uma nota só (0,5 s).
  final Duration singleNoteDelay;

  /// Chamado para cada entrada do timemap aplicada, na ordem (uma por
  /// instante do timemap; não é chamado no `seek`).
  final void Function(TimemapEntry entry)? onEntry;

  final ScoreTimeline timeline;

  /// Teto de cada movimento da haste e largura dela; `null` lê da vista (ou
  /// usa os padrões). Se personalizar, passe os **mesmos** valores ao
  /// `ScoreView`.
  final Duration? maxSweepDuration;
  final double? barWidth;

  late final ValueNotifier<int> _measureIndex;
  late final ValueNotifier<double?> _tempo;
  final ValueNotifier<SweepCurtain?> _curtain = ValueNotifier(null);

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  double _positionMs = 0;
  int _next = 0; // primeira entrada ainda não aplicada
  bool _playing = false;
  bool _disposed = false;

  /// 1.0 = o tempo do timemap.
  double speed = 1.0;

  /// A haste de virada em [position]; passe a `ScoreView.curtain`.
  ValueListenable<SweepCurtain?> get curtain => _curtain;

  /// Índice, em [measures], do compasso tocando agora.
  ValueListenable<int> get currentMeasureIndex => _measureIndex;

  /// O último `tempo` do timemap até a posição (`null` se não houver).
  ValueListenable<double?> get tempo => _tempo;

  /// Compassos em ordem de execução.
  List<MeasureInfo> get measures => timeline.measures;

  Duration get position => Duration(microseconds: (_positionMs * 1000).round());
  Duration get duration =>
      Duration(microseconds: (timeline.durationMs * 1000).round());
  bool get isPlaying => _playing;

  Duration get _maxSweepDuration =>
      maxSweepDuration ??
      ((view?.isAttached ?? false)
          ? view!.maxSweepDuration
          : kDefaultMaxSweepDuration);

  double get _barWidthValue =>
      barWidth ??
      ((view?.isAttached ?? false)
          ? view!.barWidth
          : (_defaultBar ??= defaultBarWidth(document)));
  double? _defaultBar;

  // -------------------------------------------------------------------------
  // Transporte
  // -------------------------------------------------------------------------

  void play() {
    if (_disposed || _playing) {
      return;
    }
    if (_positionMs >= timeline.durationMs) {
      seek(Duration.zero);
    }
    _playing = true;
    _lastElapsed = Duration.zero;
    (_ticker ??= Ticker(_onTick, debugLabel: 'ScorePlayer')).start();
  }

  void pause() {
    if (!_playing) {
      return;
    }
    _playing = false;
    _ticker?.stop();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    advance(Duration(microseconds: (delta.inMicroseconds * speed).round()));
    if (_positionMs >= timeline.durationMs) {
      pause();
    }
  }

  /// Avança a posição em [musical] (já multiplicado por `speed`) e aplica
  /// **todas** as entradas ultrapassadas. É o que o `Ticker` chama; o teste
  /// com relógio simulado também.
  void advance(Duration musical) {
    if (_disposed || musical <= Duration.zero) {
      return;
    }
    _advanceToMs(
      (_positionMs + musical.inMicroseconds / 1000.0).clamp(
        0.0,
        timeline.durationMs,
      ),
    );
  }

  void _advanceToMs(double ms) {
    _positionMs = ms;
    final entries = timeline.entries;
    while (_next < entries.length && entries[_next].tstamp <= ms) {
      _apply(entries[_next]);
      _next++;
    }
    _publish();
  }

  void _apply(TimemapEntry e) {
    for (final id in e.off) {
      controller.release(id);
    }
    if (e.on.isNotEmpty) {
      controller.highlightAll(
        e.on,
        color: highlightColor,
        hold: _kForever,
        release: release,
      );
    }
    if (e.tempo != null) {
      _tempo.value = e.tempo;
    }
    onEntry?.call(e);
  }

  /// Vai para [position], recalculando o estado do zero: nenhum destaque
  /// "preso" de antes.
  void seek(Duration position) {
    if (_disposed) {
      return;
    }
    final ms = (position.inMicroseconds / 1000.0).clamp(
      0.0,
      timeline.durationMs,
    );
    _positionMs = ms;
    controller.clearHighlights();
    final entries = timeline.entries;
    final active = <String>{};
    double? tempo;
    var i = 0;
    while (i < entries.length && entries[i].tstamp <= ms) {
      final e = entries[i];
      active.removeAll(e.off);
      active.addAll(e.on);
      tempo = e.tempo ?? tempo;
      i++;
    }
    _next = i;
    _tempo.value = tempo;
    if (active.isNotEmpty) {
      controller.highlightAll(
        active,
        color: highlightColor,
        hold: _kForever,
        release: release,
      );
    }
    _publish(seeking: true);
  }

  // -------------------------------------------------------------------------
  // Publicação: compasso, haste, página
  // -------------------------------------------------------------------------

  int _lastScrolledMeasure = -1;

  void _publish({bool force = false, bool seeking = false}) {
    if (timeline.measureCount == 0) {
      return;
    }
    final index = timeline.measureIndexAt(_positionMs);
    if (_measureIndex.value != index) {
      _measureIndex.value = index;
    }
    final v = view;
    final attached = v != null && v.isAttached;
    final continuous = attached && v.mode == ScorePageMode.continuousScroll;
    if (continuous) {
      if (_curtain.value != null) {
        _curtain.value = null;
      }
      if (index != _lastScrolledMeasure || seeking) {
        _lastScrolledMeasure = index;
        v.scrollToId(
          measures[index].id,
          alignment: scrollAlignment,
          duration: seeking ? Duration.zero : scrollDuration,
        );
      }
      return;
    }
    final c = timeline.curtainAt(
      _positionMs,
      maxSweep: _maxSweepDuration,
      barWidth: _barWidthValue,
      singleNoteDelay: singleNoteDelay,
    );
    if (_curtain.value != c) {
      _curtain.value = c;
    }
    if (c == null && attached) {
      final page = timeline.restPageAt(_positionMs);
      if (v.currentPage != page) {
        v.goToPage(page);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _ticker?.dispose();
    _ticker = null;
    _curtain.dispose();
    _measureIndex.dispose();
    _tempo.dispose();
  }
}
