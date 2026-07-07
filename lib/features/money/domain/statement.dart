// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'statement.freezed.dart';

/// One member's monthly statement (spec §7.3), computed server-side.
/// Negative [balanceCents] = the member owes the community.
@freezed
sealed class Statement with _$Statement {
  const Statement._();

  const factory Statement({
    required String period,
    required String planName,
    required int baseFeeCents,
    int? includedHalfDays,
    required int usedHalfDays,
    required int extraHalfDays,
    required int overageCents,
    required int creditsCents,
    required int balanceCents,
  }) = _Statement;

  bool get isSettled => balanceCents >= 0;
}
