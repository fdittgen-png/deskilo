// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3648 — the week starts where the reader's format locale starts it, and
// the reader may say otherwise. The boundary (`weekStartOf`), the three
// counts it reconciles (intl from Monday 0, the framework from Sunday 0,
// `DateTime.weekday` from Monday 1), the narrow weekday names, and the
// framework's own localizations with ONE value replaced.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/i18n/week_start.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AppFormat _format(String locale, [WeekStartPref pref = WeekStartPref.locale]) =>
    AppFormat(locale: locale, currencyCode: 'EUR', weekStart: pref);

void main() {
  setUpAll(initializeDateFormatting);

  group('weekStartOf — the locale\'s own week', () {
    test('Sunday-first, Monday-first and Saturday-first locales', () {
      expect(weekStartOf(_format('en_US')), DateTime.sunday);
      expect(weekStartOf(_format('en_CA')), DateTime.sunday);
      expect(weekStartOf(_format('ja_JP')), DateTime.sunday);
      expect(weekStartOf(_format('de_DE')), DateTime.monday);
      expect(weekStartOf(_format('fr_FR')), DateTime.monday);
      expect(weekStartOf(_format('en_GB')), DateTime.monday);
      expect(weekStartOf(_format('ar_EG')), DateTime.saturday);
    });

    test('a locale intl does not know reads the ISO Monday, not a crash', () {
      expect(weekStartOf(_format('xx_YY')), DateTime.monday);
    });
  });

  group('weekStartOf — the chosen day overrides the locale', () {
    test('every choice wins over every locale', () {
      for (final locale in ['en_US', 'de_DE', 'ar_EG']) {
        expect(weekStartOf(_format(locale, WeekStartPref.monday)), 1);
        expect(weekStartOf(_format(locale, WeekStartPref.sunday)), 7);
        expect(weekStartOf(_format(locale, WeekStartPref.saturday)), 6);
      }
    });

    test('the wire round-trips and a missing key is the locale\'s own', () {
      for (final pref in WeekStartPref.values) {
        expect(WeekStartPref.fromWire(pref.wire), pref);
        expect(FormatPrefs.fromDb(FormatPrefs(weekStart: pref).toDb()).weekStart, pref);
      }
      // A server that does not know the key yet sends none.
      expect(FormatPrefs.fromDb({'clock': '24h'}).weekStart, WeekStartPref.locale);
      expect(WeekStartPref.fromWire('someday'), WeekStartPref.locale);
    });
  });

  group('columns', () {
    test('a known Sunday sits in the column its week start gives it', () {
      final sunday = DateTime(2026, 11);
      expect(sunday.weekday, DateTime.sunday);
      expect(weekColumnOf(sunday, DateTime.sunday), 0);
      expect(weekColumnOf(sunday, DateTime.monday), 6);
      expect(weekColumnOf(sunday, DateTime.saturday), 1);
    });

    test('startOfWeek crosses month and year boundaries', () {
      expect(startOfWeek(DateTime(2026), DateTime.monday), DateTime(2025, 12, 29));
      expect(startOfWeek(DateTime(2026), DateTime.sunday), DateTime(2025, 12, 28));
      expect(startOfWeek(DateTime(2026), DateTime.saturday), DateTime(2025, 12, 27));
      expect(startOfWeek(DateTime(2026, 11), DateTime.sunday), DateTime(2026, 11));
    });
  });

  group('weekdayHeaders — narrow names, in the reader\'s order', () {
    test('German: Monday first, two days share each of D, M and S', () {
      final narrow = [for (final h in weekdayHeaders(_format('de_DE'))) h.narrow];
      expect(narrow, ['M', 'D', 'M', 'D', 'F', 'S', 'S']);
      final full = [for (final h in weekdayHeaders(_format('de_DE'))) h.full];
      expect(full.toSet().length, 7, reason: 'a screen reader tells them apart');
      expect(full.first, 'Montag');
    });

    test('English, Sunday first; the chosen Saturday moves the row', () {
      final sunday = [for (final h in weekdayHeaders(_format('en_US'))) h.full];
      expect(sunday.first, 'Sunday');
      expect(sunday.last, 'Saturday');
      final saturday = [
        for (final h in weekdayHeaders(_format('en_US', WeekStartPref.saturday))) h.full
      ];
      expect(saturday.first, 'Saturday');
      expect(saturday[1], 'Sunday');
    });

    test('a script whose first letter is not one code unit is not cut', () {
      final names = weekdayHeaders(_format('ja_JP'));
      expect(names.first.narrow, '日');
      expect(names.first.narrow.runes.length, 1);
    });
  });
}
