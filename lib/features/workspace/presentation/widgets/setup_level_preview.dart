// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/dictionary_labels.dart';
import '../../domain/setup_level_change.dart';
import '../../domain/setup_step_reach.dart';
import '../../domain/workspace_feature.dart';
import '../feature_copy.dart';
import '../feature_names.dart';

/// What applying would switch on and off, every feature by name.
class SetupLevelPreview extends StatelessWidget {
  const SetupLevelPreview({super.key, required this.change});
  final SetupLevelChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // #3076 — what the space gets, in the member-facing words of the
    // manifest, never the switches' own names.
    List<Widget> outcomes(
      String heading,
      List<WorkspaceFeature> fs,
      Key key,
    ) => [
      Text(heading, key: key, style: Theme.of(context).textTheme.titleSmall),
      // #3283 — the exact switch by the title the Features screen gives it
      // (one definition, featureName), and what it does below.
      for (final f in fs)
        Padding(
          key: ValueKey('setup-levels-switch-${f.name}'),
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                featureName(l10n, f),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                featureDescription(l10n, f),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
    ];
    return Card(
      key: const ValueKey('setup-levels-preview'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (change.isEmpty) Text(l10n.setupLevelsNoChange),
            // #3283 — first, in plain words, what the business will be able
            // to do; the exact switches follow.
            if (change.levels.isNotEmpty) ...[
              Text(
                l10n.setupLevelsOutcomeTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final MapEntry(key: p, value: id) in change.levels.entries)
                Padding(
                  key: ValueKey('setup-levels-outcome-${p.name}'),
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(l10n.setupLevelOutcome('${p.name}_$id')),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            // #3283 — the exact switches, folded: the sentences above say
            // what changes, the details are one tap away.
            if (!change.isEmpty)
              ExpansionTile(
                key: const ValueKey('setup-levels-details'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(l10n.setupChoicesSummary(change.flags.length)),
                children: [
                  if (change.switchOn.isNotEmpty)
                    ...outcomes(
                      l10n.setupLevelsSwitchOn,
                      change.switchOn,
                      const ValueKey('setup-levels-on'),
                    ),
                  if (setupStepsFor(change.switchOn) case final steps
                      when steps.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.setupLevelsStepsFollow(
                        steps.map((s) => l10n.setupStepTitle(s.id)).join(', '),
                      ),
                      key: const ValueKey('setup-levels-steps'),
                    ),
                  ],
                  if (change.switchOff.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ...outcomes(
                      l10n.setupLevelsSwitchOff,
                      change.switchOff,
                      const ValueKey('setup-levels-off'),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
