// SPDX-License-Identifier: AGPL-3.0-or-later
// #3376 -- the kernel stands alone: an amount, a date spelling, a currency's
// minor units and a strict reader work with nothing else of the application
// in the build. The moved code keeps its detailed tests in the application.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:test/test.dart';

void main() {
  test('the kernel stands alone: an amount, a date and a reader', () {
    expect(isoDay(DateTime(2026, 9, 30)), '2026-09-30');
    expect(Currencies.minorDigits('EUR'), 2);
    expect(Currencies.minorDigits('JPY'), 0);
    final amount = AccountingAmount('EUR', 1250);
    expect(amount.minor, 1250);
    final reader = JsonReader({'n': 3}, context: 'kernel');
    expect(reader.integer('n'), 3);
  });
}
