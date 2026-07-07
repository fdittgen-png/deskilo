// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan.freezed.dart';

/// A membership plan on the quota+overage model (ADR 0006).
/// null [includedHalfDays] = unlimited (Full plan).
@freezed
sealed class Plan with _$Plan {
  const factory Plan({
    required String id,
    required String workspaceId,
    required String name,
    required int baseFeeCents,
    int? includedHalfDays,
    required int overageFeeCents,
    required bool active,
  }) = _Plan;
}
