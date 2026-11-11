// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- what one fetch of a provider's settlements decided, counted from
// the recorder's outcomes (not from the calls made), and the settlement
// reports that wait for a person's review: a settlement the provider changed
// after it was recorded, or a cost in another currency than its settlement.
// The recorder refuses those and keeps them; nothing of them is booked.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

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
  const SettlementReview({
    required this.settlementId,
    required this.reason,
    this.id = '',
    this.handledAt,
    this.handledNote = '',
  });

  /// A row of `provider_settlement_reviews`; null when its reason is not one
  /// this build knows.
  static SettlementReview? fromRow(Object? row) {
    final r = JsonReader.of(row, context: 'provider_settlement_reviews');
    final reason = SettlementReviewReason.fromWire(r.raw('reason'));
    if (reason == null) return null;
    return SettlementReview(
      id: r.stringOr('id'),
      settlementId: r.stringOr('settlement_id'),
      reason: reason,
      handledAt: r.dateTimeOrNull('handled_at'),
      handledNote: r.stringOr('handled_note'),
    );
  }

  final String id;
  final String settlementId;
  final SettlementReviewReason reason;

  /// #3510 — when a person marked it handled, and what they wrote; null and
  /// '' while it waits.
  final DateTime? handledAt;
  final String handledNote;

  bool get handled => handledAt != null;
}

/// The longest note a hand-off keeps (0722's check).
const int settlementReviewNoteMax = 1000;

/// #3510 — the settlement reports kept for review, waiting and handled, and
/// the hand-off that ends one (billing managers of its own business).
abstract interface class SettlementReviews {
  /// The workspace's reviews, newest report first.
  Future<List<SettlementReview>> fetchSettlementReviews(String workspaceId);

  /// Marks [reviewId] handled with [note]; false when it was handled already.
  Future<bool> markSettlementReviewHandled(String reviewId, String note);
}

class SettlementFetch {
  const SettlementFetch({
    required this.imported,
    this.unchanged = 0,
    this.skipped = 0,
  });

  /// Settlements recorded for the first time.
  final int imported;

  /// Settlements recorded before, reported the same.
  final int unchanged;

  /// Settlements not paid or failed yet, or malformed.
  final int skipped;
}
