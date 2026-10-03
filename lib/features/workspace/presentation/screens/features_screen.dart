// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/feature_lifecycle.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/feature_capability_list.dart';
import '../widgets/feature_maturity_badge.dart';
import '../widgets/feature_switch_flow.dart';
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
  const FeaturesScreen({super.key, this.assessments = featureAssessments});

  /// #1850 — the maturity ledger; a test hands in its own.
  final Map<WorkspaceFeature, FeatureAssessment> assessments;

  @override
  ConsumerState<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends ConsumerState<FeaturesScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _changedOnly = false;
  bool _switches = false;
  var _maturity = FeatureMaturityFilter.all;

  /// A feature tapped on the overview, shown among the switches — the
  /// only place a flag is written until #1329's process activation.
  void _openFeature(String name) => setState(() {
        _switches = true;
        _changedOnly = false;
        _search.text = name;
        _query = name;
      });

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
      final assessment = featureAssessmentOf(entry.feature,
          assessments: widget.assessments);
      if (!featureMaturityFilterMatches(_maturity, assessment)) continue;
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
      appBar: AppBar(title: Text(l10n?.featuresTitle ?? 'Features')),
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
                      onOpenFeature: (f) => _openFeature(featureName(l10n, f)),
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
                    maturity: _maturity,
                    onMaturity: (value) => setState(() => _maturity = value),
                  ),
                  Expanded(
                    child: FeatureCapabilityList(
                      rows: rows,
                      raw: raw,
                      assessments: widget.assessments,
                      // Hidden while filtering: somebody who typed a name
                      // is past being introduced. The list takes the
                      // answer, not the filter state — "is the owner
                      // filtering" is a question about these controls.
                      showHint: _query.isEmpty &&
                          !_changedOnly &&
                          _maturity == FeatureMaturityFilter.all,
                      onChanged: (feature, value) => switchWorkspaceFeature(
                        context,
                        ref,
                        workspace: workspace,
                        enabled: raw,
                        feature: feature,
                        value: value,
                        assessments: widget.assessments,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
