// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The print preview of a report: the same [BiPrintDocument] the PDF lays
// out, on screen, on a sheet of the layout's paper. It reflows the typed
// content (it is not a screenshot of the phone layout), keeps every value
// as text, marks a partial or unknown figure in words, and shows where the
// layout starts a new sheet.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_pdf.dart' show biPrintFormat, biPrintMargins;
import '../../domain/bi_report_print.dart';

class BiPrintPreview extends StatelessWidget {
  const BiPrintPreview({super.key, required this.document});

  final BiPrintDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final bold = theme.textTheme.titleSmall;
    final doc = document;
    return BiPrintSheet(
      key: const ValueKey('bi-print-preview'),
      style: doc.style,
      children: [
        if (doc.style.header.isNotEmpty) Text(doc.style.header, style: small),
        Text(doc.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final line in doc.provenance)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${line.label}: ', style: bold),
                TextSpan(text: line.value),
              ],
            ),
            style: small,
          ),
        Text(
          doc.qualification,
          key: const ValueKey('bi-print-qualification'),
          style: bold,
        ),
        if (doc.management != null) Text(doc.management!, style: small),
        for (final source in doc.sources) Text(source, style: small),
        for (final section in doc.sections) ...[
          if (section.newSheet) const Divider(thickness: 2),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(section.title, style: theme.textTheme.titleSmall),
          ),
          for (final block in section.blocks) _block(context, block),
        ],
        const Divider(),
        if (doc.style.footer.isNotEmpty) Text(doc.style.footer, style: small),
        Text(
          doc.sourceLine,
          key: const ValueKey('bi-print-source'),
          style: small,
        ),
      ],
    );
  }

  Widget _block(BuildContext context, BiPrintBlock block) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: switch (block) {
        BiPrintFigure() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.title, style: theme.textTheme.labelLarge),
            Text(block.value, style: theme.textTheme.headlineSmall),
            if (block.note.isNotEmpty)
              Text(block.note, style: theme.textTheme.bodySmall),
          ],
        ),
        BiPrintTable() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.title, style: theme.textTheme.labelLarge),
            Table(
              border: TableBorder.all(color: theme.colorScheme.outlineVariant),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  children: [
                    for (final h in block.headings) _cell(h, theme, bold: true),
                  ],
                ),
                for (final row in block.rows)
                  TableRow(children: [for (final c in row) _cell(c, theme)]),
              ],
            ),
          ],
        ),
        BiPrintText() => Text(block.text),
      },
    );
  }

  Widget _cell(String text, ThemeData theme, {bool bold = false}) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xs),
    child: Text(
      text,
      style: bold ? theme.textTheme.labelMedium : theme.textTheme.bodySmall,
    ),
  );
}

/// A sheet of [style]'s paper: as wide as the room allows, its margins in
/// proportion, at least as tall as the paper.
class BiPrintSheet extends StatelessWidget {
  const BiPrintSheet({super.key, required this.style, required this.children});

  final BiPrintStyle style;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final format = biPrintFormat(style);
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.biPrintSheetPreview,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final scale = width / format.width;
          final margin =
              (biPrintMargins[style.margin] ?? biPrintMargins['normal']!) *
              scale;
          return Container(
            constraints: BoxConstraints(minHeight: format.height * scale),
            padding: EdgeInsets.all(margin),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          );
        },
      ),
    );
  }
}
