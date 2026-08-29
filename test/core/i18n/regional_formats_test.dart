// SPDX-License-Identifier: 0BSD
//
// #711 — the surfaces of globalization: the member's Region & formats
// section, the owner's currency and time-zone pickers, and the bank
// details a non-IBAN country needs on the how-to-pay card.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/features/money/presentation/widgets/bill_view.dart';
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<({FakeProfileRepository profile, FakeWorkspaceRepository workspace})>
    pumpSettings(WidgetTester tester, {Map<String, dynamic> flags = const {}}) async {
  final profile = FakeProfileRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(
      profile: profile,
      workspace: workspace,
      floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
    ),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  await tapAppBarIcon(tester, Icons.settings_outlined);
  return (profile: profile, workspace: workspace);
}

void main() {
  testWidgets('Region & formats saves to the PROFILE and previews live',
      (tester) async {
    final r = await pumpSettings(tester);
    final tile = find.byKey(const ValueKey('regional-formats'));
    await tester.scrollUntilVisible(tile, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey('regional-sheet-preview'));
    expect(preview, findsOneWidget);

    // 12-hour clock: the preview flips, and the profile carries it.
    await tester.ensureVisible(find.text('12h'));
    await tester.tap(find.text('12h'));
    await tester.pumpAndSettle();
    expect(r.profile.formatPrefs.clock, ClockPref.h12);
    expect(tester.widget<Text>(preview).data, anyOf(contains('AM'), contains('PM')));

    // Device zone: stored, not merely toggled.
    await tester.ensureVisible(find.byKey(const ValueKey('regional-device-zone')));
    await tester.tap(find.byKey(const ValueKey('regional-device-zone')));
    await tester.pumpAndSettle();
    expect(r.profile.formatPrefs.timeZoneMode, TimeZoneMode.device);
  });

  testWidgets('#734 — the format picker is a list with a check mark, full '
      'width, and the choice lands in the profile', (tester) async {
    final r = await pumpSettings(tester);
    final tile = find.byKey(const ValueKey('regional-formats'));
    await tester.scrollUntilVisible(tile, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // A screen with its own app bar — nothing under the status bar.
    expect(find.widgetWithText(AppBar, 'Region & formats'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('regional-locale')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('regional-locale-option-auto')),
        findsOneWidget);
    final tag = kFormatLocales.first;
    await tester.tap(find.byKey(ValueKey('regional-locale-option-$tag')));
    await tester.pumpAndSettle();
    expect(r.profile.formatPrefs.formatLocale, tag);
  });

  testWidgets('the section is gone when the owner turned the feature off',
      (tester) async {
    await pumpSettings(tester, flags: const {'regionalFormats': false});
    expect(find.byKey(const ValueKey('regional-formats')), findsNothing);
  });

  group('the how-to-pay card names the routing code the local way', () {
    Widget card(String country, PaymentInstructions instructions) {
      final workspace = FakeWorkspaceRepository.withWorkspace();
      workspace.workspaces[0] =
          workspace.workspaces[0].copyWith(countryCode: country);
      return ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: MaterialApp(
          home: Scaffold(
            body: HowToPayCard(instructions: instructions),
          ),
        ),
      );
    }

    testWidgets('sort code in London, routing number in New York',
        (tester) async {
      const bank = PaymentInstructions(
        accountNumber: '12345678',
        bankCode: '40-00-01',
        bankName: 'Barclays',
      );
      await tester.pumpWidget(card('GB', bank));
      await tester.pumpAndSettle();
      expect(find.text('Sort code'), findsOneWidget);
      expect(find.text('Barclays'), findsOneWidget);

      await tester.pumpWidget(card('US', bank));
      await tester.pumpAndSettle();
      expect(find.text('Routing number'), findsOneWidget);
    });

    test('the catalogue knows every scheme it names', () {
      expect(CountryCatalog.byCode('GB').scheme, BankingScheme.uk);
      expect(CountryCatalog.byCode('US').scheme, BankingScheme.us);
      expect(CountryCatalog.byCode('CA').scheme, BankingScheme.ca);
      expect(CountryCatalog.byCode('FR').scheme, BankingScheme.sepa);
    });
  });
}
