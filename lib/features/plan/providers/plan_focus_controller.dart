// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plan_focus_controller.g.dart';

/// One-shot "focus this on the Plan tab" request (#182): the calendar's
/// reservation detail sheet sets it before jumping to `/plan`; the plan
/// screen consumes it (transient level switch, browse time, highlighted
/// seat) and clears it again.
class PlanFocus {
  const PlanFocus({required this.levelId, this.seatId, this.at});

  /// Level to show — transient only, never persisted as the member's
  /// default level.
  final String levelId;

  /// Seat to highlight on the canvas; null for whole-office reservations.
  final String? seatId;

  /// Reservation start: browsed when still in the future, otherwise the
  /// plan stays live.
  final DateTime? at;
}

/// Cross-tab signal carrier for [PlanFocus] (#182). KeepAlive on purpose:
/// `PlanScreen` lives in the shell's indexed stack, so the request must
/// survive until its listener picks it up after the tab switch — route
/// params can't reach the already-built const screen.
@Riverpod(keepAlive: true)
class PlanFocusController extends _$PlanFocusController {
  @override
  PlanFocus? build() => null;

  void setFocus(PlanFocus focus) => state = focus;

  void clear() => state = null;
}
