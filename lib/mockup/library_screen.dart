import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'practice_state.dart';
import 'practice_screen.dart';
import 'theme.dart';

/// Tela inicial, em retrato — `CelularBiblioteca.dc.html`.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  SortState _sort = const SortState();
  String _query = '';
  bool _midiConnected = true;

  // A peça "em andamento" mostrada no card "continuar" — mockup fixo, como
  // no artboard (Little bird, compasso 4 de 41, Espera, mão direita, 80%).
  static const _continuing = PracticeArgs(
    title: 'Little bird, op. 43 nº 4',
    composer: 'Edvard Grieg',
    mode: PracticeMode.espera,
    hand: Hand.direita,
    tempoPercent: 80,
    measure: 4,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  List<Piece> get _filtered {
    final pieces = sortedPieces(kPieces, _sort);
    if (_query.trim().isEmpty) return pieces;
    final q = _query.toLowerCase();
    return pieces
        .where(
          (p) =>
              p.title.toLowerCase().contains(q) ||
              p.composer.toLowerCase().contains(q),
        )
        .toList();
  }

  void _openPiece(PracticeArgs args) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PracticeScreen(args: args)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLibraryBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 14),
              _searchField(),
              const SizedBox(height: 14),
              _continueCard(),
              const SizedBox(height: 14),
              _sortChips(),
              const SizedBox(height: 4),
              Expanded(child: _list()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Biblioteca', style: serifDisplay(fontSize: 30)),
        Row(
          children: [
            _IconPillButton(
              tooltip: _midiConnected
                  ? 'Teclado MIDI conectado'
                  : 'Teclado MIDI desconectado',
              onTap: () => setState(() => _midiConnected = !_midiConnected),
              background: kChipBg,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.piano, size: 18, color: kInk),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _midiConnected ? kGoodColor : kInkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _IconPillButton(
              tooltip: 'Abrir arquivo',
              onTap: () {},
              background: kAccent,
              circle: true,
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar título ou compositor',
          hintStyle: const TextStyle(color: kInkCaption),
          prefixIcon: const Icon(Icons.search, color: kInkCaption, size: 20),
          filled: true,
          fillColor: kSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kAccent),
          ),
        ),
      ),
    );
  }

  Widget _continueCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSoft),
      ),
      child: Row(
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
                    letterSpacing: 0.06,
                    color: kAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _continuing.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                Text(
                  'Compasso ${_continuing.measure} de '
                  '${_continuing.totalMeasures} · ${_continuing.mode.label} · '
                  'mão ${_continuing.hand.label.toLowerCase()} · '
                  '${_continuing.tempoPercent}%',
                  style: const TextStyle(fontSize: 13, color: kInkCaption),
                ),
              ],
            ),
          ),
          _IconPillButton(
            tooltip: 'Continuar estudo',
            onTap: () => _openPiece(_continuing),
            background: kAccent,
            circle: true,
            size: 48,
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChips() {
    const order = [
      SortKey.recent,
      SortKey.score,
      SortKey.title,
      SortKey.composer,
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: order.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final key = order[i];
          final selected = _sort.key == key;
          return _SortChip(
            label: '${labelFor(key)}${_sort.arrowFor(key)}',
            selected: selected,
            onTap: () => setState(() => _sort = _sort.toggled(key)),
          );
        },
      ),
    );
  }

  Widget _list() {
    final pieces = _filtered;
    if (pieces.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma partitura encontrada',
          style: TextStyle(color: kInkCaption),
        ),
      );
    }
    return ListView.separated(
      itemCount: pieces.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: kBorderSoft),
      itemBuilder: (context, i) {
        final p = pieces[i];
        return InkWell(
          onTap: () => _openPiece(PracticeArgs(title: p.title, composer: p.composer)),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                        ),
                      ),
                      Text(
                        '${p.composer} · ${whenStudied(p.daysAgo)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: kInkCaption,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreBandColor(p.score),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 30,
                  child: Text(
                    p.score?.toString() ?? '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.score == null ? kInkMuted : kInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? kInk : kBorder),
          ),
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

class _IconPillButton extends StatelessWidget {
  const _IconPillButton({
    required this.tooltip,
    required this.onTap,
    required this.background,
    required this.child,
    this.circle = false,
    this.size = 44,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Color background;
  final Widget child;
  final bool circle;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (circle) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Center(child: child)),
          ),
        ),
      );
    }
    // Pílula que abraça o conteúdo (ex.: o indicador de MIDI), não um
    // círculo fixo — `height:44px;padding:0 10px;border-radius:22px` no
    // artboard.
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: size,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
