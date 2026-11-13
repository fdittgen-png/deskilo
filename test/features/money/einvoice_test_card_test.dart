// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3883 — the setup card that opens issuing with a sandbox test document:
// shown only where the configured channel takes one, it says where the latest
// test stands, offers to ask the platform while one awaits its verdict, and
// offers a new test only when none awaits.
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/einvoice_test_document.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_test_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

FakeMoneyRepository _money({String provider = 'it_sdi'}) =>
    FakeMoneyRepository()
      ..einvoiceGateway = EInvoiceGatewayConfig(
        configured: true,
        provider: provider,
      );

Future<void> _pump(WidgetTester tester, FakeMoneyRepository money) async {
  await pumpApp(
    tester,
    const Scaffold(
      body: SingleChildScrollView(child: EInvoiceTestCard(workspaceId: 'ws-1')),
    ),
    overrides: standardTestOverrides(money: money),
    size: const Size(800, 1400),
  );
  await tester.pump();
}

void main() {
  testWidgets('a channel that takes no test document shows no card', (
    tester,
  ) async {
    await _pump(tester, _money(provider: 'peppol'));
    expect(find.byKey(const ValueKey('einvoice-test-card')), findsNothing);
  });

  testWidgets('before any test, the card offers to send one', (tester) async {
    await _pump(tester, _money());
    expect(find.byKey(const ValueKey('einvoice-test-none')), findsOneWidget);
    expect(find.byKey(const ValueKey('einvoice-test-send')), findsOneWidget);
    expect(find.byKey(const ValueKey('einvoice-test-ask')), findsNothing);
  });

  testWidgets('a test awaiting its verdict is asked about, not sent again', (
    tester,
  ) async {
    final money = _money()
      ..einvoiceTestId = 'demo-test-1'
      ..einvoiceTestVerdict = EInvoiceTestVerdict.awaiting;
    await _pump(tester, money);
    expect(
      find.byKey(const ValueKey('einvoice-test-awaiting')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('einvoice-test-ask')), findsOneWidget);
    expect(find.byKey(const ValueKey('einvoice-test-send')), findsNothing);
  });

  testWidgets('an accepted test says the workspace issues', (tester) async {
    final money = _money()
      ..einvoiceTestId = 'demo-test-1'
      ..einvoiceTestVerdict = EInvoiceTestVerdict.accepted;
    await _pump(tester, money);
    expect(
      find.byKey(const ValueKey('einvoice-test-accepted')),
      findsOneWidget,
    );
  });

  testWidgets('a refused test can be sent again', (tester) async {
    final money = _money()
      ..einvoiceTestId = 'demo-test-1'
      ..einvoiceTestVerdict = EInvoiceTestVerdict.rejected;
    await _pump(tester, money);
    expect(
      find.byKey(const ValueKey('einvoice-test-rejected')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('einvoice-test-send')), findsOneWidget);
  });
}
