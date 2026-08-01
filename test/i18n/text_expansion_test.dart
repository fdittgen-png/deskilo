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

/// Icons repeat across surfaces (calendar_month is a nav destination AND
/// a date-picker button), and `.first` happily taps the occluded one —
/// the warnIfMissed warning then hides a surface never being visited.
/// Scope every tap to the bar it lives in. The shell bar is the custom
/// ShellBottomBar, not Material's NavigationBar.
Future<void> _tapNav(WidgetTester tester, IconData icon) async {
  await tester.tap(find.descendant(
    of: find.byType(ShellBottomBar),
    matching: find.byIcon(icon),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapAppBar(WidgetTester tester, IconData icon) async {
  await tester.tap(find.descendant(
    of: find.byType(AppBar),
    matching: find.byIcon(icon),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in _launchLocales) {
    testWidgets('main surfaces survive ${locale.languageCode} at phone width',
        (tester) async {
      await _pumpApp(tester, locale);
      _expectNoOverflow(tester, locale, 'boot → Reserve hub');

      await _tapNav(tester, Icons.grid_view_outlined);
      _expectNoOverflow(tester, locale, 'Plan');

      await _tapNav(tester, Icons.calendar_month_outlined);
      _expectNoOverflow(tester, locale, 'Calendar');

      await _tapNav(tester, Icons.people_outline);
      _expectNoOverflow(tester, locale, 'Members');

      await _tapNav(tester, Icons.account_balance_wallet_outlined);
      _expectNoOverflow(tester, locale, 'Money (bill)');

      await _tapAppBar(tester, Icons.notifications_outlined);
      _expectNoOverflow(tester, locale, 'Events');
      // Not pageBack(): it matches the "Back" TOOLTIP, which is localized
      // — the very thing this test varies. The widget type is not.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await _tapAppBar(tester, Icons.settings_outlined);
      _expectNoOverflow(tester, locale, 'Settings');
    });
  }
}
