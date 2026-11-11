// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settlement_review_commands.dart';
import '../data/supabase_settlement_reviews.dart';
import '../domain/settlement_fetch.dart';
import 'credit_providers.dart' show moneyClientProvider;

/// #3510 — the settlement reports kept for review.
final settlementReviewsRepositoryProvider = Provider<SettlementReviews>(
  (ref) => SupabaseSettlementReviews(ref.watch(moneyClientProvider)),
);

/// A workspace's reviews, waiting and handled; one attempt, so a failed read
/// is said at once with Try again.
final settlementReviewListProvider = FutureProvider.autoDispose
    .family<List<SettlementReview>, String>(
      (ref, workspaceId) => ref
          .watch(settlementReviewsRepositoryProvider)
          .fetchSettlementReviews(workspaceId),
      retry: (_, _) => null,
    );

/// Ending a review (the hand-off), for the widgets.
final settlementReviewCommandsProvider = Provider<SettlementReviewCommands>(
  (ref) =>
      SettlementReviewCommands(ref.watch(settlementReviewsRepositoryProvider)),
);
