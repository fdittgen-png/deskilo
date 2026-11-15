// SPDX-License-Identifier: AGPL-3.0-or-later
//
// An empty list of the task wizard: one muted line that says what is not
// there yet, with the action that fills it as a text link (#4073).
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A muted line and its action, in place of an icon block.
class TaskWizardEmptyLine extends StatelessWidget {
  const TaskWizardEmptyLine({
    super.key,
    required this.text,
    required this.actionKey,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          key: actionKey,
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}
