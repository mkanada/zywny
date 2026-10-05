// I05 — texto markdown da lição: AST do pacote `markdown` (Dart puro,
// dart-lang) desenhado com widgets do app.
//
// Por que não `flutter_markdown`: o time do Flutter o descontinuou em 2025
// (pub.dev sugere `flutter_markdown_plus` como substituto); além disso ele
// interpreta HTML por baixo — aqui `html`/`inlineHtml` viram texto literal,
// como pede o I00/I05.
//
// Elementos suportados (I00): títulos `#`–`###`, parágrafo, `**negrito**`,
// `*itálico*`, listas (com aninhamento de 1 nível), citação, `---`, `código`
// em linha, links, imagens. Bloco de código comum (não `zywny-`) aparece em
// fonte monoespaçada, sem destaque de sintaxe. Todo o resto (tabelas, HTML,
// tags desconhecidas) aparece como texto — nunca é interpretado.

import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../format/course_files.dart';
import '../../ui/theme.dart';

/// Abre um link do texto fora do app. Só `https://` (o validador já garante;
/// aqui, o resto é recusado em silêncio). Nada é buscado sem toque.
typedef LessonLinkOpener = Future<void> Function(Uri uri);

/// O texto de um [TextBlock]: uma coluna com um widget por bloco de topo.
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    super.key,
    required this.text,
    required this.files,
    this.openLink,
  });

  /// O markdown de um bloco de texto da lição (já separado pelo leitor).
  final String text;
  final CourseFiles files;

  /// Para teste: falso que registra o `Uri` em vez de abrir o navegador.
  final LessonLinkOpener? openLink;

  @override
  Widget build(BuildContext context) {
    // Sem `encodeHtml`: a AST vai direto para widgets, e entidades (`"`,
    // `&`) sairiam literais como `&quot;` na tela (visto no I13, foto 51).
    final nodes = md.Document(encodeHtml: false).parse(text);
    final builder = _BlockBuilder(files: files, openLink: openLink);
    final widgets = <Widget>[];
    for (final node in nodes) {
      widgets.addAll(builder.buildBlock(node));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}

class _BlockBuilder {
  _BlockBuilder({required this.files, required this.openLink});

  final CourseFiles files;
  final LessonLinkOpener? openLink;

  List<Widget> buildBlock(md.Node node) {
    if (node is md.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return const [];
      // HTML cru chega aqui como texto (o pacote não o separa com
      // `encodeHtml` padrão): aparece como texto, como pede o I00.
      return [_paragraph(node.text)];
    }
    if (node is! md.Element) return [Text(node.textContent)];
    switch (node.tag) {
      case 'h1':
        return [_heading(node, 24)];
      case 'h2':
        return [_heading(node, 21)];
      case 'h3':
        return [_heading(node, 18)];
      case 'p':
        return _paragraphNode(node);
      case 'ul':
        return [_bulletList(node, ordered: false, depth: 0)];
      case 'ol':
        return [_bulletList(node, ordered: true, depth: 0)];
      case 'blockquote':
        return [_quote(node)];
      case 'hr':
        return const [Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: kBorderSoft, height: 1),
        )];
      case 'pre':
        return [_codeBlock(node)];
      case 'table':
      case 'thead':
      case 'tbody':
      case 'html':
        // Fora da v1 (tabelas, HTML): texto literal, nunca interpretado.
        return [_paragraph(node.textContent)];
      default:
        return [_paragraph(node.textContent)];
    }
  }

  Widget _heading(md.Element node, double size) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: RichText(
        text: TextSpan(
          children: _inline(node.children ?? const []),
          style: serifDisplay(fontSize: size).copyWith(height: 1.25),
        ),
      ),
    );
  }

  List<Widget> _paragraphNode(md.Element node) {
    final children = node.children ?? const [];
    if (children.length == 1 &&
        children.single is md.Element &&
        (children.single as md.Element).tag == 'img') {
      return [_courseImage(children.single as md.Element)];
    }
    // Parágrafo misto com imagem no meio: texto e imagens em sequência.
    if (children.any((c) => c is md.Element && c.tag == 'img')) {
      final widgets = <Widget>[];
      var spanBuffer = <md.Node>[];
      void flushText() {
        if (spanBuffer.isEmpty) return;
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RichText(
              text: TextSpan(
                children: _inline(spanBuffer),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: kInk,
                ),
              ),
            ),
          ),
        );
        spanBuffer = [];
      }

      for (final child in children) {
        if (child is md.Element && child.tag == 'img') {
          flushText();
          widgets.add(_courseImage(child));
        } else {
          spanBuffer.add(child);
        }
      }
      flushText();
      return widgets;
    }
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            children: _inline(children),
            style: const TextStyle(fontSize: 16, height: 1.4, color: kInk),
          ),
        ),
      ),
    ];
  }

  Widget _paragraph(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, height: 1.4, color: kInk),
      ),
    );
  }

  Widget _bulletList(md.Element node, {required bool ordered, required int depth}) {
    final items = [
      for (final c in node.children ?? const [])
        if (c is md.Element && c.tag == 'li') c,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            _listItem(items[i], index: i, ordered: ordered, depth: depth),
        ],
      ),
    );
  }

  Widget _listItem(
    md.Element li, {
    required int index,
    required bool ordered,
    required int depth,
  }) {
    final bullet = ordered ? '${index + 1}.' : '•';
    final inlineNodes = <md.Node>[];
    final nested = <Widget>[];
    for (final child in li.children ?? const []) {
      if (child is md.Element && (child.tag == 'ul' || child.tag == 'ol')) {
        // Aninhamento de 1 nível (I00); mais fundo vira texto.
        if (depth == 0) {
          nested.add(
            _bulletList(child, ordered: child.tag == 'ol', depth: depth + 1),
          );
        } else {
          inlineNodes.add(md.Text(child.textContent));
        }
      } else if (child is md.Element && child.tag == 'p') {
        inlineNodes.addAll(child.children ?? const []);
      } else {
        inlineNodes.add(child);
      }
    }
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 4 : 20, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: ordered ? 28 : 20,
                child: Text(
                  bullet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: kInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: _inline(inlineNodes),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: kInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ...nested,
        ],
      ),
    );
  }

  Widget _quote(md.Element node) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: kBorder, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in node.children ?? const [])
            if (child is md.Element && child.tag == 'p')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    children: _inline(child.children ?? const []),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: kInkCaption,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ...buildBlock(child),
        ],
      ),
    );
  }

  Widget _codeBlock(md.Element node) {
    final code = node.textContent.replaceAll(RegExp(r'\n$'), '');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kChipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: ['Courier'],
          fontSize: 13.5,
          height: 1.45,
          color: kInk,
        ),
      ),
    );
  }

  Widget _courseImage(md.Element node) {
    final src = node.attributes['src'] ?? '';
    final alt = node.attributes['alt'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CourseImage(src: src, files: files),
          if (alt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                alt,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kInkCaption),
              ),
            ),
        ],
      ),
    );
  }

  List<InlineSpan> _inline(List<md.Node> nodes) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is md.Text) {
        spans.add(TextSpan(text: node.text));
      } else if (node is md.Element) {
        switch (node.tag) {
          case 'strong':
            spans.add(
              TextSpan(
                children: _inline(node.children ?? const []),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          case 'em':
            spans.add(
              TextSpan(
                children: _inline(node.children ?? const []),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            );
          case 'code':
            spans.add(
              TextSpan(
                text: node.textContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: ['Courier'],
                  fontSize: 14,
                  backgroundColor: kChipBg,
                ),
              ),
            );
          case 'a':
            spans.add(_linkSpan(node));
          case 'img':
            // Imagem dentro de frase: o bloco pai já a extraiu; aqui vira
            // só o texto alternativo, para nunca sumir.
            final alt = node.attributes['alt'] ?? '';
            if (alt.isNotEmpty) spans.add(TextSpan(text: alt));
          case 'br':
            spans.add(const TextSpan(text: '\n'));
          default:
            // `html`/`inlineHtml` e o resto: texto literal, sem interpretar.
            spans.add(TextSpan(text: node.textContent));
        }
      }
    }
    return spans;
  }

  InlineSpan _linkSpan(md.Element node) {
    final href = node.attributes['href'] ?? '';
    final uri = Uri.tryParse(href);
    final valid = uri != null && uri.scheme == 'https';
    TapGestureRecognizer? recognizer;
    if (valid) {
      recognizer = TapGestureRecognizer()
        ..onTap = () {
          final open = openLink ?? defaultLessonLinkOpener;
          open(uri);
        };
    }
    return TextSpan(
      children: _inline(node.children ?? const []),
      style: TextStyle(
        color: valid ? kAccent : kInkCaption,
        decoration: valid ? TextDecoration.underline : null,
      ),
      recognizer: recognizer,
    );
  }
}

