// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../workspace/domain/overage_policy.dart';

part 'statement.freezed.dart';

/// One member's monthly statement (ADR 0008), computed server-side: the
/// band fee of the subscription percentage plus overage beyond the
/// availability-scaled entitlement plus accessory supplements (#170),
/// minus confirmed credits.
/// Negative [balanceCents] = the member owes the community.
@freezed
sealed class Statement with _$Statement {
  const Statement._();

  const factory Statement({
    required String period,
    required int subscriptionPct,
    required int feeCents,
    required int includedHalfDays,
    required int openDays,
    required int usedHalfDays,
    required int extraHalfDays,
    required int overageCents,
    required int creditsCents,
    required int balanceCents,

    /// Sum of the priced accessories of booked seats, per reserved
    /// half-day (#170). 0 unless the owner enabled the
    /// accessorySupplements feature — older `member_statement` bodies
    /// omit the field entirely, so it defaults.
    @Default(0) int accessorySupplementCents,

    /// Sum of the reserved levels' half-day prices (0050); 0 unless the
    /// member holds whole-level reservations this period.
    @Default(0) int levelSupplementCents,

    /// Sum of the reserved offices' half-day prices (0057) — the level
    /// shape over whole-office reservations.
    @Default(0) int officeSupplementCents,

    /// Sum of the reserved desks' half-day prices (0059).
    @Default(0) int deskSupplementCents,

    /// What happens once the entitlement is used up (migration 0041).
    @Default(OveragePolicy.blocked) OveragePolicy overagePolicy,

    /// The fee band's per-extra-half-day overage rate — what a
    /// pay-as-you-go half-day beyond the entitlement costs.
    @Default(0) int overageRateCents,

    /// Confirmed extra half-days this period (quota extensions / packages),
    /// on top of [includedHalfDays].
    @Default(0) int grantedHalfDays,

    /// Half-days still bookable within the cap
    /// (included + granted − used, floored at 0).
    @Default(0) int remainingHalfDays,
    /// #739 — the member's deal against the default, as the server
    /// applied it to this month. Null on older servers.
    NegotiatedTariff? negotiated,
    /// #739 — the discount the server applied to the supplements.
    @Default(0) double discountPercent,
  }) = _Statement;

  /// Parses the `member_statement` RPC's jsonb result. Tolerant of the
  /// #170 supplement field being absent (pre-0024 function body): it
  /// falls back to 0 so old and new backends both parse.
  factory Statement.fromRpc(Map<String, dynamic> json) => Statement(
        period: json['period'] as String,
        subscriptionPct: json['subscription_pct'] as int,
        feeCents: json['fee_cents'] as int,
        includedHalfDays: json['included_half_days'] as int,
        openDays: json['open_days'] as int,
        usedHalfDays: json['used_half_days'] as int,
        extraHalfDays: json['extra_half_days'] as int,
        overageCents: json['overage_cents'] as int,
        creditsCents: json['credits_cents'] as int,
        balanceCents: json['balance_cents'] as int,
        accessorySupplementCents:
            (json['accessory_supplement_cents'] as num?)?.toInt() ?? 0,
        levelSupplementCents:
            (json['level_supplement_cents'] as num?)?.toInt() ?? 0,
        officeSupplementCents:
            (json['office_supplement_cents'] as num?)?.toInt() ?? 0,
        deskSupplementCents:
            (json['desk_supplement_cents'] as num?)?.toInt() ?? 0,
        overagePolicy:
            OveragePolicy.fromName(json['overage_policy'] as String?),
        overageRateCents: (json['overage_rate_cents'] as num?)?.toInt() ?? 0,
        grantedHalfDays: (json['granted_half_days'] as num?)?.toInt() ?? 0,
        remainingHalfDays:
            (json['remaining_half_days'] as num?)?.toInt() ?? 0,
        negotiated: json['negotiated'] is Map
            ? NegotiatedTariff.fromJson(
                (json['negotiated'] as Map).cast<String, dynamic>())
            : null,
        discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0,
      );

  bool get isSettled => balanceCents >= 0;

  /// The member's monthly cap in half-days (included + confirmed grants).
  int get capHalfDays => includedHalfDays + grantedHalfDays;

  /// True once the member has consumed their whole cap this month.
  bool get isCapReached => usedHalfDays >= capHalfDays;
}

/// #739 — default vs negotiated, as the statement reports them.
class NegotiatedTariff {
  const NegotiatedTariff({
    required this.defaultFeeCents,
    required this.defaultOverageFeeCents,
    this.feeCents,
    this.overageFeeCents,
    this.discountPercent,
    this.validFrom,
    this.active = false,
  });

  factory NegotiatedTariff.fromJson(Map<String, dynamic> json) =>
      NegotiatedTariff(
        defaultFeeCents: (json['default_fee_cents'] as num?)?.toInt() ?? 0,
        defaultOverageFeeCents:
            (json['default_overage_fee_cents'] as num?)?.toInt() ?? 0,
        feeCents: (json['fee_cents'] as num?)?.toInt(),
        overageFeeCents: (json['overage_fee_cents'] as num?)?.toInt(),
        discountPercent: (json['discount_percent'] as num?)?.toDouble(),
        validFrom: json['valid_from'] == null
            ? null
            : DateTime.tryParse(json['valid_from'] as String),
        active: json['active'] == true,
      );

  final int defaultFeeCents;
  final int defaultOverageFeeCents;
  final int? feeCents;
  final int? overageFeeCents;
  final double? discountPercent;
  final DateTime? validFrom;
  final bool active;
}
