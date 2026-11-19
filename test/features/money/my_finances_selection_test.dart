// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — My finances: invoices of one business in one currency are
// selected; another business's cannot join and one line says why; "I have
// paid" records one declaration per month, each naming its invoices, after
// one confirmation; a refused payment leaves the selection as it was; a
// payment being processed is withdrawn after a confirmation that says what
// becomes of money still arriving; a received payment and a declared one
// show where they stand and offer nothing to select.
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
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

FinanceInvoice _invoice(
  String id, {
  String ws = 'ws-1',
  String name = 'Atelier',
  String currency = 'EUR',
  String period = '2026-10',
  int due = 12000,
  bool payable = true,
  bool inPayment = false,
  String? claimPaymentId,
  DateTime? handed,
  bool settling = false,
  bool received = false,
  int day = 2,
}) => FinanceInvoice(
  id: id,
  workspaceId: ws,
  workspaceName: name,
  number: 'N-$id',
  issuedAt: DateTime.utc(2026, 11, day),
  totalCents: due,
  paidCents: 0,
  currency: currency,
  state: FinanceState.open,
  stillDueCents: due,
  period: period,
  payable: payable,
  inPayment: inPayment,
  claimPaymentId: claimPaymentId,
  claimHandedAt: handed,
  claimSettling: settling,
  paymentReceived: received,
);

final _overview = FinanceOverview(
  invoices: [
    _invoice('a1'),
    _invoice('a2', period: '2026-11', due: 5900, day: 3),
    _invoice('b1', ws: 'ws-zurich', name: 'Limmat', currency: 'CHF', due: 8400),
    _invoice(
      'a3',
      payable: false,
      inPayment: true,
      claimPaymentId: 'order-7',
      handed: DateTime.utc(2026, 11, 10, 9),
      settling: true,
      day: 4,
    ),
    _invoice('a4', payable: false, received: true, day: 5),
    _invoice('a5', payable: false, inPayment: true, day: 6),
  ],
);

final _approved = <Uri>[];

final _groups = FakeInvoiceGroupRepository();

Future<FakeMoneyRepository> _show(
  WidgetTester tester, {
  bool enters = true,
  FakeAuthRepository? auth,
  void Function(String)? targetSeen,
  bool routed = false,
  String business = 'Atelier',
  bool admin = false,
  List<String>? opened,
  bool Function()? hostLost,
  bool openFails = false,
}) async {
  _approved.clear();
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final money = FakeMoneyRepository();
  final session = auth ?? FakeAuthRepository.signedIn();
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
        // the business is entered as the app enters it, or cannot be
        if (enters)
          financeWorkspaceEntryProvider.overrideWith((ref) {
            final principal = ref.watch(sessionStateProvider).value;
            return (target) async {
              targetSeen?.call(target.networkId);
              return FinanceCommandTarget(
                target: target,
                memberId: 'member-1',
                currency: 'EUR',
                commands: money.accountCommands,
                gateway: money.paymentGateway,
                isCurrent: () =>
                    ref.mounted &&
                    ref.read(sessionStateProvider).value == principal &&
                    !(hostLost?.call() ?? false),
                release: () {},
                // #4218 — who the business is, my right there, and entering it
                businessName: business,
                canAdminister: admin,
                open: () async {
                  opened?.add(target.financeKey);
                  return !openFails;
                },
              );
            };
          })
        else
          financeWorkspaceEntryProvider.overrideWithValue((_) async => null),
        // the provider's checkout opens; this test only sees that it did
        paymentApprovalProvider.overrideWithValue(
          (context, url) async => _approved.add(url),
        ),
      ],
      // opening an invoice navigates: that screen needs a router above it
      child: routed
          ? MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const MyFinancesScreen(),
                  ),
                  GoRoute(path: '/money', builder: (_, _) => const SizedBox()),
                  GoRoute(
                    path: '/payment-config',
                    builder: (_, _) => const Text('payment-config-page'),
                  ),
                ],
              ),
            )
          : const MaterialApp(
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
  await tester.tap(find.byKey(ValueKey('finances-select-$id')));
  await tester.pumpAndSettle();
}

String _summary(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('finances-selection-summary')))
    .data!;

