// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_decision.freezed.dart';

/// One validator's verdict on a pending event (#130, ADR 0008). Every
/// accept/decline — human or sweep — leaves exactly one row, so the audit
/// trail shows WHO decided WHAT and WHEN without gaps.
@freezed
sealed class EventDecision with _$EventDecision implements SystemStamped {
  const EventDecision._();

  const factory EventDecision({
    required String id,
    required String eventId,
    /// Null when the timeout sweep decided (see [decidedBySystem]).
    String? memberId,
    required bool accept,
    required bool decidedBySystem,
    required DateTime decidedAt,
    /// #992 — the server's stamp on this row.
    @Default(SystemColumns.none) SystemColumns system,
  }) = _EventDecision;
}
