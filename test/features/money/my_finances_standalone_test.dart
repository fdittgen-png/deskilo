// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (B2) -- My finances with invoices without a month, on a phone (390)
// and a desktop window (1440): they are selected apart from the monthly
// invoice (one line says why it does not join), "I have paid" is ONE
// declaration of their total, Pay opens one checkout under one request id
// that a retry after a lost answer reuses, the server's refusal of a mix is
// said in its own words and keeps the selection, and a payment function that
// does not take them is said before anything is sent.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/demo/data/invoice_group_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/money/application/finance_selection_commands.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/features/money/providers/finance_selection_provider.dart';
import 'package:deskilo/features/money/providers/payment_approval_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// An invoice of ONE business, [period] null for one without a month.
FinanceInvoice _invoice(
  String id, {
  String? period,
  int due = 12000,
  int day = 2,
  String subject = 'member-1',
}) => FinanceInvoice(
  id: id,
  workspaceId: 'ws-1',
  workspaceName: 'Atelier',
  number: 'N-$id',
  issuedAt: DateTime.utc(2026, 11, day),
  totalCents: due,
  paidCents: 0,
  currency: 'EUR',
  state: FinanceState.open,
  stillDueCents: due,
  period: period,
  payable: true,
  financialSubjectId: subject,
);

final _overview = FinanceOverview(
  invoices: [
    _invoice('s1'),
    _invoice('s2', due: 4500, day: 9),
    _invoice('m1', period: '2026-10', due: 8000, day: 3),
  ],
);

final _groups = FakeInvoiceGroupRepository();

final _approved = <Uri>[];

Future<FakeMoneyRepository> _show(WidgetTester tester, Size size) async {
  _approved.clear();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final money = FakeMoneyRepository()
    ..paymentProviders = [PaymentProvider.stripe]
    ..paymentApprovalUrl = Uri.parse('https://checkout.example/session');
  final session = FakeAuthRepository.signedIn();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          auth: session,
          accountActivity: FakeAccountActivityRepository()
            ..financeOverview = _overview,
          money: money,
          invoiceGroups: _groups,
          homeInstallation: '11111111-1111-4111-8111-111111111111',
        ),
        sessionSourceProvider.overrideWithValue(session),
        financeWorkspaceEntryProvider.overrideWith((ref) {
          final principal = ref.watch(sessionStateProvider).value;
          return (target) async => FinanceCommandTarget(
            target: target,
            memberId: 'member-1',
            currency: 'EUR',
            commands: money.accountCommands,
            gateway: money.paymentGateway,
            isCurrent: () =>
                ref.mounted && ref.read(sessionStateProvider).value == principal,
            release: () {},
            businessName: 'Atelier',
            open: () async => true,
          );
        }),
        paymentApprovalProvider.overrideWithValue(
          (context, url) async => _approved.add(url),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyFinancesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return money;
}

Checkbox _box(WidgetTester tester, String id) =>
    tester.widget<Checkbox>(find.byKey(ValueKey('finances-select-$id')));

