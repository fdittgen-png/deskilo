// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Owner online-payments configuration (0047): enter provider credentials
// from the app; secrets go to the deny-all table via an owner RPC and are
// never read back.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/money/demo_settlement_reviews.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/settlement_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpConfig(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  SettlementReviews? reviews,
}) async {
  money ??= FakeMoneyRepository();
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        // /payment-config is gated on the onlinePayments feature (default-off)
        // since the admin-menu feature-gating refactor.
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'onlinePayments': true},
        ),
        money: money,
        settlementReviews: reviews,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/payment-config'));
  await tester.pumpAndSettle();
  return money;
}

void main() {
  testWidgets(
      'with onlinePayments OFF the /payment-config deep link bounces to /plan',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        // Owner, but the feature is off → the route guard must redirect even
        // though the menu tile is already hidden (dual-layer gating).
        overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: const {'onlinePayments': false},
          ),
          money: FakeMoneyRepository(),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/payment-config'));
    await tester.pumpAndSettle();

    // Bounced away — the config screen never mounts.
    expect(find.text('Online payments'), findsNothing);
    expect(find.byKey(const ValueKey('pay-config-paypal')), findsNothing);
  });

  testWidgets('the three providers render, each with a not-configured chip',
      (tester) async {
    await pumpConfig(tester);

    expect(find.text('Online payments'), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-config-paypal')), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-config-stripe')), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-config-mollie')), findsOneWidget);
    // Wero (offered through Mollie) is its own provider card (0048).
    expect(find.byKey(const ValueKey('pay-config-wero')), findsOneWidget);
    expect(find.text('Wero (via Mollie)'), findsOneWidget);
    expect(find.text('Not configured'), findsNWidgets(4));
  });

  testWidgets('entering PayPal credentials saves the config (secrets go to '
      'the RPC, blanks omitted)', (tester) async {
    final money = await pumpConfig(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pay-field-paypal-client_id')),
      'AY-client',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pay-field-paypal-secret')),
      'EL-secret',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pay-field-paypal-return_url')),
      'https://deskilo.app/paid',
    );
    await tester.tap(find.byKey(const ValueKey('pay-save-paypal')));
    await tester.pumpAndSettle();

    final saved = money.savedPaymentConfigs.single;
    expect(saved.$1, PaymentProvider.paypal);
    expect(saved.$2, {
      'client_id': 'AY-client',
      'secret': 'EL-secret',
      // env defaults to the dropdown's first option (sandbox).
      'env': 'sandbox',
      'return_url': 'https://deskilo.app/paid',
    });
    // webhook_id was left blank → omitted (blank means "keep").
    expect(saved.$2.containsKey('webhook_id'), isFalse);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('a configured provider shows its chip, a set-secret hint, and '
      'a Remove action', (tester) async {
    final money = FakeMoneyRepository()
      ..paymentStatus[PaymentProvider.stripe] = const PaymentProviderStatus(
        configured: true,
        publicFields: {'return_url': 'https://deskilo.app/paid'},
        secretKeysSet: {'secret_key'},
      );
    await pumpConfig(tester, money: money);

    expect(find.text('Configured'), findsOneWidget);
    // The return URL is echoed back into the field.
    expect(find.text('https://deskilo.app/paid'), findsOneWidget);
    // The set secret is flagged, never shown.
    expect(find.text('Set — leave blank to keep'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(money.clearedProviders, [PaymentProvider.stripe]);
  });

  testWidgets('#3504 only a configured Mollie offers "Fetch payouts", and it '
      'reports how many settlements were recorded', (tester) async {
    final money = FakeMoneyRepository()
      ..paymentStatus[PaymentProvider.mollie] = const PaymentProviderStatus(
        configured: true,
        secretKeysSet: {'api_key'},
      )
      ..paymentStatus[PaymentProvider.stripe] = const PaymentProviderStatus(
        configured: true,
        secretKeysSet: {'secret_key'},
      );
    await pumpConfig(tester, money: money);

    expect(
      find.byKey(const ValueKey('payment-fetch-settlements')),
      findsOneWidget,
      reason: 'Mollie only: the others report fees on the payment itself',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('payment-fetch-settlements')),
    );
    await tester.tap(find.byKey(const ValueKey('payment-fetch-settlements')));
    await tester.pumpAndSettle();
    expect(find.text('1 payouts recorded'), findsOneWidget);
  });

  testWidgets('#3510 the settlement reports waiting for review are listed '
      'with why, without a fetch; one is marked handled with a note and '
      'stays readable', (tester) async {
    final reviews = DemoSettlementReviews();
    final money = FakeMoneyRepository()
      ..paymentStatus[PaymentProvider.mollie] = const PaymentProviderStatus(
        configured: true,
        secretKeysSet: {'api_key'},
      );
    await pumpConfig(tester, money: money, reviews: reviews);
    expect(find.text('Settlement reports to review'), findsOneWidget);
    const why = 'stl_demo_0426: the provider changed its costs after it was '
        'recorded. Nothing of the new report was booked.';
    expect(find.text(why), findsOneWidget);
    final handle = find.byKey(const ValueKey('settlement-review-handle-review-demo-1'));
    await tester.ensureVisible(handle);
    await tester.tap(handle);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final confirm = find.byKey(const ValueKey('settlement-review-handle-confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull,
        reason: 'no hand-off without a note');
    await tester.enterText(
      find.byKey(const ValueKey('settlement-review-note')),
      'Mollie corrected a fee; booked through a correction',
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(reviews.reviews.single.handled, isTrue);
    expect(find.text('Settlement reports to review'), findsNothing);
    expect(find.text('Handled'), findsOneWidget);
    expect(
      find.text('$why Handled: Mollie corrected a fee; booked through a correction'),
      findsOneWidget,
    );
  });

  testWidgets('#3510 a failed read of the reviews is said, with Try again', (
    tester,
  ) async {
    final reviews = _FailingReviews();
    final money = FakeMoneyRepository()
      ..paymentStatus[PaymentProvider.mollie] = const PaymentProviderStatus(
        configured: true,
        secretKeysSet: {'api_key'},
      );
    await pumpConfig(tester, money: money, reviews: reviews);
    expect(find.byKey(const ValueKey('settlement-reviews-unreadable')), findsOneWidget);
    reviews.fail = false;
    final retry = find.byKey(const ValueKey('settlement-reviews-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('settlement-reviews-unreadable')), findsNothing);
    expect(find.text('Settlement reports to review'), findsOneWidget);
  });
}

/// The Demo's review, behind a read that fails until told otherwise.
class _FailingReviews extends DemoSettlementReviews {
  bool fail = true;

  @override
  Future<List<SettlementReview>> fetchSettlementReviews(String workspaceId) async {
    if (fail) throw Exception('offline');
    return super.fetchSettlementReviews(workspaceId);
  }
}
