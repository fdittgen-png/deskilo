// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Owner online-payments configuration (0047): enter provider credentials
// from the app; secrets go to the deny-all table via an owner RPC and are
// never read back.
import 'dart:async';

import 'package:deskilo/app/app.dart';
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

  testWidgets('#3510 a fetch lists the settlement reports waiting for '
      'review, each with why; a failed read of them is said', (tester) async {
    final money = _Settlements(const SettlementFetch(
      imported: 0,
      unchanged: 2,
      reviews: [
        SettlementReview(
          settlementId: 'stl_3',
          reason: SettlementReviewReason.costsChanged,
        ),
        SettlementReview(
          settlementId: 'stl_9',
          reason: SettlementReviewReason.currencyMismatch,
        ),
      ],
    ))
      ..paymentStatus[PaymentProvider.mollie] = const PaymentProviderStatus(
        configured: true,
        secretKeysSet: {'api_key'},
      );
    await pumpConfig(tester, money: money);
    final fetch = find.byKey(const ValueKey('payment-fetch-settlements'));
    await tester.ensureVisible(fetch);
    await tester.tap(fetch);
    await tester.pumpAndSettle();
    expect(find.text('Settlement reports to review'), findsOneWidget);
    expect(
      find.text('stl_3: the provider changed its costs after it was '
          'recorded. Nothing of the new report was booked.'),
      findsOneWidget,
    );
    expect(
      find.text('stl_9: a cost is in another currency than the settlement. '
          'Nothing of it was booked.'),
      findsOneWidget,
    );

    money.answer = const SettlementFetch(imported: 0, reviews: null);
    await tester.ensureVisible(fetch);
    await tester.tap(fetch);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settlement-reviews-unreadable')),
      findsOneWidget,
    );
    expect(find.text('Settlement reports to review'), findsNothing);
  });
}

/// The provider's settlements as one fetch answers them.
class _Settlements extends FakeMoneyRepository {
  _Settlements(this.answer);

  SettlementFetch answer;

  @override
  Future<SettlementFetch> fetchProviderSettlements(
    String workspaceId,
    PaymentProvider provider,
  ) async => answer;
}
