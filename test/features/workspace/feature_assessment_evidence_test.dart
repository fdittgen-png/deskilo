// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1850 B — every maturity claim rests on the capability evidence ledger.
//
// Invariant: against the committed docs/product/capabilities.json, every
// feature above unreviewed cites only shipped, evidenced capabilities that
// name it and repeats their limitations; every feature a shipped,
// evidenced capability names is assessed against it; everything else is
// explicitly unreviewed with its reason. The rules themselves are proved
// on hand-written fixtures, each breaking exactly one of them, so the
// real ledger passing is not the only thing that shows them working.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_assessment_evidence.dart';
import 'package:deskilo/features/workspace/domain/feature_lifecycle.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

List<LedgerCapability> _ledger() {
  final json = jsonDecode(
    File('docs/product/capabilities.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return [
    for (final c in json['capabilities']! as List)
      LedgerCapability.fromManifest((c as Map).cast<String, Object?>()),
  ];
}

const _cap = LedgerCapability(
  id: 'booking',
  shipped: true,
  features: {'seriesBooking'},
  scopes: {'unit', 'local_integration'},
  limitations: 'Manual recovery.',
);

FeatureAssessment _beta({
  List<String> evidence = const ['booking'],
  String limitations = 'Manual recovery.',
}) => FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: 'fixture',
  evidence: evidence,
  limitations: limitations,
);

void main() {
  group('the committed ledger', () {
    test('every claim rests on it, and it is fully assessed', () {
      expect(
        validateAssessmentsAgainstLedger(
          assessments: featureAssessments,
          ledger: _ledger(),
        ),
        isEmpty,
      );
    });

    test('a feature no shipped capability names stays unreviewed', () {
      final named = {
        for (final c in _ledger())
          if (c.shipped && c.scopes.isNotEmpty) ...c.features,
      };
      for (final e in featureAssessments.entries) {
        if (named.contains(e.key.name)) continue;
        expect(
          e.value.maturity,
          FeatureMaturity.unreviewed,
          reason: e.key.name,
        );
        expect(e.value.rationale, contains('evidence ledger'));
      }
    });
  });

  group('the rules', () {
    Map<WorkspaceFeature, FeatureAssessment> one(FeatureAssessment a) => {
      WorkspaceFeature.seriesBooking: a,
    };

    test('a sound claim passes', () {
      expect(
        validateAssessmentsAgainstLedger(
          assessments: one(_beta()),
          ledger: const [_cap],
        ),
        isEmpty,
      );
    });

    test('a capability that is not shipped supports nothing', () {
      expect(
        validateAssessmentsAgainstLedger(
          assessments: one(_beta()),
          ledger: const [
            LedgerCapability(
              id: 'booking',
              shipped: false,
              features: {'seriesBooking'},
              scopes: {'unit'},
              limitations: 'Manual recovery.',
            ),
          ],
        ),
        contains('seriesBooking: cites "booking", which is not shipped'),
      );
    });

    test('a capability without evidence supports nothing', () {
      expect(
        validateAssessmentsAgainstLedger(
          assessments: one(_beta()),
          ledger: const [
            LedgerCapability(
              id: 'booking',
              shipped: true,
              features: {'seriesBooking'},
              scopes: {},
              limitations: 'Manual recovery.',
            ),
          ],
        ),
        contains('seriesBooking: cites "booking", which holds no evidence'),
      );
    });

    test('a capability that does not name the feature lends it nothing', () {
      expect(
        validateAssessmentsAgainstLedger(
          assessments: {WorkspaceFeature.kioskMode: _beta()},
          ledger: const [_cap],
        ),
        contains('kioskMode: cites "booking", which does not name it'),
      );
    });

    test('the limitations travel with the claim', () {
      expect(
        validateAssessmentsAgainstLedger(
          assessments: one(_beta(limitations: '')),
          ledger: const [_cap],
        ),
        contains('seriesBooking: drops the limitations of "booking"'),
      );
    });

    test('a feature the ledger names cannot stay unassessed', () {
      expect(
        validateAssessmentsAgainstLedger(
          assessments: one(const FeatureAssessment.unreviewed('not yet')),
          ledger: const [_cap],
        ),
        contains(
          'seriesBooking: named by shipped "booking" but not assessed '
          'against it',
        ),
      );
    });

    test('an unknown stored ledger entry supports nothing', () {
      final c = LedgerCapability.fromManifest(const {'id': 'x'});
      expect(c.shipped, isFalse);
      expect(c.scopes, isEmpty);
    });
  });
}
