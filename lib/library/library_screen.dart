import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../midi/midi_device_manager.dart';
import '../midi/midi_device_picker.dart';
import '../settings/app_settings.dart';
import '../settings/general_settings_panel.dart';
import '../settings/hymn_settings.dart';
import '../trail/trail_progress.dart';
import '../trail/trail_widgets.dart' show TrailProgressBar, trailResumeText;
import '../ui/theme.dart';
import 'hymn.dart';
import 'hymn_progress.dart';
import 'library_sort.dart';

/// O que a tela de partitura recebe da biblioteca ao abrir um hino.
@immutable
class OpenedHymn {
  const OpenedHymn({
    required this.hymn,
    required this.scorePath,
    required this.midiDeviceManager,
    required this.onPracticeScore,
    required this.appSettings,
    required this.hymnSettings,
    required this.onHymnSettingsChanged,
    required this.trailProgress,
  });

  final Hymn hymn;

  /// O `.musicxml` do hino já descompactado em disco.
  final String scorePath;

  /// O mesmo gerenciador da biblioteca: o teclado conectado aqui continua
  /// conectado na partitura (e vice-versa).
  final MidiDeviceManager midiDeviceManager;

  /// Precisão (0–100) de um treino avaliado que terminou.
  final ValueChanged<int> onPracticeScore;

  /// As configurações gerais do app (som, MIDI, cores) — as mesmas que a
  /// biblioteca edita.
  final AppSettings appSettings;

  /// O que este hino tinha guardado (layout, andamento, mão), e para onde
  /// vai o que o usuário mudar nele.
  final HymnSettings hymnSettings;
  final ValueChanged<HymnSettings> onHymnSettingsChanged;

  /// O progresso da trilha (o mesmo da biblioteca, para a linha do hino
  /// atualizar ao voltar da partitura sem reabrir nada — J09).
  final TrailProgressStore trailProgress;
}

