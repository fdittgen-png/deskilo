// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- the settlement reports a fetch left waiting for review: a
// settlement the provider changed after it was recorded, or a cost in another
// currency than its settlement. The recorder refused them and booked nothing
// of them; a person reads them here.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/settlement_fetch.dart';

class SettlementReviewList extends StatelessWidget {
  const SettlementReviewList(this.fetched, {super.key});

  final SettlementFetch fetched;

  static String sentence(AppLocalizations l10n, SettlementReview r) =>
      switch (r.reason) {
        SettlementReviewReason.costsChanged =>
          l10n.payConfigSettlementCostsChanged(r.settlementId),
        SettlementReviewReason.amountChanged =>
          l10n.payConfigSettlementAmountChanged(r.settlementId),
        SettlementReviewReason.currencyMismatch =>
          l10n.payConfigSettlementCurrencyMismatch(r.settlementId),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reviews = fetched.reviews;
    if (reviews == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          l10n.payConfigSettlementsReviewUnreadable,
          key: const ValueKey('settlement-reviews-unreadable'),
        ),
      );
    }
    if (reviews.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('settlement-reviews'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.payConfigSettlementsReviewTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final r in reviews)
            Text(
              sentence(l10n, r),
              key: ValueKey('settlement-review-${r.settlementId}-${r.reason.wire}'),
            ),
        ],
      ),
    );
  }
}
