// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#1974): the features the existing-community pilot excludes —
// online payments, MCP access, the accounting book, guest participation and
// public listings — are OFF for a workspace nobody configured, stay off
// however every other flag is set, and take their whole dependent chain
// with them: a child flag left on never works while its excluded parent is
// off. The set is pinned by name so widening it is a reviewed change.
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

const pilotExcluded = <WorkspaceFeature>{
  WorkspaceFeature.onlinePayments,
  WorkspaceFeature.mcpAccess,
  WorkspaceFeature.accountingBook,
  WorkspaceFeature.guestParticipation,
  WorkspaceFeature.publicListings,
};

/// Every feature whose requirement chain passes through [feature].
Set<WorkspaceFeature> dependentsOf(WorkspaceFeature feature) => {
      for (final f in WorkspaceFeature.values)
        if (requirementChain(f).contains(feature)) f,
    };

void main() {
  test('a workspace nobody configured has none of the excluded features', () {
    final effective = effectiveFeatures(resolveEnabledFeatures(const {}));
    expect(effective.intersection(pilotExcluded), isEmpty);
  });

  test('every excluded feature is a deliberate opt-in, not a default', () {
    for (final f in pilotExcluded) {
      expect(featureManifest[f]!.defaultOn, isFalse, reason: '$f');
    }
  });

  for (final excluded in pilotExcluded) {
    test('${excluded.name} off takes every dependent with it', () {
      // Everything else switched ON, the excluded one switched OFF.
      final flags = {
        for (final f in WorkspaceFeature.values) f.name: f != excluded,
      };
      final effective = effectiveFeatures(resolveEnabledFeatures(flags));
      expect(effective.contains(excluded), isFalse);
      for (final dependent in dependentsOf(excluded)) {
        expect(effective.contains(dependent), isFalse,
            reason: '${dependent.name} needs ${excluded.name}');
      }
    });
  }

  test('turning the excluded set off leaves the booking core working', () {
    final flags = {
      for (final f in WorkspaceFeature.values) f.name: !pilotExcluded.contains(f),
    };
    final effective = effectiveFeatures(resolveEnabledFeatures(flags));
    expect(effective, isNotEmpty);
    expect(effective.intersection(pilotExcluded), isEmpty);
  });
}
