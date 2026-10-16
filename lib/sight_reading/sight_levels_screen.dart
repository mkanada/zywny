import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'sight_progress.dart';
import 'sight_steps.dart';

/// Os níveis do treino de leitura, do 1a ao 20d, cada passo com a sua
/// descrição. Um passo já feito volta ao toque; "Reiniciar" leva ao 1a. Os
/// passos depois do escolhido ficam para refazer. Os passos à frente do aluno
/// aparecem, mas não se abrem.
class SightLevelsScreen extends StatefulWidget {
  const SightLevelsScreen({super.key, required this.store});

  final SightReadingStore store;

  @override
  State<SightLevelsScreen> createState() => _SightLevelsScreenState();
}

class _SightLevelsScreenState extends State<SightLevelsScreen> {
  /// `null` enquanto o progresso guardado não chega.
  SightProgress? _progress;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.store.load().then((p) {
        if (mounted) setState(() => _progress = p);
      }),
    );
  }

  Future<void> _goTo(SightStep step) async {
    final reset = step.level == 1 && step.sub == 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reset ? 'Reiniciar a leitura?' : 'Voltar ao ${step.name}?'),
        content: Text(
          reset
              ? 'O treino volta ao 1a. Os passos feitos ficam para refazer.'
              : 'Os passos depois de ${step.name} ficam para refazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(reset ? 'Reiniciar' : 'Voltar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final next = SightProgress.startOf(step);
    setState(() => _progress = next);
    await widget.store.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      backgroundColor: kLibraryBg,
      appBar: AppBar(
        backgroundColor: kPanelSideBg,
        surfaceTintColor: Colors.transparent,
        title: Text('Níveis da leitura', style: serifDisplay(fontSize: 22)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: progress == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  // O fim da lista fica acima da barra de botões do Android.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    24 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    Text(
                      'Cada nível tem quatro passos, do a ao d. Com '
                      '$sightCleanToAdvance rodadas limpas (sem erro) em um '
                      'passo, o aluno sobe para o próximo. O 20d é o último.',
                      style: const TextStyle(fontSize: 13, color: kInkCaption),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Você está no ${progress.step.name}: '
                      '${progress.step.label}.',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    for (var level = 1; level <= sightLastLevel; level++)
                      _levelCard(progress, level),
                    TextButton.icon(
                      onPressed: () => unawaited(_goTo(sightSteps.first)),
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Reiniciar a leitura'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _levelCard(SightProgress progress, int level) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Text('Nível $level', style: serifDisplay(fontSize: 18)),
          ),
          for (var sub = 0; sub < sightSubLevels; sub++)
            _stepTile(progress, sightStep(level, sub)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _stepTile(SightProgress progress, SightStep step) {
    final current = progress.step.name == step.name;
    final behind = progress.isBehind(step);
    final ahead = !current && !behind;
    final String status;
    final Widget trailing;
    if (current) {
      status = 'agora · ${progress.clean} de $sightCleanToAdvance limpas';
      trailing = const Icon(Icons.play_circle, color: kAccentDark);
    } else if (behind) {
      status = 'feito · toque para voltar aqui';
      trailing = const Icon(Icons.check_circle, color: kAccentDark);
    } else {
      status = 'depois';
      trailing = const Icon(Icons.lock_outline, color: kInkCaption);
    }
    return ListTile(
      enabled: !ahead,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      leading: SizedBox(
        width: 40,
        child: Text(
          step.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(step.label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        status,
        style: const TextStyle(fontSize: 12, color: kInkCaption),
      ),
      trailing: trailing,
      onTap: behind ? () => unawaited(_goTo(step)) : null,
    );
  }
}
