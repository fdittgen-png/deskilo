// SPDX-License-Identifier: 0BSD
//
// #872 — ONE wizard idiom for every guided invoicing flow: numbered
// steps across the top (done ✓ / current / ahead), the step's own
// content in the middle, Back · «i / n» · Next (or Finish) at the foot.
// The month-close wizard (#827), the settlement (#804/#831) and the
// expense repartition (#828) all run inside this scaffold, so a person
// learns the shape once. Steps own their content; this owns the chrome.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// One step: a stable [name] (keys `wizard-step-<name>`) and its label.
typedef WizardStepSpec = ({String name, String label});

class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.title,
    required this.steps,
    required this.index,
    required this.body,
    this.onStepTap,
    this.onBack,
    this.onNext,
    this.nextEnabled = true,
    this.onFinish,
    this.finishLabel,
    this.finishKey,
    this.finishEnabled = true,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final List<WizardStepSpec> steps;
  final int index;
  final Widget body;

  /// Jump to a step from its chip; null keeps the chips passive.
  final ValueChanged<int>? onStepTap;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final bool nextEnabled;

  /// Shown on the last step in place of Next. Null when the last step
  /// carries its own closing action (the month-close summary does).
  final VoidCallback? onFinish;
  final String? finishLabel;
  final Key? finishKey;
  final bool finishEnabled;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final last = index >= steps.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions, leading: leading),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(children: [
                for (final (i, step) in steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      key: ValueKey('wizard-step-${step.name}'),
                      avatar: i < index
                          ? const Icon(Icons.check, size: 16)
                          : CircleAvatar(
                              radius: 9,
                              backgroundColor: i == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Text((i + 1).toString(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: i == index
                                        ? theme.colorScheme.onPrimary
                                        : null,
                                  )),
                            ),
                      label: Text(step.label),
                      selected: i == index,
                      onSelected:
                          onStepTap == null ? null : (_) => onStepTap!(i),
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: body,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Row(children: [
                TextButton.icon(
                  key: const ValueKey('wizard-back'),
                  icon: const Icon(Icons.chevron_left),
                  label: Text(l10n?.wizardBack ?? 'Back'),
                  onPressed: index == 0 ? null : onBack,
                ),
                const Spacer(),
                Text([index + 1, steps.length].join(' / '),
                    style: theme.textTheme.labelMedium),
                const Spacer(),
                if (!last)
                  FilledButton.icon(
                    key: const ValueKey('wizard-next'),
                    icon: const Icon(Icons.chevron_right),
                    label: Text(l10n?.wizardNext ?? 'Next'),
                    onPressed: nextEnabled ? onNext : null,
                  )
                else if (onFinish != null)
                  FilledButton.icon(
                    key: finishKey ?? const ValueKey('wizard-finish'),
                    icon: const Icon(Icons.check),
                    label: Text(finishLabel ?? (l10n?.wizardFinish ?? 'Finish')),
                    onPressed: finishEnabled ? onFinish : null,
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
