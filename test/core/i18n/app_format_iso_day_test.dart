// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3653 — a stored calendar day reads in the member's format locale.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    for (final l in ['en_GB', 'de_DE', 'fr_FR']) {
      await initializeDateFormatting(l);
    }
  });

  AppFormat at(String locale) => AppFormat(locale: locale, currencyCode: 'EUR');

  test('an ISO day is a date in the reader\'s language', () {
    expect(at('en_GB').isoDay('2026-08-28'), '28 Aug 2026');
    expect(at('de_DE').isoDay('2026-08-28'), '28. Aug. 2026');
    expect(at('fr_FR').isoDay('2026-08-28'), '28 août 2026');
  });

  test('text that is not a day comes back as it was', () {
    expect(at('en_GB').isoDay('open end'), 'open end');
  });

  test('a picked day has no zone shift', () {
    expect(at('en_GB').calendarDay(DateTime(2026)), '1 Jan 2026');
  });
}
