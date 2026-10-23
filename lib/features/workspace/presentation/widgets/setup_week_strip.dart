// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2870 — the week as members can book it: one row per weekday, one cell
// per hour, filled where the space is open. Never colour alone: each row
// also says its hours in words, and reads as one sentence to a screen
// reader.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/work_hours.dart';

class SetupWeekStrip extends StatelessWidget {
  const SetupWeekStrip({
    super.key,
    required this.open,
    required this.workHours,
  });

  /// ISO weekdays the space is open on (1 = Monday).
  final List<int> open;
  final WorkHours workHours;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    String clock(int minutes) => material.formatTimeOfDay(
      TimeOfDay(hour: minutes ~/ 60 % 24, minute: minutes % 60),
    );
    // The hours shown: the working day, and at least 07:00 to 20:00.
    final first = (workHours.startMinutes ~/ 60).clamp(0, 7);
    final last = ((workHours.endMinutes + 59) ~/ 60).clamp(20, 24);
    final hours = l10n.setupHoursRange(
      clock(workHours.startMinutes),
      clock(workHours.endMinutes),
    );
    final labelStyle = Theme.of(context).textTheme.bodySmall;
    return Column(
      key: const ValueKey('setup-week-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              const SizedBox(width: _dayWidth),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final minutes in [first * 60, last * 60])
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(clock(minutes), style: labelStyle),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Spacer(flex: 2),
            ],
          ),
        ),
        for (var weekday = 1; weekday <= 7; weekday++)
          _DayRow(
            weekday: weekday,
            // 2024-01-01 was a Monday, so day-of-month == ISO weekday.
            day: DateFormat.E(locale).format(DateTime(2024, 1, weekday)),
            isOpen: open.contains(weekday),
            hoursText: hours,
            first: first,
            last: last,
            workHours: workHours,
          ),
      ],
    );
  }
}

const double _dayWidth = 44;

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.weekday,
    required this.day,
    required this.isOpen,
    required this.hoursText,
    required this.first,
    required this.last,
    required this.workHours,
  });

  final int weekday;
  final String day;
  final bool isOpen;
  final String hoursText;
  final int first;
  final int last;
  final WorkHours workHours;

  bool _openAt(int hour) =>
      isOpen &&
      hour * 60 < workHours.endMinutes &&
      (hour + 1) * 60 > workHours.startMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final words = isOpen ? hoursText : l10n.setupHoursClosed;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          key: ValueKey('setup-week-day-$weekday'),
          children: [
            SizedBox(width: _dayWidth, child: Text(day)),
            Expanded(
              flex: 3,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var hour = first; hour < last; hour++)
                      Expanded(
                        child: Container(
                          key: ValueKey(
                            'setup-week-cell-$weekday-$hour-'
                            '${_openAt(hour) ? 'open' : 'closed'}',
                          ),
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          color: _openAt(hour)
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: Text(
                words,
                key: ValueKey('setup-week-words-$weekday'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
