// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3484 — a tax rate reads in the member's format locale, a whole rate
// without decimals.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppFormat at(String locale) => AppFormat(locale: locale, currencyCode: 'EUR');

  test('the rate table', () {
    expect(at('fr_FR').rate(20.0), '20 %');
    expect(at('fr_FR').rate(5.5), '5,5 %');
    expect(at('de_CH').rate(7.7), '7.7 %');
    expect(at('de_DE').rate(19), '19 %');
    expect(at('en_GB').rate(17.5), '17.5 %');
    expect(at('fr_CA').rate(14.975), '14,975 %');
  });
}
