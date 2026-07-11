// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

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
      );

  bool get isSettled => balanceCents >= 0;
}
