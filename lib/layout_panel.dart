import 'package:flutter/material.dart';

import 'layout_options.dart';

/// Palette offered by [_ColorRow] for the highlight and page-turn-bar
/// pickers — curated and fixed, so the panel stays a predictable size and
/// the app doesn't need a color-picker package for two swatches.
const List<Color> kColorPalette = [
  Color(0xFFD32F2F), // vermelho — padrão do destaque
  Color(0xFF1565C0), // azul — padrão da haste
  Color(0xFFF57C00),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFF00838F),
  Color(0xFFAD1457),
  Color(0xFFF9A825),
  Color(0xFF283593),
  Color(0xFF5D4037),
];

/// Floating panel with the Verovio options of [kLayoutGroups], the on-screen
/// zoom and the appearance settings (destaque, halo, haste) — everything the
/// app lets the user tune, in one place.
///
/// It only edits [values]; `lib/main.dart` owns them and does the render.
/// Sliders report every step through [onChanged] and ask for the render once,
/// on release, through [onCommit]; toggles and choices do both at once. Zoom
/// and appearance are pure paint-time settings and apply immediately — they
/// never reach Verovio, so there's nothing to render.
class LayoutPanel extends StatelessWidget {
  const LayoutPanel({
    super.key,
    required this.values,
    required this.pageFitsBox,
    required this.fittedPage,
    required this.onChanged,
    required this.onCommit,
    required this.onFitChanged,
    required this.onReset,
    required this.onCopy,
    required this.onClose,
    required this.zoomSection,
    required this.highlightColor,
    required this.onHighlightColorChanged,
    required this.haloWidth,
    required this.onHaloWidthChanged,
    required this.barColor,
    required this.onBarColorChanged,
  });

  final Map<String, Object> values;

  /// Whether the page size follows the score area instead of the
  /// `pageWidth`/`pageHeight` values.
  final bool pageFitsBox;

  /// Page size the score area asks for, in tenths of a millimetre; null
  /// before the first layout.
  final Size? fittedPage;

  final void Function(String key, Object value) onChanged;
  final VoidCallback onCommit;
  final ValueChanged<bool> onFitChanged;
  final VoidCallback onReset;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  /// The on-screen zoom row (built in `lib/main.dart`, which owns the
  /// `TransformationController`); embedded here instead of floating over
  /// the score.
  final Widget zoomSection;

  /// Color of a highlighted note during playback.
  final Color highlightColor;
  final ValueChanged<Color> onHighlightColorChanged;

  /// Multiplier on the halo's blur radius; `0` turns it off.
  final double haloWidth;
  final ValueChanged<double> onHaloWidthChanged;

