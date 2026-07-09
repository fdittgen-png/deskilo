// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_decision.freezed.dart';

/// One validator's verdict on a pending event (#130, ADR 0008). Every
/// accept/decline — human or sweep — leaves exactly one row, so the audit
/// trail shows WHO decided WHAT and WHEN without gaps.
@freezed
sealed class EventDecision with _$EventDecision {
  const EventDecision._();

  const factory EventDecision({
    required String id,
    required String eventId,
    /// Null when the timeout sweep decided (see [decidedBySystem]).
    String? memberId,
    required bool accept,
    required bool decidedBySystem,
    required DateTime decidedAt,
  }) = _EventDecision;
}
