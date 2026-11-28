// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 (CS5) -- the cash drawer as a cashier uses it, at a phone and at a desk: a till is opened with its float (or by
// denomination), cash is paid out with a reason from the business's list, and the drawer is counted and closed. Counted
// blind, the expected cash is not shown before the count and a difference is closed with its reason once the server asks
// for it; someone who may see the finances sees the expected cash and the difference as they type.
import 'package:deskilo/core/demo/data/demo_till_drawer.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:deskilo/features/money/presentation/till_drawer/till_drawer_screen.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show cashValuesOf;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

const _blind = DrawerSettings(blindCount: true, byDenomination: false, paidOutLimitMinor: 0);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> _open(
  WidgetTester tester,
  DemoTillDrawer drawer,
  Size size, {
  DrawerSettings settings = _blind,
  String currency = 'EUR',
}) async {
  drawer.rules = () => settings;
  await pumpApp(
    tester,
    TillDrawerScreen(workspaceId: 'ws-1', currency: currency, canManage: true),
    size: size,
    overrides: [
      tillDrawerPortProvider.overrideWithValue(drawer),
      drawerSettingsProvider.overrideWith((ref) => settings),
    ],
  );
  await _settle(tester);
}

/// The drawer with the front counter already open on [float].
Future<DemoTillDrawer> _openedDrawer({int float = 10000, bool seesFinances = false}) async {
  final drawer = DemoTillDrawer()..canSeeFinances = () => seesFinances;
  await drawer.openSession('ws-1', requestId: 'seed', tillId: 'demo-till-front', floatMinor: float);
  return drawer;
}

