// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3729 (K2) — "needs at least" is raised only by a change the app cannot
// work without, and every raise carries its reason. The number of the last
// migration is pinned elsewhere (migration_version_marker_test.dart): it is
// what the app was BUILT against and moves with every migration.
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/workspace/domain/feature_operation.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the last entry of the history is the constant, with its reason', () {
    expect(appNeedsHistory, isNotEmpty);
    expect(appNeedsHistory.last.number, appNeedsSchemaVersion);
    for (final e in appNeedsHistory) {
      expect(e.reason.trim().length, greaterThan(20), reason: '${e.number}');
    }
  });

  test('every raise is a raise, and never above what the app was built '
      'against', () {
    var previous = 0;
    for (final e in appNeedsHistory) {
      expect(e.number, greaterThan(previous), reason: 'history is increasing');
      previous = e.number;
    }
    expect(appNeedsSchemaVersion, lessThanOrEqualTo(requiredSchemaVersion));
  });

  test('a feature never needs less than the app, and states a real schema',
      () {
    for (final e in featureManifest.values) {
      final since = e.since;
      if (since == null) continue;
      expect(since, greaterThan(0), reason: e.feature.name);
      expect(since, lessThanOrEqualTo(requiredSchemaVersion),
          reason: '${e.feature.name} needs a migration this build knows');
    }
  });

  test('an operation class never claims to hold before its feature does', () {
    for (final f in featureOperationSince.keys) {
      final own = featureManifest[f]?.since;
      if (own != null) {
        expect(featureOperationSince[f], greaterThanOrEqualTo(own));
      }
    }
  });
}
