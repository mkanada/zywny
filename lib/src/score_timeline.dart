// Linha do tempo da peça (A05a/A05b): índice de compassos e posição da haste.
//
// Tudo aqui é **função pura** de `(documento, posição)`, sem widget, sem
// `Ticker` e sem relógio: o `ScorePlayer` só empurra a posição para cá. Por
// isso `seek`, `pause` e `speed` funcionam sem código extra — a haste é
// derivada, nunca guardada.
//
// ÍNDICE DE COMPASSOS. `measures` é a ordem de **execução**: um compasso
// repetido aparece uma vez por passagem (E02b). "Em que compasso é ESTE nó"
// sai da **cena**: o nó de classe `measure` que é ancestral do id, num único
// percurso que também numera cada compasso em ordem de documento (para achar
// salto: a ocorrência seguinte não é o próximo compasso dessa ordem). "Que
// OCORRÊNCIA está tocando" sai do timemap: com `measureOn` (E01b), cada
// entrada com `measureOn` abre uma ocorrência; sem ele (`.vsb` de antes de
// E01b), pelas notas de `on`, abrindo uma ocorrência nova quando o par
// (compasso da cena, passagem) muda — os dois caminhos dão a mesma lista nas
// peças do corpus (E02b, critério 1). Ids são sempre resolvidos por
// `VsbDocument.sceneIdOf`/`passOf` (E02a) antes de entrar em `noteIds`, nas
// bboxes ou na comparação de compasso/passagem.
//
// Um salto (ocorrência cujo compasso não é o seguinte, na ordem de
// documento, do compasso da ocorrência anterior) sempre fecha o `_Run`
// corrente, mesmo **na mesma página** — é o que impede a haste (abaixo) de
// tratar esse trecho como uma virada de página comum.
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

/// Uma ocorrência de compasso na ordem de execução (E02b): um compasso
/// repetido aparece uma vez por passagem.
class MeasureInfo {
  const MeasureInfo({
    required this.id,
    required this.page,
    required this.pass,
    required this.timemapId,
    required this.noteIds,
    required this.startMs,
    required this.endMs,
  });

  /// `xml:id` do compasso **na cena** (compatível com quem já usa; o mesmo
  /// em todas as ocorrências do mesmo compasso).
  final String id;

  /// Página onde ele está.
  final int page;

  /// A execução: `1` na primeira vez que o compasso toca.
  final int pass;

  /// O id como está no timemap desta ocorrência (`id`, ou `id-rendN`). Sem
  /// `measureOn` no `.vsb` (antes de E01b), é reconstruído pela convenção do
  /// sufixo (`id` na passagem 1, `id-rendN` depois).
  final String timemapId;

  /// Notas do compasso nesta ocorrência, na ordem do timemap, resolvidas ao
  /// id da cena (E02a).
  final List<String> noteIds;

  /// `tstamp` da primeira nota desta ocorrência.
  final int startMs;

  /// `tstamp` da primeira nota da ocorrência seguinte (o `tstamp` final, na
  /// última).
  final int endMs;

  @override
  String toString() => 'MeasureInfo($id pass$pass p$page $startMs-$endMs)';
}

/// Uma nota (ou acorde) do compasso: o instante e o x da borda esquerda da
/// mais à esquerda, em unidades de viewBox.
class _Onset {
  const _Onset(this.ms, this.x);
  final double ms;
  final double x;
}

class _Measure {
  _Measure(this.id, this.page, this.pass, this.timemapId);
  final String id;
  final int page;
  final int pass;
  final String timemapId;
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

  /// id (nota, ou o próprio compasso) -> id do compasso ancestral na cena.
  final Map<String, String> _measureOfId = {};

  /// Página de cada compasso.
  final Map<String, int> _pageOfMeasure = {};

  /// Ordem de documento de cada compasso (0-based; para achar salto).
  final Map<String, int> _docOrderOfMeasure = {};

  /// Compassos em ordem de execução (A05a).
  List<MeasureInfo> get measureInfos => measures;

  int get measureCount => _measures.length;