void main() {
  _demoRefusesOutsideThePick();
  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    group('the till drawer at ${size.width.toInt()}', () {
      testWidgets('the tills are listed closed, and a till is opened with its float', (tester) async {
        final drawer = DemoTillDrawer();
        await _open(tester, drawer, size);
        expect(find.text('Front counter'), findsOneWidget);
        expect(find.byKey(const ValueKey('drawer-state-demo-till-front')), findsOneWidget);
        expect(find.text(_en.tillDrawerStateClosed), findsWidgets);
        await _tap(tester, 'drawer-open-demo-till-front');
        await _type(tester, 'drawer-float', '100');
        await _tap(tester, 'drawer-open-submit');
        expect(find.textContaining('100.00'), findsWidgets);
        expect(find.byKey(const ValueKey('drawer-close-demo-till-front')), findsOneWidget);
      });

      testWidgets('an open sheet without a float says so under the field', (tester) async {
        await _open(tester, DemoTillDrawer(), size);
        await _tap(tester, 'drawer-open-demo-till-front');
        await _tap(tester, 'drawer-open-submit');
        expect(find.text(_en.tillDrawerAmountInvalid), findsWidgets);
      });

      // #4511 -- the till's notes and coins are listed; only how many of each is entered
      testWidgets('by denomination the till\'s notes and coins are listed and add up to the float', (tester) async {
        const settings = DrawerSettings(blindCount: true, byDenomination: true, paidOutLimitMinor: 0);
        await _open(tester, DemoTillDrawer(), size, settings: settings);
        await _tap(tester, 'drawer-open-demo-till-front');
        final fifty = cashValuesOf('EUR').indexOf(5000);
        expect(find.byKey(const ValueKey('drawer-denom-add')), findsNothing, reason: 'no value is typed');
        expect(find.byKey(ValueKey('drawer-denom-count-${cashValuesOf('EUR').length - 1}')), findsOneWidget, reason: 'down to the cent');
        await _type(tester, 'drawer-denom-count-$fifty', '2');
        expect(find.text(_en.tillDrawerDenomTotal('€100.00')), findsOneWidget);
        await _tap(tester, 'drawer-open-submit');
        expect(find.byKey(const ValueKey('drawer-close-demo-till-front')), findsOneWidget);
      });

      testWidgets('a till that carries no cents lists none, and its pick is made in its sheet', (tester) async {
        const settings = DrawerSettings(blindCount: true, byDenomination: true, paidOutLimitMinor: 0);
        final drawer = DemoTillDrawer();
        await _open(tester, drawer, size, settings: settings);
        await _tap(tester, 'drawer-edit-demo-till-front');
        expect(find.byKey(const ValueKey('drawer-till-note-1')), findsOneWidget);
        await _tap(tester, 'drawer-till-note-1');
        await _tap(tester, 'drawer-till-note-2');
        await _tap(tester, 'drawer-till-save');
        final front = (await drawer.tills('ws-1')).firstWhere((t) => t.id == 'demo-till-front');
        expect(front.denominations, [for (final v in cashValuesOf('EUR')) if (v > 2) v]);
        await _tap(tester, 'drawer-open-demo-till-front');
        expect(find.byKey(ValueKey('drawer-denom-count-${cashValuesOf('EUR').length - 3}')), findsOneWidget);
        expect(find.byKey(ValueKey('drawer-denom-count-${cashValuesOf('EUR').length - 2}')), findsNothing, reason: 'no 1 and 2 cents');
      });

      testWidgets('a currency the reference does not list is counted with typed values, as before', (tester) async {
        const settings = DrawerSettings(blindCount: true, byDenomination: true, paidOutLimitMinor: 0);
        await _open(tester, DemoTillDrawer(currency: 'THB'), size, settings: settings, currency: 'THB');
        await _tap(tester, 'drawer-open-demo-till-front');
        await _type(tester, 'drawer-denom-value-0', '50');
        await _type(tester, 'drawer-denom-count-0', '2');
        await _tap(tester, 'drawer-open-submit');
        expect(find.byKey(const ValueKey('drawer-close-demo-till-front')), findsOneWidget);
      });

      testWidgets('cash paid out is recorded with a reason from the list', (tester) async {
        final drawer = await _openedDrawer(seesFinances: true);
        await _open(tester, drawer, size);
        await _tap(tester, 'drawer-entry-demo-till-front');
        await _tap(tester, 'drawer-entry-submit');
        expect(find.text(_en.tillDrawerEntryReasonMissing), findsOneWidget);
        await _type(tester, 'drawer-entry-amount', '5');
        await _tap(tester, 'drawer-entry-reason-expense');
        await _tap(tester, 'drawer-entry-submit');
        expect(find.text(_en.tillDrawerEntryDone), findsOneWidget);
        expect(find.textContaining('95.00'), findsWidgets);
      });

      testWidgets('a paid-in offers its own reasons, by name (#4514)', (tester) async {
        final drawer = await _openedDrawer(seesFinances: true);
        await _open(tester, drawer, size);
        await _tap(tester, 'drawer-entry-demo-till-front');
        expect(find.text(_en.tillCashReasonExpense), findsOneWidget);
        await _tap(tester, 'drawer-entry-reason-expense');
        await _tap(tester, 'drawer-entry-paid_in');
        expect(find.byKey(const ValueKey('drawer-entry-reason-expense')), findsNothing);
        expect(find.text(_en.tillCashReasonChange), findsOneWidget);
        await _type(tester, 'drawer-entry-amount', '5');
        await _tap(tester, 'drawer-entry-submit');
        expect(find.text(_en.tillDrawerEntryReasonMissing), findsOneWidget, reason: 'the paid-out reason was dropped with the kind');
        await _tap(tester, 'drawer-entry-reason-change');
        await _tap(tester, 'drawer-entry-submit');
        expect(find.text(_en.tillDrawerEntryDone), findsOneWidget);
      });

      testWidgets('counted blind, the expected cash is not shown before the count; a difference asks for its reason', (tester) async {
        final drawer = await _openedDrawer();
        await _open(tester, drawer, size);
        expect(find.text(_en.tillDrawerExpectedHidden), findsOneWidget);
        await _tap(tester, 'drawer-close-demo-till-front');
        expect(find.byKey(const ValueKey('drawer-close-expected')), findsNothing);
        await _type(tester, 'drawer-counted', '90');
        await _tap(tester, 'drawer-close-submit');
        expect(find.byKey(const ValueKey('drawer-close-reasons')), findsOneWidget);
        expect(find.text(_en.tillDrawerRefusalDifference), findsOneWidget);
        // #4514 -- the count-difference reasons, by name; not a paid-out one
        expect(find.byKey(const ValueKey('drawer-close-reason-expense')), findsNothing);
        await _tap(tester, 'drawer-close-reason-counting_error');
        await _tap(tester, 'drawer-close-submit');
        expect(find.byKey(const ValueKey('drawer-closed-counts')), findsOneWidget);
        expect(find.text(_en.tillDrawerClosedShort('€10.00')), findsOneWidget);
      });

      testWidgets('someone who may see the finances sees the expected cash and the difference while counting', (tester) async {
        final drawer = await _openedDrawer(seesFinances: true);
        await _open(tester, drawer, size);
        expect(find.byKey(const ValueKey('drawer-expected-demo-session-1')), findsOneWidget);
        await _tap(tester, 'drawer-close-demo-till-front');
        expect(find.byKey(const ValueKey('drawer-close-expected')), findsOneWidget);
        await _type(tester, 'drawer-counted', '100');
        expect(find.byKey(const ValueKey('drawer-close-reasons')), findsNothing);
        await _tap(tester, 'drawer-close-submit');
        expect(find.text(_en.tillDrawerClosedSame), findsOneWidget);
      });

      testWidgets('a banked amount above the counted cash is refused under its field', (tester) async {
        final drawer = await _openedDrawer(seesFinances: true);
        await _open(tester, drawer, size);
        await _tap(tester, 'drawer-close-demo-till-front');
        await _type(tester, 'drawer-counted', '100');
        await _type(tester, 'drawer-banked', '150');
        await _tap(tester, 'drawer-close-submit');
        expect(find.text(_en.tillDrawerBankedAbove), findsWidgets);
      });
    });
  }

  testWidgets('with no till yet, the manager is told to add one and the others to ask', (tester) async {
    final drawer = DemoTillDrawer(tills: const []);
    await pumpApp(
      tester,
      const TillDrawerScreen(workspaceId: 'ws-1', currency: 'EUR', canManage: true),
      overrides: [tillDrawerPortProvider.overrideWithValue(drawer), drawerSettingsProvider.overrideWith((ref) => _blind)],
    );
    await _settle(tester);
    expect(find.text(_en.tillDrawerNoTills), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-add-till')), findsOneWidget);
  });
}

// #4511 -- the Demo refuses what the server refuses: a value the till does not carry
void _demoRefusesOutsideThePick() {
  test('a float naming a coin the till does not carry is refused; a currency not listed takes any value', () async {
    final drawer = DemoTillDrawer();
    await drawer.setTillDenominations('ws-1', tillId: 'demo-till-front', values: const [5000, 1000]);
    await expectLater(
      drawer.openSession('ws-1', requestId: 'r1', tillId: 'demo-till-front', floatMinor: 5001, denominations: const Denominations({5000: 1, 1: 1})),
      throwsA(isA<Object>()),
    );
    expect(
      await drawer.openSession('ws-1', requestId: 'r2', tillId: 'demo-till-front', floatMinor: 6000, denominations: const Denominations({5000: 1, 1000: 1})),
      isNotNull,
    );
    await expectLater(drawer.setTillDenominations('ws-1', tillId: 'demo-till-front', values: const [300]), throwsA(isA<Object>()));
  });
}
