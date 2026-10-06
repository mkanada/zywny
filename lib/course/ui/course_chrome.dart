// Moldura das telas dos cursos (curso, lição, exercício): o tamanho do texto
// escolhido no "Aa" e o cabeçalho que, no celular deitado, sai do caminho.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../settings/app_settings.dart';
import '../../ui/theme.dart';

/// Celular deitado: a altura é curta e cada linha do cabeçalho pesa. O
/// cabeçalho fica mais baixo e, nas telas que rolam, some ao descer e volta
/// ao subir.
bool courseCompactHeader(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height && size.height < 500;
}

/// Altura da barra do cabeçalho conforme [courseCompactHeader].
double courseToolbarHeight(BuildContext context) =>
    courseCompactHeader(context) ? 44 : kToolbarHeight;

/// Ampliação base das partituras do curso no celular, antes do "Aa": com o
/// papel 1:1 (mesmo `unit` dos hinos) as notas ainda saíam miúdas perto do
/// texto da lição.
const double kPhoneLessonScoreZoom = 1.3;

/// Largura do papel do Verovio (pixels do dispositivo, ver
/// `lessonScoreLayout`) para uma caixa de [boxWidth] pontos lógicos. O
/// `ScoreView` estica a página até a largura da caixa: papel mais estreito
/// = partitura maior. Segue o tamanho do texto da tela (o "Aa" e a fonte do
/// sistema), então aumentar a letra aumenta a partitura junto.
double lessonScorePaperPx(BuildContext context, double boxWidth) {
  final phone =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final zoom =
      (phone ? kPhoneLessonScoreZoom : 1.0) *
      MediaQuery.textScalerOf(context).scale(1);
  return (boxWidth * MediaQuery.devicePixelRatioOf(context) / zoom)
      .roundToDouble();
}

/// Passos do "Aa" (multiplicam o tamanho de fonte do sistema).
const kCourseTextScales = [0.85, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

/// Aplica [AppSettings.courseTextScale] ao texto de [child], por cima do
/// tamanho de fonte do sistema.
class CourseTextScale extends StatelessWidget {
  const CourseTextScale({
    super.key,
    required this.settings,
    required this.child,
  });

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, child) {
        final factor = settings.courseTextScale;
        if (factor == 1.0) return child!;
        final system = MediaQuery.textScalerOf(context);
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(system.scale(1) * factor)),
          child: child!,
        );
      },
      child: child,
    );
  }
}

/// Botão "Aa" do cabeçalho: abre a escolha do tamanho do texto.
class CourseTextSizeButton extends StatelessWidget {
  const CourseTextSizeButton({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Tamanho do texto',
      icon: const Icon(Icons.text_fields),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => _TextSizeSheet(settings: settings),
      ),
    );
  }
}

class _TextSizeSheet extends StatelessWidget {
  const _TextSizeSheet({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final current = settings.courseTextScale;
        double? step(int direction) {
          final candidates = direction > 0
              ? kCourseTextScales.where((s) => s > current + 0.001)
              : kCourseTextScales.reversed.where((s) => s < current - 0.001);
          return candidates.isEmpty ? null : candidates.first;
        }

        final smaller = step(-1);
        final bigger = step(1);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tamanho do texto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(
                      tooltip: 'Diminuir o texto',
                      onPressed: smaller == null
                          ? null
                          : () => settings.courseTextScale = smaller,
                      icon: const Icon(Icons.text_decrease),
                    ),
                    SizedBox(
                      width: 88,
                      child: Text(
                        '${(current * 100).round()}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: kInk),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Aumentar o texto',
                      onPressed: bigger == null
                          ? null
                          : () => settings.courseTextScale = bigger,
                      icon: const Icon(Icons.text_increase),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: current == 1.0
                      ? null
                      : () => settings.courseTextScale = 1.0,
                  child: const Text('Tamanho normal'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tela de curso que rola inteira: o cabeçalho é uma `SliverAppBar` — fixo
/// em pé; no celular deitado ([courseCompactHeader]) baixo, sumindo ao rolar
/// para baixo e voltando ao rolar para cima. O conteúdo fica numa coluna de
/// até [maxWidth], centrada, com o texto no tamanho do "Aa".
class CourseScrollScaffold extends StatelessWidget {
  const CourseScrollScaffold({
    super.key,
    required this.settings,
    required this.backgroundColor,
    required this.title,
    required this.children,
    this.leading,
    this.actions = const [],
    this.topPadding = 0,
    this.onScroll,
    this.maxWidth = 720,
  });

  final AppSettings settings;
  final Color backgroundColor;
  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final List<Widget> children;
  final double topPadding;
  final NotificationListenerCallback<ScrollNotification>? onScroll;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final compact = courseCompactHeader(context);
    final view = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      backgroundColor: backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Coluna centrada de até [maxWidth]; 16 de folga nos lados, mais a
          // barra do sistema quando o celular está deitado.
          final extra = (constraints.maxWidth - maxWidth) / 2;
          final left = 16 + (extra > 0 ? extra : 0) + view.left;
          final right = 16 + (extra > 0 ? extra : 0) + view.right;
          final scroll = CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: kPanelSideBg,
                surfaceTintColor: Colors.transparent,
                pinned: !compact,
                floating: compact,
                snap: compact,
                toolbarHeight: courseToolbarHeight(context),
                leading: leading,
                automaticallyImplyLeading: leading == null,
                title: title,
                actions: actions,
              ),
              SliverPadding(
                // O fim fica acima da barra de botões do Android.
                padding: EdgeInsets.fromLTRB(
                  left,
                  topPadding,
                  right,
                  24 + view.bottom,
                ),
                sliver: CourseTextScale(
                  settings: settings,
                  child: SliverList(
                    delegate: SliverChildListDelegate(children),
                  ),
                ),
              ),
            ],
          );
          final callback = onScroll;
          return callback == null
              ? scroll
              : NotificationListener<ScrollNotification>(
                  onNotification: callback,
                  child: scroll,
                );
        },
      ),
    );
  }
}
