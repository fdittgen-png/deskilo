// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_feature.dart';
import '../feature_copy.dart';
import '../feature_names.dart';
import 'feature_tile.dart';

/// The capability list of the Features screen: the surface headings and
/// one [FeatureTile] per row, or the empty state when a filter matched
/// nothing.
///
/// Extracted from `features_screen.dart` for #1327. The screen owns the
/// *filtering* — which rows survive the search and the changed-only
/// switch — and this widget owns the *rendering* of whatever survived.
/// That split is what lets the process-first overview (#1327's real
/// subject) grow a second presentation over the same rows without
/// touching the screen's state, and it took the screen back under its
/// length budget on the way.
///
/// It deliberately takes no filter state. [showHint] arrives already
/// decided, because "is the owner filtering" is a question about the
/// screen's controls, not about this list.
class FeatureCapabilityList extends StatelessWidget {
  const FeatureCapabilityList({
    super.key,
    required this.rows,
    required this.raw,
    required this.showHint,
    required this.onChanged,
  });

  /// The rows that survived the screen's filter, in registry order.
  final List<FeatureManifestEntry> rows;

  /// The RAW stored set, not the effective one: a child's saved choice
  /// must survive its parent being switched off, and its switch must
  /// show that saved choice, greyed out.
  final Set<WorkspaceFeature> raw;

  /// Whether to show the contextual how-to above the list. False while
  /// filtering: somebody who typed a name is past being introduced.
  final bool showHint;

  final void Function(WorkspaceFeature feature, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (rows.isEmpty) {
      return EmptyState(
        key: const ValueKey('features-no-match'),
        icon: Icons.search_off_outlined,
        title: l10n?.featuresNoMatch ?? 'No feature matches that.',
      );
    }

    return ListView(
      children: [
        // #606 — contextual how-to; gated inside the widget.
        if (showHint) const HelpHint(HelpHintId.features),
        // #1063 — two sections, so that reaching for a platform
        // capability is a deliberate act rather than the state the
        // workspace woke up in. Registry order is kept INSIDE each
        // tier: the hierarchy indents children under their parent, and
        // a parent and its child are always in the same tier.
        // #1221 — grouped by WHERE it shows up. The tier answers
        // "should a space like mine have this"; the surface answers
        // "where would I see it", which is the question an owner
        // actually arrives with. The tier survives as a chip on the row.
        for (final surface in FeatureSurface.values) ...[
          // A heading over nothing is worse than no heading: while
          // filtering, a surface that matched nothing is simply absent.
          if (rows.any((e) => e.surface == surface))
            FeatureSurfaceHeading(surface: surface),
          for (final entry in rows)
            if (entry.surface == surface) _tile(l10n, entry),
        ],
      ],
    );
  }

  Widget _tile(AppLocalizations? l10n, FeatureManifestEntry entry) {
    final requires = entry.requires;
    return FeatureTile(
      entry: entry,
      name: featureName(l10n, entry.feature),
      description: featureDescription(l10n, entry.feature),
      requiresLabel: requires == null
          ? null
          : (l10n?.featureRequires(featureName(l10n, requires)) ??
              'Requires ${featureName(l10n, requires)}'),
      value: raw.contains(entry.feature),
      // #800 — every switch is live. A child no longer waits for its
      // parent: turning it on brings the parent with it, which is what
      // an owner means by "switch this on".
      inactive: requires != null && !effectiveFeatures(raw).contains(requires),
      alsoEnables: alsoEnabledWith(raw: raw, feature: entry.feature)
          .map((f) => featureName(l10n, f))
          .toList(),
      onChanged: (value) => onChanged(entry.feature, value),
    );
  }
}
