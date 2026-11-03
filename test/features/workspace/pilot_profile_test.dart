// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#1974, amendment 2026-10-14): the existing-community pilot's
// feature profile, as explicit values, and the exact set of features it
// resolves to (a reviewed golden list). The five excluded features are OFF with
// everything that needs them; the features the pilot fixtures and the
// amendment name are explicitly ON. An absent key is NOT on since #2566 (a
// platform flag nobody chose is off), so a profile that leaves one out loses
// it. The golden list is maintainer-derived from the current manifest; an
// operator-reviewed inventory of the real workspace is #1285, where the
// feature profile was deliberately left unchanged.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pilot_profile.dart';

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
      final entry = featureManifest[f]!;
      // A default-on core feature stays on whatever is stored; only a flag
      // nobody chose that resolves OFF can be lost this way.
      if (entry.tier == FeatureTier.core && entry.defaultOn) continue;
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

  test('the flags the pilot fixtures enable are all in the required set', () {
    // 160 and 164 are the pilot's database journey; the features they switch
    // on are what the journey needs, so the profile must name every one.
    final named = {for (final f in pilotRequiredOn) f.dbKey};
    for (final file in const [
      'supabase/tests/database/160_pilot_reconciliation.sql',
      'supabase/tests/database/164_invoice_feature_guards.sql',
    ]) {
      final sql = File(file).readAsStringSync();
      final flags = RegExp(r'\{("[A-Za-z]+":true(?:,"[A-Za-z]+":true)*)\}')
          .firstMatch(sql);
      expect(flags, isNotNull, reason: '$file has no feature_flags literal');
      for (final m in RegExp(r'"([A-Za-z]+)":true').allMatches(flags![1]!)) {
        expect(named, contains(m[1]), reason: '$file enables ${m[1]}');
      }
    }
  });

  test('the exact effective set is the reviewed golden list: a core default '
      'or an unlisted platform feature cannot change it unnoticed', () {
    final names = [for (final f in _effective(pilotProfile())) f.name]..sort();
    final golden = File('test/helpers/pilot_effective_features.txt');
    if (Platform.environment['PILOT_GOLDEN_WRITE'] == '1') {
      golden.writeAsStringSync('${names.join('\n')}\n');
    }
    expect(
      names,
      golden.readAsLinesSync().where((l) => l.isNotEmpty).toList(),
      reason: 'the effective pilot feature set changed: review the diff, then '
          'rerun with PILOT_GOLDEN_WRITE=1 to record it',
    );
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
