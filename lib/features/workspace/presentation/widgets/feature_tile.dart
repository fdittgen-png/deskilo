// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/schema_version.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/feature_lifecycle.dart';
import '../../domain/feature_operation.dart';
import '../../domain/workspace_feature.dart';
import '../feature_surface_labels.dart';
import 'feature_maturity_badge.dart';

/// #1221 — the heading of one part of the app: what it is called, what
/// that part of the app is for, and what it looks like on the bar.
///
/// It replaced a tier heading, which sorted the list by a judgement
/// ("core" / "platform") rather than by a place. An owner looking for
/// the VAT one thinks "Money", never "platform tier".
class FeatureSurfaceHeading extends StatelessWidget {
  const FeatureSurfaceHeading({super.key, required this.surface});

  final FeatureSurface surface;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('feature-surface-${surface.name}'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            featureSurfaceIcon(surface),
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featureSurfaceName(context, l10n, surface).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  featureSurfaceHint(l10n, surface),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One feature row: children indent under their parent, carry the
/// "Requires X" note, and grey out while the parent (chain) is off.
class FeatureTile extends ConsumerWidget {
  const FeatureTile({
    super.key,
    required this.entry,
    required this.name,
    required this.description,
    required this.requiresLabel,
    required this.value,
    required this.inactive,
    required this.alsoEnables,
    required this.onChanged,
    this.assessment,
  });

  final FeatureManifestEntry entry;
  final String name;
  final String description;
  final String? requiresLabel;
  final bool value;

  /// On, but held back by a parent that is off — the switch still reads
  /// the owner's choice, and the subtitle says why nothing happens.
  final bool inactive;

  /// What turning this on would switch on as well, already named.
  final List<String> alsoEnables;
  final ValueChanged<bool> onChanged;

  /// #1850 — the row's maturity and lifecycle; the registry's when null.
  final FeatureAssessment? assessment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final child = entry.requires != null;
    // #1851 C — only a server that runs the classes may be described as
    // keeping open work answerable; an older, offline or unknown one is
    // not claimed to.
    final keepsWork = featureKeepsExistingWork(entry.feature);
    final confirmed = keepsWork &&
        serverKeepsExistingWork(
          entry.feature,
          ref.watch(schemaCompatibilityProvider).value,
        );
    final notes = [
      ?requiresLabel,
      if (!value && alsoEnables.isNotEmpty)
        l10n?.featureAlsoEnables(alsoEnables.join(', ')) ??
            'Switching this on also enables ${alsoEnables.join(', ')}',
      // #1851 — what off means for a feature whose open work survives it.
      if (!value && confirmed)
        l10n?.featureIntakeStoppedNote ??
            'Off: nothing new starts; what is already open can still be '
                'answered and closed.',
      if (!value && keepsWork && !confirmed)
        l10n?.featureIntakeUnconfirmedNote ??
            'Off: nothing new starts. This server could not confirm that '
                'what is already open stays answerable, so do not count on '
                'it.',
      if (value && inactive)
        l10n?.featureHeldBack ??
            'Waiting on the feature above — switch that on and this one '
                'works again.',
    ];
    // #1221 — the lead sentence says WHAT it is; the rest says how it
    // behaves, and only matters for the one row you stopped on. The
    // descriptions average 158 characters and run to 390, so shown
    // whole they were prose you scrolled past rather than read.
    final split = splitFeatureDescription(description);
    final held = value && inactive;
    return Padding(
      padding: EdgeInsets.only(left: child ? 24 : 0),
      child: SwitchListTile(
        key: ValueKey('feature-${entry.feature.name}'),
        // #1190 — 102 of these at roughly 230 px each was thirteen
        // screens of scrolling. Compact takes the padding, never the
        // text: the description is the half that earns its room.
        visualDensity: VisualDensity.compact,
        isThreeLine: notes.isNotEmpty,
        title: Row(
          children: [
            Flexible(
              child: HelpDotTitle(
                name,
                l10n?.helpHintFeaturesTopic ?? 'Features',
                anchor: HelpAnchor.featuresSwitch,
              ),
            ),
            // The tier the grouping used to be: a space that wants only
            // the basics can still see at a glance which rows are the
            // deliberate extras.
            if (entry.tier == FeatureTier.platform) ...[
              const SizedBox(width: AppSpacing.xs),
              _TierChip(tier: entry.tier),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // #1850 — its own line: beside the title it squeezed the
            // name at phone width and at large text.
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: FeatureMaturityBadge(
                assessment: assessment ?? featureAssessmentOf(entry.feature),
              ),
            ),
            Text(
              split.lead,
              style: held ? TextStyle(color: theme.colorScheme.error) : null,
            ),
            if (split.rest.isNotEmpty)
              _MoreAbout(
                key: ValueKey('feature-more-${entry.feature.name}'),
                text: split.rest,
              ),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: held
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// The detail behind a feature's lead sentence, folded away (#1221).
class _MoreAbout extends StatefulWidget {
  const _MoreAbout({super.key, required this.text});

  final String text;

  @override
  State<_MoreAbout> createState() => _MoreAboutState();
}

class _MoreAboutState extends State<_MoreAbout> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        // A plain inline control, not an IconButton: it sits inside a
        // switch row, and a 48 dp target here would fight the switch
        // for the row's height and for the tap.
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              _open
                  ? (l10n?.featureLess ?? 'Less')
                  : (l10n?.featureMore ?? 'More'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// #1221 — what the tier heading became: a mark on the rows that are
/// deliberate extras rather than the sorting key of the whole screen.
class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final FeatureTier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        l10n?.featureTierPlatform ?? 'Platform',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}