  /// Color of the page-turn sweep bar.
  final Color barColor;
  final ValueChanged<Color> onBarColorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Opções', style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  tooltip: 'Copiar opções (JSON)',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_all, size: 20),
                ),
                IconButton(
                  tooltip: 'Restaurar padrões',
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt, size: 20),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('Zoom', style: theme.textTheme.labelLarge),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: zoomSection,
                ),
                ExpansionTile(
                  key: const PageStorageKey<String>('Destaque e virada'),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  dense: true,
                  title: Text(
                    'Destaque e virada de página',
                    style: theme.textTheme.labelLarge,
                  ),
                  children: [
                    _ColorRow(
                      label: 'Cor da nota destacada',
                      value: highlightColor,
                      onChanged: onHighlightColorChanged,
                    ),
                    _SliderRow(
                      label: 'Largura do halo',
                      value: haloWidth,
                      min: 0,
                      max: 3,
                      formatValue: (v) =>
                          v <= 0 ? 'desligado' : '${v.toStringAsFixed(1)}×',
                      onChanged: onHaloWidthChanged,
                    ),
                    _ColorRow(
                      label: 'Cor da haste de virada',
                      value: barColor,
                      onChanged: onBarColorChanged,
                    ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Página acompanha a área'),
                  subtitle: Text(_fitSubtitle()),
                  value: pageFitsBox,
                  onChanged: onFitChanged,
                ),
                for (final group in kLayoutGroups)
                  ExpansionTile(
                    key: PageStorageKey<String>(group.title),
                    initiallyExpanded: group == kLayoutGroups.first,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    dense: true,
                    title: Text(group.title, style: theme.textTheme.labelLarge),
                    children: [
                      for (final option in group.options)
                        _OptionRow(
                          option: option,
                          value: _shownValue(option),
                          enabled:
                              !(pageFitsBox &&
                                  kPageSizeKeys.contains(option.key)),
                          onChanged: onChanged,
                          onCommit: onCommit,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fitSubtitle() {
    final page = fittedPage;
    if (!pageFitsBox) return 'usa a largura e a altura abaixo';
    if (page == null) return 'aguardando o primeiro layout';
    return '${page.width.round()}×${page.height.round()} '
        '(${(page.width / 10).round()}×${(page.height / 10).round()} mm)';
  }

  /// While the page follows the score area the size sliders show what is
  /// actually used, not the stale manual value.
  Object _shownValue(LayoutOption option) {
    final page = fittedPage;
    if (pageFitsBox && page != null) {
      if (option.key == 'pageWidth') return page.width.round();
      if (option.key == 'pageHeight') return page.height.round();
    }
    return values[option.key] ?? option.defaultValue;
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onCommit,
  });

  final LayoutOption option;
  final Object value;
  final bool enabled;
  final void Function(String key, Object value) onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modified = value != option.defaultValue;
    final style = theme.textTheme.bodySmall!.copyWith(
      color: modified ? theme.colorScheme.primary : null,
      fontWeight: modified ? FontWeight.w600 : null,
    );

    Widget label(Widget trailing) {
      Widget text = Text(option.label, style: style);
      if (option.tooltip != null) {
        text = Tooltip(message: option.tooltip!, child: text);
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: text),
            trailing,
          ],
        ),
      );
    }

    switch (option.kind) {
      case LayoutOptionKind.toggle:
        return SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(option.label, style: style),
          value: value as bool,
          onChanged: (v) {
            onChanged(option.key, v);
            onCommit();
          },
        );
      case LayoutOptionKind.choice:
        return label(
          DropdownButton<String>(
            isDense: true,
            value: value as String,
            style: style.copyWith(color: theme.colorScheme.onSurface),
            items: [
              for (final c in option.choices)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) {
              if (v == null) return;
              onChanged(option.key, v);
              onCommit();
            },
          ),
        );
      case LayoutOptionKind.integer:
      case LayoutOptionKind.decimal:
        final isInt = option.kind == LayoutOptionKind.integer;
        // Decimals: hundredths for the 0–1 style ranges, tenths otherwise.
        final decimals = isInt ? 0 : (option.max - option.min <= 1.5 ? 2 : 1);
        final step = isInt ? 1.0 : (decimals == 2 ? 0.01 : 0.1);
        final lo = option.min.toDouble();
        final hi = (option.softMax ?? option.max).toDouble();
        final steps = ((hi - lo) / step).round();
        final number = (value as num).toDouble();
        return Column(
          children: [
            label(
              Text(
                isInt ? '${number.round()}' : number.toStringAsFixed(decimals),
                style: style,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: number.clamp(lo, hi),
                min: lo,
                max: hi,
                divisions: steps <= 1000 ? steps : null,
                onChanged: enabled
                    ? (v) => onChanged(
                        option.key,
                        isInt
                            ? v.round()
                            : double.parse(v.toStringAsFixed(decimals)),
                      )
                    : null,
                onChangeEnd: enabled ? (_) => onCommit() : null,
              ),
            ),
          ],
        );
    }
  }
}

/// A label and a row of tappable color swatches from [kColorPalette]. If
/// [value] isn't one of them (a leftover from a previous session, say), it's
/// prepended so the current color is always shown and stays selectable.
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = kColorPalette.contains(value)
        ? kColorPalette
        : [value, ...kColorPalette];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in palette)
                _Swatch(
                  color: c,
                  selected: c == value,
                  onTap: () => onChanged(c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.black26,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 16,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

/// A generic labelled slider for a setting that isn't a Verovio option (so
/// doesn't fit [LayoutOption]/[_OptionRow]) and applies immediately — no
/// `onCommit`/render step.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.formatValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double value) formatValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: style)),
              Text(formatValue(value), style: style),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / 0.1).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
