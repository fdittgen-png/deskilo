// SPDX-License-Identifier: 0BSD
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
//   5. this pin bumped — the number changing in review IS the check
//      that the author thought about feature management.
// See docs/AGENT_RULES.md ("Feature management").
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/feature_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// 27 pre-#502 + documents (#500) + dunning + memberReports +
/// deletionRequests (#502).
// 30→31 (2026-08-06): #513 roleManagement.
// 31→32 (2026-08-11): #534 vatDeclarations (requires invoicing).
// 32→33 (2026-08-11): #544 vatManagement (rates editor + rate pickers;
// vatDeclarations re-parented under it).
// 33→34 (2026-08-14): #568 einvoiceCustomerDelivery (second send leg).
const int _expectedFeatureCount = 34;

void main() {
  test('every functionality is registered — the pin', () {
    expect(
      WorkspaceFeature.values.length,
      _expectedFeatureCount,
      reason: 'WorkspaceFeature has ${WorkspaceFeature.values.length} '
          'entries, the pin says $_expectedFeatureCount. New '
          'functionality? Add its flag (enum + manifest + names + l10n '
          '+ UI gates) and bump the pin. Removed one? Walk the manifest '
          'and the gates first.',
    );
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
