// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the test payment of the online-payments step. Nothing is read
// until the owner asks. Test keys say the checkout moves no real money; a
// live key says it charges a real card; a rehearsal space says it opens
// no payment whatever the keys; every answer names each provider's key
// and says what the test cannot see. A refused read says so and a second
// try reads again and recovers. The test never asks for a secret, and is
// not offered while online payments are off.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/payment_test_check.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);
const _none = PaymentTestCheck(
  verdict: PaymentTestVerdict.noProvider,
  takesPayments: true,
);

/// Answers [answer] and counts the reads; with [refuseFirst] the first
/// read is refused, as a server refusing the owner would.
class _Keys extends FakeMoneyRepository {
  _Keys(this.answer, {this.refuseFirst = false});

  final PaymentTestCheck answer;
  bool refuseFirst;
  int reads = 0;

  @override
  Future<PaymentTestCheck> testPaymentKeys(String workspaceId) async {
    if (refuseFirst) {
      refuseFirst = false;
      throw StateError('only an owner of this workspace tests');
    }
    reads++;
    return answer;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Keys money, {
  bool online = true,
}) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'online_payments', runPages: setupRunPages),
    size: _phone,
    overrides: standardTestOverrides(
      workspace: FakeWorkspaceRepository.withWorkspace(
        featureFlags: {'moneyTab': true, 'onlinePayments': online},
      ),
      money: money,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _run(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('setup-online-test-run')));
  await tester.pumpAndSettle();
}

Finder _mode(String provider, String text) => find.descendant(
  of: find.byKey(ValueKey('setup-online-test-mode-$provider')),
  matching: find.text(text),
);

void main() {
  testWidgets('nothing is read until the owner asks; test keys move no real '
      'money, and the answer says what it cannot see', (tester) async {
    final money = _Keys(
      const PaymentTestCheck(
        verdict: PaymentTestVerdict.testKeys,
        takesPayments: true,
        modes: {
          PaymentProvider.stripe: PaymentKeyMode.test,
          PaymentProvider.paypal: PaymentKeyMode.test,
        },
      ),
    );
    await _pump(tester, money);
    expect(money.reads, 0);
    expect(
      find.byKey(const ValueKey('setup-online-test-limits')),
      findsNothing,
    );
    expect(find.byType(TextField), findsNothing, reason: 'no secret asked');

    await _run(tester);
    expect(money.reads, 1);
    expect(
      find.byKey(const ValueKey('setup-online-test-test_keys')),
      findsOneWidget,
    );
    expect(
      find.text("Test keys: a member's checkout takes no real money."),
      findsOneWidget,
    );
    expect(_mode('stripe', 'Test key'), findsOneWidget);
    expect(_mode('paypal', 'Test key'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('setup-online-test-rehearsal')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('setup-online-test-limits')),
      findsOneWidget,
    );
  });

  testWidgets('a live key charges a real card; a rehearsal space opens no '
      'payment; an unreadable field is the installation\'s', (tester) async {
    final money = _Keys(
      const PaymentTestCheck(
        verdict: PaymentTestVerdict.liveKeys,
        takesPayments: false,
        modes: {
          PaymentProvider.mollie: PaymentKeyMode.live,
          PaymentProvider.paypal: PaymentKeyMode.installation,
        },
      ),
    );
    await _pump(tester, money);
    await _run(tester);
    expect(
      find.byKey(const ValueKey('setup-online-test-live_keys')),
      findsOneWidget,
    );
    expect(_mode('mollie', 'Live key'), findsOneWidget);
    expect(
      _mode('paypal', 'Set by the installation, which this test cannot read'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('setup-online-test-rehearsal')),
      findsOneWidget,
    );
  });

  testWidgets('online payments off: no test is offered', (tester) async {
    final money = _Keys(_none);
    await _pump(tester, money, online: false);
    expect(find.byKey(const ValueKey('setup-online-test-run')), findsNothing);
    expect(money.reads, 0);
  });

  testWidgets('no provider: nothing to test', (tester) async {
    await _pump(tester, _Keys(_none));
    await _run(tester);
    expect(
      find.byKey(const ValueKey('setup-online-test-no_provider')),
      findsOneWidget,
    );
  });

  testWidgets('a refused read says so; asking again reads again and '
      'recovers', (tester) async {
    final money = _Keys(
      refuseFirst: true,
      const PaymentTestCheck(
        verdict: PaymentTestVerdict.unverified,
        takesPayments: true,
        modes: {PaymentProvider.stripe: PaymentKeyMode.unknown},
      ),
    );
    await _pump(tester, money);
    await _run(tester);
    expect(
      find.byKey(const ValueKey('setup-online-test-failed')),
      findsOneWidget,
    );
    expect(money.reads, 0);

    await _run(tester);
    expect(
      find.byKey(const ValueKey('setup-online-test-failed')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('setup-online-test-unverified')),
      findsOneWidget,
    );
    expect(_mode('stripe', 'A key of unknown kind'), findsOneWidget);
    expect(money.reads, 1);
  });
}
