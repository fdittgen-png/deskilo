// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the pricing step of the setup guide. The level chips are
// prefilled from the stored levels and the bands are listed as stored;
// the preview prices each offered level from its band (monthly fee, an
// extra half-day, an extra day) and follows the chips before anything is
// saved; offering stores exactly the chosen presets beside the owner's
// own levels. One column on a phone.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

Future<void> _pump(WidgetTester tester, FakeMoneyRepository money) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'pricing', runPages: setupRunPages),
    size: _phone,
    overrides: standardTestOverrides(money: money),
  );
  await tester.pumpAndSettle();
}

/// The fixture's bands: (0,25] free + €15 a half-day, (25,50] €150 +
/// €8, (50,100] €250 + nothing; 50 % and 100 % offered, 80 % the owner's.
FakeMoneyRepository _money() => FakeMoneyRepository()
  ..subscriptionLevels = const SubscriptionLevels(
    enabledPresets: [50, 100],
    extraLevels: [80],
  );

bool _chip(WidgetTester tester, int preset) => tester
    .widget<FilterChip>(find.byKey(ValueKey('setup-pricing-level-$preset')))
    .selected;

String _terms(WidgetTester tester, int pct) {
  final tile = tester.widget<ListTile>(
    find.byKey(ValueKey('setup-pricing-price-$pct')),
  );
  return (tile.subtitle! as Text).data!;
}

void main() {
  testWidgets('prefilled from the stored levels and bands, each offered '
      'level priced from its band', (tester) async {
    await _pump(tester, _money());
    expect(
      [
        for (final p in [25, 50, 75, 100]) _chip(tester, p),
      ],
      [false, true, false, true],
    );
    expect(find.byKey(const ValueKey('setup-pricing-band-50')), findsOneWidget);
    expect(
      _terms(tester, 50),
      '€150.00 a month\nAn extra half-day €8.00 · an extra day €16.00',
    );
    expect(_terms(tester, 80), startsWith('€250.00 a month'));
    expect(find.byKey(const ValueKey('setup-pricing-price-25')), findsNothing);
  });

  testWidgets('a chip joins the preview before saving, and offering stores '
      'the chosen presets beside the owner\'s own level', (tester) async {
    final money = _money();
    await _pump(tester, money);
    await tester.tap(find.byKey(const ValueKey('setup-pricing-level-25')));
    await tester.pump();
    expect(
      _terms(tester, 25),
      '€0.00 a month\nAn extra half-day €15.00 · an extra day €30.00',
    );
    expect(money.subscriptionLevels.enabledPresets, [50, 100]);

    await tester.tap(find.byKey(const ValueKey('setup-pricing-offer')));
    await tester.pumpAndSettle();
    expect(money.subscriptionLevels.enabledPresets, [25, 50, 100]);
    expect(money.subscriptionLevels.extraLevels, [80]);
  });

  testWidgets('no level offered: the preview says members cannot choose', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeMoneyRepository()
        ..subscriptionLevels = const SubscriptionLevels(enabledPresets: []),
    );
    expect(
      find.byKey(const ValueKey('setup-pricing-preview-none')),
      findsOneWidget,
    );
  });

  testWidgets('one column on a phone', (tester) async {
    await _pump(tester, _money());
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