void main() {
  testWidgets('a selection is of one business in one currency: another '
      'business cannot join, and one line says why', (tester) async {
    await _show(tester);
    expect(find.byKey(const ValueKey('finances-selection-bar')), findsNothing);
    await _select(tester, 'a1');
    expect(
      _summary(tester),
      allOf(startsWith('1 invoice selected · '), contains('120.00')),
    );
    expect(
      _box(tester, 'b1').onChanged,
      isNull,
      reason: 'another business, another currency',
    );
    expect(_box(tester, 'a2').onChanged, isNotNull);
    expect(
      find.text('A payment is for one business in one currency: Atelier.'),
      findsOneWidget,
    );
    await _select(tester, 'a2');
    expect(
      _summary(tester),
      allOf(startsWith('2 invoices selected · '), contains('179.00')),
    );
    expect(
      find.byKey(const ValueKey('finances-selection-pay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('finances-selection-declare')),
      findsOneWidget,
    );
  });

  testWidgets('"I have paid" across two months: one confirmation lists each '
      'month, then one declaration per month naming its invoices', (
    tester,
  ) async {
    final money = await _show(tester);
    await _select(tester, 'a1');
    await _select(tester, 'a2');
    await tester.tap(find.byKey(const ValueKey('finances-selection-declare')));
    await tester.pumpAndSettle();
    final months = [
      for (final k in ['finances-confirm-month-0', 'finances-confirm-month-1'])
        tester.widget<Text>(find.byKey(ValueKey(k))).data!,
    ];
    expect(months.first, allOf(startsWith('October 2026'), contains('120.00')));
    expect(months.last, allOf(startsWith('November 2026'), contains('59.00')));
    expect(
      money.recordedPayments,
      isEmpty,
      reason: 'nothing before the confirmation',
    );
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(money.recordedPayments.map((p) => (p.period, p.amountCents)), [
      ('2026-10', 12000),
      ('2026-11', 5900),
    ]);
    expect(money.claims.values, [
      ['a1'],
      ['a2'],
    ]);
    expect(find.text('Recorded. Atelier approves it.'), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-selection-bar')), findsNothing);
  });

  testWidgets(
    'a workspace switch during confirmation keeps the displayed target',
    (tester) async {
      final targets = <String>[];
      final money = await _show(tester, targetSeen: targets.add);
      await _select(tester, 'a1');
      await tester.tap(
        find.byKey(const ValueKey('finances-selection-declare')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyFinancesScreen)),
      );
      container.read(activeWorkspaceIdProvider.notifier).activate('ws-other');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(targets, ['11111111-1111-4111-8111-111111111111:ws-1']);
      expect(money.recordedPayments.single.amountCents, 12000);
    },
  );

  testWidgets('an account change during confirmation prevents the command', (
    tester,
  ) async {
    final auth = FakeAuthRepository.signedIn();
    final money = await _show(tester, auth: auth);
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-declare')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await auth.signOut();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(money.recordedPayments, isEmpty);
  });

  testWidgets('a refused declaration leaves the selection as it was and says '
      'why', (tester) async {
    final money = await _show(tester);
    money.accountCommands.refuseClaimWith = ClaimRefusal.alreadyInPayment;
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-declare')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'One of these invoices is already in another payment. Nothing was charged.',
      ),
      findsOneWidget,
    );
    expect(_box(tester, 'a1').value, isTrue, reason: 'the selection stays');
    expect(_summary(tester), startsWith('1 invoice selected'));
  });

  testWidgets('a payment being processed is withdrawn after its confirmation; '
      'a received and a declared payment show where they stand', (
    tester,
  ) async {
    final money = await _show(tester);
    money.claims['order-7'] = ['a3'];
    expect(find.byKey(const ValueKey('finances-select-a3')), findsNothing);
    expect(find.textContaining('In payment'), findsOneWidget);
    expect(
      find.text('Payment received · Atelier is matching it'),
      findsOneWidget,
    );
    expect(find.text('Declared paid · waits for Atelier'), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-select-a4')), findsNothing);
    expect(find.byKey(const ValueKey('finances-select-a5')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('finances-withdraw-a3')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Money that still arrives is credited to your account',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('finances-withdraw-yes')));
    await tester.pumpAndSettle();
    expect(money.withdrawnClaims, ['order-7']);
    expect(
      find.text('Payment withdrawn. Its invoices can be paid again.'),
      findsOneWidget,
    );
  });

  testWidgets('Pay across two months pays the oldest, says which follows, and '
      'leaves it selected: one provider checkout per tap', (tester) async {
    final money = await _show(tester);
    money
      ..paymentProviders = [PaymentProvider.stripe]
      ..paymentApprovalUrl = Uri.parse('https://checkout.example/session');
    await _select(tester, 'a1');
    await _select(tester, 'a2');
    await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
    await tester.pumpAndSettle();
    final then = tester
        .widget<Text>(find.byKey(const ValueKey('finances-pay-then')))
        .data!;
    expect(then, allOf(contains('November 2026'), contains('59.00')));
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(money.paymentOrders, [
      (PaymentProvider.stripe, 12000),
    ], reason: 'October only');
    expect(_approved, hasLength(1), reason: 'one checkout');
    expect(money.claims['order-1'], ['a1']);
    expect(_box(tester, 'a2').value, isTrue, reason: 'November stays selected');
    expect(_summary(tester), startsWith('1 invoice selected'));
  });

  testWidgets('a provider that cannot be reached leaves the selection as it '
      'was', (tester) async {
    final money = await _show(tester);
    money
      ..paymentProviders = [PaymentProvider.stripe]
      ..paymentGateway.unreachable = true;
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(money.paymentOrders, isEmpty);
    expect(money.claims, isEmpty);
    expect(_approved, isEmpty);
    expect(_box(tester, 'a1').value, isTrue, reason: 'the selection stays');
  });

  testWidgets('a selection is filed in one of my groups from the bar', (
    tester,
  ) async {
    await _show(tester);
    await _select(tester, 'a1');
    await _select(tester, 'a2');
    await tester.tap(find.byKey(const ValueKey('finances-selection-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-selection-group')));
    await tester.pumpAndSettle();
    expect(find.text('Groups of 2 invoices'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('invoice-group-new-name')),
      'Taxes 2026',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-group-create')));
    await tester.pumpAndSettle();
    final group = (await _groups.groups()).single;
    expect(group.items.map((i) => i.number), ['N-a1', 'N-a2']);
  });

  testWidgets('a Pay whose answer was lost is retried under the same request '
      'id, so the checkout comes back instead of a second payment', (
    tester,
  ) async {
    final money = await _show(tester);
    money
      ..paymentProviders = [PaymentProvider.stripe]
      ..paymentApprovalUrl = Uri.parse('https://checkout.example/session')
      ..paymentGateway.loseNextAnswer = true;
    await _select(tester, 'a1');
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
      await tester.pumpAndSettle();
    }
    final ids = money.paymentGateway.requestIds;
    expect(ids, hasLength(2));
    expect(ids.first, isNotNull);
    expect(ids.last, ids.first, reason: 'the retry is the same request');
    expect(_approved, hasLength(1), reason: 'one checkout, the second time');
  });

  testWidgets('a declaration refused at its second month says what was '
      'recorded and what was not, and keeps the rest selected', (tester) async {
    final money = await _show(tester);
    money.accountCommands
      ..refuseClaimWith = ClaimRefusal.alreadyInPayment
      ..refuseAfter = 1;
    await _select(tester, 'a1');
    await _select(tester, 'a2');
    await tester.tap(find.byKey(const ValueKey('finances-selection-declare')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(money.recordedPayments.map((p) => p.period), ['2026-10']);
    expect(
      find.textContaining(
        'Recorded: October 2026. Not recorded: November 2026.',
      ),
      findsOneWidget,
    );
    expect(_box(tester, 'a2').value, isTrue, reason: 'November stays selected');
  });

  testWidgets('a payment service older than the claim is not used for a '
      'selection, and one that drops the claim opens no checkout', (
    tester,
  ) async {
    final money = await _show(tester);
    money
      ..paymentProviders = [PaymentProvider.stripe]
      ..paymentApprovalUrl = Uri.parse('https://checkout.example/session')
      ..paymentGateway.takesClaims = false;
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('must be updated'),
      ),
      findsOneWidget,
    );
    expect(money.paymentOrders, isEmpty);

    money.paymentGateway
      ..takesClaims = true
      ..dropsClaim = true;
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('did not take these invoices'), findsOneWidget);
    expect(_approved, isEmpty, reason: 'no checkout opened');
  });

  testWidgets('a business that cannot be entered is said, nothing sent', (
    tester,
  ) async {
    final money = await _show(tester, enters: false);
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-declare')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Atelier cannot be reached or verified right now. Nothing was sent.',
      ),
      findsOneWidget,
    );
    expect(money.recordedPayments, isEmpty);
    // #4218 — and the person is offered to try again: the same action runs
    // again from its confirmation.
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-confirm-send')), findsOneWidget);
  });

  testWidgets('a Pay on a business that cannot be reached or verified says '
      'so and offers to try again', (tester) async {
    final money = await _show(tester, enters: false);
    money
      ..paymentProviders = [PaymentProvider.stripe]
      ..paymentApprovalUrl = Uri.parse('https://checkout.example/session');
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Atelier cannot be reached or verified right now. Nothing was sent.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(money.paymentOrders, isEmpty);
  });

  testWidgets('an administrator paying another business\'s selection sees '
      'THAT business named and its own configuration offered, entered first', (
    tester,
  ) async {
    final opened = <String>[];
    final money = await _show(
      tester,
      routed: true,
      business: 'Lyon',
      admin: true,
      opened: opened,
    );
    money
      ..paymentProviders = []
      ..paymentMissing = {
        'stripe': ['STRIPE_SECRET_KEY'],
      };
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(find.text('Business: Lyon'), findsOneWidget);
    expect(find.text('stripe: STRIPE_SECRET_KEY'), findsOneWidget);
    // the button names the business, and does not open the selected one's
    await tester.tap(find.byKey(const ValueKey('pay-config-open')));
    await tester.pumpAndSettle();
    expect(find.text('payment-config-page'), findsOneWidget);
    expect(
      opened,
      hasLength(1),
      reason: 'that business is entered (its host) before its configuration',
    );
    expect(opened.single, endsWith(':ws-1'));
  });

  testWidgets('a member who does not administer the business is told, not '
      'shown its configuration', (tester) async {
    final money = await _show(tester, business: 'Lyon');
    money
      ..paymentProviders = []
      ..paymentMissing = {
        'stripe': ['STRIPE_SECRET_KEY'],
      };
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-config-open')), findsNothing);
    expect(find.textContaining('set up yet'), findsOneWidget);
  });

  testWidgets('a declaration over two months interrupted after the first '
      'says what was recorded, never "nothing was sent", and Try again '
      'declares only what is still selected', (tester) async {
    var lost = true;
    late FakeMoneyRepository money;
    money = await _show(
      tester,
      hostLost: () => lost && money.recordedPayments.isNotEmpty,
    );
    await _select(tester, 'a1');
    await _select(tester, 'a2');
    await tester.tap(find.byKey(const ValueKey('finances-selection-declare')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(money.recordedPayments.map((p) => p.period), ['2026-10']);
    expect(
      find.text(
        'Recorded: October 2026. Not recorded: November 2026. '
        'Atelier cannot be reached or verified right now.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing was sent'), findsNothing);
    expect(_box(tester, 'a2').value, isTrue, reason: 'November stays selected');
    expect(_box(tester, 'a1').value, isFalse, reason: 'October left');
    // the host is back: Try again offers only the second month
    lost = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('November'), findsWidgets);
    expect(find.textContaining('October 2026'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    expect(money.recordedPayments.map((p) => p.period), [
      '2026-10',
      '2026-11',
    ], reason: 'October is not declared twice');
  });

  testWidgets('opening an invoice whose business cannot be entered says so '
      'and offers to try again, instead of doing nothing', (tester) async {
    await _show(tester, routed: true, openFails: true);
    await tester.ensureVisible(find.byKey(const ValueKey('finances-open-a1')));
    await tester.tap(find.byKey(const ValueKey('finances-open-a1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Atelier cannot be reached or verified right now.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Configure for a business that cannot be entered says so and '
      'offers to try again; its configuration does not open', (tester) async {
    final money = await _show(
      tester,
      routed: true,
      business: 'Lyon',
      admin: true,
      openFails: true,
    );
    money
      ..paymentProviders = []
      ..paymentMissing = {
        'stripe': ['STRIPE_SECRET_KEY'],
      };
    await _select(tester, 'a1');
    await tester.tap(find.byKey(const ValueKey('finances-selection-pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-confirm-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay-config-open')));
    await tester.pumpAndSettle();
    expect(find.text('payment-config-page'), findsNothing);
    expect(
      find.text('Lyon cannot be reached or verified right now.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('opening an invoice of a business that cannot be reached or '
      'verified says so, naming it, and offers to try again', (tester) async {
    await _show(tester, enters: false, routed: true);
    await tester.ensureVisible(find.byKey(const ValueKey('finances-open-a1')));
    await tester.tap(find.byKey(const ValueKey('finances-open-a1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Atelier cannot be reached or verified right now.'),
      findsOneWidget,
      reason: 'opening sends nothing, so the sentence does not say it',
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a payment says since when it is in payment, and withdrawing it '
      'just after the hand-over says to wait if it was just paid', (
    tester,
  ) async {
    await _show(tester);
    expect(find.textContaining('In payment since'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finances-withdraw-a3')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('If you have just paid at the provider, wait'),
      findsOneWidget,
    );
  });
}
