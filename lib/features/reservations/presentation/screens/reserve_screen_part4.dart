// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'reserve_screen.dart';


/// Geometry and ranges of the Reserve hub (#208). Pinned by test — treat
/// these as part of the visual/behavioural contract, not free-floating
/// magic numbers.
@visibleForTesting
abstract final class ReserveHubMetrics {
  /// Day pills on the date strip, starting today.
  static const int stripDayCount = 14;

  /// Height of the date-strip row (fits the two-line day pills). Trimmed
  /// from 76 (screenshot feedback 2026-07-20) — the compact chips fit the
  /// weekday + day-number stack in less vertical space.
  static const double stripHeight = 58;

  /// Furthest day (from today) reachable via the strip's calendar icon.
  static const int datePickerRangeDays = 365;

  /// Snapping of the from→to window chips (#184 pattern): 15-minute steps.
  static const int snapMinutes = 15;

  /// Default window length before capping (mirrors the plan's stay).
  static const Duration defaultStay = Duration(hours: 4);

  /// Latest selectable window end within a day (#184 pattern): 23:45.
  static const int lastSlotHour = 23;
  static const int lastSlotMinute = 45;
}
