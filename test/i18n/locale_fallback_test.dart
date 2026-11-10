// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3483 -- a device in a language the app does not ship opens it in English,
// the canonical locale (ADR 0007), not in the alphabetically first one.
// `l10n.yaml` lists `en` first; Flutter's standard resolution falls back to
// the first supported locale, on all three MaterialApps at once.
import 'dart:io';

import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  test('English leads the supported locales', () {
    expect(supported.first, const Locale('en'));
  });

  test('an unshipped language resolves to English, a shipped one to itself', () {
    Locale resolve(Locale device) =>
        basicLocaleListResolution([device], supported);
    for (final unshipped in ['nl', 'pl', 'pt', 'sv']) {
      expect(resolve(Locale(unshipped)), const Locale('en'), reason: unshipped);
    }
    expect(resolve(const Locale('fr', 'CA')).languageCode, 'fr');
    expect(resolve(const Locale('de', 'CH')).languageCode, 'de');
  });

  test('the fix is the list order, not a resolution callback', () {
    final hits = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('localeResolutionCallback'))
          f.path,
    ];
    expect(hits, isEmpty);
  });

  testWidgets('a Polish device sees English strings', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('pl')];
    tester.platformDispatcher.localeTestValue = const Locale('pl');
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(l10n.localeName, 'en');
  });
}
