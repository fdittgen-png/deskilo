// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1231 — a date that is printed, invoiced or chased is never computed
// with `Duration(days: n)`.
//
// A week containing a clock change is not 168 hours long. Two money
// dates were computed that way: the day a subscription invoice is
// issued, and an invoice's payment term — one of which members see and
// one of which is printed on the document and starts the dunning clock.
// Both were off by a day, twice a year, in half the world.
//
// `addCalendarDays` / `calendarDaysBetween` in `core/time/calendar_days.dart`
// go through the `DateTime` constructor, which normalises out-of-range
// components using calendar arithmetic and cannot drift.
//
// A `Duration` in days is still right for a WINDOW — "look 60 days
// ahead", "a picker's first date" — where an hour either way changes
// nothing. Those are the exemptions below, each with its reason.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Where a day-Duration is measuring a span rather than naming a date.
const Map<String, String> _exempt = {
  'lib/features/workspace/domain/next_open_day.dart':
      'a search horizon — how far to look, not a date to print',
  'lib/features/money/presentation/screens/vat_declarations_screen.dart':
      'the half-open end of a period query',
  'lib/features/money/presentation/widgets/expense_schedule_sheet.dart':
      'date-picker bounds — how far the picker may scroll',
  'lib/features/money/presentation/widgets/register_payment_sheet.dart':
      'a date-picker bound',
  'lib/features/money/domain/report_data_letters.dart':
      'weekday NAMES from a Monday — the labels, not a date',
};

void main() {
  test('no printed or chased date is built from a day-Duration', () {
    final offenders = <String>[];
    for (final file in handWrittenDartFilesIn(
      ['lib/features/money', 'lib/features/workspace/domain'],
    )) {
      if (_exempt.containsKey(file.path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('//')) continue;
        if (RegExp(r'Duration\(days:').hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'use addCalendarDays / calendarDaysBetween — a Duration of '
          'days drifts by an hour across a clock change, and a date that '
          'is printed or starts a dunning clock cannot afford that. If '
          'this one measures a WINDOW rather than naming a date, add it '
          'to _exempt with the reason:\n${offenders.join('\n')}',
    );
  });
}
