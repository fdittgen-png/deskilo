// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4514 (STK-10) -- the cash reasons on Master data: the built-in ones by the app's words, a business's own one added by
// its name and used where it was meant, an archived one no longer offered at the till, and the refusals said under
// their fields.
import 'package:deskilo/core/demo/data/demo_till_drawer.dart';
import 'package:deskilo/features/money/domain/cash_reason.dart';
import 'package:deskilo/features/money/presentation/till_drawer/cash_reasons_screen.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

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

Future<DemoTillDrawer> _open(WidgetTester tester, Size size) async {
  final drawer = DemoTillDrawer();
  await pumpApp(
    tester,
    const CashReasonsScreen(workspaceId: 'ws-1'),
    size: size,
    overrides: [tillDrawerPortProvider.overrideWithValue(drawer)],
  );
  await _settle(tester);
  return drawer;
}

void main() {
  for (final (label, size) in const [
    ('phone', Size(390, 844)),
    ('desk', Size(1280, 900)),
  ]) {
    group('at a $label', () {
      testWidgets(
        'the built-in reasons are listed by the app\'s words, with what they are used for',
        (tester) async {
          await _open(tester, size);
          expect(find.text(_en.tillCashReasonChange), findsOneWidget);
          expect(find.text(_en.tillCashReasonCountingError), findsOneWidget);
          expect(
            find.text(
              '${_en.tillDrawerEntryPaidIn}, ${_en.tillDrawerEntryPaidOut}',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'a reason of the business is added by its name and offered where it is used',
        (tester) async {
          final drawer = await _open(tester, size);
          await _tap(tester, 'cash-reason-add');
          await _tap(tester, 'cash-reason-save');
          expect(find.text(_en.cashReasonsNameMissing), findsOneWidget);
          expect(find.text(_en.cashReasonsProcessMissing), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('cash-reason-name')),
            'Tips & gifts',
          );
          await _tap(tester, 'cash-reason-use-paid_in');
          await _tap(tester, 'cash-reason-save');
          expect(find.text(_en.cashReasonsSaved), findsOneWidget);
          expect(
            find.byKey(const ValueKey('cash-reason-tips_gifts')),
            findsOneWidget,
          );
          final offered = cashReasonsFor(
            await drawer.cashReasons('ws-1'),
            CashReasonProcess.paidIn,
          );
          expect(offered.map((r) => r.code), contains('tips_gifts'));
          expect(
            cashReasonsFor(
              await drawer.cashReasons('ws-1'),
              CashReasonProcess.paidOut,
            ).map((r) => r.code),
            isNot(contains('tips_gifts')),
          );
        },
      );

      testWidgets(
        'an archived reason is marked and no longer offered; a built-in one keeps the app\'s words',
        (tester) async {
          final drawer = await _open(tester, size);
          await _tap(tester, 'cash-reason-expense');
          expect(
            find.byKey(const ValueKey('cash-reason-builtin')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('cash-reason-name')), findsNothing);
          await _tap(tester, 'cash-reason-archived');
          await _tap(tester, 'cash-reason-save');
          expect(
            find.text(
              _en.cashReasonsArchivedName(_en.tillCashReasonExpense),
            ),
            findsOneWidget,
          );
          expect(
            cashReasonsFor(
              await drawer.cashReasons('ws-1'),
              CashReasonProcess.paidOut,
            ).map((r) => r.code),
            isNot(contains('expense')),
          );
        },
      );
    });
  }

  test('the Demo refuses what the server refuses: an unknown or archived reason, a reason of another process', () async {
    final drawer = DemoTillDrawer();
    await expectLater(
      drawer.saveCashReason('ws-1', name: 'x', processes: const {}),
      throwsA(anything),
    );
    await expectLater(
      drawer.saveCashReason(
        'ws-1',
        code: 'nope',
        name: 'x',
        processes: const {CashReasonProcess.paidIn},
      ),
      throwsA(anything),
    );
    final made = await drawer.saveCashReason(
      'ws-1',
      name: 'Pourboires',
      processes: const {CashReasonProcess.paidIn},
    );
    expect(made.code, 'pourboires');
    expect(
      (await drawer.saveCashReason(
        'ws-1',
        name: 'Pourboires',
        processes: const {CashReasonProcess.paidIn},
      )).code,
      'pourboires_2',
    );
  });

  test('a code is made from a name as the server makes it', () {
    expect(cashReasonCodeOf('Tips & gifts'), 'tips_gifts');
    expect(cashReasonCodeOf('  '), 'reason');
    expect(cashReasonCodeOf('Café'), 'caf');
  });
}
