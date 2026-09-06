// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'report_field_picker.dart';

/// #966 — the markup mode's guide, in place of a flat run of every
/// placeholder the engine knows. Collapsed by default behind one
/// expander; inside: how a band works in two sentences, a button that
/// opens the grouped field picker (name + meaning, searchable), the
/// line markup one sign per row, and three ready-made Liquid pieces.
/// Everything inserts at the caret of the band last edited through
/// [onInsert]; the syntax itself is language and stays identical in
/// every locale (HARD RULE #1).
class ReportMarkupGuide extends StatelessWidget {
  const ReportMarkupGuide({
    super.key,
    required this.onInsert,
    this.textKeys = const [],
  });

  /// Receives the markup to put at the caret.
  final ValueChanged<String> onInsert;

  /// #880 — the owner's text keys, offered by the picker as `text.<key>`.
  final List<String> textKeys;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: theme.colorScheme.primary,
    );
    return ExpansionTile(
      key: const ValueKey('report-markup-guide'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      title: Text(
        l10n?.reportGuideTitle ?? 'Placeholders and markup',
        style: theme.textTheme.titleSmall,
      ),
      children: [
        Text(
          l10n?.reportGuideIntro ??
              'Three bands make the PDF: header, body, footer. Write text, '
                  'put a field where a value goes, and use one markup sign '
                  'at the start of a line for its style. The e-invoice XML '
                  'is never touched.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey('report-guide-insert-field'),
            icon: const Icon(Icons.data_object),
            label: Text(l10n?.reportGuideInsertField ?? 'Insert a field…'),
            onPressed: () async {
              final markup =
                  await showReportFieldPicker(context, textKeys: textKeys);
              if (markup != null) onInsert(markup);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n?.reportGuideMarkupTitle ?? 'Line markup',
            style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        for (final row in reportMarkupRows(l10n))
          InkWell(
            key: ValueKey('report-markup-${row.id}'),
            onTap: () => onInsert(row.example),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(row.example, style: mono),
                  ),
                  Expanded(
                    child: Text(row.meaning, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n?.reportGuideSnippetsTitle ?? 'Ready-made pieces',
            style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final snippet in reportLiquidSnippets(l10n))
              ActionChip(
                key: ValueKey('report-snippet-${snippet.id}'),
                label: Text(snippet.label),
                onPressed: () => onInsert(snippet.markup),
              ),
          ],
        ),
      ],
    );
  }
}

/// One line-markup rule: the sign as an example line, and what it does.
typedef ReportMarkupRow = ({String id, String example, String meaning});

/// The line markup the renderer accepts, one row each, in reading order.
/// The examples are syntax (identical everywhere); the meanings are
/// translated.
List<ReportMarkupRow> reportMarkupRows(AppLocalizations? l10n) => [
      (
        id: 'heading',
        example: '# Title',
        meaning: l10n?.reportMarkupHeading ?? 'A large title',
      ),
      (
        id: 'section',
        example: '## Section',
        meaning: l10n?.reportMarkupSection ?? 'A section heading',
      ),
      (
        id: 'small',
        example: '> small text',
        meaning: l10n?.reportMarkupSmall ?? 'Small muted text',
      ),
      (
        id: 'rule',
        example: '---',
        meaning: l10n?.reportMarkupRule ?? 'A horizontal rule',
      ),
      (
        id: 'table',
        example: 'a | b | c',
        meaning: l10n?.reportMarkupTable ?? 'A table row, one cell per |',
      ),
      (
        id: 'bold-row',
        example: '= a | b',
        meaning: l10n?.reportMarkupBoldRow ?? 'A bold table row',
      ),
      (
        id: 'columns',
        example: ':::\nleft\n|||\nright\n:::',
        meaning: l10n?.reportMarkupColumns ??
            'Side-by-side columns, split at |||',
      ),
      (
        id: 'image',
        example: '![logo|m|left]',
        meaning: l10n?.reportMarkupImage ??
            'A library image: size s/m/l, align left/center/right',
      ),
    ];

/// One ready-made Liquid piece: what it is for, and the markup.
typedef ReportLiquidSnippet = ({String id, String label, String markup});

/// The three Liquid patterns a band actually needs; anything else is
/// the same three combined.
List<ReportLiquidSnippet> reportLiquidSnippets(AppLocalizations? l10n) => [
      (
        id: 'if',
        label: l10n?.reportGuideSnippetIf ??
            'A line only when the value exists',
        markup: '{% if due_date != "" %}{{ due_date }}{% endif %}',
      ),
      (
        id: 'loop',
        label: l10n?.reportGuideSnippetLoop ?? 'One row per invoice line',
        markup:
            '{% for line in lines %}{{ line.label }} | {{ line.amount }}\n'
            '{% endfor %}',
      ),
      (
        id: 'title',
        label: l10n?.reportGuideSnippetTitle ??
            'The title: invoice, credit note or proforma',
        markup: '{% if credit_note %}CREDIT NOTE{% elsif proforma %}PROFORMA'
            '{% else %}INVOICE{% endif %} {{ number }}',
      ),
    ];

/// Puts [markup] at the caret of [value] (replacing a selection), the
/// caret landing after it; without a valid selection it appends. Pure,
/// so the sheet's undo history sees one change.
TextEditingValue insertMarkupAt(TextEditingValue value, String markup) {
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : start;
  return value.copyWith(
    text: value.text.replaceRange(start, end, markup),
    selection: TextSelection.collapsed(offset: start + markup.length),
    composing: TextRange.empty,
  );
}
