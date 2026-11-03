// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#1974, amendment 2026-10-14): the existing-community pilot's
// feature profile is pinned whole, as explicit values. The five excluded
// features are OFF with everything that needs them; supplyClassification
// and configurableSettings, which the pilot needs, are explicitly ON. An
// absent key is NOT on since #2566 (a platform flag nobody chose is off), so
// a profile that leaves one out loses it: the profile must say it.
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pilot_exclusions_test.dart' show dependentsOf, pilotExcluded;

/// What the pilot needs on, beside the core. Each brings its requirement chain.
const pilotRequiredOn = <WorkspaceFeature>{
  WorkspaceFeature.supplyClassification,
  WorkspaceFeature.configurableSettings,
};

/// The profile as stored: every excluded feature explicitly off, every
/// required one explicitly on with what it needs.
Map<String, bool> pilotProfile() => {
      for (final f in pilotExcluded) f.dbKey: false,
      for (final f in pilotRequiredOn)
        for (final e in featureFlagsToggleDelta(feature: f, value: true).entries)
          e.key.dbKey: e.value,
    };

Set<WorkspaceFeature> _effective(Map<String, dynamic> flags) =>
    effectiveFeatures(resolveEnabledFeatures(flags));

void main() {
  test('the profile names the excluded features off and the required ones on', () {
    final profile = pilotProfile();
    for (final f in pilotExcluded) {
      expect(profile[f.dbKey], isFalse, reason: f.name);
    }
    for (final f in pilotRequiredOn) {
      expect(profile[f.dbKey], isTrue, reason: f.name);
      for (final needed in requirementChain(f)) {
        expect(profile[needed.dbKey], isTrue, reason: '${f.name} needs ${needed.name}');
      }
    }
  });

  test('the effective pilot: the required features work, the excluded ones '
      'and their dependents do not, the core works', () {
    final effective = _effective(pilotProfile());
    for (final f in pilotRequiredOn) {
      expect(effective.contains(f), isTrue, reason: f.name);
    }
    for (final excluded in pilotExcluded) {
      expect(effective.contains(excluded), isFalse, reason: excluded.name);
      for (final dependent in dependentsOf(excluded)) {
        expect(effective.contains(dependent), isFalse,
            reason: '${dependent.name} needs ${excluded.name}');
      }
    }
    expect(effective, isNotEmpty);
  });

  test('a legacy profile that leaves a required key out loses it (#2566): '
      'absent is off, so the pilot profile must state it', () {
    for (final f in pilotRequiredOn) {
      final legacy = {...pilotProfile()}..remove(f.dbKey);
      expect(_effective(legacy).contains(f), isFalse,
          reason: '${f.name} left out of the stored profile');
    }
    // What an absent key used to resolve to is not the pilot's choice: the
    // old default-on platform flags, merged under the explicit profile, change
    // nothing the profile states.
    final withOldDefaults = {...platformFeaturesOnByDefault, ...pilotProfile()};
    final effective = _effective(withOldDefaults);
    for (final excluded in pilotExcluded) {
      expect(effective.contains(excluded), isFalse, reason: excluded.name);
    }
    for (final f in pilotRequiredOn) {
      expect(effective.contains(f), isTrue, reason: f.name);
    }
  });

  test('an explicit override of an excluded feature is a visible change of the '
      'profile, not a silent one', () {
    for (final excluded in pilotExcluded) {
      final changed = {...pilotProfile(), excluded.dbKey: true};
      expect(changed, isNot(equals(pilotProfile())), reason: excluded.name);
      expect(_effective(changed).contains(excluded) ||
              requirementChain(excluded).any((r) => !_effective(changed).contains(r)),
          isTrue,
          reason: '${excluded.name} on is either effective or held by its own parent');
    }
  });

  test('the profile never switches a default-on core feature off', () {
    final profile = pilotProfile();
    for (final f in WorkspaceFeature.values) {
      final entry = featureManifest[f];
      if (entry != null && entry.tier == FeatureTier.core && entry.defaultOn) {
        expect(profile[f.dbKey], isNot(isFalse),
            reason: '${f.name} is a default-on core flag the pilot keeps');
      }
    }
  });
}
