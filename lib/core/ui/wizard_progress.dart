// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'wizard_scaffold.dart';
import 'wizard_form_layout.dart';

enum WizardStepState { available, completed, skipped, unavailable }

/// Presentation only: the caller owns validation, applicability and navigation.
class WizardProgress extends StatelessWidget {
  const WizardProgress({super.key, required this.steps, required this.states,
    required this.index, this.onStepTap});
  final List<WizardStepSpec> steps;
  final List<WizardStepState> states;
  final int index;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String status(int i) => switch (states[i]) {
      WizardStepState.completed => l10n?.wizardStepCompleted ?? 'Completed',
      WizardStepState.skipped => l10n?.wizardStepSkipped ?? 'Skipped — suggested settings',
      WizardStepState.unavailable => l10n?.wizardStepUnavailable ?? 'Not available yet',
      WizardStepState.available => '',
    };
    IconData icon(int i) => switch (states[i]) {
      WizardStepState.completed => Icons.check,
      WizardStepState.skipped => Icons.skip_next_outlined,
      WizardStepState.unavailable => Icons.lock_outline,
      WizardStepState.available => Icons.circle_outlined,
    };
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxWidth < WizardFormLayout.shortFormWidth ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final items = [for (final (i, step) in steps.indexed)
        Semantics(container: true, key: ValueKey('wizard-step-${step.name}'),
          selected: i == index, value: status(i), child: TextButton.icon(
          onPressed: onStepTap == null || states[i] == WizardStepState.unavailable
              ? null : () => onStepTap!(i),
          icon: Icon(i == index ? Icons.radio_button_checked : icon(i)),
          style: i == index ? TextButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer) : null,
          label: Text(step.label))),
      ];
      if (compact) {
        return ExpansionTile(
          key: const ValueKey('wizard-progress-overview'),
          title: Semantics(header: true, liveRegion: true,
            child: Text(steps[index].label)),
          subtitle: Text([index + 1, steps.length].join(' / ')),
          children: items,
        );
      }
      return Padding(padding: AppSpacing.smAll,
        child: Wrap(spacing: AppSpacing.xs, children: items));
    });
  }
}
