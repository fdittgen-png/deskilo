// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../../application/toggle_workspace_feature.dart';
import '../widgets/feature_capability_list.dart';
import '../widgets/process_details.dart';
import '../widgets/features_filter_bar.dart';
import '../widgets/features_view_switch.dart';
import '../widgets/process_overview.dart';
import '../feature_copy.dart';
import '../feature_names.dart';

/// Owner-only feature management (#146). #1327 — it opens on the process
/// overview; one switch per registry feature is the second view, kept
/// whole for support (search, Changed, one flip). A toggle writes its
/// delta and refetches, so the gates apply immediately.
class FeaturesScreen extends ConsumerStatefulWidget {
  const FeaturesScreen({super.key});

  @override
  ConsumerState<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends ConsumerState<FeaturesScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _changedOnly = false;
  bool _switches = false;

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

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
    Set<WorkspaceFeature> enabled,
    WorkspaceFeature feature,
    bool value,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Switching on includes the prerequisites named in the result.
    final alsoOn = alsoEnabledWith(raw: enabled, feature: feature);
    // #1327 — the write itself (the #963 delta, then the forced
    // refetch) is application/toggle_workspace_feature.dart's decision.
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'set feature flags failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => toggleWorkspaceFeature(ref,
          workspace: workspace, feature: feature, value: value),
    )) {
      return;
    }
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
        featureName(l10n, entry.feature),
        featureDescription(l10n, entry.feature),
        requires,
      )) {
        continue;
      }
      rows.add(entry);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.featuresTitle ?? 'Features'), actions: [
        IconButton(
          key: const ValueKey('process-details-open'),
          tooltip: l10n?.processDetails ?? 'Processes and dependencies',
          icon: const Icon(Icons.account_tree_outlined),
          onPressed: workspace == null ? null : () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => ProcessDetails(raw: raw))),
        ),
      ]),
      body: workspace == null
          ? const LoadingView()
          : Column(
              children: [
                FeaturesViewSwitch(
                  switches: _switches,
                  onChanged: (value) => setState(() => _switches = value),
                ),
                if (!_switches)
                  Expanded(
                    child: ProcessOverview(
                      raw: raw,
                      onOpenFeature: (f) => Navigator.of(context).push<void>(
                        MaterialPageRoute(builder: (_) => CapabilityDetails(
                          feature: f, raw: raw))),
                    ),
                  )
                else ...[
                  FeaturesFilterBar(
                    controller: _search,
                    onQuery: (value) => setState(() => _query = value.trim()),
                    changedOnly: _changedOnly,
                    onChangedOnly: (value) =>
                        setState(() => _changedOnly = value),
                    changedCount: changedCount,
                  ),
                  Expanded(
                    child: FeatureCapabilityList(
                      rows: rows,
                      raw: raw,
                      // Hidden while filtering: somebody who typed a name
                      // is past being introduced. The list takes the
                      // answer, not the filter state — "is the owner
                      // filtering" is a question about these controls.
                      showHint: _query.isEmpty && !_changedOnly,
                      onChanged: (feature, value) => _toggle(
                          context, ref, workspace, raw, feature, value),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
