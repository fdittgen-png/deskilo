// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the pricing step of the setup guide. The level chips are
// prefilled from the stored levels and the bands are listed as stored;
// the preview prices each offered level from its band (monthly fee, an
// extra half-day, an extra day) and follows the chips before anything is
// saved; offering stores exactly the chosen presets beside the owner's
// own levels. One column on a phone.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/features/money/domain/member_price_list.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

Future<void> _pump(
  WidgetTester tester,
  FakeMoneyRepository money, {
  Future<int> Function()? openDays,
}) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'pricing', runPages: setupRunPages),
    size: _phone,
    overrides: [
      ...standardTestOverrides(money: money),
      monthOpenDaysProvider.overrideWith((_) => (openDays ?? () async => 21)()),
    ],
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

  // #3283 — a level is explained on this workspace's own month: the
  // half-days each includes for its open days, never a universal rule.
  testWidgets('each level says how many half-days it includes this month', (
    tester,
  ) async {
    await _pump(tester, _money());
    expect(find.byKey(const ValueKey('setup-pricing-basis')), findsOneWidget);
    expect(find.textContaining('open 21 days'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('setup-pricing-includes-50')))
          .data,
      endsWith(': 21 half-days included'),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('setup-pricing-includes-25')))
          .data,
      endsWith(': 11 half-days included'),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('setup-pricing-includes-100')),
          )
          .data,
      endsWith(': 42 half-days included'),
    );
  });

  testWidgets('unread opening days say so instead of an example', (
    tester,
  ) async {
    await _pump(
      tester,
      _money(),
      openDays: () async => throw StateError('offline'),
    );
    expect(
      find.byKey(const ValueKey('setup-pricing-basis-unknown')),
      findsOneWidget,
    );
    expect(find.textContaining('half-days included'), findsNothing);
  });

  test('the entitlement rule and the open days of a month', () {
    expect(includedHalfDays(21, 50), 21);
    expect(includedHalfDays(21, 25), 11, reason: 'rounded up');
    expect(includedHalfDays(0, 100), 0);
    // May 2026: 21 weekdays, Ascension (14 May) closed.
    expect(
      openDaysIn(DateTime(2026, 5), [1, 2, 3, 4, 5], [DateTime(2026, 5, 14)]),
      20,
    );
    expect(openDaysIn(DateTime(2026, 5), [6], const []), 5);
  });

  testWidgets('one column on a phone', (tester) async {
    await _pump(tester, _money());
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
