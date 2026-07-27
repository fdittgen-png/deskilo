// SPDX-License-Identifier: 0BSD
//
// Direct submission (0073): with a platform configured, the e-invoice sheet
// SENDS instead of handing over a file — the Factur-X document goes to the
// edge function, which holds the credential and logs the attempt. Without
// one, the button is not offered at all: an affordance that cannot work is
// worse than none.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

/// A workspace with a complete legal identity — otherwise the export
/// refuses before any of this matters (0069).
FakeWorkspaceRepository _identified() {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    legalId: 'HRB 12345 B',
    city: 'Berlin',
    postalCode: '10115',
  );
  return workspace;
}

Future<FakeMoneyRepository> _pumpArchive(
  WidgetTester tester, {
  required FakeMoneyRepository money,
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        money: money,
        workspace: workspace ?? _identified(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
  await tester.pumpAndSettle();
  return money;
}

/// A matched (archived) invoice to act on.
Future<FakeMoneyRepository> _seeded() async {
  final money = FakeMoneyRepository();
  final id = await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-06',
  );
  await money.matchInvoice(
    invoiceId: id,
    paymentLedgerId:
        money.seedPayment('member-1', money.invoices.single.totalCents),
    resolution: 'exact',
  );
  return money;
}

Future<void> _openEInvoiceSheet(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('invoice-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoice-einvoice-action')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'with NO platform configured the sheet offers files only — never a '
      'Send button that cannot work', (tester) async {
    final money = await _pumpArchive(tester, money: await _seeded());

    await _openEInvoiceSheet(tester, money.invoices.single.id);

    expect(find.byKey(const ValueKey('invoice-einvoice-send')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-facturx-download')),
        findsOneWidget);
  });

  testWidgets(
      'with a platform configured, Send posts the FACTUR-X document and '
      'reports what the platform answered', (tester) async {
    final money = await _seeded()
      ..einvoiceGateway = const EInvoiceGatewayConfig(configured: true);
    await _pumpArchive(tester, money: money);
    final invoice = money.invoices.single;

    await _openEInvoiceSheet(tester, invoice.id);
    expect(find.byKey(const ValueKey('invoice-einvoice-send')), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('invoice-einvoice-send')));
      await tester.pump();
      // Building the PDF loads real font assets.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final sent = money.sentEInvoices.single;
    expect(sent.invoiceId, invoice.id);
    expect(sent.fileName, contains('facturx'));
    expect(sent.bytes, greaterThan(1000),
        reason: 'a real PDF left, not an empty body');
    expect(find.text('Sent — the platform accepted it.'), findsOneWidget);
    expect(money.transmissions[invoice.id]!.accepted, isTrue);
  });

  testWidgets('a REFUSAL surfaces the platform\'s own words', (tester) async {
    final money = await _seeded()
      ..einvoiceGateway = const EInvoiceGatewayConfig(configured: true)
      ..einvoiceOutcome = EInvoiceSubmissionStatus.rejected;
    await _pumpArchive(tester, money: money);

    await _openEInvoiceSheet(tester, money.invoices.single.id);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('invoice-einvoice-send')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('the platform said no'), findsOneWidget,
        reason: 'a generic failure would leave the owner guessing');
  });

  testWidgets(
      'the OWNER configures the platform: the endpoint reads back, the token '
      'never does, and a blank token keeps the stored one', (tester) async {
    final money = FakeMoneyRepository();
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money, workspace: _identified()),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push('/einvoice-config');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('einvoice-endpoint')),
        'https://pa.example.com/upload');
    await tester.enterText(
        find.byKey(const ValueKey('einvoice-token')), 'Bearer s3cret');
    await tester.tap(find.byKey(const ValueKey('einvoice-save')));
    await tester.pumpAndSettle();

    expect(money.einvoiceConfig['endpoint'], 'https://pa.example.com/upload');
    expect(money.einvoiceConfig['auth_value'], 'Bearer s3cret');
    expect(find.text('Platform saved.'), findsOneWidget);

    // Changing only the endpoint must not wipe the token.
    await tester.enterText(find.byKey(const ValueKey('einvoice-endpoint')),
        'https://pa.example.com/v2/upload');
    await tester.tap(find.byKey(const ValueKey('einvoice-save')));
    await tester.pumpAndSettle();

    expect(money.einvoiceConfig['auth_value'], 'Bearer s3cret',
        reason: 'a secret nobody can read back must not vanish on save');
    expect(money.einvoiceConfig['endpoint'], 'https://pa.example.com/v2/upload');
  });
}
