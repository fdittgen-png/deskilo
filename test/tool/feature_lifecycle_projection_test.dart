// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1850 B — the public-safe projection of the feature assessments.
//
// Invariant: the release artifact lists every registered and retired
// key once, sorted, with only the key, the two axes, the capability ids,
// the replacement chain and the versions — never the rationale, the
// limitations prose or anything else an assessment holds; and the
// committed docs/product/capabilities.release.json carries exactly what
// the registry says today.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_lifecycle.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capability_evidence/render.dart';

const _secret = 'CANARY-internal-rollout-note';

void main() {
  test('only public fields leave, for every key, retired included', () {
    final rows = featureLifecycleProjection(
      assessments: {
        'seriesBooking': const FeatureAssessment(
          maturity: FeatureMaturity.beta,
          rationale: _secret,
          evidence: ['booking'],
          limitations: _secret,
        ),
        'oldThing': const FeatureAssessment(
          maturity: FeatureMaturity.stable,
          lifecycle: FeatureLifecycle.retired,
          rationale: _secret,
          evidence: ['booking'],
          replacedBy: ['seriesBooking'],
          deprecatedIn: '1.0.0',
        ),
      },
    );
    expect(rows.map((r) => r['key']), ['oldThing', 'seriesBooking']);
    for (final r in rows) {
      expect(
        r.keys.toSet().difference({
          'key',
          'maturity',
          'lifecycle',
          'capabilities',
          'replaced_by',
          'introduced_in',
          'deprecated_in',
        }),
        isEmpty,
      );
    }
    expect(jsonEncode(rows), isNot(contains('CANARY')));
    expect(rows.first['replaced_by'], ['seriesBooking']);
    expect(rows.last['maturity'], 'beta');
  });

  test('the committed release artifact matches the registry', () {
    final release = jsonDecode(
      File('docs/product/capabilities.release.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final features = (release['features']! as List)
        .cast<Map<String, Object?>>();
    expect(features.map((f) => f['key']).toSet(), {
      for (final f in WorkspaceFeature.values) f.name,
      ...retiredFeatureAssessments.keys,
    });
    for (final f in features) {
      final live = WorkspaceFeature.values
          .where((w) => w.name == f['key'])
          .firstOrNull;
      if (live == null) continue;
      expect(f['maturity'], featureAssessmentOf(live).maturity.name);
      expect(f['capabilities'], featureAssessmentOf(live).evidence);
    }
  });
}
