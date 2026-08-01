// SPDX-License-Identifier: 0BSD
//
// Text-expansion survival: the main surfaces render in every launch
// locale at phone width without a RenderFlex overflow.
//
// Sparkilo ships a generated pseudo-locale for this. DesKilo does not
// need one — deliberately: HARD RULE #1 lands all five translations in
// the same PR, so there is no pre-translation window for a pseudo-locale
// to cover. What remains worth catching is the layout that only breaks
// in a language the developer does not read — German compounds and
// French phrases run 20–40% past the English a screen was eyeballed in.
// So this walks the real locales instead of a synthetic one: honest
// strings, real failure.
//
// Navigation is BY ICON, never by label — the labels are the very thing
// under test, and they change per locale.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_floor_plan_repository.dart';
import '../helpers/mock_providers.dart';
import '../helpers/navigation.dart';

/// One representative phone: 360 logical px is a Pixel-class width and
/// the narrowest mainstream device. Portrait, so the landscape split
/// (which triggers whenever W > H) stays out of the way.
const _phone = Size(360, 740);

const _launchLocales = [
  Locale('de'),
  Locale('fr'),
  Locale('es'),
  Locale('it'),
];

Future<void> _pumpApp(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.localeTestValue = locale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fails with the locale and surface named — an overflow deep in a
/// pumpAndSettle is unfindable without the attribution.
void _expectNoOverflow(WidgetTester tester, Locale locale, String surface) {
  final e = tester.takeException();
  expect(
    e,
    isNull,
    reason: '"$surface" under ${locale.languageCode} at '
        '${_phone.width.toInt()}px threw: $e — almost always a RenderFlex '
        'overflow from a string longer than the English this layout was '
        'built against. Wrap with Expanded/Flexible, ellipsize, or let it '
        'wrap.',
  );
}

void main() {
  for (final locale in _launchLocales) {
    testWidgets('main surfaces survive ${locale.languageCode} at phone width',
        (tester) async {
      await _pumpApp(tester, locale);
      _expectNoOverflow(tester, locale, 'boot → Reserve hub');

      // Growth guard: this walk hardcodes the destinations, so a NEW
      // shell destination must fail here (and get added below) instead
      // of silently shipping with zero expansion coverage.
      expect(
        find.descendant(
          of: find.byType(ShellBottomBar),
          matching: find.byType(InkWell),
        ),
        findsNWidgets(5),
        reason: 'The shell bar gained or lost a destination — update the '
            'walk in this test so every surface keeps expansion coverage.',
      );

      await tapNavIcon(tester, Icons.grid_view_outlined);
      _expectNoOverflow(tester, locale, 'Plan');

      await tapNavIcon(tester, Icons.calendar_month_outlined);
      _expectNoOverflow(tester, locale, 'Calendar');

      await tapNavIcon(tester, Icons.people_outline);
      _expectNoOverflow(tester, locale, 'Members');

      await tapNavIcon(tester, Icons.account_balance_wallet_outlined);
      _expectNoOverflow(tester, locale, 'Money (bill)');

      await tapAppBarIcon(tester, Icons.notifications_outlined);
      _expectNoOverflow(tester, locale, 'Events');
      // Not pageBack(): it matches the "Back" TOOLTIP, which is localized
      // — the very thing this test varies. The widget type is not.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tapAppBarIcon(tester, Icons.settings_outlined);
      _expectNoOverflow(tester, locale, 'Settings');
    });
  }
}