/// Abre [uri] fora do app; recusa em silêncio o que não é `https://`.
/// Nada é buscado na rede sem toque (I05).
Future<void> defaultLessonLinkOpener(Uri uri) async {
  if (uri.scheme != 'https') return;
  final ok = await DefaultLessonLinkLauncher.launch(uri);
  if (!ok) {
    // Sem navegador à mão (teste, Linux mínimo): silêncio, como pede o I05.
    debugPrint('lição: não deu para abrir $uri');
  }
}

/// Ponto único de `url_launcher`, trocável em teste via [MarkdownView.openLink]
/// ou [DefaultLessonLinkLauncher.debugOverride].
class DefaultLessonLinkLauncher {
  const DefaultLessonLinkLauncher._();

  // ignore: avoid-global-state — ponto único proposital, só repassa ao plugin.
  static Future<bool> Function(Uri uri)? debugOverride;

  static Future<bool> launch(Uri uri) {
    final override = debugOverride;
    if (override != null) return override(uri);
    // `url_launcher` (dependência nova do I05): abre fora do app.
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// A imagem da pasta, com o `Future` guardado no estado: criado no `build` a
/// cada frame, o `FutureBuilder` recomeçaria o carregamento sem fim.
class _CourseImage extends StatefulWidget {
  const _CourseImage({required this.src, required this.files});

  final String src;
  final CourseFiles files;

  @override
  State<_CourseImage> createState() => _CourseImageState();
}

class _CourseImageState extends State<_CourseImage> {
  late final Future<Uint8List> _bytes = widget.files.read(widget.src);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Não consegui abrir a imagem ${widget.src}.',
              style: const TextStyle(fontSize: 14, color: kInkCaption),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(snapshot.data!, fit: BoxFit.contain),
        );
      },
    );
  }
}
