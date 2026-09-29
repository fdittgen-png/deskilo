// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/mcp/mcp_operations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../mcp_operation_labels.dart';

/// #1809 — a fictional answer to "which places are free?", minimised and
/// as detailed as [fields] allow, so the owner sees what a choice changes
/// before saving it. Nothing here is read from the workspace.
class McpDisclosurePreview extends StatelessWidget {
  const McpDisclosurePreview({super.key, required this.fields});

  /// The optional fields the detailed answer carries.
  final Set<String> fields;

  static String answer(AppLocalizations? l10n, Iterable<String> fields) {
    final lines = [
      '  "seat_id": "7f3a…"',
      '  "free": true',
      for (final f in mcpOptionalFields)
        if (fields.contains(f)) '  "$f": "${mcpOptionalFieldSample(l10n, f)}"',
    ];
    return '{\n${lines.join(',\n')}\n}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget column(String key, String title, Iterable<String> shown) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          answer(l10n, shown),
          key: ValueKey(key),
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
    return Card(
      key: const ValueKey('mcp-disclosure-preview'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.mcpDisclosurePreviewNote ??
                  'A fictional answer, to show what assistants would see.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                column(
                  'mcp-disclosure-preview-minimised',
                  l10n?.mcpDisclosurePreviewMinimised ?? 'Minimised answer',
                  const [],
                ),
                column(
                  'mcp-disclosure-preview-detailed',
                  l10n?.mcpDisclosurePreviewDetailed ?? 'Detailed answer',
                  fields,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
