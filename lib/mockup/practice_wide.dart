import 'package:flutter/material.dart';

import 'practice_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Barra de topo do layout largo (tablet/desktop) — `Main.dc.html` /
/// `TabletEstudo.dc.html`: "← Biblioteca" à esquerda, título da peça
/// centralizado, indicador de MIDI + engrenagem à direita. É aqui que o
/// título mora nas telas largas — no celular não há espaço para ele.
class WideTopBar extends StatelessWidget {
  const WideTopBar({
    super.key,
    required this.title,
    required this.composer,
    required this.midiConnected,
    required this.onBack,
    required this.onSettings,
  });

  final String title;
  final String composer;
  final bool midiConnected;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final (name, catalog) = splitTitle(title);
    final subtitle = catalog == null ? composer : '$composer · $catalog';
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: kPanelSideBg,
        border: Border(bottom: BorderSide(color: kBorderPanel)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: kInk,
                  padding: const EdgeInsets.only(
                    left: 6,
                    right: 12,
                  ),
                ),
                icon: const Icon(Icons.chevron_left, size: 20),
                label: const Text(
                  'Biblioteca',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: serifDisplay(fontSize: 20)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12.5, color: kInkCaption),
              ),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Material(
                  color: kChipBg,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () {},
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.piano, size: 18, color: kInk),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: midiConnected ? kGoodColor : kInkMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Teclado',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: kInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Configurações',
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined, color: kInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa de status do treino no layout largo — `Treino.dc.html` /
/// `TabletTreino.dc.html`: selo "Esperando você · mão X" + legenda, mais os
/// contadores por extenso ("23 certas"). Só aparece fora do modo Ouvir —
/// mesmo papel do selo+contadores compactos do celular
/// (`practice_screen.dart`), com espaço para o texto completo.
class WideStatusBar extends StatelessWidget {
  const WideStatusBar({
    super.key,
    required this.mode,
    required this.hand,
    required this.correct,
    required this.reminders,
    required this.mistakes,
  });

  final PracticeMode mode;
  final Hand hand;
  final int correct;
  final int reminders;
  final int mistakes;

  @override
  Widget build(BuildContext context) {
    final otherHand = switch (hand) {
      Hand.direita => 'esquerda',
      Hand.esquerda => 'direita',
      Hand.ambas => null,
    };
    final statusText = mode == PracticeMode.espera
        ? '${mode.statusVerb} você · mão ${hand.label.toLowerCase()}'
        : '${mode.statusVerb} · mão ${hand.label.toLowerCase()}';
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(bottom: BorderSide(color: kLibraryBg)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kAccentSoftBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: kAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kAccentDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (otherHand != null) ...[
                const SizedBox(width: 10),
                Text(
                  'a mão $otherHand toca junto, em cinza',
                  style: const TextStyle(fontSize: 13, color: kInkCaption),
                ),
              ],
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _counter(kGoodColor, correct, 'certas'),
              const SizedBox(width: 18),
              _counter(kOkColor, reminders, 'quase'),
              const SizedBox(width: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '×',
                    style: TextStyle(
                      color: kBadColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$mistakes ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: 'errada'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13.5, color: kInk),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counter(Color color, int count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$count ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: label),
            ],
          ),
          style: const TextStyle(fontSize: 13.5, color: kInk),
        ),
      ],
    );
  }
}

/// Setas de página sobre a partitura, no layout largo — `Main.dc.html`
/// mostra "página 1 de 7"; este mockup só tem uma imagem por peça, então
/// os botões ficam desabilitados (decorativos), como ficariam na última
/// página.
class WidePageArrow extends StatelessWidget {
  const WidePageArrow({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: null,
      disabledColor: kInkMuted,
      icon: Icon(icon, size: 24),
    );
  }
}

