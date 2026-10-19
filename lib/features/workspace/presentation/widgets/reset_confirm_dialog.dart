// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

/// Destructive reset confirmation (0039): the confirm button unlocks only
/// once the owner types [phrase] exactly (case-insensitive). Owns its text
/// controller so it never outlives the dialog's dismissal.
class ResetConfirmDialog extends StatefulWidget {
  const ResetConfirmDialog({super.key, required this.phrase});

  final String phrase;

  @override
  State<ResetConfirmDialog> createState() => ResetConfirmDialogState();
}

class ResetConfirmDialogState extends State<ResetConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final matches = _controller.text.trim().toLowerCase() ==
        widget.phrase.toLowerCase();
    return AlertDialog(scrollable: true,
      title:
          Text(l10n.workspaceResetDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.workspaceResetWarning,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('workspaceResetConfirmField'),
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.workspaceResetConfirmLabel(widget.phrase),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('reset-confirm-dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('workspaceResetConfirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed:
              matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.workspaceResetConfirmButton),
        ),
      ],
    );
  }
}
