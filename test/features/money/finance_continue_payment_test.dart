// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/demo/data/money/demo_payment_gateway_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/money/application/finance_selection_commands.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/presentation/widgets/finance_claim_state.dart';
import 'package:deskilo/features/money/providers/finance_overview_provider.dart';
import 'package:deskilo/features/money/providers/finance_selection_provider.dart';
import 'package:deskilo/features/money/providers/payment_approval_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

FinanceInvoice _invoice(
  String installation, {
  bool? ready = true,
  String? state = 'ready',
}) => FinanceInvoice(
  id: 'same-invoice',
  workspaceId: 'same-workspace',
  installationId: installation,
  workspaceName: installation == _a ? 'A' : 'B',
  number: 'INV-1',
  issuedAt: DateTime.utc(2026, 11, 17),
  totalCents: 4000,
  paidCents: 1000,
  stillDueCents: 3000,
  currency: 'EUR',
  state: FinanceState.partiallyPaid,
  inPayment: true,
  claimPaymentId: 'same-payment',
  claimCanContinue: ready,
  claimPaymentState: state,
);

class _Gateway extends DemoPaymentGateway {
  // The superclass parameter is private to its library.
  // ignore: use_super_parameters
  _Gateway(FakeMoneyRepository money, this.host) : super(money);
  final String host;
  final calls = <(String, String, String)>[];
  Completer<PaymentOrderStart>? pending;
  bool refused = false;
  PaymentOrderStart get answer => PaymentOrderStart(
    approveUrl: Uri.https('$host.example', '/original-order'),
    orderId: 'same-payment',
    claimed: 1,
  );

  @override
  Future<PaymentOrderStart> resumeClaimOrder({
    required String workspaceId,
    required String memberId,
    required String paymentId,
  }) async {
    calls.add((workspaceId, memberId, paymentId));
    if (refused) throw const ClaimRefused(ClaimRefusal.notProcessing);
    return pending == null ? answer : pending!.future;
  }
}

class _Harness {
  final auth = FakeAuthRepository.signedIn();
  final money = FakeMoneyRepository();
  late final a = _Gateway(money, 'a');
  late final b = _Gateway(money, 'b');
  final opened = <Uri>[];
  final entered = <WorkspaceTarget>[];
  final released = <WorkspaceTarget>[];
  bool leaseCurrent = true;
  Completer<void>? entering;

  Future<void> show(
    WidgetTester tester, {
    bool? ready = true,
    String? state = 'ready',
  }) async {
    final invoices = [_invoice(_a, ready: ready, state: state), _invoice(_b)];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            auth: auth,
            money: money,
            homeInstallation: _a,
            accountActivity: FakeAccountActivityRepository()
              ..financeOverview = FinanceOverview(invoices: invoices),
          ),
          sessionSourceProvider.overrideWithValue(auth),
          financeCurrentTargetProvider.overrideWithValue(invoices.last.target),
          financeWorkspaceEntryProvider.overrideWith((ref) {
            final principal = ref.watch(sessionStateProvider).value;
            return (target) async {
              entered.add(target);
              if (entering != null) await entering!.future;
              return FinanceCommandTarget(
                target: target,
                memberId: 'member-${target.installationId}',
                currency: 'GBP',
                commands: money.accountCommands,
                gateway: target.installationId == _a ? a : b,
                isCurrent: () =>
                    ref.mounted &&
                    leaseCurrent &&
                    ref.read(sessionStateProvider).value == principal,
                release: () => released.add(target),
                open: () async => true,
              );
            };
          }),
          paymentApprovalProvider.overrideWithValue(
            (context, url) async => opened.add(url),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                for (final invoice in invoices)
                  KeyedSubtree(
                    key: ValueKey<String>(invoice.installationId!),
                    child: FinanceClaimState(invoice),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Finder _continue(String installation) => find.descendant(
  of: find.byKey(ValueKey(installation)),
  matching: find.byKey(const ValueKey('finances-continue-same-invoice')),
);

void main() {
  testWidgets(
    'A and B share local IDs: with B selected A keeps its own checkout',
    (tester) async {
      final h = _Harness();
      await h.show(tester);
      await tester.tap(_continue(_a));
      await tester.pumpAndSettle();
      expect(h.entered.single, _invoice(_a).target);
      expect(h.a.calls, [('same-workspace', 'member-$_a', 'same-payment')]);
      expect(h.b.calls, isEmpty);
      expect(h.opened, [h.a.answer.approveUrl]);
      expect(h.released, h.entered);
    },
  );

  for (final wait in ['entry', 'provider']) {
    for (final change in ['sign out', 'account change', 'revoke lease']) {
      testWidgets('$change during $wait prevents stale provider handoff', (
        tester,
      ) async {
        final h = _Harness();
        if (wait == 'entry') {
          h.entering = Completer<void>();
        } else {
          h.a.pending = Completer<PaymentOrderStart>();
        }
        await h.show(tester);
        await tester.tap(_continue(_a));
        await tester.pump();
        switch (change) {
          case 'sign out':
            await h.auth.signOut();
          case 'account change':
            h.auth.signInAs('other-account');
          case 'revoke lease':
            h.leaseCurrent = false;
        }
        await tester.pump();
        h.entering?.complete();
        h.a.pending?.complete(h.a.answer);
        await tester.pumpAndSettle();
        expect(h.opened, isEmpty);
        expect(h.b.calls, isEmpty);
        if (wait == 'entry') expect(h.a.calls, isEmpty);
        expect(h.released, h.entered);
      });
    }
  }

  testWidgets('repeated taps while waiting send one continuation', (
    tester,
  ) async {
    final h = _Harness();
    h.a.pending = Completer<PaymentOrderStart>();
    await h.show(tester);
    await tester.tap(_continue(_a));
    await tester.pump();
    await tester.tap(_continue(_a));
    expect(h.a.calls, hasLength(1));
    h.a.pending!.complete(h.a.answer);
    await tester.pumpAndSettle();
    expect(h.opened, hasLength(1));
  });

  testWidgets(
    'old overview withholds Continue and explains unavailable support',
    (tester) async {
      final h = _Harness();
      await h.show(tester, ready: null, state: null);
      expect(_continue(_a), findsNothing);
      expect(find.textContaining('must be updated'), findsWidgets);
      expect(h.a.calls, isEmpty);
    },
  );

  testWidgets('old payment function cannot fall back to a new order', (
    tester,
  ) async {
    final h = _Harness();
    h.a.takesContinuations = false;
    await h.show(tester);
    await tester.tap(_continue(_a));
    await tester.pumpAndSettle();
    expect(h.a.calls, isEmpty);
    expect(h.money.paymentOrders, isEmpty);
    expect(h.opened, isEmpty);
  });

  testWidgets('stale overview refuses a payment that ended meanwhile', (
    tester,
  ) async {
    final h = _Harness();
    h.a.refused = true;
    await h.show(tester);
    await tester.tap(_continue(_a));
    await tester.pumpAndSettle();
    expect(h.opened, isEmpty);
    expect(h.money.paymentOrders, isEmpty);
    expect(h.released, h.entered);
  });

  for (final ended in ['failed', 'expired', 'withdrawn', 'reversed']) {
    testWidgets('$ended is stated and offers no Continue', (tester) async {
      final h = _Harness();
      await h.show(tester, ready: false, state: ended);
      expect(_continue(_a), findsNothing);
      expect(
        find.textContaining(RegExp(ended, caseSensitive: false)),
        findsWidgets,
      );
    });
  }
}
