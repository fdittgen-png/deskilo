// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1246 — every screen we can pump, in every language, narrowed to a
// phone.
//
// `arb_key_parity_test` proves the five ARB key sets are identical
// and the CI l10n gate proves the aggregates cannot drift, so a MISSING
// translation is already a red build. What was never proved is that the
// UI works in the other four.
//
// `text_expansion_test.dart` walks the seven shell surfaces. This walks
// the screens that have their own pump helper — the settings forms, the
// money faces, the editor — and it walks them at 360 px, because that
// is where a German compound stops fitting beside a trailing control.
//
// The helpers set generous viewports on purpose: they need every row
// BUILT so a finder can reach it. So each screen is pumped the way its
// own test pumps it, and then narrowed. The narrowing is the test.
//
// #2601 — the screens are the `locales` axis of `test/a11y/matrix.dart`
// (kMatrix), the one list: a screen is added there once, and a row that does
// not walk this axis says so with a dated reason. ARB parity proves key
// existence, not layout, so a fixture below proves this walk fails when only
// a translated label stops fitting.
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../a11y/matrix.dart';

/// German first: the longest of the five, and the one a developer
/// reading English is least likely to eyeball correctly.
const _locales = [Locale('de'), Locale('fr'), Locale('es'), Locale('it')];

/// A Pixel-class width, portrait. Narrower than anything mainstream and
/// wide enough to be a real target rather than a synthetic worst case.
const _phone = Size(360, 740);

/// Pumps [pump] under [locale], narrows the view to a phone and returns the
/// first exception the framework recorded (a RenderFlex overflow, almost
/// always), or null.
Future<Object?> exceptionAt(
  WidgetTester tester,
  Locale locale,
  ScreenPump pump, {
  Size size = _phone,
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.localeTestValue = locale;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  await pump(tester);
  // Whatever the helper chose, the phone is what a member holds.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpAndSettle();
  return tester.takeException();
}

void main() {
  for (final locale in _locales) {
    for (final row in matrixRowsFor(MatrixAxis.locales)) {
      testWidgets('${row.screen} survives ${locale.languageCode} at phone width',
          (tester) async {
        final e = await exceptionAt(tester, locale, row.localePump!);
        expect(
          e,
          isNull,
          reason: '"${row.screen}" under ${locale.languageCode} at '
              '${_phone.width.toInt()}px threw: $e — almost always a '
              'RenderFlex overflow from a string longer than the English '
              'this layout was built against. Wrap with Expanded or '
              'Flexible, ellipsize, or let it wrap.',
        );
      });
    }
  }

  // Perfect ARB parity, and a label that only the German string breaks.
  Future<void> labelRow(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final de = Localizations.localeOf(context).languageCode == 'de';
                return Row(
                  children: [
                    Text(de ? 'Zugangsberechtigungsverwaltung' : 'Access'),
                  ],
                );
              },
            ),
          ),
        ),
      );

  testWidgets('the walk fails when only a translated label stops fitting',
      (tester) async {
    expect(await exceptionAt(tester, const Locale('fr'), labelRow, size: const Size(120, 740)), isNull);
    expect(await exceptionAt(tester, const Locale('de'), labelRow, size: const Size(120, 740)), isNotNull);
  });

  test('the locale axis names the nine screens it has always walked', () {
    expect(
      matrixRowsFor(MatrixAxis.locales).map((r) => r.screen).toSet(),
      {
        'Reserve hub',
        'Money faces',
        'Invoices',
        'Alerts',
        'Validation rules',
        'Features',
        'Process overview',
        'Accessories',
        'Level canvas',
      },
    );
  });
}
