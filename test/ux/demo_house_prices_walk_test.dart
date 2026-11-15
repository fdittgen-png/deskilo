// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — the Demo performs a house's first task. Ada adds the Demo's house
// abroad (Kraków, in złoty) and lands on its home. The card says what comes
// before its first sale: Poland's tax rates first, then its prices, waiting
// for the rates. Once the rates are set, she names a price for every service
// and package (empty, since the currency differs) and activates each, with
// the rate the head's category proposes. The card closes itself, and "Done"
// ends the task.
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;
import '../helpers/settings_sections.dart';
import '../helpers/shell_bar.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) =>
    _tap(tester, find.byKey(ValueKey(key)));

void main() {
  testWidgets('Ada names the prices of the Demo\'s new house', (tester) async {
    final journey = await pumpDemo(tester, openHub: false);
    final f = journey.fixture;

    await tapShellBarControl(tester, 'shell-settings-button');
    await tester.pumpAndSettle();
    await showWorkspaceSettings(tester);
    await revealInSettings(tester, find.text('Workspace'));
    await _tap(tester, find.text('Workspace'));
    await _tapKey(tester, 'workspace-settings-organisation');
    await _tapKey(tester, 'organisation-add-house');
    await tester.enterText(
      find.byKey(const ValueKey('house-add-name')),
      'Atelier Kraków',
    );
    await _tapKey(tester, 'house-add-submit');
    await _tapKey(tester, 'house-birth-ok');

    // The house's home: its first task, the prices waiting for the rates.
    expect(find.byKey(const ValueKey('house-prices-card')), findsOneWidget);
    final name = find.byKey(const ValueKey('house-prices-name'));
    expect(tester.widget<ListTile>(name).enabled, isFalse);

    // Poland's rate, as the tax step sets it.
    await f.house.money.taxReporting.setVatRates(demoHouseSpaceId, const [
      VatRate(label: '23 %', percent: 23, isDefault: true),
    ]);
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .invalidate(vatRatesProvider);
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(name).enabled, isTrue);
    await _tap(tester, name);

    final terms = f.house.money.commercialTerms;
    final rows = [
      ...await terms.fetchServices(demoHouseSpaceId, includeInactive: true),
    ];
    final packages = await terms.fetchPackages(
      demoHouseSpaceId,
      includeInactive: true,
    );
    for (final id in [
      for (final r in rows) r.id,
      for (final p in packages) p.id,
    ]) {
      final price = find.descendant(
        of: find.byKey(ValueKey('house-price-$id')),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(price);
      await tester.enterText(price, '40');
      await _tapKey(tester, 'house-activate-$id');
    }

    final named = await terms.fetchServices(
      demoHouseSpaceId,
      includeInactive: true,
    );
    expect(named.every((s) => s.active && s.priceCents == 4000), isTrue);
    expect(
      named.every((s) => s.vatRateId.isNotEmpty),
      isTrue,
      reason: 'the rate the head\'s category proposes',
    );

    await _tapKey(tester, 'house-prices-done');
    expect(find.byKey(const ValueKey('house-prices-card')), findsNothing);
  });
}
