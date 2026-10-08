// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../../../core/time/work_hours.dart';

/// An always-visible review of the actual window, including at narrow widths.
/// The workspace clock is explicit even when personal formatting uses another zone.
class BookingWindowSummary extends StatelessWidget {
  const BookingWindowSummary({
    super.key,
    required this.window,
    required this.today,
    this.timezone,
  });
  final ({DateTime start, DateTime end}) window;
  final DateTime today;
  final String? timezone;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final format = appFormatOf(context);
    final day = WorkspaceTime.dateOf(window.start);
    final cue = day == today
        ? words.calendarToday
        : day == DateTime(today.year, today.month, today.day + 1)
        ? words.calendarTomorrow
        : null;
    final start = WorkspaceTime.wall(window.start);
    final end = WorkspaceTime.wall(window.end);
    final hoursConfig = WorkHours.current;
    final fromMinutes = start.hour * 60 + start.minute;
    final toMinutes = end.hour * 60 + end.minute;
    final period =
        fromMinutes == hoursConfig.startMinutes &&
            toMinutes == hoursConfig.halfBoundaryMinutes
        ? words.planMorningChip
        : fromMinutes == hoursConfig.halfBoundaryMinutes &&
              toMinutes == hoursConfig.endMinutes
        ? words.planAfternoonChip
        : fromMinutes == hoursConfig.startMinutes &&
              toMinutes == hoursConfig.endMinutes
        ? words.reserveFullDayChip
        : null;
    final dates = DateFormat.yMMMEd(format.locale).format(day);
    final hours = '${format.wallTime(start)}–${format.wallTime(end)}';
    final zone = timezone ?? window.start.timeZoneName;
    final personalZone = format.zoneSuffix(window.start);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          [
            ?cue,
            dates,
            ?period,
            '${words.uxWorkspaceTime}: $hours ($zone)',
            if (personalZone.isNotEmpty)
              '${words.uxDeviceTime}: ${format.dateTime(window.start)}–'
                  '${format.time(window.end)} ($personalZone)',
          ].join(' · '),
          key: const ValueKey('booking-window-summary'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