/// Barra de transporte inferior do layout largo — `Main.dc.html` /
/// `Treino.dc.html`: tudo que no celular mora atrás do botão "⋯" (modo,
/// mão, andamento, repetir, metrônomo) fica à vista aqui, mais uma barra
/// de progresso do compasso atual e um botão Parar.
class WideTransportBar extends StatelessWidget {
  const WideTransportBar({
    super.key,
    required this.playing,
    required this.onPlayPause,
    required this.onStop,
    required this.measure,
    required this.totalMeasures,
    required this.onMeasureTap,
    required this.tempoPercent,
    required this.onTempoStep,
    required this.hand,
    required this.onHandChanged,
    required this.mode,
    required this.onModeChanged,
    required this.repeatAB,
    required this.onRepeatABChanged,
    required this.metronome,
    required this.onMetronomeChanged,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final int measure;
  final int totalMeasures;
  final VoidCallback onMeasureTap;
  final int tempoPercent;
  final ValueChanged<int> onTempoStep;
  final Hand hand;
  final ValueChanged<Hand> onHandChanged;
  final PracticeMode mode;
  final ValueChanged<PracticeMode> onModeChanged;
  final bool repeatAB;
  final ValueChanged<bool> onRepeatABChanged;
  final bool metronome;
  final ValueChanged<bool> onMetronomeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: kPanelSideBg,
        border: Border(top: BorderSide(color: kBorderPanel)),
      ),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: playing ? 'Pausar' : 'Tocar',
            onPressed: onPlayPause,
            style: IconButton.styleFrom(
              backgroundColor: kAccent,
              minimumSize: const Size(48, 48),
            ),
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Parar',
            onPressed: onStop,
            color: kIconQuiet,
            icon: const Icon(Icons.stop_rounded, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: _progress(context)),
          const SizedBox(width: 20),
          _tempoStepper(),
          const SizedBox(width: 12),
          Segmented<Hand>(
            value: hand,
            options: Hand.values,
            labelOf: (h) => h.shortLabel,
            onChanged: onHandChanged,
            stretch: false,
          ),
          const SizedBox(width: 12),
          _modeDropdown(),
          const SizedBox(width: 12),
          Row(
            children: [
              _toggleIcon(
                icon: Icons.repeat,
                tooltip: 'Repetir trecho A-B',
                active: repeatAB,
                onTap: () => onRepeatABChanged(!repeatAB),
              ),
              _toggleIcon(
                icon: Icons.av_timer,
                tooltip: 'Metrônomo',
                active: metronome,
                onTap: () => onMetronomeChanged(!metronome),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context) {
    final fraction = (measure / totalMeasures).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onMeasureTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Compasso $measure ',
                      style: const TextStyle(
                        color: kInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: 'de $totalMeasures'),
                  ],
                ),
                style: const TextStyle(fontSize: 12.5, color: kInkCaption),
              ),
              const Text(
                'página 1 de 1',
                style: TextStyle(fontSize: 12.5, color: kInkCaption),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final x = constraints.maxWidth * fraction;
              return SizedBox(
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 5,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: kBorderPanel,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      left: 0,
                      width: x,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (x - 8).clamp(0.0, constraints.maxWidth - 16),
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: kSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: kAccent, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tempoStepper() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Mais devagar',
          onPressed: () => onTempoStep(-5),
          color: kIconQuiet,
          icon: const Icon(Icons.remove, size: 18),
        ),
        SizedBox(
          width: 56,
          child: Column(
            children: [
              Text(
                '$tempoPercent%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Text(
                'andamento',
                style: TextStyle(fontSize: 11, color: kInkCaption),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Mais depressa',
          onPressed: () => onTempoStep(5),
          color: kIconQuiet,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }

  Widget _modeDropdown() {
    return PopupMenuButton<PracticeMode>(
      tooltip: 'Modo de estudo',
      onSelected: onModeChanged,
      itemBuilder: (context) => [
        for (final m in PracticeMode.values)
          PopupMenuItem(value: m, child: Text(m.label)),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.only(left: 14, right: 10),
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(10),
          color: kSurface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode.label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: kInk),
          ],
        ),
      ),
    );
  }

  Widget _toggleIcon({
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      isSelected: active,
      color: kIconQuiet,
      selectedIcon: Icon(icon, color: kAccent),
      style: IconButton.styleFrom(
        backgroundColor: active ? kAccentSoftBg : Colors.transparent,
      ),
      icon: Icon(icon),
    );
  }
}
