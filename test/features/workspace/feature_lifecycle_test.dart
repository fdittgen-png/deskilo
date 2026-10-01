// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1850 — the maturity/lifecycle ledger beside the feature registry.
// Expectations here are written out by hand, never derived from the
// ledger under test.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_lifecycle.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> _evidenceIds() {
  final json = jsonDecode(
    File('docs/product/capabilities.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    for (final c in json['capabilities'] as List)
      (c as Map<String, dynamic>)['id'] as String,
  };
}

const _ok = FeatureAssessment.unreviewed('fixture');

Map<WorkspaceFeature, FeatureAssessment> _ledger(
  Map<WorkspaceFeature, FeatureAssessment> overrides,
) => {for (final f in WorkspaceFeature.values) f: overrides[f] ?? _ok};

List<String> _check(
  Map<WorkspaceFeature, FeatureAssessment> overrides, {
  Map<String, FeatureAssessment> retired = const {},
}) => validateFeatureAssessments(
  assessments: _ledger(overrides),
  retired: retired,
  evidenceIds: const {'booking', 'payments'},
);

void main() {
  group('the shipped ledger', () {
    test('every registered feature has an explicit assessment', () {
      final missing = WorkspaceFeature.values
          .where((f) => !featureAssessments.containsKey(f))
          .map((f) => f.name)
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'A new WorkspaceFeature needs a featureAssessments line '
            '(unreviewed until evidence says otherwise, #1850).',
      );
    });

    test('is valid against the capability evidence ledger', () {
      expect(
        validateFeatureAssessments(
          assessments: featureAssessments,
          retired: retiredFeatureAssessments,
          evidenceIds: _evidenceIds(),
        ),
        isEmpty,
      );
    });

    test('claims nothing above unreviewed until an assessment lands', () {
      // The baseline of #1850: no capability is certified by code landing,
      // an issue closing or a test count. Moving this number is a review
      // with evidence ids, never a side effect.
      final reviewed = featureAssessments.values
          .where((a) => a.maturity != FeatureMaturity.unreviewed)
          .length;
      expect(reviewed, 0);
    });
  });

  group('validation', () {
    test('stable + deprecated with evidence and a version is legal', () {
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment(
            maturity: FeatureMaturity.stable,
            lifecycle: FeatureLifecycle.deprecated,
            rationale: 'assessed',
            evidence: ['booking'],
            deprecatedIn: '1.4.0',
            replacedBy: ['usageRecords'],
          ),
          WorkspaceFeature.services: const FeatureAssessment(
            maturity: FeatureMaturity.alpha,
            rationale: 'pilot only',
          ),
        }),
        isEmpty,
      );
    });

    test('beta or stable without evidence is refused', () {
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment(
            maturity: FeatureMaturity.beta,
            rationale: 'x',
          ),
        }),
        ['carnets: beta without evidence'],
      );
    });

    test('evidence must name a capability the ledger declares', () {
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment(
            maturity: FeatureMaturity.stable,
            rationale: 'x',
            evidence: ['nowhere'],
          ),
        }),
        ['carnets: unknown evidence "nowhere"'],
      );
    });

    test('an empty rationale is refused, also for unreviewed', () {
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment.unreviewed(' '),
        }),
        ['carnets: no rationale'],
      );
    });

    test('a missing feature is named', () {
      final ledger = _ledger(const {})..remove(WorkspaceFeature.carnets);
      expect(
        validateFeatureAssessments(
          assessments: ledger,
          retired: const {},
          evidenceIds: const {},
        ),
        ['carnets: no assessment'],
      );
    });

    test('replacements: unknown, self, while active, and cycles', () {
      const dep = FeatureLifecycle.deprecated;
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment(
            maturity: FeatureMaturity.unreviewed,
            lifecycle: dep,
            deprecatedIn: '1',
            rationale: 'x',
            replacedBy: ['ghost'],
          ),
        }),
        ['carnets: replaced by unknown or retired "ghost"'],
      );
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment(
            maturity: FeatureMaturity.unreviewed,
            lifecycle: dep,
            deprecatedIn: '1',
            rationale: 'x',
            replacedBy: ['carnets'],
          ),
        }),
        ['carnets: replaced by itself'],
      );
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment(
            maturity: FeatureMaturity.unreviewed,
            rationale: 'x',
            replacedBy: ['services'],
          ),
        }),
        ['carnets: replaced while still active'],
      );
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment(
            maturity: FeatureMaturity.unreviewed,
            lifecycle: dep,
            deprecatedIn: '1',
            rationale: 'x',
            replacedBy: ['services'],
          ),
          WorkspaceFeature.services: const FeatureAssessment(
            maturity: FeatureMaturity.unreviewed,
            lifecycle: dep,
            deprecatedIn: '1',
            rationale: 'x',
            replacedBy: ['carnets'],
          ),
        }),
        unorderedEquals(
            ['carnets: replacement cycle', 'services: replacement cycle']),
      );
    });

    test('a deprecation needs a version', () {
      expect(
        _check({
          WorkspaceFeature.carnets: const FeatureAssessment(
            maturity: FeatureMaturity.unreviewed,
            lifecycle: FeatureLifecycle.deprecated,
            rationale: 'x',
          ),
        }),
        ['carnets: deprecated without a version'],
      );
    });

    test('retired keys stay retired and are never registered again', () {
      const gone = FeatureAssessment(
        maturity: FeatureMaturity.unreviewed,
        lifecycle: FeatureLifecycle.retired,
        deprecatedIn: '1',
        rationale: 'removed',
      );
      expect(_check(const {}, retired: {'oldThing': gone}), isEmpty);
      expect(_check(const {}, retired: {'carnets': gone}), [
        'carnets: a retired key is registered again',
      ]);
      expect(_check({WorkspaceFeature.carnets: gone}), [
        'carnets: retired but still registered',
      ]);
      expect(_check(const {}, retired: {'oldThing': _ok}), [
        'oldThing: in the retired list but not retired',
      ]);
    });
  });

  group('reading stored values', () {
    test('unknown maturity, version or nothing reads as unreviewed', () {
      expect(featureMaturityFromName('stable'), FeatureMaturity.stable);
      expect(featureMaturityFromName('gamma'), FeatureMaturity.unreviewed);
      expect(featureMaturityFromName(null), FeatureMaturity.unreviewed);
      expect(
        featureMaturityFromName('stable', schemaVersion: 99),
        FeatureMaturity.unreviewed,
      );
    });

    test('an unknown lifecycle reads as active', () {
      expect(
        featureLifecycleFromName('deprecated'),
        FeatureLifecycle.deprecated,
      );
      expect(featureLifecycleFromName('sunset'), FeatureLifecycle.active);
    });
  });

  test('maturity never grants anything: no gate reads the ledger', () {
    // Only the ledger itself and the Features screen's presentation may
    // import it. A flag gate, a permission, a route or the MCP seam that
    // read maturity would turn a review label into an authorisation.
    final readers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('feature_lifecycle.dart'))
        .map((f) => f.path)
        .where(
          (p) =>
              !p.endsWith('domain/feature_lifecycle.dart') &&
              !p.contains('features/workspace/presentation/'),
        )
        .toList();
    expect(readers, isEmpty);
  });
}
