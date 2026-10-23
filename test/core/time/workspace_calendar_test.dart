// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L4 -- the calendar and the tax reference a WorkspaceContext carries:
// validated (a bad zone or an empty dataset is a typed failure, never the
// device clock or an empty answer), immutable, and compared by revision.
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/core/time/workspace_calendar.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/core/vat/tax_reference_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceCalendar _calendar({
  String timezone = 'Europe/Paris',
  List<int> weekdays = const [1, 2, 3, 4, 5],
  List<CalendarClosure> closures = const [],
}) =>
    WorkspaceCalendar(
      timezone: timezone,
      openWeekdays: weekdays,
      workHours: WorkHours.defaults,
      closures: closures,
    );

TaxReferenceRow _gate(String country, {required bool supported}) =>
    TaxReferenceRow.fromJson({
      'domain': 'issuing_gate',
      'country': country,
      'key': 'gate',
      'valid_from': '1900-01-01',
      'valid_to': null,
      'value': {
        'supported': supported,
        'requires_tax_number': false,
        'national_channel_required': false,
      },
      'source': 'test',
      'confirmed': true,
    });

void main() {
  test('an unknown or empty zone is a typed configuration failure', () {
    expect(() => _calendar(timezone: 'Mars/Olympus_Mons'),
        throwsA(isA<WorkspaceCalendarUnavailable>()));
    expect(() => _calendar(timezone: '  '),
        throwsA(isA<WorkspaceCalendarUnavailable>()));
    expect(() => _calendar(weekdays: const [0]),
        throwsA(isA<WorkspaceCalendarUnavailable>()));
  });

  test('times are the workspace zone\'s, whatever the device says', () {
    final paris = _calendar();
    final newYork = _calendar(timezone: 'America/New_York');
    // Midnight of the same calendar day is six hours apart in UTC.
    expect(paris.at(2026, 10, 16).toUtc(), DateTime.utc(2026, 10, 15, 22));
    expect(newYork.at(2026, 10, 16).toUtc(), DateTime.utc(2026, 10, 16, 4));
    // 23:30 UTC is already the next day in Paris, still the same in New York.
    final instant = DateTime.utc(2026, 10, 16, 23, 30);
    expect(paris.dateOf(instant), DateTime(2026, 10, 17));
    expect(newYork.dateOf(instant), DateTime(2026, 10, 16));
    expect(newYork.wall(instant), DateTime(2026, 10, 16, 19, 30));
  });

  test('open days and closures answer per calendar date', () {
    final calendar = _calendar(closures: [
      CalendarClosure(id: 'c-1', day: DateTime(2026, 12, 25), reason: 'Noël'),
    ]);
    expect(calendar.isOpenOn(DateTime(2026, 12, 24)), isTrue); // Thursday
    expect(calendar.isClosedOn(DateTime(2026, 12, 25)), isTrue);
    expect(calendar.isOpenOn(DateTime(2026, 12, 25)), isFalse);
    expect(calendar.isOpenOn(DateTime(2026, 12, 26)), isFalse); // Saturday
    expect(() => calendar.openWeekdays.add(6), throwsUnsupportedError);
  });

  test('two calendars are equal exactly when what they say is equal', () {
    expect(_calendar(), _calendar());
    expect(_calendar().revision, _calendar().revision);
    expect(_calendar(timezone: 'America/New_York'), isNot(_calendar()));
    expect(_calendar(weekdays: const [1, 2, 3, 4, 5, 6]), isNot(_calendar()));
    expect(
      _calendar(closures: [
        CalendarClosure(id: 'c', day: DateTime(2026, 5, 8), reason: 'x'),
      ]),
      isNot(_calendar()),
    );
  });

  test('a tax reference snapshot names its revision and refuses no data', () {
    expect(() => TaxReferenceSnapshot(const TaxReferenceSet([])),
        throwsA(isA<TaxReferenceUnavailable>()));
    final a = TaxReferenceSnapshot(TaxReferenceSet([_gate('FR', supported: true)]));
    final same = TaxReferenceSnapshot(TaxReferenceSet([_gate('FR', supported: true)]));
    final b = TaxReferenceSnapshot(TaxReferenceSet([_gate('FR', supported: false)]));
    expect(a, same);
    expect(a, isNot(b));
    expect(a.set.issuesFor('FR'), isTrue);
    expect(b.set.issuesFor('FR'), isFalse);
  });
}
