// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4299 -- a few features' switches on a page that is not the Features screen
// (the Stock settings): the same rows and the same switch flow (consent,
// conflicts, the confirmed write), asked of the same workspace. The maturity
// ledger is read here, in the workspace presentation, and nowhere else.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/feature_lifecycle.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_schema_providers.dart';
import 'feature_capability_list.dart';
import 'feature_switch_flow.dart';

class FeatureSwitchList extends ConsumerWidget {
  const FeatureSwitchList({super.key, required this.features});

  /// The features shown, parents first.
  final List<WorkspaceFeature> features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null) return const SizedBox.shrink();
    // The RAW stored set, as the Features screen reads it: a child's saved
    // choice must survive its parent being off.
    final raw = resolveEnabledFeatures(workspace.featureFlags);
    return FeatureCapabilityList(
      key: const ValueKey('feature-switch-list'),
      shrinkWrap: true,
      roomyTargets: true,
      showHint: false,
      rows: [for (final f in features) featureManifest[f]!],
      raw: raw,
      country: workspace.countryCode,
      schema: ref.watch(currentWorkspaceSchemaProvider),
      onChanged: (feature, {required value}) => switchWorkspaceFeature(
        context,
        ref,
        workspace: workspace,
        enabled: raw,
        feature: feature,
        value: value,
        assessments: featureAssessments,
      ),
    );
  }
}