Future<void> _select(WidgetTester tester, String id) async {
  // on a phone the list runs below the fold
  final box = find.byKey(ValueKey('finances-select-$id'));
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

const _sizes = <String, Size>{
  '390': Size(390, 844),
  '1440': Size(1440, 900),
};

void main() {
  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    group('at $name', () {
      testWidgets('invoices without a month are selected apart from the '
          'monthly one, and one line says why', (tester) async {
        await _show(tester, size);
        await _select(tester, 's1');
        expect(_box(tester, 'm1').onChanged, isNull,
            reason: 'a monthly invoice does not join');
        expect(_box(tester, 's2').onChanged, isNotNull);
        expect(
          find.text('Invoices without a month are paid together, apart from '
              'monthly invoices.'),
          findsOneWidget,
        );
        await _select(tester, 's2');
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('finances-selection-summary'))).data,
          allOf(startsWith('2 invoices selected'), contains('165.00')),
        );
        // a selection of the monthly invoice alone refuses the others instead
        await _tap(tester, 'finances-selection-clear');
        await _select(tester, 'm1');
        expect(_box(tester, 's1').onChanged, isNull);
        expect(
          find.text('Monthly invoices are paid with their month, apart from '
              'invoices without one.'),
          findsOneWidget,
        );
      });

      testWidgets('"I have paid" is ONE declaration of their total, after one '
          'confirmation without a month', (tester) async {
        final money = await _show(tester, size);
        await _select(tester, 's1');
        await _select(tester, 's2');
        await _tap(tester, 'finances-selection-declare');
        expect(find.byKey(const ValueKey('finances-confirm-month-0')), findsNothing);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('finances-confirm-standalone-total'))).data,
          contains('165.00'),
        );
        expect(money.recordedPayments, isEmpty, reason: 'nothing before the confirmation');
        await _tap(tester, 'finances-confirm-send');
        expect(
          money.recordedPayments.map((p) => (p.period, p.amountCents)),
          [(null, 16500)],
        );
        expect(money.claims.values.single, unorderedEquals(['s1', 's2']));
        expect(find.text('Recorded. Atelier approves it.'), findsOneWidget);
        expect(find.byKey(const ValueKey('finances-selection-bar')), findsNothing);
      });

      testWidgets('Pay opens one checkout of the total under one request id, '
          'and the selection is spent', (tester) async {
        final money = await _show(tester, size);
        await _select(tester, 's1');
        await _select(tester, 's2');
        await _tap(tester, 'finances-selection-pay');
        await _tap(tester, 'finances-confirm-send');
        expect(_approved, hasLength(1));
        expect(money.paymentGateway.requestIds, hasLength(1));
        expect(money.paymentGateway.requestIds.single, isNotNull);
        expect(find.byKey(const ValueKey('finances-selection-bar')), findsNothing);
      });

      for (final (refusal, words) in [
        (
          ClaimRefusal.monthlyInStandalone,
          'Monthly invoices are paid with their month, apart from invoices '
              'without one. Nothing was charged.',
        ),
        (
          ClaimRefusal.standaloneInMonthly,
          'An invoice without a month is paid on its own, apart from monthly '
              'invoices. Nothing was charged.',
        ),
      ]) {
        testWidgets('a refusal of the server (${refusal.code}) is said in its '
            'words and keeps the selection', (tester) async {
          final money = await _show(tester, size);
          money.accountCommands.refuseClaimWith = refusal;
          await _select(tester, 's1');
          await _tap(tester, 'finances-selection-declare');
          await _tap(tester, 'finances-confirm-send');
          expect(find.text(words), findsOneWidget);
          expect(money.recordedPayments, isEmpty);
          expect(_box(tester, 's1').value, isTrue, reason: 'still selected');
        });
      }

      testWidgets('a Pay whose answer was lost is the same request when tried '
          'again: one checkout, never a second payment', (tester) async {
        final money = await _show(tester, size);
        money.paymentGateway.loseNextAnswer = true;
        await _select(tester, 's1');
        await _select(tester, 's2');
        for (var i = 0; i < 2; i++) {
          await _tap(tester, 'finances-selection-pay');
          await _tap(tester, 'finances-confirm-send');
        }
        final ids = money.paymentGateway.requestIds;
        expect(ids, hasLength(2));
        expect(ids.last, ids.first, reason: 'the retry is the same request');
        expect(_approved, hasLength(1), reason: 'one checkout, the second time');
      });

      testWidgets('a payment function that does not take them is said before '
          'anything is sent', (tester) async {
        final money = await _show(tester, size);
        money.paymentGateway.takesStandalone = false;
        await _select(tester, 's1');
        await _tap(tester, 'finances-selection-pay');
        await _tap(tester, 'finances-confirm-send');
        expect(
          find.text("This business's payment service must be updated before "
              'invoices without a month can be paid online.'),
          findsOneWidget,
        );
        expect(_approved, isEmpty);
        expect(money.paymentGateway.requestIds, isEmpty);
      });
    });
  }
}
