// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — two parts of the setup guide (`/setup`): where the space stands,
// and what it could add. The milestones read out as one sentence, the next
// milestone's progress and the next action, announced again whenever the
// guide reads the status anew, so a screen reader hears progress without
// the colour or the icon of a chip. The steps outside the levels the owner
// chose are not in the plan: folded and greyed under "Add more to your
// space", each one "add it" away on the levels screen, they never move a
// counter of the plan.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/setup_status.dart';

/// The milestones the space chose, each with where it stands.
class SetupGuideMilestones extends StatelessWidget {
  const SetupGuideMilestones({super.key, required this.status});

  final SetupStatus status;

  /// Where the space stands, in one sentence: the next milestone's
  /// progress and the next action, or that every chosen one is reached.
  static String _progress(AppLocalizations l10n, SetupStatus status) =>
      switch ((status.nextMilestone, status.nextStep)) {
        (final m?, final step?) => l10n.setupGuideBanner(
          l10n.setupMilestoneName(m.milestone),
          m.ready,
          m.required,
          l10n.setupStepTitle(step.step),
        ),
        _ => l10n.setupGuideAllDone,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final next = status.nextMilestone;
    return Semantics(
      key: const ValueKey('setup-guide-progress'),
      container: true,
      liveRegion: true,
      label: _progress(l10n, status),
      child: Wrap(
        key: const ValueKey('setup-guide-milestones'),
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final m in status.milestones)
            if (m.applies)
              Chip(
                key: ValueKey('setup-milestone-${m.milestone}'),
                avatar: Icon(
                  m.reached
                      ? Icons.check_circle
                      : m == next
                      ? Icons.adjust
                      : Icons.radio_button_unchecked,
                  size: 18,
                ),
                label: Text(
                  m.reached
                      ? '${l10n.setupMilestoneName(m.milestone)} · '
                            '${l10n.setupStateName('ready')}'
                      : '${l10n.setupMilestoneName(m.milestone)} · '
                            '${l10n.setupGuideProgress(m.ready, m.required)}',
                ),
              ),
        ],
      ),
    );
  }
}

/// The steps outside the chosen levels ([SetupStatus.addable]); nothing
/// when every step is in the plan. [onAdd] opens the levels screen.
class SetupGuideAddMore extends StatelessWidget {
  const SetupGuideAddMore({
    super.key,
    required this.steps,
    required this.onAdd,
  });

  final List<SetupStepStatus> steps;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ExpansionTile(
      key: const ValueKey('setup-guide-add-more'),
      tilePadding: EdgeInsets.zero,
      title: Text('${l10n.setupGuideAddMore} (${steps.length})'),
      children: [
        for (final s in steps)
          ListTile(
            key: ValueKey('setup-step-${s.step}'),
            contentPadding: EdgeInsets.zero,
            textColor: muted,
            iconColor: muted,
            leading: const Icon(Icons.add_circle_outline),
            title: Text(l10n.setupStepTitle(s.step)),
            subtitle: Text(
              '${l10n.setupGuideNotInSetup} · ${l10n.setupStepHint(s.step)}',
            ),
            trailing: TextButton(
              key: ValueKey('setup-step-add-${s.step}'),
              onPressed: onAdd,
              child: Text(l10n.setupGuideAddIt),
            ),
            onTap: onAdd,
          ),
      ],
    );
  }
}
