// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The task wizard's section header: a section's name, said as a heading,
// and the section's one action beside it (task_wizard_screen.dart).
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A section of the task wizard: its title and its action.
class TaskWizardSectionHeader extends StatelessWidget {
  const TaskWizardSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: AppSpacing.xs,
        spacing: AppSpacing.sm,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?action,
        ],
      ),
    );
  }
}
