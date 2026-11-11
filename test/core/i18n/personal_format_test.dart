// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3647 — a personal surface reads the PERSON's format: the same dates and
// numbers whichever business is open, the person's chosen format locale
// whatever that business's `regionalFormats` switch says, and the device's
// region when no business is open. A business screen keeps the business's
// rule, and one provider picks between the two from the route's layer.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/demo/data/personal_preferences_repository.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/money/presentation/screens/account_activity_screen.dart';
import 'package:deskilo/features/profile/domain/personal_preferences.dart';
import 'package:deskilo/features/profile/providers/personal_appearance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/me/me_app.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _at = DateTime.utc(2026, 9, 28, 10);

FakeAccountActivityRepository _history() =>
    FakeAccountActivityRepository()
      ..records[AccountActivityKind.invoices] = [
        AccountActivity(
          id: '1',
          workspaceId: 'ws-1',
          workspaceName: 'Office',
          occurredAt: _at,
          reference: 'INV-1',
          description: 'Desk use',
          currency: 'EUR',
          status: 'issued',
          amountCents: 123456,
        ),
      ];

/// One business, in [country] with [currency], open as the active one.
FakeWorkspaceRepository _business(
  String country,
  String currency, {
  Map<String, dynamic> flags = const {},
}) {
  final repo = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    countryCode: country,
    currencyCode: currency,
  );
  return repo;
}

/// Pumps Me › account history and returns its one row's text with the
/// container, then leaves the tree for the next pump.
Future<(String, ProviderContainer)> _row(
  WidgetTester tester, {
  required FakeWorkspaceRepository workspace,
  FakePersonalPreferencesRepository? preferences,
  Locale device = const Locale('en', 'US'),
}) async {
  await pumpApp(
    tester,
    // As in the app: the MaterialApp keeps the person's settings read (it
    // watches their language), and the screen rebuilds with their format.
    Consumer(
      builder: (context, ref, _) {
        ref.watch(personalLocaleProvider);
        final format = ref.watch(personalFormatProvider);
        return AccountActivityScreen(key: ValueKey(format.locale));
      },
    ),
    overrides: standardTestOverrides(
      pinFormats: false,
      auth: FakeAuthRepository.signedIn(),
      workspace: workspace,
      accountActivity: _history(),
      personalPreferences: preferences,
      deviceLocale: device,
    ),
  );
  await tester.pumpAndSettle();
  final row = find.descendant(
    of: find.byKey(const ValueKey('account-activity-1')),
    matching: find.byType(Text),
  );
  final text = tester.widgetList<Text>(row).map((t) => t.data).join(' | ');
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AccountActivityScreen)),
  );
  return (text, container);
}

String _expected(String locale) {
  final format = AppFormat(
    locale: locale,
    currencyCode: 'EUR',
    timeZoneMode: TimeZoneMode.device,
  );
  return '${format.dates(DateShape.date).format(format.wall(_at))} · '
      '${format.moneyNamed('EUR').formatMinor(123456)}';
}

void main() {
  testWidgets('the same Me screen reads the same with a French or an '
      'American business open', (tester) async {
    final (inFrance, a) = await _row(tester, workspace: _business('FR', 'EUR'));
    expect(
      a.read(businessFormatProvider).locale,
      'en_GB',
      reason: 'the French business reads English the British way',
    );
    await tester.pumpWidget(const SizedBox());

    final (inAmerica, b) = await _row(
      tester,
      workspace: _business('US', 'USD'),
    );
    expect(b.read(businessFormatProvider).locale, 'en_US');
    await tester.pumpWidget(const SizedBox());

    expect(inAmerica, inFrance);
    expect(
      inFrance,
      contains(_expected('en_US')),
      reason: 'an English app on a United States device reads en_US',
    );
  });

  testWidgets('the person\'s chosen format locale applies with the open '
      'business\'s regionalFormats off', (tester) async {
    final preferences = FakePersonalPreferencesRepository()
      ..defaults[PersonalPreference.formatLocale] = 'de_CH'
      ..defaults[PersonalPreference.clock] = '12h';
    final (text, container) = await _row(
      tester,
      workspace: _business(
        'FR',
        'EUR',
        flags: const {'regionalFormats': false},
      ),
      preferences: preferences,
    );
    expect(text, contains(_expected('de_CH')));
    final personal = container.read(personalFormatProvider);
    expect(personal.locale, 'de_CH');
    expect(personal.clock, ClockPref.h12);
    expect(
      container.read(businessFormatProvider).locale,
      'en_GB',
      reason: 'the business screens keep their rule: preferences off',
    );
  });

  testWidgets('a business\'s own exception does not reach a personal '
      'surface', (tester) async {
    final preferences = FakePersonalPreferencesRepository()
      ..overrides['ws-1'] = {PersonalPreference.formatLocale: 'fr_CH'};
    final (_, container) = await _row(
      tester,
      workspace: _business('FR', 'EUR'),
      preferences: preferences,
    );
    expect(container.read(businessFormatProvider).locale, 'fr_CH');
    expect(container.read(personalFormatProvider).locale, 'en_US');
  });

  testWidgets('no business open: the device\'s region', (tester) async {
    final (text, container) = await _row(
      tester,
      workspace: FakeWorkspaceRepository(),
      device: const Locale('fr', 'CA'),
    );
    expect(container.read(personalFormatProvider).locale, 'fr_CA');
    expect(container.read(businessFormatProvider).locale, 'fr_CA');
    expect(text, contains(_expected('fr_CA')));
  });

  testWidgets('one provider picks the format from the surface', (tester) async {
    final (_, container) = await _row(
      tester,
      workspace: _business('FR', 'EUR'),
    );
    final surface = container.read(formatSurfaceOfRouteProvider.notifier)
      ..set(FormatSurface.personal);
    expect(container.read(appFormatProvider).locale, 'en_US');
    surface.set(FormatSurface.business);
    expect(container.read(appFormatProvider).locale, 'en_GB');
  });

  testWidgets('the router sets the surface from the route\'s layer', (
    tester,
  ) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    await goTo(tester, router, '/reserve');
    expect(
      container.read(formatSurfaceOfRouteProvider),
      FormatSurface.business,
    );
    await goTo(tester, router, '/me');
    expect(
      container.read(formatSurfaceOfRouteProvider),
      FormatSurface.personal,
    );
    await goTo(tester, router, '/reserve');
    expect(
      container.read(formatSurfaceOfRouteProvider),
      FormatSurface.business,
    );
  });
}
