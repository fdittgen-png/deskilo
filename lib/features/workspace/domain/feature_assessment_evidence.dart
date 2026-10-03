// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1850 B/C — the checks that tie each maturity claim of
// feature_lifecycle.dart to the capability evidence ledger
// (docs/product/capabilities.json, #1634) and to the current standing of
// that evidence. Pure: the tests and the evidence tool hand in what they
// read from the ledger and the release artifact.

import 'feature_lifecycle.dart';
import 'workspace_feature.dart';

/// #1850 B — one capability of the evidence ledger
/// (docs/product/capabilities.json, #1634), as far as an assessment reads
/// it.
class LedgerCapability {
  const LedgerCapability({
    required this.id,
    required this.shipped,
    required this.features,
    required this.scopes,
    this.limitations = '',
  });

  /// Reads one manifest entry; anything missing reads as "not shipped,
  /// no evidence", which can support no claim.
  factory LedgerCapability.fromManifest(Map<String, Object?> entry) {
    // A manifest entry, not a table row: it has no system columns.
    final id = entry['id'];
    final limitations = entry['limitations'];
    return LedgerCapability(
      id: id is String ? id : '',
      shipped: entry['status'] == 'shipped',
      features: {...(entry['features'] as List? ?? const []).cast<String>()},
      scopes: {
        for (final e in (entry['evidence'] as List? ?? const []))
          if (e is Map && e['scope'] is String) e['scope'] as String,
      },
      limitations: limitations is String ? limitations : '',
    );
  }

  final String id;
  final bool shipped;
  final Set<String> features;

  /// The evidence scopes the capability declares (unit, local_integration,
  /// provider_sandbox, …).
  final Set<String> scopes;
  final String limitations;
}

/// #1850 B — what is wrong with [assessments] against the evidence
/// [ledger], one sentence per problem:
///
/// * a claim above unreviewed cites only capabilities that are shipped,
///   hold evidence and name the feature, and repeats their limitations —
///   an assessment cannot lend itself a capability it is not part of, or
///   drop the limits that capability states;
/// * a feature that a shipped, evidenced capability names is assessed —
///   the ledger and the registry cannot drift apart silently.
List<String> validateAssessmentsAgainstLedger({
  required Map<WorkspaceFeature, FeatureAssessment> assessments,
  required List<LedgerCapability> ledger,
}) {
  final problems = <String>[];
  final byId = {for (final c in ledger) c.id: c};
  for (final e in assessments.entries) {
    final key = e.key.name;
    final a = e.value;
    if (a.maturity == FeatureMaturity.unreviewed) continue;
    for (final id in a.evidence) {
      final c = byId[id];
      if (c == null) continue; // validateFeatureAssessments names it
      if (!c.shipped) problems.add('$key: cites "$id", which is not shipped');
      if (c.scopes.isEmpty) {
        problems.add('$key: cites "$id", which holds no evidence');
      }
      if (!c.features.contains(key)) {
        problems.add('$key: cites "$id", which does not name it');
      }
      if (c.limitations.isNotEmpty && !a.limitations.contains(c.limitations)) {
        problems.add('$key: drops the limitations of "$id"');
      }
    }
  }
  final live = {for (final f in WorkspaceFeature.values) f.name: f};
  for (final c in ledger) {
    if (!c.shipped || c.scopes.isEmpty) continue;
    for (final name in c.features) {
      final f = live[name];
      if (f == null) continue;
      final a = assessments[f];
      if (a == null ||
          a.maturity == FeatureMaturity.unreviewed ||
          !a.evidence.contains(c.id)) {
        problems.add(
          '$name: named by shipped "${c.id}" but not assessed '
          'against it',
        );
      }
    }
  }
  return problems;
}

/// #1850 C — how one evidence scope of a capability stands today, as the
/// evidence tool computes it (tool/capability_evidence/render.dart):
/// gated scopes run on every change, recorded ones were run once against
/// the component's current fingerprint, stale ones against an older one.
enum EvidenceStanding { unverified, stale, gated, recorded }

/// A standing name from the release artifact; anything unknown is
/// [EvidenceStanding.unverified], which supports nothing.
EvidenceStanding evidenceStandingFromName(String? name) {
  for (final s in EvidenceStanding.values) {
    if (s.name == name) return s;
  }
  return EvidenceStanding.unverified;
}

/// The scopes whose evidence is recorded, not gated: a provider's
/// sandbox, a named runtime or build, an operator's pilot. Stable needs
/// one of them, current.
const Set<String> promotionScopes = {
  'provider_sandbox',
  'named_runtime',
  'operator_pilot',
};

/// #1850 C — the promotion checks: what each maturity claim needs from
/// the CURRENT standing of the evidence it cites ([standings]: capability
/// id → scope → standing).
///
/// * beta: at least one cited capability holds evidence that is gated or
///   recorded — stale or unverified evidence certifies nothing;
/// * stable: at least one cited capability holds a [promotionScopes]
///   record against its current component, and none of the cited
///   capabilities' records at those scopes has gone stale.
///
/// Evidence counts only for the capability that records it: a Stripe
/// sandbox run says nothing about a capability that does not cite it
/// (validateAssessmentsAgainstLedger keeps citations honest).
List<String> validatePromotions({
  required Map<WorkspaceFeature, FeatureAssessment> assessments,
  required Map<String, Map<String, EvidenceStanding>> standings,
}) {
  final problems = <String>[];
  for (final e in assessments.entries) {
    final key = e.key.name;
    final a = e.value;
    if (a.maturity.index < FeatureMaturity.beta.index) continue;
    final cited = [
      for (final id in a.evidence) (id, standings[id] ?? const {}),
    ];
    final current = cited.any(
      (c) => c.$2.values.any(
        (s) => s == EvidenceStanding.gated || s == EvidenceStanding.recorded,
      ),
    );
    if (!current) {
      problems.add(
        '$key: ${a.maturity.name} on evidence that is stale or '
        'unverified',
      );
    }
    if (a.maturity != FeatureMaturity.stable) continue;
    final recorded = cited.any(
      (c) => promotionScopes.any(
        (scope) => c.$2[scope] == EvidenceStanding.recorded,
      ),
    );
    if (!recorded) {
      problems.add(
        '$key: stable without a current provider, runtime or '
        'operator record',
      );
    }
    for (final (id, byScope) in cited) {
      for (final scope in promotionScopes) {
        if (byScope[scope] == EvidenceStanding.stale) {
          problems.add('$key: stable on a stale $scope record of "$id"');
        }
      }
    }
  }
  return problems;
}
