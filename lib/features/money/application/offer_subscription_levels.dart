// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The pricing step of the setup guide offers the preset subscription
// levels (25, 50, 75, 100 %) through the billing screen's own write. Only
// the presets change: the owner's own levels and the free-value option
// are written back as they were stored.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/commercial_terms_repository.dart';
import '../domain/subscription_levels.dart';
import '../providers/money_queries_providers.dart';

part 'offer_subscription_levels.g.dart';

class OfferSubscriptionLevels {
  const OfferSubscriptionLevels(this._terms);
  final CommercialTermsRepository _terms;

  /// Offers exactly [presets] of [SubscriptionLevels.presets] beside what
  /// [stored] already holds. Throws whatever the repository throws.
  Future<void> offer(
    String workspaceId,
    SubscriptionLevels stored,
    Set<int> presets,
  ) => _terms.setSubscriptionLevels(
    workspaceId,
    stored.copyWith(
      enabledPresets: [
        for (final p in SubscriptionLevels.presets)
          if (presets.contains(p)) p,
      ],
    ),
  );
}

/// The pricing step's write of the offered levels.
@riverpod
OfferSubscriptionLevels offerSubscriptionLevels(Ref ref) =>
    OfferSubscriptionLevels(ref.watch(commercialTermsProvider));
