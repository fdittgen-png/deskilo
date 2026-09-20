// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1303 S1 — a new workspace starts in the country the device is in.
//
// Onboarding hardcoded Germany (DE, EUR, Europe/Berlin) for everyone. The
// device's own region decides now when the catalog knows it; a language
// spoken as the main language of one catalog country decides next; and the
// explicit fallback is France, the same answer the catalog gives an
// unknown code. Nothing beyond the country is inferred.
import 'dart:ui';

import 'package:deskilo/core/locale/device_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the device region wins when the catalog knows it', () {
    final ch = initialCountryFor(const Locale('fr', 'CH'));
    expect(ch.code, 'CH');
    expect(ch.currencyCode, 'CHF');
    expect(initialCountryFor(const Locale('en', 'GB')).code, 'GB');
    expect(initialCountryFor(const Locale('de', 'AT')).code, 'AT');
  });

  test('a language alone picks its one country', () {
    expect(initialCountryFor(const Locale('it')).code, 'IT');
    expect(initialCountryFor(const Locale('de')).code, 'DE');
  });

  test('an unknown region falls back to the language, then to France', () {
    expect(initialCountryFor(const Locale('es', 'MX')).code, 'ES');
    expect(initialCountryFor(const Locale('ja', 'JP')).code, 'FR');
    expect(initialCountryFor(null).code, 'FR');
  });

  test('currency and time zone come with the country', () {
    final fr = initialCountryFor(const Locale('fr', 'FR'));
    expect(fr.currencyCode, 'EUR');
    expect(fr.defaultTimezone, 'Europe/Paris');
  });
}
