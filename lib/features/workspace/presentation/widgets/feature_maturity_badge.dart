// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/feature_lifecycle.dart';

/// #1850 — the maturity filter of the Features screen. [deprecated] is a
/// lifecycle, not a maturity, and is offered beside them because "what is
/// being replaced" is the question an owner asks of that axis.
enum FeatureMaturityFilter { all, unreviewed, alpha, beta, stable, deprecated }

/// Does [assessment] pass [filter]?
bool featureMaturityFilterMatches(
  FeatureMaturityFilter filter,
  FeatureAssessment assessment,
) => switch (filter) {
  FeatureMaturityFilter.all => true,
  FeatureMaturityFilter.deprecated =>
    assessment.lifecycle == FeatureLifecycle.deprecated,
  _ => assessment.maturity.name == filter.name,
};

String featureMaturityLabel(AppLocalizations? l10n, FeatureMaturity m) =>
    switch (m) {
      FeatureMaturity.unreviewed =>
        l10n?.featureMaturityUnreviewed ?? 'Unreviewed',
      FeatureMaturity.alpha => l10n?.featureMaturityAlpha ?? 'Alpha',
      FeatureMaturity.beta => l10n?.featureMaturityBeta ?? 'Beta',
      FeatureMaturity.stable => l10n?.featureMaturityStable ?? 'Stable',
    };

String featureLifecycleLabel(AppLocalizations? l10n, FeatureLifecycle l) =>
    switch (l) {
      FeatureLifecycle.active => l10n?.featureLifecycleActive ?? 'Active',
      FeatureLifecycle.deprecated =>
        l10n?.featureLifecycleDeprecated ?? 'Deprecated',
      FeatureLifecycle.retired => l10n?.featureLifecycleRetired ?? 'Retired',
    };

String featureMaturityFilterLabel(
  AppLocalizations? l10n,
  FeatureMaturityFilter f,
) => switch (f) {
  FeatureMaturityFilter.all => l10n?.featureMaturityFilterAll ?? 'All stages',
  FeatureMaturityFilter.deprecated => featureLifecycleLabel(
    l10n,
    FeatureLifecycle.deprecated,
  ),
  _ => featureMaturityLabel(l10n, FeatureMaturity.values.byName(f.name)),
};

/// The badges of one feature row: its maturity, always — unreviewed is a
/// statement too — and its lifecycle when it is not plain active. Words,
/// never colour alone, and one screen-reader sentence for both.
class FeatureMaturityBadge extends StatelessWidget {
  const FeatureMaturityBadge({super.key, required this.assessment});

  final FeatureAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final maturity = featureMaturityLabel(l10n, assessment.maturity);
    final lifecycle = featureLifecycleLabel(l10n, assessment.lifecycle);
    final reviewed = assessment.maturity != FeatureMaturity.unreviewed;
    final semantics =
        l10n?.featureMaturitySemantics(maturity, lifecycle) ??
        'Maturity $maturity, $lifecycle';
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.xs,
        children: [
          _Badge(
            key: const ValueKey('feature-maturity'),
            text: maturity,
            background: reviewed
                ? theme.colorScheme.tertiaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            foreground: reviewed
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
          if (assessment.lifecycle != FeatureLifecycle.active)
            _Badge(
              key: const ValueKey('feature-lifecycle'),
              text: lifecycle,
              background: theme.colorScheme.errorContainer,
              foreground: theme.colorScheme.onErrorContainer,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: background, borderRadius: AppRadius.smAll),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: foreground),
    ),
  );
}

/// The filter control: a chip naming the current stage, a menu of the
/// others.
class FeatureMaturityFilterButton extends StatelessWidget {
  const FeatureMaturityFilterButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FeatureMaturityFilter value;
  final ValueChanged<FeatureMaturityFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.featureMaturityFilterLabel ?? 'Maturity';
    return PopupMenuButton<FeatureMaturityFilter>(
      key: const ValueKey('features-filter-maturity'),
      tooltip: title,
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final f in FeatureMaturityFilter.values)
          CheckedPopupMenuItem(
            key: ValueKey('features-maturity-${f.name}'),
            value: f,
            checked: f == value,
            child: Text(featureMaturityFilterLabel(l10n, f)),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.verified_outlined, size: 18),
        label: Text(
          value == FeatureMaturityFilter.all
              ? title
              : featureMaturityFilterLabel(l10n, value),
        ),
      ),
    );
  }
}
