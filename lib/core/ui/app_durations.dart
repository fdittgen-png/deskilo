// SPDX-License-Identifier: AGPL-3.0-or-later

/// The waits the app's screens share, by what they are for (#2388): a
/// debounce written as a literal in each screen drifted (200, 250, 300 ms
/// for the same job). Animation timings live in `AppMotion`/`MotionTokens`.
abstract final class AppDurations {
  /// Typing in a search field: the query runs once the person pauses.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// A burst of realtime changes: one refresh after it settles.
  static const Duration realtimeDebounce = Duration(milliseconds: 300);
}
