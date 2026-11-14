// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3883 — the test document card from one end to the other, over the Demo's
// stores and a stand-in for the document builder: none → a member picked →
// sent → awaiting → the platform asked → accepted (the workspace issues), or
// refused (another may be sent); and the refusal when a test already awaits.
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/presentation/einvoice_test_document.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_test_card.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<FakeMoneyRepository> _pump(WidgetTester tester) async {
  final money = FakeMoneyRepository()
    ..einvoiceGateway = const EInvoiceGatewayConfig(
      configured: true,
      provider: 'it_sdi',
    );
  await pumpApp(
    tester,
    const Scaffold(body: SingleChildScrollView(child: EInvoiceTestCard())),
    overrides: [
      ...standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(),
        money: money,
      ),
      invoicingOverviewProvider.overrideWith(
        (ref) async => (
          period: '2026-10',
          toInvoice: const [(memberId: 'm-1', name: 'Ada', totalCents: 1200)],
          open: const <OpenInvoiceEntry>[],
        ),
      ),
      eInvoiceTestDocumentBuilderProvider.overrideWithValue(
        (ref, {required memberId, required period}) async =>
            (bytes: const [1, 2, 3], fileName: 'TEST.xml'),
      ),
    ],
    size: const Size(800, 1400),
  );
  await tester.pumpAndSettle();
  return money;
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('einvoice-test-member')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ada').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('einvoice-test-send')));
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('einvoice-test-ask')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sent, awaited, then accepted: the workspace issues', (
    tester,
  ) async {
    final money = await _pump(tester);
    expect(find.byKey(const ValueKey('einvoice-test-none')), findsOneWidget);

    await _send(tester);
    expect(find.textContaining('Test document sent'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('einvoice-test-awaiting')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('einvoice-test-send')), findsNothing);

    // The platform answers; the person asks it.
    money.eInvoices.testVerdict = EInvoiceTestVerdict.accepted;
    await _ask(tester);
    expect(
      find.byKey(const ValueKey('einvoice-test-accepted')),
      findsOneWidget,
    );
  });

  testWidgets('refused by the platform: another test is offered', (
    tester,
  ) async {
    final money = await _pump(tester);
    await _send(tester);
    money.eInvoices.testVerdict = EInvoiceTestVerdict.rejected;
    await _ask(tester);
    expect(
      find.byKey(const ValueKey('einvoice-test-rejected')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('einvoice-test-send')), findsOneWidget);
  });

  testWidgets('a test that already awaits refuses a second, with a sentence', (
    tester,
  ) async {
    final money = await _pump(tester);
    // Someone else sent one after this card was read.
    money.eInvoices
      ..testId = 'demo-test-9'
      ..testVerdict = EInvoiceTestVerdict.awaiting;
    await _send(tester);
    expect(
      find.textContaining('still waiting for the platform\'s verdict'),
      findsOneWidget,
    );
    expect(money.eInvoices.tests, 0, reason: 'nothing was sent');
  });
}
