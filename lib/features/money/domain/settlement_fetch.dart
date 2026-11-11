// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- what one fetch of a provider's settlements decided, counted from
// the recorder's outcomes (not from the calls made), and the settlement
// reports that wait for a person's review: a settlement the provider changed
// after it was recorded, or a cost in another currency than its settlement.
// The recorder refuses those and keeps them; nothing of them is booked.

/// Why the recorder refused a settlement report.
enum SettlementReviewReason {
  costsChanged('costs_changed'),
  amountChanged('amount_changed'),
  currencyMismatch('currency_mismatch');

  const SettlementReviewReason(this.wire);
  final String wire;

  static SettlementReviewReason? fromWire(Object? wire) =>
      values.where((r) => r.wire == wire).firstOrNull;
}

/// A refused settlement report, kept for review.
class SettlementReview {
  const SettlementReview({required this.settlementId, required this.reason});

  final String settlementId;
  final SettlementReviewReason reason;
}

class SettlementFetch {
  const SettlementFetch({
    required this.imported,
    this.unchanged = 0,
    this.skipped = 0,
    this.reviews = const [],
  });

  /// Settlements recorded for the first time.
  final int imported;

  /// Settlements recorded before, reported the same.
  final int unchanged;

  /// Settlements not paid or failed yet, or malformed.
  final int skipped;

  /// Every report of this provider that waits for review, this fetch's
  /// refusals included; null when they could not be read.
  final List<SettlementReview>? reviews;
}