/// Tela inicial, em retrato — artboard `CelularBiblioteca.dc.html` do
/// artefato "zywny — interface de estudo", com os hinos embutidos no lugar
/// das partituras de exemplo. Não há "abrir arquivo": o app não importa
/// música.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.scoreBuilder,
    this.loadCatalog = HymnCatalog.load,
    this.extractScore = HymnCatalog.extractScore,
    this.progress,
    this.appSettings,
    this.hymnSettings,
    this.trailProgress,
  });

  /// Constrói a tela de partitura do hino aberto (`ScoreHomePage`).
  final Widget Function(BuildContext context, OpenedHymn opened) scoreBuilder;

  /// Trocáveis nos testes, que não têm `assets/hinos/` nem disco.
  final Future<HymnCatalog> Function() loadCatalog;
  final Future<String> Function(Hymn hymn) extractScore;
  final HymnProgressStore? progress;
  final AppSettings? appSettings;
  final HymnSettingsStore? hymnSettings;

  /// Resumos da trilha por hino (J09); os testes injetam com dados.
  final TrailProgressStore? trailProgress;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final Future<HymnCatalog> _catalog = widget.loadCatalog();
  late final HymnProgressStore _progress =
      widget.progress ?? HymnProgressStore();
  final MidiDeviceManager _midi = MidiDeviceManager();

  /// Configurações gerais (uma só para o app inteiro, lida ao abrir) e as
  /// de cada hino (lidas quando o hino abre).
  late final AppSettings _settings = widget.appSettings ?? AppSettings();
  late final Future<void> _settingsLoaded = _settings.load();
  late final HymnSettingsStore _hymnSettings =
      widget.hymnSettings ?? HymnSettingsStore();
  late final TrailProgressStore _trail =
      widget.trailProgress ?? TrailProgressStore();

  SortState _sort = const SortState();
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  bool _opening = false;

  /// Há pastilhas de ordenação fora da tela, à direita (o esmaecido na borda
  /// avisa; some ao rolar até o fim — U14).
  bool _moreChips = true;

  @override
  void initState() {
    super.initState();
    _lockPortrait();
    unawaited(_progress.load());
    unawaited(_trail.load());
    unawaited(_settingsLoaded);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _midi.dispose();
    if (widget.progress == null) _progress.dispose();
    if (widget.trailProgress == null) _trail.dispose();
    if (widget.appSettings == null) _settings.dispose();
    super.dispose();
  }

  /// A biblioteca é para ler em retrato no celular; a partitura, em
  /// paisagem (quem vira é a própria tela de partitura). No desktop isto não
  /// vale nada.
  void _lockPortrait() {
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    // A biblioteca mostra a barra de status (a partitura a esconde, U10).
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  Future<void> _open(Hymn hymn) async {
    if (_opening) return;
    _opening = true;
    try {
      final path = await widget.extractScore(hymn);
      final hymnSettings = await _hymnSettings.load(hymn.number);
      await _settingsLoaded;
      if (!mounted) return;
      unawaited(_progress.markOpened(hymn.number));
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => widget.scoreBuilder(
            context,
            OpenedHymn(
              hymn: hymn,
              scorePath: path,
              midiDeviceManager: _midi,
              onPracticeScore: (score) =>
                  unawaited(_progress.recordScore(hymn.number, score)),
              appSettings: _settings,
              hymnSettings: hymnSettings,
              onHymnSettingsChanged: (changed) =>
                  unawaited(_hymnSettings.save(hymn.number, changed)),
              trailProgress: _trail,
            ),
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não deu para abrir o hino ${hymn.number}: $e')),
      );
    } finally {
      _opening = false;
      if (mounted) _lockPortrait();
    }
  }

  /// Som, teclado MIDI e cores — o que vale para todos os hinos. (O que é
  /// de um hino só é mexido com ele aberto.)
  void _openSettings() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => GeneralSettingsScreen(
            settings: _settings,
            midiDeviceManager: _midi,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLibraryCardBg,
      // Fundo claro: ícones escuros na barra de status.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    return SizedBox.expand(
      child: SafeArea(
        bottom: false,
        child: Center(
          // Numa janela larga (desktop) a lista não se esparrama: fica na
          // medida de leitura de um celular deitado.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FutureBuilder<HymnCatalog>(
                future: _catalog,
                builder: (context, snapshot) => ListenableBuilder(
                  listenable: Listenable.merge([_progress, _trail]),
                  builder: (context, _) => _content(snapshot),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(AsyncSnapshot<HymnCatalog> snapshot) {
    final catalog = snapshot.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(catalog),
        const SizedBox(height: 14),
        _searchField(),
        const SizedBox(height: 14),
        if (catalog != null) ...[
          if (_continuing(catalog) case final hymn?) ...[
            _continueCard(hymn),
            const SizedBox(height: 14),
          ],
          _sortChips(),
          const SizedBox(height: 4),
          Expanded(child: _list(catalog)),
        ] else
          Expanded(
            child: Center(
              child: snapshot.hasError
                  ? const Text(
                      'Os hinos não vieram com esta compilação.\n'
                      'Gere-os com tool/build_hymn_assets.py e compile de novo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kInkCaption),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Hymn? _continuing(HymnCatalog catalog) {
    final number = _progress.lastOpenedNumber;
    if (number == null) return null;
    for (final h in catalog.hymns) {
      if (h.number == number) return h;
    }
    return null;
  }

  Widget _header(HymnCatalog? catalog) {
    return Row(
      children: [
        Text('Hinário', style: serifDisplay(fontSize: 30)),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              catalog == null ? '' : '${catalog.hymns.length} hinos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: kInkCaption),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Configurações gerais',
          onPressed: _openSettings,
          color: kIconQuiet,
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 4),
        // Com a palavra ao lado do ícone o botão ficou mais largo: em
        // cabeçalho apertado ele encolhe em vez de estourar a linha.
        Flexible(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: MidiStatusPill(deviceManager: _midi),
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar número, título ou autor',
          hintStyle: const TextStyle(color: kInkCaption),
          prefixIcon: const Icon(Icons.search, color: kInkCaption, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar a busca',
                  onPressed: _clearSearch,
                  iconSize: 18,
                  color: kInkCaption,
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: kSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: border(kBorder),
          enabledBorder: border(kBorder),
          focusedBorder: border(kAccent),
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Widget _continueCard(Hymn hymn) {
    final progress = _progress[hymn.number];
    final trail = _trail[hymn.number];
    final started = trail.total > 0;
    // A etapa em que parou, numa linha própria; o resto, menor, embaixo.
    final resume = trail.resume;
    final stage = resume == null ? null : trailResumeText(resume);
    final details = [
      'Hino ${hymn.number}',
      if (progress?.lastOpened case final at?) whenStudied(at, DateTime.now()),
      if (progress?.bestScore case final score?) 'melhor $score%',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CONTINUAR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                        color: kAccent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hymn.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    if (stage != null)
                      Text(
                        stage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: kInk),
                      ),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kInkCaption),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Tooltip(
                message: 'Continuar estudo',
                child: Material(
                  color: kAccent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => unawaited(_open(hymn)),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // O progresso do hino na base do cartão.
          if (started) ...[
            const SizedBox(height: 10),
            TrailProgressBar(
              done: trail.finalApproved ? trail.total : trail.done,
              skipped: trail.finalApproved ? 0 : trail.skipped,
              total: trail.total,
              height: 5,
            ),
          ],
        ],
      ),
    );
  }

  void _updateMoreChips(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 1;
    if (more == _moreChips) return;
    // As notificações chegam durante o layout: o redesenho espera o quadro.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && more != _moreChips) setState(() => _moreChips = more);
    });
  }

  Widget _sortChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ORDENAR POR',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.75,
            color: kInkCaption,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) {
              _updateMoreChips(n.metrics);
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                _updateMoreChips(n.metrics);
                return false;
              },
              // Um esmaecido na borda direita enquanto houver pastilhas
              // fora da tela: "Pontuação" e "Compositor" têm pista.
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  colors: [
                    Colors.black,
                    Colors.black,
                    _moreChips ? Colors.transparent : Colors.black,
                  ],
                  stops: const [0, 0.88, 1],
                ).createShader(rect),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: SortKey.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final key = SortKey.values[i];
                    return _SortChip(
                      label: '${labelFor(key)}${_sort.arrowFor(key)}',
                      selected: _sort.key == key,
                      onTap: () => setState(() => _sort = _sort.toggled(key)),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(HymnCatalog catalog) {
    final hymns = filterHymns(
      sortedHymns(catalog.hymns, _sort, _progress),
      _query,
    );
    if (hymns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _query.trim().isEmpty
                  ? 'Nenhum hino encontrado'
                  : 'Nenhum hino com “${_query.trim()}”.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kInkCaption),
            ),
            if (_query.isNotEmpty)
              TextButton(
                onPressed: _clearSearch,
                child: const Text('Limpar a busca'),
              ),
          ],
        ),
      );
    }
    final now = DateTime.now();
    return ListView.builder(
      // 600 linhas iguais: altura fixa deixa a rolagem e a barra exatas.
      itemExtent: 64,
      itemCount: hymns.length,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      itemBuilder: (context, i) {
        final hymn = hymns[i];
        return _HymnRow(
          hymn: hymn,
          progress: _progress[hymn.number],
          trail: _trail[hymn.number],
          now: now,
          match: hymnMatch(hymn, _query),
          onTap: () => unawaited(_open(hymn)),
        );
      },
    );
  }
}

class _HymnRow extends StatelessWidget {
  const _HymnRow({
    required this.hymn,
    required this.progress,
    required this.trail,
    required this.now,
    required this.onTap,
    this.match,
  });

  /// Onde a busca casou neste hino (U14); `null` sem busca.
  final HymnMatch? match;

  final Hymn hymn;
  final HymnProgress? progress;

  /// Progresso da trilha (resumo pronto do JSON, sem plano — J09). Sem nada
  /// iniciado (`total == 0`), a linha fica como hoje.
  final TrailProgress trail;
  final DateTime now;
  final VoidCallback onTap;

  /// O que a segunda linha diz de autoria. Com busca que casou só no
  /// letrista ou só no título original, mostra esse campo (com o motivo) no
  /// lugar do compositor; fora disso, o compositor, com o que casou em
  /// negrito.
  TextSpan _matchedAuthor() {
    const style = TextStyle(fontSize: 13, color: kInkCaption);
    final m = match;
    if (m != null && m.composer.isEmpty) {
      final lyricist = hymn.lyricist;
      if (lyricist != null && m.lyricist.isNotEmpty) {
        return TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'letra: '),
            _highlighted(lyricist, m.lyricist, style),
          ],
        );
      }
      final original = hymn.originalTitle;
      if (original != null && m.title.isEmpty && m.originalTitle.isNotEmpty) {
        return TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'original: '),
            _highlighted(original, m.originalTitle, style),
          ],
        );
      }
    }
    return _highlighted(hymn.composer, m?.composer ?? const [], style);
  }

  @override
  Widget build(BuildContext context) {
    final score = progress?.bestScore;
    final started = trail.total > 0;
    // O que vem depois do compositor, sem reticências: é ele quem cede.
    final rest = [
      if (hymn.level case final level?) 'nível $level',
      if (progress?.lastOpened case final at?) whenStudied(at, now),
      if (score != null) 'melhor $score%',
    ].map((part) => ' · $part').join();
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorderSoft)),
        ),
        child: Row(
          children: [
            // O número do hinário, na coluna da esquerda: é por ele que se
            // acha um hino. Algarismos de largura fixa para alinhar.
            SizedBox(
              width: 38,
              child: Text(
                '${hymn.number}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kInkCaption,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text.rich(
                    _highlighted(
                      hymn.title,
                      match?.title ?? const [],
                      const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  _SubtitleLine(composer: _matchedAuthor(), rest: rest),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Só quem começou a trilha tem progresso à direita; sem ela, a
            // coluna fica vazia (nada de "—" em 600 linhas).
            if (started) _TrailCell(trail: trail),
          ],
        ),
      ),
    );
  }
}

