// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #875 — the layout controls for ONE report kind, in the designer.
//
// Export the layout as XML, import one back, remove it so the kind
// falls back to its bands, and say plainly which engine currently draws
// this document. Kept out of invoice_template_sheet.dart, which is at
// its length budget; the sheet passes the kind and the callbacks.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

class ReportLayoutPanel extends StatelessWidget {
  const ReportLayoutPanel({
    super.key,
    required this.hasLayout,
    required this.onExport,
    required this.onImport,
    required this.onRemove,
    this.onPreview,
    this.busy = false,
  });

  /// Whether this kind is currently drawn by a positioned layout.
  final bool hasLayout;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onRemove;
  final VoidCallback? onPreview;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('report-layout-panel'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.straighten, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.reportLayoutTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              // Which engine draws this document, said plainly.
              Chip(
                key: const ValueKey('report-layout-engine-chip'),
                label: Text(hasLayout
                    ? (l10n.reportLayoutActive)
                    : (l10n.reportLayoutBands)),
                avatar: Icon(
                  hasLayout ? Icons.grid_on : Icons.view_agenda_outlined,
                  size: 18,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.reportLayoutSubtitle,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('report-layout-export'),
                  onPressed: busy ? null : onExport,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l10n.reportLayoutExport),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('report-layout-import'),
                  onPressed: busy ? null : onImport,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l10n.reportLayoutImport),
                ),
                if (hasLayout && onPreview != null)
                  OutlinedButton.icon(
                    key: const ValueKey('report-layout-preview'),
                    onPressed: busy ? null : onPreview,
                    icon: const Icon(Icons.preview_outlined),
                    label: Text(l10n.reportLayoutPreview),
                  ),
                if (hasLayout)
                  TextButton.icon(
                    key: const ValueKey('report-layout-remove'),
                    onPressed: busy ? null : onRemove,
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: Text(
                        l10n.reportLayoutRemove),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
