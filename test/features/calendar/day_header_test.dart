// SPDX-License-Identifier: 0BSD
//
// #1175 — the agenda's day header names the weekday ONCE.
//
// `AppFormat.shortDate` is `DateFormat.MMMEd`, whose E is already the
// abbreviated weekday. Prefixing `DateFormat.EEEE` gave every header in
// every language a stutter: "Today · Sunday Sun 13 Sept".
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  test('shortDate already carries the weekday — nothing may prepend it',
      () {
    const format = AppFormat(locale: 'en_US', currencyCode: 'EUR');
    final sunday = DateTime(2026, 9, 13, 12);
    final header = format.shortDate(sunday);
    expect(header, contains('Sun'));
    // The stutter, spelled out: the full weekday must not also be there.
    expect(header.toLowerCase(), isNot(contains('sunday')),
        reason: 'MMMEd gives the short form; a long one beside it is the bug');
  });

  test('the French header stutters the same way when doubled', () {
    const format = AppFormat(locale: 'fr', currencyCode: 'EUR');
    final header = format.shortDate(DateTime(2026, 9, 13, 12));
    expect(header.toLowerCase(), contains('dim'));
    expect(header.toLowerCase(), isNot(contains('dimanche')));
  });
}