/// [text] com os trechos [ranges] em negrito e na cor de destaque.
TextSpan _highlighted(
  String text,
  List<TextSpanRange> ranges,
  TextStyle style,
) {
  if (ranges.isEmpty) return TextSpan(text: text, style: style);
  final bold = style.copyWith(fontWeight: FontWeight.w800, color: kAccentDark);
  final spans = <TextSpan>[];
  var at = 0;
  for (final r in ranges) {
    final start = r.start.clamp(0, text.length);
    final end = r.end.clamp(start, text.length);
    if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
    if (end > start) {
      spans.add(TextSpan(text: text.substring(start, end), style: bold));
    }
    at = end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: style, children: spans);
}

/// Segunda linha da lista: o compositor cede (reticências) para que "nível",
/// "quando" e "melhor" apareçam inteiros.
class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({required this.composer, required this.rest});

  /// O compositor (ou o campo que casou na busca), já com os negritos.
  final TextSpan composer;
  final String rest;

  static const _style = TextStyle(fontSize: 13, color: kInkCaption);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: rest, style: _style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final composerMax = (box.maxWidth - painter.width).clamp(
          0.0,
          box.maxWidth,
        );
        painter.dispose();
        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: composerMax),
              child: Text.rich(
                composer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (rest.isNotEmpty)
              Flexible(
                child: Text(
                  rest,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A coluna da direita da linha: a barra do progresso da trilha e, embaixo,
/// "13/75" (e as puladas). Concluída: a barra cheia e o ✓.
class _TrailCell extends StatelessWidget {
  const _TrailCell({required this.trail});

  final TrailProgress trail;

  @override
  Widget build(BuildContext context) {
    final concluded = trail.finalApproved;
    return SizedBox(
      width: 84,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrailProgressBar(
                done: concluded ? trail.total : trail.done,
                skipped: concluded ? 0 : trail.skipped,
                total: trail.total,
                width: 48,
              ),
              if (concluded)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Trilha concluída',
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: kGoodColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${trail.done}/${trail.total}'
              '${trail.skipped > 0 ? ' · ${trail.skipped} pul.' : ''}',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                color: kInkCaption,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kInk : kSurface,
      shape: StadiumBorder(side: BorderSide(color: selected ? kInk : kBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : kInk,
            ),
          ),
        ),
      ),
    );
  }
}
