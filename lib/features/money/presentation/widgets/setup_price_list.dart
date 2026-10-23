// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a member pays at each level the space offers, as the setup
// guide's pricing step previews it: the monthly fee, and what a half-day
// and a whole day beyond the level's entitlement cost.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/fee_band.dart';
import '../../domain/member_price_list.dart';

class SetupPriceList extends StatelessWidget {
  const SetupPriceList({
    super.key,
    required this.levels,
    required this.bands,
    required this.money,
  });

  /// The offered levels, in any order.
  final Set<int> levels;
  final List<FeeBand> bands;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prices = memberPriceList(bands, levels);
    return Column(
      key: const ValueKey('setup-pricing-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupPricingPreviewTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (prices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.setupPricingNoLevels,
              key: const ValueKey('setup-pricing-preview-none'),
            ),
          ),
        for (final price in prices)
          ListTile(
            key: ValueKey('setup-pricing-price-${price.pct}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sell_outlined),
            title: Text(l10n.setupPricingLevel(price.pct)),
            subtitle: Text(_terms(context, price)),
          ),
      ],
    );
  }

  String _terms(BuildContext context, LevelPrice price) {
    final l10n = context.l10n;
    final monthly = price.monthlyCents;
    final half = price.extraHalfDayCents;
    final day = price.extraDayCents;
    if (monthly == null || half == null || day == null) {
      return l10n.setupPricingNoPrice;
    }
    return l10n.setupPricingTerms(money(monthly), money(half), money(day));
  }
}
