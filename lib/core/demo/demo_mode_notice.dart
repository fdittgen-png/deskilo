// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';

/// #970 — what a personal-data form shows instead of itself while demo
/// mode is on: the fields would be seeded with invented values, and a
/// save would write them over the real ones.
class DemoModeEditBlocked extends StatelessWidget {
  const DemoModeEditBlocked({super.key, this.asDialog = false});

  /// Rendered inside a dialog (the legacy address editor) rather than a
  /// page body.
  final bool asDialog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = l10n?.demoModeEditBlocked ??
        'Demo mode is on: switch it off in Settings to edit personal '
            'information.';
    final body = Padding(
      key: const ValueKey('demo-mode-edit-blocked'),
      padding: AppSpacing.gutterAll,
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
    if (!asDialog) return body;
    return AlertDialog(
      content: body,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonClose ?? 'Close'),
        ),
      ],
    );
  }
}
