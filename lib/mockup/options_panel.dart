import 'package:flutter/material.dart';

import 'practice_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Gaveta lateral de opções — `CelularPainel.dc.html`: modo, mão, tamanho da
/// partitura, andamento e os dois interruptores (repetir A-B, metrônomo).
class OptionsPanel extends StatelessWidget {
  const OptionsPanel({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.hand,
    required this.onHandChanged,
    required this.size,
    required this.onSizeChanged,
    required this.tempoPercent,
    required this.onTempoChanged,
    required this.repeatAB,
    required this.onRepeatABChanged,
    required this.metronome,
    required this.onMetronomeChanged,
    required this.onClose,
  });

  final PracticeMode mode;
  final ValueChanged<PracticeMode> onModeChanged;
  final Hand hand;
  final ValueChanged<Hand> onHandChanged;
  final ScoreSize size;
  final ValueChanged<ScoreSize> onSizeChanged;
  final int tempoPercent;
  final ValueChanged<int> onTempoChanged;
  final bool repeatAB;
  final ValueChanged<bool> onRepeatABChanged;
  final bool metronome;
  final ValueChanged<bool> onMetronomeChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      elevation: 8,
      child: SafeArea(
        left: false,
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Opções de estudo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close, color: kInk, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        label: 'MODO',
                        child: Segmented<PracticeMode>(
                          value: mode,
                          options: PracticeMode.values,
                          labelOf: (m) => m.label,
                          onChanged: onModeChanged,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        label: 'MÃO',
                        child: Segmented<Hand>(
                          value: hand,
                          options: Hand.values,
                          labelOf: (h) => h.label,
                          onChanged: onHandChanged,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        label: 'TAMANHO DA PARTITURA',
                        child: Segmented<ScoreSize>(
                          value: size,
                          options: ScoreSize.values,
                          labelOf: (s) => s.label,
                          onChanged: onSizeChanged,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ANDAMENTO',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.06,
                              color: kInkCaption,
                            ),
                          ),
                          Text(
                            '$tempoPercent%',
                            style: const TextStyle(
                              fontSize: 13,
                              color: kInk,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: tempoPercent.toDouble(),
                        min: 25,
                        max: 150,
                        activeColor: kAccent,
                        onChanged: (v) => onTempoChanged(v.round()),
                      ),
                      const SizedBox(height: 4),
                      _ToggleRow(
                        label: 'Repetir A-B',
                        value: repeatAB,
                        onChanged: onRepeatABChanged,
                      ),
                      _ToggleRow(
                        label: 'Metrônomo',
                        value: metronome,
                        onChanged: onMetronomeChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.06,
            color: kInkCaption,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: kAccent,
          ),
        ],
      ),
    );
  }
}
