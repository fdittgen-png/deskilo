// SPDX-License-Identifier: 0BSD
//
// #711 — globalization. The workspace owns the money and the clock; the
// member owns how they read them. These pin the formatting seam, the
// currency table and the catalogues — the pure parts, where a wrong
// answer is a wrong invoice.
import 'dart:io';

import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/currencies.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/i18n/time_zones.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    tzdata.initializeTimeZones();
  });

  group('Currencies — minor units are not always cents', () {
    test('the euro has two, the yen none, the dinar three', () {
      expect(Currencies.minorDigits('EUR'), 2);
      expect(Currencies.minorDigits('JPY'), 0);
      expect(Currencies.minorDigits('KWD'), 3);
      expect(Currencies.minorDigits('xyz'), 2, reason: 'unknown → ISO majority');
    });

    test('storage ↔ major round-trips at the currency\'s grain', () {
      expect(Currencies.toMajor(1250, 'EUR'), 12.5);
      expect(Currencies.toMajor(1250, 'JPY'), 1250);
      expect(Currencies.toMajor(1250, 'KWD'), 1.25);
      expect(Currencies.toMinor(12.5, 'EUR'), 1250);
      expect(Currencies.toMinor(1250, 'JPY'), 1250);
    });

    test('every selectable code is well-formed', () {
      for (final code in Currencies.selectable) {
        expect(Currencies.isWellFormed(code), isTrue, reason: code);
      }
    });
  });

  group('AppFormat.money — the workspace currency, the reader\'s spelling', () {
    test('123456 EUR reads three ways for three readers', () {
      const eur = 'EUR';
      expect(const AppFormat(locale: 'en_US', currencyCode: eur).money(123456),
          '€1,234.56');
      // intl spells the French group separator as a narrow no-break
      // space; the test compares on plain spaces so the intent reads.
      String plain(String s) => s.replaceAll('\u202f', ' ').replaceAll('\u00a0', ' ');
      expect(plain(const AppFormat(locale: 'fr_FR', currencyCode: eur).money(123456)),
          contains('1 234,56'));
      expect(const AppFormat(locale: 'de_CH', currencyCode: eur).money(123456),
          contains('1’234.56'));
    });

    test('a yen amount is never divided by 100', () {
      final s = const AppFormat(locale: 'en_US', currencyCode: 'JPY').money(1250);
      expect(s, contains('1,250'));
      expect(s, isNot(contains('12.50')));
    });

    test('a dinar amount carries three decimals', () {
      expect(const AppFormat(locale: 'en_US', currencyCode: 'KWD').money(1250),
          contains('1.250'));
    });

    test('compact drops the decimals of a whole amount only', () {
      const f = AppFormat(locale: 'en_US', currencyCode: 'EUR');
      expect(f.moneyCompact(1200), '€12');
      expect(f.moneyCompact(1250), '€12.50');
    });
  });

  group('AppFormat — dates and clock', () {
    final instant = DateTime.utc(2026, 8, 28, 12, 30);

    test('the date follows the format locale', () {
      const en = AppFormat(locale: 'en_GB', currencyCode: 'EUR',
          timeZoneMode: TimeZoneMode.device);
      const de = AppFormat(locale: 'de_DE', currencyCode: 'EUR',
          timeZoneMode: TimeZoneMode.device);
      expect(en.date(instant), contains('Aug'));
      expect(de.date(instant), contains('Aug.'));
    });

    test('24h, 12h, and auto for a 12-hour region', () {
      const h24 = AppFormat(locale: 'en_US', currencyCode: 'EUR',
          clock: ClockPref.h24, timeZoneMode: TimeZoneMode.device);
      const h12 = AppFormat(locale: 'fr_FR', currencyCode: 'EUR',
          clock: ClockPref.h12, timeZoneMode: TimeZoneMode.device);
      const auto = AppFormat(locale: 'en_US', currencyCode: 'EUR',
          timeZoneMode: TimeZoneMode.device);
      final local = instant.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      expect(h24.time(instant), '$hh:$mm');
      expect(h12.time(instant), anyOf(contains('AM'), contains('PM')));
      expect(auto.time(instant), anyOf(contains('AM'), contains('PM')),
          reason: 'en_US prefers a 12-hour clock');
    });

    test('workspace mode reads the workspace wall clock', () {
      WorkspaceTime.install('Asia/Tokyo');
      addTearDown(WorkspaceTime.reset);
      const f = AppFormat(locale: 'en_GB', currencyCode: 'JPY',
          clock: ClockPref.h24);
      // 12:30 UTC is 21:30 in Tokyo, whatever the device says.
      expect(f.time(instant), '21:30');
    });
  });

  group('defaults and catalogues', () {
    test('the default format locale pairs language with workspace country',
        () {
      expect(defaultFormatLocale('fr', 'CA'), 'fr_CA');
      expect(defaultFormatLocale('en', 'CH'), 'en_GB',
          reason: 'no en_CH symbols → the language\'s home region');
      expect(defaultFormatLocale('zz', 'FR'), 'en_GB');
    });

    test('every country has a known zone and a well-formed currency', () {
      expect(CountryCatalog.countries, hasLength(32));
      for (final c in CountryCatalog.countries) {
        expect(TimeZones.isKnown(c.defaultTimezone), isTrue,
            reason: '${c.code}: ${c.defaultTimezone}');
        expect(Currencies.isWellFormed(c.currencyCode), isTrue, reason: c.code);
      }
    });

    test('the zone picker searches loosely and labels the offset', () {
      expect(TimeZones.search('paris'), contains('Europe/Paris'));
      expect(TimeZones.search('new york'), contains('America/New_York'));
      expect(TimeZones.offsetLabel('Europe/Paris', DateTime.utc(2026, 1, 15)),
          'UTC+01:00');
      expect(TimeZones.all, isNot(contains('CET')),
          reason: 'aliases are noise in a picker');
    });

    test('FormatPrefs round-trips and tolerates garbage', () {
      const prefs = FormatPrefs(
        formatLocale: 'de_CH',
        clock: ClockPref.h12,
        timeZoneMode: TimeZoneMode.device,
      );
      expect(FormatPrefs.fromDb(prefs.toDb()), prefs);
      expect(FormatPrefs.fromDb({'clock': 'bogus'}).clock, ClockPref.auto);
    });
  });

  group('the pieces the widget tree cannot show', () {
    test('0132 validates what the pickers offer', () {
      final sql =
          File('supabase/migrations/0132_globalization.sql').readAsStringSync();
      expect(sql, contains(r"check (currency_code ~ '^[A-Z]{3}$')"));
      expect(sql, contains('pg_timezone_names'));
      expect(sql, contains("check (clock in ('auto', '24h', '12h'))"));
    });

    test('the payment-order function knows a yen has no cents', () {
      final ts = File('supabase/functions/create-payment-order/index.ts')
          .readAsStringSync();
      expect(ts, contains('ZERO_DECIMAL'));
      expect(ts, isNot(contains('(cents / 100).toFixed(2)')));
      expect(ts, contains('major(amountCents, currency)'));
    });
  });
}
