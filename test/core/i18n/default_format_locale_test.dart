// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3647 — a format locale nobody chose is decided in one function: its
// language is the language the app is SHOWN in (never the raw device
// language), its region the device's (personal surface) or the business's
// (business screen); without such a pairing, the closest one, else the
// language's home region.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/shown_language.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('language × region', () {
    // language, region, expected
    const table = <(String, String, String)>[
      // the five shipped languages: the exact pairing when intl has it
      ('en', 'GB', 'en_GB'), ('en', 'US', 'en_US'), ('en', 'CA', 'en_CA'),
      ('en', 'AU', 'en_AU'), ('en', 'IE', 'en_IE'),
      ('fr', 'FR', 'fr_FR'), ('fr', 'CA', 'fr_CA'), ('fr', 'CH', 'fr_CH'),
      ('fr', 'BE', 'fr_BE'),
      ('de', 'DE', 'de_DE'), ('de', 'AT', 'de_AT'), ('de', 'CH', 'de_CH'),
      ('es', 'ES', 'es_ES'), ('es', 'MX', 'es_MX'),
      ('it', 'IT', 'it_IT'), ('it', 'CH', 'it_CH'),
      // no such pairing: the closest one, else the language's home region
      ('en', 'CH', 'en_GB'), ('en', 'FR', 'en_GB'), ('en', 'DE', 'en_GB'),
      ('en', 'IT', 'en_GB'), ('en', 'ES', 'en_GB'), ('en', 'PL', 'en_GB'),
      ('en', 'NL', 'en_GB'), ('en', 'PT', 'en_GB'), ('en', 'BR', 'en_GB'),
      ('es', 'US', 'es_MX'), ('es', 'AR', 'es_MX'), ('es', 'FR', 'es_ES'),
      ('fr', 'LU', 'fr_FR'), ('fr', 'US', 'fr_FR'), ('de', 'LU', 'de_DE'),
      ('de', 'PL', 'de_DE'), ('it', 'FR', 'it_IT'), ('it', 'US', 'it_IT'),
      // a lower-case region reads the same
      ('fr', 'ca', 'fr_CA'),
      // the languages of Dutch, Polish and Portuguese devices, were they shown
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
  });

  group('the shown language, never the raw device language', () {
    // device, chosen in the app, shown language, personal format locale
    const table = <(Locale, Locale?, String, String)>[
      (Locale('en', 'US'), null, 'en', 'en_US'),
      (Locale('en', 'GB'), null, 'en', 'en_GB'),
      (Locale('fr', 'FR'), null, 'fr', 'fr_FR'),
      (Locale('de', 'CH'), null, 'de', 'de_CH'),
      (Locale('es', 'US'), null, 'es', 'es_MX'),
      (Locale('it', 'IT'), null, 'it', 'it_IT'),
      // Dutch, Polish and Portuguese devices read the app in English:
      // English month names in their region's nearest English
      (Locale('nl', 'NL'), null, 'en', 'en_GB'),
      (Locale('nl', 'BE'), null, 'en', 'en_GB'),
      (Locale('pl', 'PL'), null, 'en', 'en_GB'),
      (Locale('pt', 'PT'), null, 'en', 'en_GB'),
      (Locale('pt', 'BR'), null, 'en', 'en_GB'),
      // the language chosen in the app wins over the device's
      (Locale('nl', 'NL'), Locale('fr'), 'fr', 'fr_FR'),
      (Locale('pl', 'PL'), Locale('de'), 'de', 'de_DE'),
      (Locale('en', 'US'), Locale('es'), 'es', 'es_MX'),
      (Locale('fr', 'CA'), Locale('en'), 'en', 'en_CA'),
    ];

    for (final (device, chosen, shown, expected) in table) {
      test('$device device, ${chosen ?? 'no'} app language → $expected', () {
        final language = shownLanguage(chosen: chosen, device: [device]);
        expect(language, shown);
        expect(
          personalDefaultFormatLocale(
            language: language,
            deviceRegion: device.countryCode,
            operatorLocale: 'fr_FR',
          ),
          expected,
        );
      });
    }

    test('a later device language the app ships is the shown one', () {
      expect(
        shownLanguage(
          chosen: null,
          device: const [Locale('nl', 'NL'), Locale('fr', 'BE')],
        ),
        'fr',
      );
    });
  });

  group('a device without a region reads the operator default', () {
    test('in its own language: the operator locale as it is', () {
      expect(
        personalDefaultFormatLocale(
          language: 'fr',
          deviceRegion: null,
          operatorLocale: 'fr_CH',
        ),
        'fr_CH',
      );
    });

    test('in another language: its region with the shown language', () {
      expect(
        personalDefaultFormatLocale(
          language: 'en',
          deviceRegion: '',
          operatorLocale: 'fr_CA',
        ),
        'en_CA',
      );
    });
  });
}
