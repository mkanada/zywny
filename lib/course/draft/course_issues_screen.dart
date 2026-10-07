// I12 — a lista de problemas do validador, para o professor corrigir.
//
// Com erros, o rascunho não abre o curso: mostra esta tela, agrupada por
// arquivo, linha e mensagem, erros primeiro, com Recarregar no topo. Só
// avisos: o curso abre e uma tira recolhível mostra "N avisos" (na
// `CourseScreen`, não aqui).

import 'package:flutter/material.dart';

import '../../ui/theme.dart';

import 'package:zywny_course_format/course_issue.dart';

/// A lista de problemas do rascunho, com Recarregar no topo.
class CourseIssuesScreen extends StatelessWidget {
  const CourseIssuesScreen({
    super.key,
    required this.label,
    required this.issues,
    required this.onReload,
    this.loading = false,
  });

  /// Nome da pasta, para a faixa.
  final String label;
  final List<CourseIssue> issues;
  final VoidCallback onReload;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final errors = [
      for (final i in issues)
        if (i.isError) i,
    ];
    final warnings = [
      for (final i in issues)
        if (!i.isError) i,
    ];
    final ordered = [...errors, ...warnings];
    return Scaffold(
      backgroundColor: kLibraryBg,
      appBar: AppBar(
        backgroundColor: kPanelSideBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Rascunho', style: TextStyle(fontSize: 20)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _DraftBanner(label: label, onReload: onReload, loading: loading),
              const SizedBox(height: 12),
              Text(
                errors.isEmpty
                    ? 'Só avisos — o curso abre assim mesmo.'
                    : '${errors.length} ${errors.length == 1 ? 'erro' : 'erros'} — corrija na pasta e recarregue.',
                style: const TextStyle(fontSize: 14, color: kInkCaption),
              ),
              const SizedBox(height: 8),
              for (final issue in ordered) _IssueRow(issue: issue),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faixa fixa do rascunho (I12): `Rascunho · não verificado · <pasta>` +
/// Recarregar. A mesma na lista de problemas, na tela do curso e na lição.
class DraftBanner extends StatelessWidget {
  const DraftBanner({
    super.key,
    required this.label,
    required this.onReload,
    this.loading = false,
    this.warnings = 0,
    this.onShowWarnings,
  });

  final String label;
  final VoidCallback onReload;
  final bool loading;

  /// Só avisos (sem erros): a tira recolhível "N avisos" aparece abaixo da
  /// faixa, na tela do curso.
  final int warnings;
  final VoidCallback? onShowWarnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kOkColor.withValues(alpha: 0.12),
        border: Border.all(color: kOkColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18, color: kInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rascunho · não verificado · $label',
              style: const TextStyle(fontSize: 13, color: kInk),
            ),
          ),
          const SizedBox(width: 8),
          loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton.icon(
                  onPressed: onReload,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Recarregar'),
                ),
        ],
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({
    required this.label,
    required this.onReload,
    required this.loading,
  });

  final String label;
  final VoidCallback onReload;
  final bool loading;

  @override
  Widget build(BuildContext context) =>
      DraftBanner(label: label, onReload: onReload, loading: loading);
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});

  final CourseIssue issue;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kSurface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorderSoft),
      ),
      child: ListTile(
        leading: Icon(
          issue.isError ? Icons.error_outline : Icons.warning_amber,
          color: issue.isError ? kBadColor : kInkCaption,
        ),
        title: Text(
          '${issue.file}:${issue.line}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(issue.message, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
