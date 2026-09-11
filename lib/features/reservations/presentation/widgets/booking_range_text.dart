// SPDX-License-Identifier: 0BSD

import '../../../../core/time/workspace_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/booking_window_label.dart';
import '../../../../core/i18n/app_format.dart';

/// One booking range as humans read it (field report: a full-day booking
/// showed as "00:00 – 00:00"): canonical day windows get their names —
/// "Full day", "Morning · 00:00 – 13:00", "Afternoon · 13:00 – 24:00" —
/// and free ranges read from–to on the window's own wall clock, with a
/// next-midnight end written 24:00, never 00:00.
String bookingRangeText(
  AppFormat format,
  AppLocalizations? l10n,
  DateTime start,
  DateTime end,
) {
  final timeFormat = format; // #1150 — the member's clock and zone
  String fmt(DateTime t) => timeFormat.time(t);
  String fmtEnd() {
    final display = WorkspaceTime.display(end);
    final isNextMidnight = display.hour == 0 &&
        display.minute == 0 &&
        end.isAfter(start);
    return isNextMidnight ? '24:00' : timeFormat.time(end);
  }

  return switch (bookingWindowKindOf(start, end)) {
    BookingWindowKind.fullDay => l10n?.reserveFullDayChip ?? 'Full day',
    BookingWindowKind.morning =>
      '${l10n?.planMorningChip ?? 'Morning'} · ${fmt(start)} – ${fmtEnd()}',
    BookingWindowKind.afternoon =>
      '${l10n?.planAfternoonChip ?? 'Afternoon'} · '
          '${fmt(start)} – ${fmtEnd()}',
    BookingWindowKind.times => '${fmt(start)} – ${fmtEnd()}',
  };
}

/// The repetition modality of a series booking: the stored pattern's
/// label (0034), or the generic recurring label for pre-0034 series.
String repeatLabelText(AppLocalizations? l10n, String? seriesPattern) {
  return switch (seriesPattern) {
    'daily' => l10n?.repeatDaily ?? 'Every day',
    'weekdays' => l10n?.repeatWeekdays ?? 'Every weekday',
    'weekly' => l10n?.repeatWeekly ?? 'Weekly',
    _ => l10n?.reservationRecurring ?? 'Recurring booking',
  };
}
