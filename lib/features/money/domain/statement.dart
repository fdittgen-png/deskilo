// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'statement.freezed.dart';

/// One member's monthly statement (ADR 0008), computed server-side: the
/// band fee of the subscription percentage plus overage beyond the
/// availability-scaled entitlement, minus confirmed credits.
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
  }) = _Statement;

  bool get isSettled => balanceCents >= 0;
}
