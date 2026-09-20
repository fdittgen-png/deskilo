// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'browsed_level.g.dart';

/// The level the member is BROWSING, shared by every view of the hub.
///
/// #1269 — it used to be three separate `State` fields: one in
/// `ReserveScreen` for the plan and the seat list, one in `DayTimeline`,
/// one in `WeekGrid`. Switching the view disposes one widget and builds
/// another, so the new one started at null and fell back to
/// `levels.first`. Choosing the second floor and tapping the day view
/// put you back on the first, every time — and choosing it again and
/// going back did it again.
///
/// One value, held above all four views, so the floor survives the
/// switch. Session-scoped on purpose: it is BROWSING state, not the
/// member's persisted default (`SelectedLevelId`, #159), which the plan
/// still reads when nothing has been browsed yet and which only an
/// explicit choice on the plan writes.
///
/// ## Why "all levels" lives here too
///
/// The day and week grids offer an "All levels" chip; the plan cannot
/// show two floors at once. Keeping the sentinel in the shared value —
/// rather than in the two grids that understand it — is what lets the
/// plan RESOLVE it without DESTROYING it: it renders a single floor
/// while the value still says "all", and going back to the day view
/// finds the chip exactly as it was left.
///
/// A view that cannot honour the value must never write over it.
@Riverpod(keepAlive: true)
class BrowsedLevel extends _$BrowsedLevel {
  /// Sentinel for the "All levels" chip — never a real level id.
  static const String allLevels = '__all-levels__';

  /// Null means "nothing browsed yet": each view then falls back to what
  /// it considers its own default, which for the plan is the member's
  /// persisted level and for the grids is the first one.
  @override
  String? build() => null;

  void select(String levelId) => state = levelId;

  void selectAll() => state = allLevels;

  /// Whether [state] names a floor a single-floor view can show.
  bool get isOneLevel => state != null && state != allLevels;
}
