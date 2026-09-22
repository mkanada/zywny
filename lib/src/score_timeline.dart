// Linha do tempo da peça (A05a/A05b): índice de compassos e posição da haste.
//
// Tudo aqui é **função pura** de `(documento, posição)`, sem widget, sem
// `Ticker` e sem relógio: o `ScorePlayer` só empurra a posição para cá. Por
// isso `seek`, `pause` e `speed` funcionam sem código extra — a haste é
// derivada, nunca guardada.
//
// ÍNDICE DE COMPASSOS. "Em que compasso estou" sai da **cena**: o nó de
// classe `measure` que é ancestral do id. Um único percurso da árvore monta o
// mapa `id → compasso` e a página de cada compasso; o timemap dá o instante.
// Compassos e notas com sufixo `-rend<N>` de repetição (ids expandidos, que
// não existem na cena) ficam de fora sem erro NESTE arquivo — o timemap
// embutido preenche `measureOn` desde E01b e `VsbDocument.sceneIdOf`/`passOf`
// resolvem esses ids desde E02a, mas usá-los para que uma ocorrência de
// compasso repetida apareça na linha do tempo é E02b, ainda não feito aqui.
// Até lá, uma peça com repetição fica presa no último compasso "novo" antes
// dela durante toda a 2ª passagem (ver E02b, "O defeito de hoje").
//
// REGRA DA HASTE (decidida com o usuário em 2026-09-21; ver A05b). Sejam `P`
// uma página com uma seguinte, `M` o seu último compasso e `M+1` o primeiro da
// página seguinte, `D = min(teto, duração de M / 4)`:
//
//   * `M.start → M.start + D`   entrada: `0 → xInício(M)`
//   * `→ (M+1).start`           estacionada em `xInício(M)`
//   * `(M+1).start → + D`       conclusão: `xInício(M) → fim`
//   * antes/depois              repouso
//
// Página de **um** compasso com várias notas: a haste acompanha as notas —
// entra assim que a página aparece, fica logo antes da nota atual e, ao
// destacar a nota k, começa a saltar para a k+1 em `min(D, tempo até ela)`
// (nunca chega atrasada). Com **uma** nota só a conclusão começa 0,5 s depois
// do destaque dela.
library;

import 'dart:math' as math;

import 'model.dart';
import 'score_view.dart' show SweepCurtain, sweepEndX;

/// Um compasso na ordem de execução.
class MeasureInfo {
  const MeasureInfo({
    required this.id,
    required this.page,
    required this.noteIds,
    required this.startMs,
    required this.endMs,
  });

  /// `xml:id` do compasso.
  final String id;

  /// Página onde ele está.
  final int page;

  /// Notas do compasso, na ordem do timemap.
  final List<String> noteIds;

  /// `tstamp` da primeira nota do compasso.
  final int startMs;

  /// `tstamp` da primeira nota do compasso seguinte (o `tstamp` final, no
  /// último).
  final int endMs;

  @override
  String toString() => 'MeasureInfo($id p$page $startMs-$endMs)';
}

/// Uma nota (ou acorde) do compasso: o instante e o x da borda esquerda da
/// mais à esquerda, em unidades de viewBox.
class _Onset {
  const _Onset(this.ms, this.x);
  final double ms;
  final double x;
}

class _Measure {
  _Measure(this.id, this.page);
  final String id;
  final int page;
  final List<String> noteIds = [];
  final List<_Onset> onsets = [];
  double startMs = 0;
  double endMs = 0;
  double left = 0;

  double get durationMs => endMs - startMs;
}

/// Sequência de compassos consecutivos numa mesma página.
class _Run {
  _Run(this.page, this.first, this.last);
  final int page;
  final int first;
  int last;
}

class ScoreTimeline {
  ScoreTimeline(this.document) {
    _build();
  }

  final VsbDocument document;

  final List<_Measure> _measures = [];
  final List<_Run> _runs = [];
  late final List<MeasureInfo> measures;
  double durationMs = 0;

  /// Entradas do timemap em ordem de `tstamp`.
  late final List<TimemapEntry> entries;

  /// Compassos em ordem de execução (A05a).
  List<MeasureInfo> get measureInfos => measures;

  int get measureCount => _measures.length;

  void _build() {
    final entriesList = [...?document.timemap]
      ..sort((a, b) => a.tstamp.compareTo(b.tstamp));
    entries = entriesList;
    durationMs = entriesList.isEmpty ? 0 : entriesList.last.tstamp;

    // id -> compasso (id do compasso), e página de cada compasso.
    final measureOfId = <String, String>{};
    final pageOfMeasure = <String, int>{};
    for (final page in document.pages) {
      _collect(page.root, page.index, null, measureOfId, pageOfMeasure);
    }

    final byId = <String, _Measure>{};
    void touch(
      String id,
      double ms,
      List<String>? notes,
      Map<_Measure, double> leftAtThisEntry,
    ) {
      final mid = measureOfId[id];
      if (mid == null) {
        return;
      }
      final m = byId.putIfAbsent(mid, () {
        final created = _Measure(mid, pageOfMeasure[mid]!)..startMs = ms;
        _measures.add(created);
        return created;
      });
      if (notes != null) {
        if (!m.noteIds.contains(id)) {
          m.noteIds.add(id);
        }
        final ref = document.geometry.elementOf(id);
        if (ref != null) {
          final prev = leftAtThisEntry[m];
          leftAtThisEntry[m] = prev == null
              ? ref.bbox.left
              : math.min(prev, ref.bbox.left);
        }
      }
    }

    for (final e in entriesList) {
      final lefts = <_Measure, double>{};
      for (final id in e.on) {
        touch(id, e.tstamp, const [], lefts);
      }
      for (final id in e.restsOn) {
        touch(id, e.tstamp, null, lefts);
      }
      lefts.forEach((m, x) => m.onsets.add(_Onset(e.tstamp, x)));
    }

    for (var i = 0; i < _measures.length; i++) {
      final m = _measures[i];
      m.endMs = i + 1 < _measures.length
          ? _measures[i + 1].startMs
          : durationMs;
      m.left = document.geometry.elementOf(m.id)?.bbox.left ?? 0;
      if (m.onsets.isEmpty) {
        m.onsets.add(_Onset(m.startMs, m.left));
      }
      final last = _runs.isEmpty ? null : _runs.last;
      if (last != null && last.page == m.page) {
        last.last = i;
      } else {
        _runs.add(_Run(m.page, i, i));
      }
    }
    measures = [
      for (final m in _measures)
        MeasureInfo(
          id: m.id,
          page: m.page,
          noteIds: List.unmodifiable(m.noteIds),
          startMs: m.startMs.round(),
          endMs: m.endMs.round(),
        ),
    ];
  }

