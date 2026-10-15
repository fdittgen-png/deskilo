// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2566 — a flag nobody has chosen resolves exactly as a new workspace
// stores it, on the client and on the server: a core flag follows its
// default, a platform flag ("asked for, never assumed") is off. A platform
// flag added after a workspace was created must not switch itself on there,
// and the two definitions cannot drift apart again.

import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

String _latestFeatureRaw() {
  final files = sqlFiles('supabase/migrations')
      .where(
        (f) => f.readAsStringSync().contains(
          'create or replace function public.feature_raw(',
        ),
      )
      .toList();
  final sql = files.last.readAsStringSync();
  final start = sql.indexOf('create or replace function public.feature_raw(');
  return sql.substring(start, sql.indexOf(r'$$;', start));
}

void main() {
  test('a key absent from the stored flags resolves as a new workspace '
      'stores it', () {
    final stored = defaultFeatureFlagsForNewWorkspace();
    final resolved = resolveEnabledFeatures(const {});
    for (final entry in featureManifest.values) {
      expect(
        resolved.contains(entry.feature),
        stored[entry.feature.dbKey],
        reason: entry.feature.dbKey,
      );
    }
  });

  test('a platform flag added later stays off; a stored choice wins', () {
    expect(featureManifest[WorkspaceFeature.salesTax]!.defaultOn, isTrue);
    expect(
      resolveEnabledFeatures(const {}),
      isNot(contains(WorkspaceFeature.salesTax)),
    );
    expect(
      effectiveFeatures(resolveEnabledFeatures(const {'salesTax': true})),
      contains(WorkspaceFeature.salesTax),
    );
    expect(
      resolveEnabledFeatures(const {}),
      contains(WorkspaceFeature.formHelpHints),
    );
  });

  test('the live feature_raw answers an absent key with default AND core', () {
    final body = _latestFeatureRaw();
    expect(body, contains("->> 'default'"));
    expect(body, contains("->> 'core'"));
  });
}
