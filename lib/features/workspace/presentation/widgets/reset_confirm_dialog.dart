// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final matches = _controller.text.trim().toLowerCase() ==
        widget.phrase.toLowerCase();
    return AlertDialog(
      title:
          Text(l10n?.workspaceResetDialogTitle ?? 'Reset this workspace?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.workspaceResetWarning ??
                'This permanently deletes every reservation, all money and '
                    'ledger entries, the activity feed, and the entire floor '
                    'plan. Settings and members are kept. This cannot be '
                    'undone.',
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
              labelText: l10n?.workspaceResetConfirmLabel(widget.phrase) ??
                  'Type "${widget.phrase}" to confirm',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const Key('workspaceResetConfirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed:
              matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n?.workspaceResetConfirmButton ?? 'Reset workspace'),
        ),
      ],
    );
  }
}
