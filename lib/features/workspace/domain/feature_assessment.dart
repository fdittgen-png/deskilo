// SPDX-License-Identifier: AGPL-3.0-or-later

/// The review axis. Declared in increasing order of assurance.
enum FeatureMaturity { unreviewed, alpha, beta, stable }

/// The life axis.
enum FeatureLifecycle { active, deprecated, retired }

/// What a classification rests on. [evidence] is the assessment of #1850:
/// capability ids of the evidence ledger. [ownerDecision] is the owner's
/// declaration (#2519, 2026-10-13: every shipped feature is beta): it can
/// say beta, never stable, and it says so in its rationale — so a reader can
/// tell a declared beta from an evidenced one.
enum AssessmentBasis { evidence, ownerDecision }

/// One capability's assessment.
class FeatureAssessment {
  const FeatureAssessment({
    required this.maturity,
    required this.rationale,
    this.lifecycle = FeatureLifecycle.active,
    this.evidence = const [],
    this.basis = AssessmentBasis.evidence,
    this.limitations = '',
    this.replacedBy = const [],
    this.introducedIn,
    this.deprecatedIn,
  });

  /// The explicit "nobody has assessed this yet" state every legacy entry
  /// starts in.
  const FeatureAssessment.unreviewed(this.rationale)
    : maturity = FeatureMaturity.unreviewed,
      lifecycle = FeatureLifecycle.active,
      evidence = const [],
      basis = AssessmentBasis.evidence,
      limitations = '',
      replacedBy = const [],
      introducedIn = null,
      deprecatedIn = null;

  final FeatureMaturity maturity;
  final FeatureLifecycle lifecycle;

  /// Why this classification — required, also for unreviewed.
  final String rationale;

  /// Capability ids of the evidence ledger (docs/product/capabilities.json,
  /// #1634) the classification rests on. Beta and stable need at least one.
  final List<String> evidence;

  /// Whether [evidence] or the owner's declaration carries the maturity.
  final AssessmentBasis basis;
  final String limitations;

  /// Registry keys that take over once this one is deprecated or retired.
  final List<String> replacedBy;
  final String? introducedIn;
  final String? deprecatedIn;
}

