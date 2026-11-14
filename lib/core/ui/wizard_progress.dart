// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';
import '../theme/app_spacing.dart';
import 'adaptive/window_class.dart';
import 'kit/kit_metrics.dart';
import 'wizard_scaffold.dart';

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
    final l10n = context.l10n;
    String status(int i) => switch (states[i]) {
      WizardStepState.completed => l10n.wizardStepCompleted,
      WizardStepState.skipped => l10n.wizardStepSkipped,
      WizardStepState.unavailable => l10n.wizardStepUnavailable,
      WizardStepState.available => '',
    };
    IconData icon(int i) => switch (states[i]) {
      WizardStepState.completed => Icons.check,
      WizardStepState.skipped => Icons.skip_next_outlined,
      WizardStepState.unavailable => Icons.lock_outline,
      WizardStepState.available => Icons.circle_outlined,
    };
    return LayoutBuilder(builder: (context, box) {
      // #3619 — a phone's window class lists the steps compactly.
      final compact = WindowClass.ofWidth(box.maxWidth) == WindowClass.compact ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final items = [for (final (i, step) in steps.indexed)
        Semantics(container: true, key: ValueKey('wizard-step-${step.name}'),
          selected: i == index, value: status(i), child: TextButton.icon(
          onPressed: onStepTap == null || states[i] == WizardStepState.unavailable
              ? null : () => onStepTap!(i),
          icon: Icon(i == index ? Icons.radio_button_checked : icon(i)),
          // #3947 — a step is a target of the kit's minimum height.
          style: i == index ? TextButton.styleFrom(
            minimumSize: const Size(0, KitMetrics.minTarget),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer)
            : TextButton.styleFrom(
                minimumSize: const Size(0, KitMetrics.minTarget)),
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
