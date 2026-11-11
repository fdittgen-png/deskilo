// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3656 -- the format locale is decided in one function: language = the
// language the app is shown in, region = the device's or the business's.
import 'dart:io';

import 'package:deskilo/core/i18n/app_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // language, region, expected
  const table = <(String, String, String)>[
    // shipped languages: the exact pairing when it exists
    ('en', 'GB', 'en_GB'), ('en', 'US', 'en_US'), ('en', 'CA', 'en_CA'),
    ('en', 'AU', 'en_AU'), ('en', 'IE', 'en_IE'),
    ('fr', 'FR', 'fr_FR'), ('fr', 'CA', 'fr_CA'), ('fr', 'CH', 'fr_CH'),
    ('fr', 'BE', 'fr_BE'),
    ('de', 'DE', 'de_DE'), ('de', 'AT', 'de_AT'), ('de', 'CH', 'de_CH'),
    ('es', 'ES', 'es_ES'), ('es', 'MX', 'es_MX'),
    ('it', 'IT', 'it_IT'), ('it', 'CH', 'it_CH'),
    // shipped languages without a pairing: the closest, else the home region
    ('en', 'CH', 'en_GB'), ('en', 'FR', 'en_GB'), ('en', 'DE', 'en_GB'),
    ('en', 'IT', 'en_GB'), ('en', 'ES', 'en_GB'), ('en', 'PL', 'en_GB'),
    ('es', 'US', 'es_MX'), ('es', 'AR', 'es_MX'), ('es', 'FR', 'es_ES'),
    ('fr', 'LU', 'fr_FR'), ('de', 'LU', 'de_DE'), ('it', 'FR', 'it_IT'),
    // lower-case regions are read the same
    ('fr', 'ca', 'fr_CA'),
    // languages the app does not ship yet (the epic's next ones)
    ('nl', 'NL', 'nl_NL'), ('nl', 'BE', 'nl_BE'), ('nl', 'FR', 'nl_NL'),
    ('pl', 'PL', 'pl_PL'), ('pl', 'DE', 'pl_PL'),
    ('pt', 'PT', 'pt_PT'), ('pt', 'BR', 'pt_PT'),
    // a language the list does not know, and a missing region
    ('zz', 'FR', 'en_GB'), ('fr', '', 'fr_FR'), ('en', '', 'en_GB'),
  ];

  for (final (language, region, expected) in table) {
    test('$language in "$region" reads $expected', () {
      expect(defaultFormatLocale(language, region), expected);
      expect(kFormatLocales, contains(expected));
    });
  }

  test('saving the interface language leaves the document language alone', () {
    final text = File(
      'lib/features/profile/presentation/widgets/preference_scope_controls.dart',
    ).readAsStringSync();
    final save = text.substring(
      text.indexOf('Future<void> savePersonalLanguage'),
      text.indexOf('Future<void> savePersonalTheme'),
    );
    expect(save, contains('PersonalPreference.uiLocale'));
    expect(save, isNot(contains('PersonalPreference.documentLocale')));
  });
}
