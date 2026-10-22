// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 C2 — a purchase document is three questions answered apart, never
// one blended status: was it approved, is what it created settled, and is
// its accounting and tax qualified. An approved expense whose credit landed
// on the member's account is SETTLED by that credit, never "paid"; a
// document the space paid at once owes nobody anything.
//
// Pure Dart: no Flutter, no l10n.
library;

import 'purchase.dart';

/// Where the document stands as a document.
enum PurchaseApproval { draft, waiting, approved, rejected, cancelled }

/// What became of what it made the space owe.
enum PurchaseSettlement {
  /// Not approved yet, or nobody is owed anything (the space paid at once).
  nothingOwed,
  unpaid,
  partlySettled,
  settled,
}

/// Whether its accounting and tax are qualified.
enum PurchaseQualification {
  qualified,

  /// A line nobody classified (day-to-day use, equipment, …).
  needsReview,

  /// A taxed line whose recoverable share was not stated.
  taxNotQualified,

  /// Filed before the purchase document existed: unverified.
  unverified,
}

typedef PurchaseStatus = ({
  PurchaseApproval approval,
  PurchaseSettlement settlement,
  PurchaseQualification qualification,
});

/// The three answers for [detail].
PurchaseStatus purchaseStatusOf(PurchaseDetail detail) {
  final approval = switch (detail.summary.state) {
    PurchaseState.draft => PurchaseApproval.draft,
    PurchaseState.pending => PurchaseApproval.waiting,
    PurchaseState.approved => PurchaseApproval.approved,
    PurchaseState.rejected => PurchaseApproval.rejected,
    PurchaseState.cancelled => PurchaseApproval.cancelled,
  };
  final owed = [
    for (final o in detail.obligations)
      if (o.state != ObligationState.cancelled) o,
  ];
  final total = owed.fold<int>(0, (s, o) => s + o.amountCents);
  final remaining = owed.fold<int>(0, (s, o) => s + o.remainingCents);
  final settlement = approval != PurchaseApproval.approved || total == 0
      ? PurchaseSettlement.nothingOwed
      : remaining == 0
      ? PurchaseSettlement.settled
      : remaining < total
      ? PurchaseSettlement.partlySettled
      : PurchaseSettlement.unpaid;
  final qualification = detail.summary.legacy
      ? PurchaseQualification.unverified
      : detail.lines.any((l) => l.recognitionKind == 'unresolved')
      ? PurchaseQualification.needsReview
      : detail.lines.any(
          (l) =>
              l.taxStated && l.taxCents != 0 && l.recoverableTaxCents == null,
        )
      ? PurchaseQualification.taxNotQualified
      : PurchaseQualification.qualified;
  return (
    approval: approval,
    settlement: settlement,
    qualification: qualification,
  );
}
