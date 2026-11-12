// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3819 — a person who chose a 12-hour clock in a 24-hour locale reads it on
// the BI printout and the capacity details too; a label baked into a message
// for other readers keeps the reference language's own convention.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/i18n/reference_when.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/presentation/bi_print_strings_l10n.dart';
import 'package:deskilo/features/workspace/presentation/widgets/capacity_kpi_card.dart';
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AppFormat _german(ClockPref clock) => AppFormat(
  locale: 'de_DE',
  currencyCode: 'EUR',
  clock: clock,
  weekStart: WeekStartPref.monday,
);

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  final at = DateTime.utc(2026, 10, 3, 14, 30);

  test('the BI printout stamps a time on the person\'s clock', () {
    String stamp(ClockPref clock) => biPrintStringsOf(
      AppLocalizationsDe(),
      'de_DE',
      wall: (instant) => instant,
      format: _german(clock),
    ).formats.dateTime(at);
    expect(stamp(ClockPref.h12), contains('2:30 PM'));
    expect(stamp(ClockPref.h24), contains('14:30'));
  });

  test('the capacity details state when the figure was computed on the '
      'person\'s clock', () {
    final kpi = SeatCapacityKpi(
      from: DateTime.utc(2026, 9),
      to: DateTime.utc(2026, 10),
      physicalSeatHours: 100,
      offeredSeatHours: 80,
      reservedSeatHours: 20,
      reservedOutsideOfferedSeatHours: 0,
      overlappingSeatHours: 0,
      seats: 10,
      roomsWithoutSeats: 0,
      offeredRoomHours: 0,
      reservedRoomHours: 0,
      quality: const {},
      reasons: const [],
      computedAt: at,
    );
    String details(ClockPref clock) => capacityKpiDetails(
      kpi,
      AppLocalizationsDe(),
      _german(clock),
    ).join('\n');
    expect(details(ClockPref.h12), contains('2:30 PM'));
    expect(details(ClockPref.h12), isNot(contains('14:30')));
    expect(details(ClockPref.h24), contains('14:30'));
  });

  test('a picker row follows the person\'s clock; a baked label keeps the '
      'reference language\'s convention', () {
    final morning = DateTime(2026, 10, 3, 9, 5);
    expect(
      referenceWhen(morning, 'de_DE', reader: _german(ClockPref.h12)),
      contains('9:05 AM'),
    );
    expect(referenceWhen(morning, 'de_DE'), contains('09:05'));
    expect(referenceWhen(morning, 'de_DE'), isNot(contains('AM')));
  });
}
