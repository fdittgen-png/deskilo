// SPDX-License-Identifier: 0BSD
//
// #713 — the format picker speaks the reader's language, not BCP-47.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/locale_names.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('language (region) and a number sample in the candidate spelling',
      () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(formatLocaleLabel(en, 'de_DE'), 'German (Germany) · 1.234,56');
    expect(formatLocaleLabel(en, 'en_US'), 'English (United States) · 1,234.56');
    // The sample is whatever the app will actually render for that tag —
    // intl's own symbols, never a hand-typed idea of them.
    final chSample = NumberFormat.decimalPattern('fr_CH').format(1234.56);
    expect(formatLocaleLabel(en, 'fr_CH'), 'French (Switzerland) · $chSample');
    final fr = await AppLocalizations.delegate.load(const Locale('fr'));
    expect(formatLocaleLabel(fr, 'fr_CH'), 'Français (Suisse) · $chSample');
  });

  test('every pickable locale has a name in every UI language', () async {
    for (final ui in ['en', 'fr', 'de', 'es', 'it']) {
      final l10n = await AppLocalizations.delegate.load(Locale(ui));
      for (final tag in kFormatLocales) {
        final label = formatLocaleLabel(l10n, tag);
        // A raw code leaking into the label is the bug this replaces.
        expect(label, isNot(startsWith(tag.split('_').first)),
            reason: '$ui: $tag → $label');
        expect(label, isNot(contains(RegExp(r'\([A-Z]{2}\)'))),
            reason: '$ui: $tag → $label');
      }
    }
  });
}
