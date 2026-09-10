// SPDX-License-Identifier: 0BSD
//
// #1077 — `Currencies.selectable` offers JPY, KRW and ISK, which have NO
// minor unit: 1 yen is 1 yen, not 100 of anything. `parseCentsInput` and
// `centsToMajor` hardcoded 100 anyway, while `Currencies.minorPerMajor`
// existed for exactly this and was already used by `formatMinor`.
//
// In a yen workspace the owner typed 5000 into a fee band and the app
// stored 500 000 minor units. The editor read it back through
// `centsToMajor` and showed 5000, so the FORM looked right — and every
// bill, invoice and statement then rendered ¥500,000. The member was
// billed a hundred times the price.
import 'package:deskilo/core/format/cents.dart';
import 'package:deskilo/core/i18n/workspace_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(WorkspaceCurrency.reset);

  group('a currency with no minor unit (JPY)', () {
    setUp(() => WorkspaceCurrency.install('JPY'));

    test('5000 yen is stored as 5000, not 500 000', () {
      expect(parseCentsInput('5000'), 5000);
    });

    test('and reads back as the same 5000', () {
      expect(centsToMajor(5000), '5000');
    });

    test('the round trip is the identity', () {
      for (final typed in ['1', '250', '5000', '123456']) {
        expect(centsToMajor(parseCentsInput(typed)!), typed);
      }
    });
  });

  group('a three-decimal currency (BHD)', () {
    setUp(() => WorkspaceCurrency.install('BHD'));

    test('12.5 is 12 500 fils', () {
      expect(parseCentsInput('12.5'), 12500);
    });
  });

  group('the euro is unchanged', () {
    setUp(() => WorkspaceCurrency.install('EUR'));

    test('12,50 is 1250 cents and reads back as 12.50', () {
      expect(parseCentsInput('12,50'), 1250);
      expect(centsToMajor(1250), '12.50');
      expect(centsToMajor(15000), '150');
    });
  });

  test('with nothing installed the euro grain is the safe default', () {
    expect(parseCentsInput('12.50'), 1250);
    expect(centsToMajor(1250), '12.50');
  });
}
