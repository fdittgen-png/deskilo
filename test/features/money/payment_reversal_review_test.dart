// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3925 — a payment the provider reversed: the roles that see the finances
// are told on the decision surface until one of them marks it looked at on the
// payments screen; a plain member is not; the member's own history and bill
// say it, with the amount the provider reversed.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/presentation/screens/account_activity_screen.dart';
import 'package:deskilo/features/money/presentation/screens/recorded_payments_screen.dart';
import 'package:deskilo/features/money/presentation/widgets/online_payment_status_card.dart';
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_workspace_context.dart';

PaymentIntent _reversed({
  String reason = 'charge.refunded 5.00 EUR',
  DateTime? reviewedAt,
}) => PaymentIntent(
  id: 'pi-1',
  memberId: 'm-1',
  provider: 'stripe',
  orderId: 'cs_1',
  period: '2026-11',
  amountCents: 1200,
  status: 'reversed',
  createdAt: DateTime.utc(2026, 11, 2),
  reference: 'PAY-2026-0001',
  reversedAt: DateTime.utc(2026, 11, 3),
  reversalReason: reason,
  reversalReviewedAt: reviewedAt,
);

Future<List<Attention>> _lines(
  FakeMoneyRepository money,
  Set<WorkspacePermission> permissions,
) async {
  final container = ProviderContainer(
    overrides: [
      ...standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(),
        money: money,
      ),
      myPermissionsProvider.overrideWithValue(permissions),
      testReadyWorkspaceContext(),
    ],
  );
  addTearDown(container.dispose);
  final keep = container.listen(attentionProvider, (_, _) {});
  addTearDown(keep.close);
  return [
    for (final a in await container.read(attentionProvider.future))
      if (a.action == AttentionAction.reviewReversals) a,
  ];
}

void main() {
  group('the amount the provider reversed', () {
    test('is read from the reason, in minor units of its currency', () {
      expect(_reversed().reversedMinor('EUR'), 500);
      expect(
        _reversed(reason: 'chargeback 1200 JPY').reversedMinor('JPY'),
        1200,
      );
    });

    test('is unknown in another currency, or when the reason has none', () {
      expect(_reversed().reversedMinor('CHF'), isNull);
      expect(
        _reversed(reason: 'charge.dispute.created').reversedMinor('EUR'),
        isNull,
      );
    });
  });

  test('a reversal waits until someone looked at it', () {
    expect(_reversed().awaitsReview, isTrue);
    expect(
      _reversed(reviewedAt: DateTime.utc(2026, 11, 4)).awaitsReview,
      isFalse,
    );
  });

  group('the decision surface', () {
    test(
      'tells whoever sees the finances, with the way to the payments',
      () async {
        final money = FakeMoneyRepository()..paymentIntents.add(_reversed());
        final lines = await _lines(money, {WorkspacePermission.viewFinances});
        expect(
          [for (final l in lines) (l.count, l.route)],
          [(1, '/money/payments')],
        );
      },
    );

    test(
      'tells nobody without the finances, and nobody once looked at',
      () async {
        final money = FakeMoneyRepository()..paymentIntents.add(_reversed());
        expect(await _lines(money, const {}), isEmpty);
        final seen = FakeMoneyRepository()
          ..paymentIntents.add(
            _reversed(reviewedAt: DateTime.utc(2026, 11, 4)),
          );
        expect(await _lines(seen, {WorkspacePermission.viewFinances}), isEmpty);
      },
    );
  });

  testWidgets('the payments screen lists it until it is marked looked at', (
    tester,
  ) async {
    final money = FakeMoneyRepository()..paymentIntents.add(_reversed());
    await pumpApp(
      tester,
      const RecordedPaymentsScreen(),
      overrides: standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(),
        money: money,
      ),
      size: const Size(800, 1400),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-reversal-pi-1')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('payment-reversal-reviewed-pi-1')),
    );
    await tester.pumpAndSettle();
    expect(money.paymentIntents.single.reversalReviewedAt, isNotNull);
    expect(find.byKey(const ValueKey('payment-reversals')), findsNothing);
  });

  testWidgets('the member\'s own history labels a reversed payment', (
    tester,
  ) async {
    final repo = FakeAccountActivityRepository();
    repo.records[AccountActivityKind.payments] = [
      AccountActivity(
        id: 'pi-1',
        workspaceId: 'w1',
        workspaceName: 'Office',
        occurredAt: DateTime.utc(2026, 11, 3),
        reference: 'PAY-2026-0001',
        description: 'stripe',
        currency: 'EUR',
        status: 'reversed',
        amountCents: 1200,
      ),
    ];
    await pumpApp(
      tester,
      const AccountActivityScreen(),
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        accountActivity: repo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('account-activity-invoices-title')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payments').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Online payment reversed'), findsWidgets);
  });

  testWidgets('the member\'s bill names the part the provider reversed', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: OnlinePaymentStatusCard(
          intents: [_reversed()],
          currencyCode: 'EUR',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('the provider reversed'), findsOneWidget);
    expect(find.textContaining('5.00'), findsOneWidget);
  });
}
