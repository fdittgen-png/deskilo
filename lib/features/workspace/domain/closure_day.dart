// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'closure_day.freezed.dart';

/// One whole-day closure of a workspace (#127). [day] is date-only
/// (local midnight, no time component) in the workspace's calendar;
/// the server rejects reservations and check-ins touching it.
@freezed
sealed class ClosureDay with _$ClosureDay {
  const factory ClosureDay({
    required String id,
    required String workspaceId,
    required DateTime day,
    required String reason,
  }) = _ClosureDay;
}
