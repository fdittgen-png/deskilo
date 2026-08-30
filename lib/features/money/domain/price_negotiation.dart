// SPDX-License-Identifier: 0BSD

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

  factory NegotiationDeal.fromJson(Map<String, dynamic> json) => NegotiationDeal(
        feeCents: (json['fee_cents'] as num?)?.toInt(),
        overageFeeCents: (json['overage_fee_cents'] as num?)?.toInt(),
        discountPercent: (json['discount_percent'] as num?)?.toDouble(),
        note: json['note'] as String? ?? '',
        validFrom: DateTime.tryParse(json['valid_from'] as String? ?? '') ??
            DateTime(1970),
        status: json['status'] as String? ?? 'pending',
        subscriptionPct: (json['subscription_pct'] as num?)?.toInt(),
        previousSubscriptionPct:
            (json['previous_subscription_pct'] as num?)?.toInt(),
        items: {
          for (final kind in (json['items'] as Map? ?? const {}).entries)
            kind.key as String: {
              for (final e in (kind.value as Map).entries)
                e.key as String: int.tryParse('${e.value}') ?? 0,
            },
        },
      );

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
    final def = (json['default'] as Map?)?.cast<String, dynamic>() ?? const {};
    NegotiationDeal? deal(Object? v) =>
        v is Map ? NegotiationDeal.fromJson(v.cast<String, dynamic>()) : null;
    return PriceNegotiation(
      defaultFeeCents: (def['fee_cents'] as num?)?.toInt() ?? 0,
      defaultOverageFeeCents: (def['overage_fee_cents'] as num?)?.toInt() ?? 0,
      active: deal(json['active']),
      pending: deal(json['pending']),
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
