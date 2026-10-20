// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// The month as a compact day picker (#478: the calendar is a picker, not
/// the content itself): a weekday header, the month's days, a ring on
/// today, a disc on the selected day and one dot per truth -- red for a
/// day carrying MY bookings, blue for a day with only other members',
/// both when both apply.
class MonthDayPicker extends StatelessWidget {
  const MonthDayPicker({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.myDays,
    required this.otherDays,
    required this.onSelect,
  });

  /// Compact cell height (#478 phone audit: the month grid ate ~40% of the
  /// screen before any content).
  static const double cellHeight = 36;

  final DateTime month;
  final DateTime selectedDay;

  /// Local today -- gets a ring so it stays findable when another day is
  /// selected.
  final DateTime today;

  /// Days with at least one of MY bookings -- the red dot.
  final Set<DateTime> myDays;

  /// Days with at least one OTHER member's booking -- the blue dot. A day
  /// in both sets shows both dots.
  final Set<DateTime> otherDays;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = DateTime(month.year, month.month).weekday - 1;
    final rows = ((leading + daysInMonth) / 7).ceil();
    return Padding(
      padding: AppSpacing.smH,
      child: Column(
        children: [
          const _WeekdayHeader(),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(row, col, leading, daysInMonth)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int row, int col, int leading, int daysInMonth) {
    final index = row * 7 + col - leading;
    if (index < 0 || index >= daysInMonth) {
      return const SizedBox(height: cellHeight);
    }
    final day = DateTime(month.year, month.month, index + 1);
    return _DayCell(
      column: col,
      day: day,
      selected: DateUtils.isSameDay(day, selectedDay),
      isToday: DateUtils.isSameDay(day, today),
      mine: myDays.contains(day),
      others: otherDays.contains(day),
      onPick: () => onSelect(day),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final weekdayFormat = DateFormat.E();
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                weekdayFormat
                    .format(DateTime(2026, 6, 1 + i)) // a Monday
                    .substring(0, 1),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.column,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.mine,
    required this.others,
    required this.onPick,
  });

  /// Reservation-marker dot colours: fixed hues (not scheme colours) so
  /// "mine vs. theirs" reads the same in light and dark.
  static const Color _mineDot = Color(0xFFEF5350); // red 400
  static const Color _otherDot = Color(0xFF42A5F5); // blue 400

  /// The weekday column, which names the cell for the recorder and tests.
  final int column;
  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool mine;
  final bool others;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Selected wins the filled disc; an unselected today keeps a ring so it
    // stays findable.
    final decoration = selected
        ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
        : isToday
        ? BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary, width: 1.5),
          )
        : null;
    return InkWell(
      key: ValueKey('calendar-circle-$column'),
      onTap: onPick,
      borderRadius: AppRadius.mdAll,
      child: SizedBox(
        height: MonthDayPicker.cellHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: decoration,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: isToday || selected ? FontWeight.w700 : null,
                ),
              ),
            ),
            // One dot per truth (field request): red = I have a booking,
            // blue = others do, BOTH when both apply.
            SizedBox(
              height: 5,
              child: mine || others
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (mine)
                          const Icon(Icons.circle, size: 5, color: _mineDot),
                        if (mine && others) const SizedBox(width: 2),
                        if (others)
                          const Icon(Icons.circle, size: 5, color: _otherDot),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
