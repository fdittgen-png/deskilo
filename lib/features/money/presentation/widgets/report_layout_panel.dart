// SPDX-License-Identifier: 0BSD
//
// #875 — the layout controls for ONE report kind, in the designer.
//
// Export the layout as XML, import one back, remove it so the kind
// falls back to its bands, and say plainly which engine currently draws
// this document. Kept out of invoice_template_sheet.dart, which is at
// its length budget; the sheet passes the kind and the callbacks.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
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
                  l10n?.reportLayoutTitle ?? 'Positioned layout (XML)',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              // Which engine draws this document, said plainly.
              Chip(
                key: const ValueKey('report-layout-engine-chip'),
                label: Text(hasLayout
                    ? (l10n?.reportLayoutActive ?? 'Layout active')
                    : (l10n?.reportLayoutBands ?? 'Bands')),
                avatar: Icon(
                  hasLayout ? Icons.grid_on : Icons.view_agenda_outlined,
                  size: 18,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n?.reportLayoutSubtitle ??
                  'A layout states where every element sits, in mm, cm, '
                      'px or %. Export it, edit it, check it with '
                      '`dart run tool/report.dart check`, import it back. '
                      'When a layout exists it is what prints; remove it '
                      'and the bands print again.',
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
                  label: Text(l10n?.reportLayoutExport ?? 'Export XML'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('report-layout-import'),
                  onPressed: busy ? null : onImport,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l10n?.reportLayoutImport ?? 'Import XML'),
                ),
                if (hasLayout && onPreview != null)
                  OutlinedButton.icon(
                    key: const ValueKey('report-layout-preview'),
                    onPressed: busy ? null : onPreview,
                    icon: const Icon(Icons.preview_outlined),
                    label: Text(l10n?.reportLayoutPreview ?? 'Page preview'),
                  ),
                if (hasLayout)
                  TextButton.icon(
                    key: const ValueKey('report-layout-remove'),
                    onPressed: busy ? null : onRemove,
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: Text(
                        l10n?.reportLayoutRemove ?? 'Remove layout (use bands)'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
