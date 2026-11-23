// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4426 -- today on the business's calendar: a business a day ahead of the clock's zone offers its own date.
import 'package:deskilo/core/time/business_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a business in Auckland at 23:30 UTC is on the next day, one in Los Angeles on the same', () {
    final instant = DateTime.utc(2026, 11, 22, 23, 30);
    expect(businessDateOf(instant, 'Pacific/Auckland'), DateTime(2026, 11, 23));
    expect(businessDateOf(instant, 'America/Los_Angeles'), DateTime(2026, 11, 22));
  });

  test('a zone that is not known reads the UTC date, never the device\'s', () {
    expect(businessDateOf(DateTime.utc(2026, 11, 22, 23, 30), null), DateTime(2026, 11, 22));
  });
}