  void _collect(
    SceneNode node,
    int page,
    String? measure,
    Map<String, String> measureOfId,
    Map<String, int> pageOfMeasure,
  ) {
    if (node.hidden) {
      return;
    }
    var current = measure;
    if (node.className == 'measure' && node.id != null) {
      current = node.id;
      pageOfMeasure[node.id!] = page;
    }
    if (current != null && node.id != null) {
      measureOfId[node.id!] = current;
    }
    for (final child in node.children) {
      if (child is SceneNode) {
        _collect(child, page, current, measureOfId, pageOfMeasure);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Consultas por posição
  // -------------------------------------------------------------------------

  /// Índice, em [measures], do compasso tocando em [ms] (0 antes do primeiro).
  int measureIndexAt(double ms) {
    var lo = 0;
    var hi = _measures.length - 1;
    var found = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_measures[mid].startMs <= ms) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  /// A página que fica em repouso em [ms] quando não há haste: a do compasso
  /// corrente.
  int restPageAt(double ms) =>
      _measures.isEmpty ? 0 : _measures[measureIndexAt(ms)].page;

  double _dOf(_Measure m, double maxSweepMs) =>
      math.min(maxSweepMs, m.durationMs / 4);

  /// A haste em [ms], ou `null` (repouso). Função pura da posição.
  ///
  /// [maxSweep] é o teto de cada movimento (`ScoreView.maxSweepDuration`) e
  /// [barWidth] a largura da haste em unidades de viewBox (para o "fim").
  SweepCurtain? curtainAt(
    double ms, {
    required Duration maxSweep,
    required double barWidth,
    Duration singleNoteDelay = const Duration(milliseconds: 500),
  }) {
    final maxMs = maxSweep.inMicroseconds / 1000.0;
    for (var r = 0; r + 1 < _runs.length; r++) {
      final run = _runs[r];
      final next = _runs[r + 1];
      if (next.page != run.page + 1) {
        continue; // salto de repetição: sem haste
      }
      final m = _measures[run.last];
      final page = document.pages[run.page];
      final end = sweepEndX(page, barWidth);
      final d = _dOf(m, maxMs);
      final count = run.last - run.first + 1;
      final edge = count > 1
          ? _multiMeasureEdge(ms, m, d, end)
          : _singleMeasureEdge(
              ms,
              run,
              r > 0 ? _runs[r - 1] : null,
              m,
              d,
              end,
              maxMs,
              singleNoteDelay.inMicroseconds / 1000.0,
            );
      if (edge != null) {
        return SweepCurtain(pageIndex: run.page, edgeX: edge);
      }
    }
    return null;
  }

  double? _multiMeasureEdge(double ms, _Measure m, double d, double end) {
    final s = m.startMs;
    final e = m.endMs;
    if (ms < s || ms >= e + d) {
      return null;
    }
    if (ms < s + d) {
      return m.left * ((ms - s) / d);
    }
    if (ms < e) {
      return m.left;
    }
    return m.left + (end - m.left) * ((ms - e) / d);
  }

  double? _singleMeasureEdge(
    double ms,
    _Run run,
    _Run? prev,
    _Measure m,
    double d,
    double end,
    double maxMs,
    double delayMs,
  ) {
    final onsets = m.onsets;
    final first = _measures[run.first];
    // Quando a página aparece: 0 na primeira; senão, quando termina a
    // conclusão da virada anterior.
    var appear = 0.0;
    if (prev != null) {
      appear = first.startMs;
      if (prev.page == run.page - 1) {
        appear += _dOf(_measures[prev.last], maxMs);
      }
    }
    final single = onsets.length == 1;
    // Uma nota só: a conclusão começa `delayMs` após o destaque — mas não
    // antes de a haste ter terminado de entrar (se a página aparece depois
    // disso, a haste não pode surgir já no meio da conclusão).
    final concStart = single
        ? math.min(math.max(onsets.first.ms + delayMs, appear + d), m.endMs)
        : m.endMs;
    if (ms < appear || ms >= concStart + d) {
      return null;
    }
    // Posição-alvo antes da entrada e do fecho.
    var pos = onsets.first.x;
    for (var k = 1; k < onsets.length; k++) {
      final from = onsets[k - 1];
      final to = onsets[k];
      final dur = math.min(d, to.ms - from.ms);
      if (ms >= from.ms + dur) {
        pos = to.x;
      } else if (ms >= from.ms) {
        pos = from.x + (to.x - from.x) * (dur == 0 ? 1 : (ms - from.ms) / dur);
        break;
      } else {
        break;
      }
    }
    if (ms >= concStart) {
      return pos + (end - pos) * ((ms - concStart) / d);
    }
    if (ms < appear + d) {
      return pos * ((ms - appear) / d);
    }
    return pos;
  }
}