  void _build() {
    final entriesList = [...?document.timemap]
      ..sort((a, b) => a.tstamp.compareTo(b.tstamp));
    entries = entriesList;
    durationMs = entriesList.isEmpty ? 0 : entriesList.last.tstamp;

    for (final page in document.pages) {
      _collect(page.root, page.index, null);
    }

    // com measureOn (E01b): cada entrada com measureOn abre uma ocorrência.
    // sem ele (.vsb de antes de E01b): pela 1ª nota de `on` que resolve a um
    // compasso conhecido, abrindo uma ocorrência nova quando o par
    // (compasso, passagem) muda — mesma regra do script de E01a.
    final hasMeasureOn = entriesList.any((e) => e.measureOn != null);

    _Measure? cur;
    String? curKey;

    void openOccurrence(String measureId, int pass, double ms) {
      final timemapId = pass == 1 ? measureId : '$measureId-rend$pass';
      cur = _Measure(measureId, _pageOfMeasure[measureId]!, pass, timemapId)
        ..startMs = ms;
      _measures.add(cur!);
      curKey = '$measureId\u0000$pass';
    }

    for (final e in entriesList) {
      if (hasMeasureOn) {
        final mo = e.measureOn;
        if (mo != null) {
          final measureId = document.sceneIdOf(mo);
          if (measureId != null) {
            openOccurrence(measureId, document.passOf(mo), e.tstamp);
          }
        }
      } else {
        for (final id in e.on) {
          final sceneId = document.sceneIdOf(id);
          if (sceneId == null) continue;
          final measureId = _measureOfId[sceneId];
          if (measureId == null) continue;
          final pass = document.passOf(id);
          final key = '$measureId\u0000$pass';
          if (key != curKey) {
            openOccurrence(measureId, pass, e.tstamp);
          }
          break; // só a 1ª nota de 'on' que resolve decide a ocorrência.
        }
      }
      final m = cur;
      if (m == null) {
        continue; // nada tocado ainda, ou id sem correspondente na cena.
      }
      final lefts = <_Measure, double>{};
      for (final id in e.on) {
        final sceneId = document.sceneIdOf(id);
        if (sceneId == null) continue;
        if (!m.noteIds.contains(sceneId)) {
          m.noteIds.add(sceneId);
        }
        final ref = document.geometry.elementOf(sceneId);
        if (ref != null) {
          final prev = lefts[m];
          lefts[m] = prev == null
              ? ref.bbox.left
              : math.min(prev, ref.bbox.left);
        }
      }
      lefts.forEach((mm, x) => mm.onsets.add(_Onset(e.tstamp, x)));
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
      final prev = i > 0 ? _measures[i - 1] : null;
      final isJump =
          prev != null &&
          _docOrderOfMeasure[m.id] != _docOrderOfMeasure[prev.id]! + 1;
      final last = _runs.isEmpty ? null : _runs.last;
      if (last != null && last.page == m.page && !isJump) {
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
          pass: m.pass,
          timemapId: m.timemapId,
          noteIds: List.unmodifiable(m.noteIds),
          startMs: m.startMs.round(),
          endMs: m.endMs.round(),
        ),
    ];
  }

  void _collect(SceneNode node, int page, String? measure) {
    if (node.hidden) {
      return;
    }
    var current = measure;
    if (node.className == 'measure' && node.id != null) {
      current = node.id;
      _pageOfMeasure[node.id!] = page;
      _docOrderOfMeasure.putIfAbsent(node.id!, () => _docOrderOfMeasure.length);
    }
    if (current != null && node.id != null) {
      _measureOfId[node.id!] = current;
    }
    for (final child in node.children) {
      if (child is SceneNode) {
        _collect(child, page, current);
      }
    }
  }

  /// Índices em [measures] das ocorrências de [id]: compasso ou nota, todas
  /// as passagens em que aparece; um id expandido (`-rend<N>`), só a sua
  /// (E02b).
  List<int> occurrencesOf(String id) {
    final sceneId = document.sceneIdOf(id);
    if (sceneId == null) {
      return const [];
    }
    final measureId = _measureOfId[sceneId];
    if (measureId == null) {
      return const [];
    }
    final expanded = id != sceneId;
    final pass = document.passOf(id);
    return [
      for (var i = 0; i < measures.length; i++)
        if (measures[i].id == measureId &&
            (!expanded || measures[i].pass == pass))
          i,
    ];
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
