// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../core/data/json_reader.dart';

/// #739 — one deal: what was negotiated (each part optional — the
/// tariff where absent), from when, in which state.
class NegotiationDeal {
  const NegotiationDeal({
    this.feeCents,
    this.overageFeeCents,
    this.discountPercent,
    this.note = '',
    required this.validFrom,
    required this.status,
    this.subscriptionPct,
    this.previousSubscriptionPct,
    this.items = const {},
  });

  factory NegotiationDeal.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'negotiation_deal');
    return NegotiationDeal(
      feeCents: r.intOrNull('fee_cents'),
      overageFeeCents: r.intOrNull('overage_fee_cents'),
      discountPercent: r.doubleOrNull('discount_percent'),
      note: r.stringOr('note'),
      validFrom: r.dateTimeOrNull('valid_from') ?? DateTime(1970),
      status: r.stringOr('status', 'pending'),
      subscriptionPct: r.intOrNull('subscription_pct'),
      previousSubscriptionPct: r.intOrNull('previous_subscription_pct'),
      items: {
        for (final kind in r.objectOrEmpty('items').entries)
          kind.key: {
            for (final e in JsonReader.of(kind.value, context: r.context)
                .json
                .entries)
              e.key: int.tryParse('${e.value}') ?? 0,
          },
      },
    );
  }

  final int? feeCents;
  final int? overageFeeCents;
  final double? discountPercent;
  final String note;
  final DateTime validFrom;

  /// pending | active | rejected | superseded
  final String status;

  /// #744 — the occupation negotiated with its price, and what it was.
  final int? subscriptionPct;
  final int? previousSubscriptionPct;

  /// #744 — negotiated unit prices: {'services': {id: cents}, 'packages': {id: cents}}.
  final Map<String, Map<String, int>> items;

  int? itemPrice(String kind, String id) => items[kind]?[id];
  int get itemCount =>
      items.values.fold(0, (n, m) => n + m.length);
}

/// The member's deal as the server reports it: the workspace default
/// for their band, the active deal, the one awaiting validation.
class PriceNegotiation {
  const PriceNegotiation({
    required this.defaultFeeCents,
    required this.defaultOverageFeeCents,
    this.active,
    this.pending,
  });

  factory PriceNegotiation.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'price_negotiation');
    final def = r.objectOrNull('default');
    NegotiationDeal? deal(String key) => switch (r.objectOrNull(key)) {
      final JsonReader d => NegotiationDeal.fromJson(d.json),
      null => null,
    };
    return PriceNegotiation(
      defaultFeeCents: def?.intOrNull('fee_cents') ?? 0,
      defaultOverageFeeCents: def?.intOrNull('overage_fee_cents') ?? 0,
      active: deal('active'),
      pending: deal('pending'),
    );
  }

  final int defaultFeeCents;
  final int defaultOverageFeeCents;
  final NegotiationDeal? active;
  final NegotiationDeal? pending;

  bool get isOnTariff => active == null && pending == null;

  PriceNegotiation copyWith({NegotiationDeal? active, NegotiationDeal? pending}) =>
      PriceNegotiation(
        defaultFeeCents: defaultFeeCents,
        defaultOverageFeeCents: defaultOverageFeeCents,
        active: active ?? this.active,
        pending: pending ?? this.pending,
      );
}
