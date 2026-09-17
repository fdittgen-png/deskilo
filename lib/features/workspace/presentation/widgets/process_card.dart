// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/process_status.dart';
import '../../domain/workspace_feature.dart';
import '../feature_names.dart';
import '../process_names.dart';

/// The word for a [ProcessState] — always shown beside its icon, never
/// replaced by a colour (#1327, spec §11).
String processStateLabel(AppLocalizations? l10n, ProcessState state) =>
    switch (state) {
      ProcessState.active => l10n?.processStateActive ?? 'Active',
      ProcessState.partial => l10n?.processStatePartial ?? 'Partial',
      ProcessState.available => l10n?.processStateAvailable ?? 'Available',
      ProcessState.needsAttention =>
        l10n?.processStateNeedsAttention ?? 'Needs attention',
    };

IconData processStateIcon(ProcessState state) => switch (state) {
  ProcessState.active => Icons.check_circle_outline,
  ProcessState.partial => Icons.incomplete_circle_outlined,
  ProcessState.available => Icons.radio_button_unchecked,
  ProcessState.needsAttention => Icons.warning_amber_outlined,
};

Color _stateColor(ThemeData theme, ProcessState state) => switch (state) {
  ProcessState.active => AppStatusColors.successOf(theme.brightness),
  ProcessState.partial => theme.colorScheme.primary,
  ProcessState.available => theme.colorScheme.onSurfaceVariant,
  ProcessState.needsAttention => theme.colorScheme.error,
};

/// One business process on the Features overview (#1327).
///
/// The header is ONE semantics node — name, state and counts in one
/// announcement — and the expanded detail follows it in reading and
/// focus order, subprocess by subprocess, so a keyboard walks process →
/// subprocess → feature. No switch lives here: turning features on and
/// off stays on the switches view until the atomic process activation
/// of #1329 exists, and tapping a feature goes there.
class ProcessCard extends StatelessWidget {
  const ProcessCard({
    super.key,
    required this.status,
    required this.expanded,
    required this.onToggle,
    required this.onOpenFeature,
    this.subprocessKeys = const {},
  });

  final ProcessStatus status;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<WorkspaceFeature> onOpenFeature;

  /// Keys for the subprocess rows, so a search hit can scroll to one.
  final Map<String, GlobalKey> subprocessKeys;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final copy = processCopy(l10n, status.process.key);
    final counts = [
      l10n?.processSubprocessCount(
            status.activeSubprocessCount,
            status.subprocesses.length,
          ) ??
          '${status.activeSubprocessCount} of ${status.subprocesses.length} '
              'subprocesses active',
      l10n?.processFeatureCount(status.enabledCount, status.capabilityCount) ??
          '${status.enabledCount} of ${status.capabilityCount} features on',
    ];
    final warnings = [
      if (status.heldBackCount > 0)
        l10n?.processHeldBack(status.heldBackCount) ??
            '${status.heldBackCount} features are on but wait for a '
                'switched-off prerequisite',
      if (status.outsidePrerequisites.isNotEmpty) _alsoNeeds(l10n),
    ];
    final stateLabel = processStateLabel(l10n, status.state);

    return Card(
      key: ValueKey('process-${status.process.key}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            key: ValueKey('process-header-${status.process.key}'),
            container: true,
            button: true,
            expanded: expanded,
            excludeSemantics: true,
            label: [copy.title, stateLabel, ...counts, ...warnings].join('. '),
            onTap: onToggle,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(copy.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          _StateLine(state: status.state, label: stateLabel),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            copy.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            counts.join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                          for (final warning in warnings) _Note(text: warning),
                        ],
                      ),
                    ),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
          MotionReveal(
            child: expanded
                ? _Detail(
                    key: ValueKey('process-detail-${status.process.key}'),
                    status: status,
                    subprocessKeys: subprocessKeys,
                    onOpenFeature: onOpenFeature,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _alsoNeeds(AppLocalizations? l10n) {
    final names = status.outsidePrerequisites
        .map(
          (p) =>
              '${featureName(l10n, p.feature)} '
              '(${processLabel(l10n, p.processKey)})',
        )
        .join(', ');
    return l10n?.processAlsoNeeds(names) ??
        'Switching it all on also needs: $names';
  }
}

class _StateLine extends StatelessWidget {
  const _StateLine({required this.state, required this.label});

  final ProcessState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          processStateIcon(state),
          size: 18,
          color: _stateColor(theme, state),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// What the process is made of: each subprocess with its state, and
/// each of its features with what it is doing.
class _Detail extends StatelessWidget {
  const _Detail({
    super.key,
    required this.status,
    required this.subprocessKeys,
    required this.onOpenFeature,
  });

  final ProcessStatus status;
  final Map<String, GlobalKey> subprocessKeys;
  final ValueChanged<WorkspaceFeature> onOpenFeature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Text(
            l10n?.processSwitchHint ??
                'Tap a feature to change it among the switches.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final sub in status.subprocesses) ...[
          _SubprocessHeading(
            key: subprocessKeys[sub.subprocess.key],
            status: sub,
          ),
          for (final feature in sub.subprocess.capabilities)
            if (_stateOf(sub, feature) case final line?)
              ListTile(
                key: ValueKey('process-feature-${feature.name}'),
                contentPadding: const EdgeInsets.only(
                  left: AppSpacing.xl,
                  right: AppSpacing.md,
                ),
                leading: Icon(line.icon),
                title: Text(featureName(l10n, feature)),
                subtitle: Text(line.label(l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenFeature(feature),
              ),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  /// Null for a feature this subprocess does not list as selectable —
  /// an internal capability has no row.
  _FeatureLine? _stateOf(SubprocessStatus sub, WorkspaceFeature feature) {
    if (sub.enabled.contains(feature)) {
      return (
        icon: Icons.check,
        label: (l10n) => l10n?.processFeatureOn ?? 'On',
      );
    }
    for (final held in sub.heldBack) {
      if (held.feature != feature) continue;
      return (
        icon: Icons.pause_circle_outline,
        label: (l10n) {
          final parent = featureName(l10n, held.waitingFor);
          return l10n?.processFeatureWaiting(parent) ??
              'On, waiting for $parent';
        },
      );
    }
    if (sub.off.contains(feature)) {
      return (
        icon: Icons.remove,
        label: (l10n) => l10n?.processFeatureOff ?? 'Off',
      );
    }
    return null;
  }
}

typedef _FeatureLine = ({
  IconData icon,
  String Function(AppLocalizations? l10n) label,
});

class _SubprocessHeading extends StatelessWidget {
  const _SubprocessHeading({super.key, required this.status});

  final SubprocessStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final copy = processCopy(l10n, status.subprocess.key);
    final stateLabel = processStateLabel(l10n, status.state);
    final count =
        l10n?.processFeatureCount(
          status.enabled.length,
          status.capabilityCount,
        ) ??
        '${status.enabled.length} of ${status.capabilityCount} features on';
    return Semantics(
      container: true,
      header: true,
      excludeSemantics: true,
      label: [copy.title, stateLabel, count].join('. '),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(copy.title, style: theme.textTheme.titleSmall),
            Text(
              copy.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _StateLine(state: status.state, label: '$stateLabel · $count'),
          ],
        ),
      ),
    );
  }
}
