// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- the Demo's settlement reports kept for review: one Mollie
// settlement whose costs changed after it was recorded, so the review and
// its hand-off can be seen without a provider.
import 'package:deskilo/features/money/domain/settlement_fetch.dart';

import '../fixture_clock.dart';

class DemoSettlementReviews implements SettlementReviews {
  /// The Demo's one review; [DemoSettlementReviews.empty] has none.
  DemoSettlementReviews({DateTime Function()? clock})
    : _clock = clock ?? (() => kTestNow),
      reviews = [
        const SettlementReview(
          id: 'review-demo-1',
          settlementId: 'stl_demo_0426',
          reason: SettlementReviewReason.costsChanged,
        ),
      ];

  DemoSettlementReviews.empty() : _clock = (() => kTestNow), reviews = [];

  final DateTime Function() _clock;
  final List<SettlementReview> reviews;

  @override
  Future<List<SettlementReview>> fetchSettlementReviews(
    String workspaceId,
  ) async => List.of(reviews);

  @override
  Future<bool> markSettlementReviewHandled(String reviewId, String note) async {
    final i = reviews.indexWhere((r) => r.id == reviewId);
    if (i < 0) throw StateError('unknown review');
    final note0 = note.trim();
    if (note0.isEmpty || note0.length > settlementReviewNoteMax) {
      throw StateError('a note of 1 to 1000 characters is required');
    }
    final r = reviews[i];
    if (r.handled) return false;
    reviews[i] = SettlementReview(
      id: r.id,
      settlementId: r.settlementId,
      reason: r.reason,
      handledAt: _clock(),
      handledNote: note0,
    );
    return true;
  }
}
