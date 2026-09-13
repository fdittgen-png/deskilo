// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../../../core/ui/empty_state.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/feature_tile.dart';
import '../widgets/features_filter_bar.dart';
import '../feature_copy.dart';
import '../feature_names.dart';

/// Owner-only feature management (#146): one switch per registry feature.
/// Toggling writes the full flags map to the workspace row (owner RLS)
/// and invalidates the workspace chain so the gates apply immediately —
/// other members pick the flags up on their next connect/refetch.
class FeaturesScreen extends ConsumerStatefulWidget {
  const FeaturesScreen({super.key});

  @override
  ConsumerState<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends ConsumerState<FeaturesScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _changedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Does this row answer what the owner typed?
  ///
  /// Name AND description, because an owner who does not know a
  /// feature's name searches for what it does — "reminder" finds
  /// *Payment reminders*, and "VAT" finds the four that mention it.
  bool _matches(String name, String description, String? requires) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    return name.toLowerCase().contains(needle) ||
        description.toLowerCase().contains(needle) ||
        (requires ?? '').toLowerCase().contains(needle);
  }

  String _name(AppLocalizations? l10n, WorkspaceFeature feature) =>
      featureName(l10n, feature);

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
    Set<WorkspaceFeature> enabled,
    WorkspaceFeature feature,
    bool value,
  ) async {
    final l10n = AppLocalizations.of(context);
    // #800 — switching one ON switches on everything it NEEDS.
    //
    // A switch that can be flipped green while the feature stays absent
    // is the worst kind of setting: the owner has configured the thing
    // and the app disagrees, with nothing on screen to explain it.
    final alsoOn = alsoEnabledWith(raw: enabled, feature: feature);
    // #963 — write ONLY what this toggle changes; the server merges it
    // into the row. A full map written from a stale copy of the row put
    // the pilot's earlier switches back off.
    final flags = {
      for (final entry
          in featureFlagsToggleDelta(feature: feature, value: value).entries)
        entry.key.dbKey: entry.value,
    };
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'set feature flags failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
          await ref
              .read(workspaceRepositoryProvider)
              .setFeatureFlags(workspace.id, flags);
      },
    )) {
      return;
    }
    // The workspace chain re-derives enabledFeatures from the new row —
    // that applies the gates locally right away. The read after the
    // invalidation FORCES the fetch: the pilot's device skipped it twice
    // out of three and the switch stayed where it was.
    ref.invalidate(myWorkspacesProvider);
    await ref.read(myWorkspacesProvider.future);
    // Naming what else came on: a cascade nobody sees is a surprise the
    // next time they read the list.
    if (value && alsoOn.isNotEmpty && context.mounted) {
      AppSnack.info(
        context,
        l10n?.featureAlsoEnabled(
              alsoOn.map((f) => featureName(l10n, f)).join(', '),
            ) ??
            'Also switched on: '
                '${alsoOn.map((f) => featureName(l10n, f)).join(', ')}',
        replace: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    // The RAW stored set, not the effective one: a child's saved choice
    // must survive its parent being switched off (and its switch must
    // show that saved choice, greyed out).
    final raw = workspace == null
        ? const <WorkspaceFeature>{}
        : resolveEnabledFeatures(workspace.featureFlags);

    // #1190 — one row per feature, already filtered, so the tier
    // headings and the empty state can both ask "did anything survive".
    final rows = <FeatureManifestEntry>[];
    var changedCount = 0;
    for (final entry in featureManifest.values) {
      if (raw.contains(entry.feature) != entry.defaultOn) changedCount++;
      final requires = entry.requires == null
          ? null
          : (l10n?.featureRequires(featureName(l10n, entry.requires!)) ??
              'Requires ${featureName(l10n, entry.requires!)}');
      if (_changedOnly && raw.contains(entry.feature) == entry.defaultOn) {
        continue;
      }
      if (!_matches(
        _name(l10n, entry.feature),
        featureDescription(l10n, entry.feature),
        requires,
      )) {
        continue;
      }
      rows.add(entry);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.featuresTitle ?? 'Features')),
      body: workspace == null
          ? const LoadingView()
          : Column(
              children: [
                FeaturesFilterBar(
                  controller: _search,
                  onQuery: (value) => setState(() => _query = value.trim()),
                  changedOnly: _changedOnly,
                  onChangedOnly: (value) =>
                      setState(() => _changedOnly = value),
                  changedCount: changedCount,
                ),
                Expanded(
                  child: rows.isEmpty
                      ? EmptyState(
                          key: const ValueKey('features-no-match'),
                          icon: Icons.search_off_outlined,
                          title: l10n?.featuresNoMatch ??
                              'No feature matches that.',
                        )
                      : ListView(
                          children: [
                            // #606 — contextual how-to; gated inside the
                            // widget. Hidden while filtering: somebody
                            // who typed a name is past being introduced.
                            if (_query.isEmpty && !_changedOnly)
                              const HelpHint(HelpHintId.features),
                            // #1063 — two sections, so that reaching for
                            // a platform capability is a deliberate act
                            // rather than the state the workspace woke
                            // up in. Registry order is kept INSIDE each
                            // tier: the hierarchy indents children under
                            // their parent, and a parent and its child
                            // are always in the same tier.
                            // #1221 — grouped by WHERE it shows up. The
                            // tier answers "should a space like mine
                            // have this"; the surface answers "where
                            // would I see it", which is the question an
                            // owner actually arrives with. The tier
                            // survives as a chip on the row.
                            for (final surface in FeatureSurface.values) ...[
                              // A heading over nothing is worse than no
                              // heading: while filtering, a surface that
                              // matched nothing is simply absent.
                              if (rows.any((e) => e.surface == surface))
                                FeatureSurfaceHeading(surface: surface),
                              for (final entry in rows)
                                if (entry.surface == surface)
                                  FeatureTile(
                                    entry: entry,
                                    name: _name(l10n, entry.feature),
                                    description: featureDescription(
                                        l10n, entry.feature),
                                    requiresLabel: entry.requires == null
                                        ? null
                                        : (l10n?.featureRequires(featureName(
                                                l10n, entry.requires!)) ??
                                            'Requires '
                                                '${featureName(l10n, entry.requires!)}'),
                                    value: raw.contains(entry.feature),
                                    // #800 — every switch is live. A
                                    // child no longer waits for its
                                    // parent: turning it on brings the
                                    // parent with it, which is what an
                                    // owner means by "switch this on".
                                    inactive: entry.requires != null &&
                                        !effectiveFeatures(raw)
                                            .contains(entry.requires),
                                    alsoEnables: alsoEnabledWith(
                                      raw: raw,
                                      feature: entry.feature,
                                    )
                                        .map((f) => featureName(l10n, f))
                                        .toList(),
                                    onChanged: (value) => _toggle(
                                      context,
                                      ref,
                                      workspace,
                                      raw,
                                      entry.feature,
                                      value,
                                    ),
                                  ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
