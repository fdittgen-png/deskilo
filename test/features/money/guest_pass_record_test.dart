// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 — a pass sold: the last day it covers and the units begun.
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:flutter_test/flutter_test.dart';

GuestPassRecord _pass({
  required DateTime from,
  required DateTime to,
  required int units,
  GuestPassUnit unit = GuestPassUnit.day,
}) => GuestPassRecord(
  id: 'p',
  memberId: 'm',
  offerId: 'o',
  unit: unit,
  units: units,
  amountCents: 2400 * units,
  startsAt: from,
  endsAt: to,
);

/// The calendar day of an instant, the instants being the business's own
/// wall clock in these cases.
DateTime _dayOf(DateTime i) => DateTime.utc(i.year, i.month, i.day);

void main() {
  test('a window that ends at midnight ends with the day before', () {
    final twoDays = _pass(
      from: DateTime.utc(2026, 11, 2),
      to: DateTime.utc(2026, 11, 4),
      units: 2,
    );
    expect(twoDays.lastDay(_dayOf), DateTime.utc(2026, 11, 3));
  });

  test('a window that ends in the evening ends on that day', () {
    final twoDays = _pass(
      from: DateTime.utc(2026, 11, 2, 8),
      to: DateTime.utc(2026, 11, 3, 18),
      units: 2,
    );
    expect(twoDays.lastDay(_dayOf), DateTime.utc(2026, 11, 3));
  });

  test('the units begun: none before, one per day begun, never more than '
      'sold', () {
    final pass = _pass(
      from: DateTime.utc(2026, 11, 2, 8),
      to: DateTime.utc(2026, 11, 3, 18),
      units: 2,
    );
    expect(pass.usedAt(DateTime.utc(2026, 11, 1, 23), _dayOf), 0);
    expect(pass.usedAt(DateTime.utc(2026, 11, 2, 9), _dayOf), 1);
    expect(pass.usedAt(DateTime.utc(2026, 11, 3, 7), _dayOf), 2);
    expect(pass.usedAt(DateTime.utc(2026, 11, 9), _dayOf), 2);
  });

  test('an hourly pass is one window: all of it once it began', () {
    final hours = _pass(
      from: DateTime.utc(2026, 11, 2, 9),
      to: DateTime.utc(2026, 11, 2, 12),
      units: 3,
      unit: GuestPassUnit.hour,
    );
    expect(hours.usedAt(DateTime.utc(2026, 11, 2, 8), _dayOf), 0);
    expect(hours.usedAt(DateTime.utc(2026, 11, 2, 10), _dayOf), 3);
  });
}
