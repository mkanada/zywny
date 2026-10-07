// I05 — `zywny-video`: cartão que abre o vídeo no navegador (D-LIC-VIDEO).
//
// Sem miniatura: seria buscar na rede sem toque (I05). O cartão mostra o ícone,
// a legenda e o domínio do link ("youtube.com"); o toque abre fora do app.

import 'package:flutter/material.dart';

import '../../ui/theme.dart';

import 'package:zywny_course_format/course_model.dart';

import 'markdown_view.dart' show LessonLinkOpener, defaultLessonLinkOpener;

/// O domínio de [link] ("youtube.com"), ou o próprio texto se não der para ler.
String videoDomain(String link) {
  final uri = Uri.tryParse(link);
  final host = uri?.host ?? '';
  if (host.isEmpty) return link;
  return host.startsWith('www.') ? host.substring(4) : host;
}

class VideoMarkView extends StatelessWidget {
  const VideoMarkView({super.key, required this.mark, this.openLink});

  final VideoMark mark;
  final LessonLinkOpener? openLink;

  @override
  Widget build(BuildContext context) {
    final domain = videoDomain(mark.link);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final uri = Uri.tryParse(mark.link);
          if (uri == null || uri.scheme != 'https') return;
          (openLink ?? defaultLessonLinkOpener)(uri);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kSurface,
            border: Border.all(color: kBorderSoft),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kAccentSoftBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  color: kAccentDark,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mark.caption != null && mark.caption!.isNotEmpty)
                      Text(
                        mark.caption!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      domain,
                      style: const TextStyle(fontSize: 13, color: kInkCaption),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: kInkCaption),
            ],
          ),
        ),
      ),
    );
  }
}
