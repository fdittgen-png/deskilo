// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1850 C — promotion checks against the CURRENT standing of evidence.
//
// Invariant: with the standings of the committed release artifact
// (docs/product/capabilities.release.json, written by the evidence tool
// from each capability's component fingerprint), every beta rests on
// gated or recorded evidence and nothing claims stable. On fixtures, each
// rule refuses exactly what it should: beta on stale or unverified
// evidence; stable without a current provider, runtime or operator
// record; stable while one of those records went stale; and evidence
// recorded for another capability never counts. Stable + deprecated with
// current evidence stays legal.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_assessment_evidence.dart';
import 'package:deskilo/features/workspace/domain/feature_lifecycle.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Map<String, EvidenceStanding>> _committedStandings() {
  final release = jsonDecode(
    File('docs/product/capabilities.release.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return {
    for (final c
        in (release['capabilities']! as List).cast<Map<String, Object?>>())
      c['id']! as String: {
        for (final e in (c['scopes']! as Map).entries)
          e.key as String: evidenceStandingFromName(e.value as String?),
      },
  };
}

FeatureAssessment _claim(
  FeatureMaturity maturity, {
  List<String> evidence = const ['pay'],
  FeatureLifecycle lifecycle = FeatureLifecycle.active,
}) => FeatureAssessment(
  maturity: maturity,
  lifecycle: lifecycle,
  rationale: 'fixture',
  evidence: evidence,
  deprecatedIn: lifecycle == FeatureLifecycle.active ? null : '1.1.0',
);

List<String> _check(
  FeatureAssessment a,
  Map<String, Map<String, EvidenceStanding>> standings,
) => validatePromotions(
  assessments: {WorkspaceFeature.onlinePayments: a},
  standings: standings,
);

const _gated = {'unit': EvidenceStanding.gated};

void main() {
  test('the committed claims pass the promotion checks', () {
    expect(
      validatePromotions(
        assessments: featureAssessments,
        standings: _committedStandings(),
      ),
      isEmpty,
    );
  });

  test('beta needs gated or recorded evidence', () {
    expect(_check(_claim(FeatureMaturity.beta), {'pay': _gated}), isEmpty);
    for (final weak in [EvidenceStanding.stale, EvidenceStanding.unverified]) {
      expect(
        _check(_claim(FeatureMaturity.beta), {
          'pay': {'unit': weak},
        }),
        ['onlinePayments: beta on evidence that is stale or unverified'],
        reason: weak.name,
      );
    }
    expect(_check(_claim(FeatureMaturity.beta), const {}), [
      'onlinePayments: beta on evidence that is stale or unverified',
    ]);
  });

  test('stable needs a current provider, runtime or operator record', () {
    expect(_check(_claim(FeatureMaturity.stable), {'pay': _gated}), [
      'onlinePayments: stable without a current provider, runtime or '
          'operator record',
    ]);
    expect(
      _check(_claim(FeatureMaturity.stable), {
        'pay': {
          'unit': EvidenceStanding.gated,
          'provider_sandbox': EvidenceStanding.recorded,
        },
      }),
      isEmpty,
    );
  });

  test('a stale record withdraws stable', () {
    expect(
      _check(_claim(FeatureMaturity.stable, evidence: ['pay', 'other']), {
        'pay': {'provider_sandbox': EvidenceStanding.recorded},
        'other': {'operator_pilot': EvidenceStanding.stale},
      }),
      ['onlinePayments: stable on a stale operator_pilot record of "other"'],
    );
  });

  test('another capability\'s record does not count', () {
    expect(
      _check(_claim(FeatureMaturity.stable), {
        'pay': _gated,
        'stripe': {'provider_sandbox': EvidenceStanding.recorded},
      }),
      [
        'onlinePayments: stable without a current provider, runtime or '
            'operator record',
      ],
    );
  });

  test('stable + deprecated with a current record stays legal', () {
    expect(
      _check(
        _claim(FeatureMaturity.stable, lifecycle: FeatureLifecycle.deprecated),
        {
          'pay': {'named_runtime': EvidenceStanding.recorded},
        },
      ),
      isEmpty,
    );
  });

  test('an unknown standing supports nothing', () {
    expect(evidenceStandingFromName('certified'), EvidenceStanding.unverified);
    expect(evidenceStandingFromName(null), EvidenceStanding.unverified);
  });
}
