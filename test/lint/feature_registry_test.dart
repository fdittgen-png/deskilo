// SPDX-License-Identifier: AGPL-3.0-or-later
// 2026-09-16: #1325 process_registry_test also requires every flag to have
// one business home or an explicit internal reason; enum count unchanged.
//
// Feature-management completeness (#502) — the LIFETIME rule of this
// project: every user-facing functionality ships behind a
// [WorkspaceFeature] flag, wired end to end. Concretely, a new
// functionality lands with:
//   1. a WorkspaceFeature enum value (compile-time exhaustive switches
//      then FORCE the name + description wiring),
//   2. a featureManifest entry (defaultOn + requires),
//   3. featureXxx / featureXxxDesc l10n keys in all five locales,
//   4. `features.contains(...)` gates on its UI surfaces,
//   5. its assessment line in feature_lifecycle.dart (#1850) and its
//      row in the generated process catalogue (#1863 retired the count
//      pins: the catalogue row and the server registry are the review).
// See docs/AGENT_RULES.md ("Feature management").
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_lifecycle.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/feature_names.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  _tierPins();

  test('every key the server ever registered is live or retired', () {
    // #1863 — the stable-ID contract that replaced the count pin. A flag
    // key lives on in stored maps, templates and exports long after the
    // migration that introduced it, so it may be retired (and stays in
    // the #1850 ledger so it is never reused) but never silently renamed
    // or dropped. Read from every feature_registry() the migrations ever
    // defined, not from a hand-kept list.
    final live = {for (final f in WorkspaceFeature.values) f.name};
    final ever = everRegisteredFeatureKeys();
    expect(ever, isNotEmpty, reason: 'the migrations define no registry');
    final lost = ever
        .where((k) => !live.contains(k) &&
            !retiredFeatureAssessments.containsKey(k))
        .toList()
      ..sort();
    expect(lost, isEmpty,
        reason: 'these keys were registered on the server and are neither '
            'a WorkspaceFeature nor in retiredFeatureAssessments: '
            '${lost.join(', ')}');
  });

  test('every manifest key is a WorkspaceFeature, once', () {
    expect(featureManifest.keys.toSet(), WorkspaceFeature.values.toSet());
    for (final e in featureManifest.entries) {
      expect(e.value.feature, e.key, reason: e.key.name);
    }
    final names = WorkspaceFeature.values.map((f) => f.dbKey).toList();
    expect(names.toSet().length, names.length,
        reason: 'two features share a stored key');
  });

  test('every feature has a manifest entry (defaultOn/requires)', () {
    for (final feature in WorkspaceFeature.values) {
      expect(
        featureManifest[feature],
        isNotNull,
        reason: '${feature.name} is missing from featureManifest — the '
            'Features screen would not offer it and enabledFeatures '
            'could not default it.',
      );
    }
  });

  test('every feature has a human name (fallback wired)', () {
    for (final feature in WorkspaceFeature.values) {
      expect(
        featureName(null, feature).trim(),
        isNotEmpty,
        reason: '${feature.name} has no name in feature_names.dart',
      );
    }
  });

  test('requires-chains stay acyclic and point at registered features',
      () {
    for (final entry in featureManifest.entries) {
      final seen = <WorkspaceFeature>{entry.key};
      var current = entry.value.requires;
      while (current != null) {
        expect(seen.add(current), isTrue,
            reason: 'requires cycle through ${current.name}');
        expect(featureManifest[current], isNotNull,
            reason:
                '${entry.key.name} requires unregistered ${current.name}');
        current = featureManifest[current]?.requires;
      }
    }
  });
}


void _tierPins() {
  test('every feature declares a tier, and the split is pinned', () {
    final core = featuresOfTier(FeatureTier.core).toSet();
    final platform = featuresOfTier(FeatureTier.platform).toSet();
    expect(core.intersection(platform), isEmpty);
    expect(core.union(platform), WorkspaceFeature.values.toSet(),
        reason: 'every feature is in exactly one tier');
    // #1863 — what a NEW workspace meets is no longer a count pin: every
    // feature's tier and default are rows of the generated, drift-checked
    // docs/design/process-catalogue.md (process_registry_test), so moving
    // one into Core shows in review as that row changing.
  });

  test('a child is never in a lower tier than its parent', () {
    // The Features screen indents a child under its parent, and the two
    // tiers are separate sections — so a core child of a platform parent
    // would be rendered away from the thing it depends on, and switching
    // it on would silently drag a platform capability in with it.
    final offenders = <String>[];
    for (final entry in featureManifest.values) {
      final parent = entry.requires;
      if (parent == null) continue;
      final parentEntry = featureManifest[parent]!;
      if (entry.tier == FeatureTier.core &&
          parentEntry.tier == FeatureTier.platform) {
        offenders.add('${entry.feature.name} (core) under '
            '${parent.name} (platform)');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('a new workspace starts Core, and nothing else', () {
    final flags = defaultFeatureFlagsForNewWorkspace();
    expect(
      flags.length,
      WorkspaceFeature.values.length,
      reason: 'every key is written EXPLICITLY at creation — that is what '
          'keeps resolution unchanged for workspaces that already exist',
    );
    for (final entry in featureManifest.values) {
      expect(
        flags[entry.feature.dbKey],
        entry.tier == FeatureTier.core && entry.defaultOn,
        reason: entry.feature.name,
      );
    }
    // The platform half is written FALSE, not omitted: "nobody has
    // chosen yet" and "chosen off" have to stay distinguishable.
    expect(
      flags.values.where((on) => on).length,
      lessThan(WorkspaceFeature.values.length),
    );
  });
}

/// Every key any migration's `feature_registry()` ever returned.
Set<String> everRegisteredFeatureKeys() {
  const definition = 'create or replace function public.feature_registry()';
  final keys = <String>{};
  for (final f in Directory('supabase/migrations').listSync().whereType<File>()) {
    if (!f.path.endsWith('.sql')) continue;
    final sql = f.readAsStringSync();
    final at = sql.indexOf(definition);
    if (at < 0) continue;
    final open = sql.indexOf("select '", at) + "select '".length;
    final close = sql.indexOf("'::jsonb", open);
    keys.addAll(
        (jsonDecode(sql.substring(open, close)) as Map<String, dynamic>).keys);
  }
  return keys;
}
