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
FakeWorkspaceRepository _identified({
  Map<String, dynamic> featureFlags = const {},
}) {
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags);
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
  bool devMode = false,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        money: money,
        workspace: workspace ?? _identified(),
        devMode: devMode,
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

  // ── Environments (#393) ────────────────────────────────────────────

  /// The gateway as the NEW function reports it: prod ready, UAT ready.
  const gatewayWithUat = EInvoiceGatewayConfig(
    configured: true,
    environments: {'prod': true, 'uat': true, 'dev': false},
  );

  testWidgets(
      'dev mode ON + a UAT platform → Send asks which environment, and '
      'choosing UAT posts there and says so', (tester) async {
    final money = await _seeded()..einvoiceGateway = gatewayWithUat;
    await _pumpArchive(
      tester,
      money: money,
      devMode: true,
    );

    await _openEInvoiceSheet(tester, money.invoices.single.id);
    await tester.tap(find.byKey(const ValueKey('invoice-einvoice-send')));
    await tester.pumpAndSettle();

    // The picker offers production and the configured UAT — never the
    // unconfigured dev endpoint.
    expect(find.byKey(const ValueKey('einvoice-env-prod')), findsOneWidget);
    expect(find.byKey(const ValueKey('einvoice-env-uat')), findsOneWidget);
    expect(find.byKey(const ValueKey('einvoice-env-dev')), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('einvoice-env-uat')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(money.sentEInvoices.single.environment, 'uat');
    // A rehearsal must never read like the real submission.
    expect(find.text('Test send accepted (UAT).'), findsOneWidget);
    expect(money.transmissions.values.single.isTestSend, isTrue);
  });

  testWidgets(
      'dev mode OFF → no environment question, the send goes to production',
      (tester) async {
    final money = await _seeded()..einvoiceGateway = gatewayWithUat;
    await _pumpArchive(tester, money: money);

    await _openEInvoiceSheet(tester, money.invoices.single.id);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('invoice-einvoice-send')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('einvoice-env-prod')), findsNothing,
        reason: 'a normal admin never sees a test choice');
    expect(money.sentEInvoices.single.environment, 'prod');
  });

  testWidgets(
      'dev mode ON but the DEPLOYED function predates environments → no '
      'choice, production — the latch against misrouting a test send',
      (tester) async {
    // An old function's probe carries no environments map at all.
    final money = await _seeded()
      ..einvoiceGateway = const EInvoiceGatewayConfig(configured: true);
    await _pumpArchive(
      tester,
      money: money,
      devMode: true,
    );

    await _openEInvoiceSheet(tester, money.invoices.single.id);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('invoice-einvoice-send')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('einvoice-env-uat')), findsNothing);
    expect(money.sentEInvoices.single.environment, 'prod');
  });

  testWidgets(
      'the platform screen saves the UAT/dev endpoints as suffixed keys — '
      'the shape the function and 0074 read', (tester) async {
    final money = FakeMoneyRepository();
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    // Deep link straight to the config screen — the settings entry is
    // covered by the feature-gating tests.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/einvoice-config');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('einvoice-endpoint')),
      'https://prod.example/upload',
    );
    await tester.enterText(
      find.byKey(const ValueKey('einvoice-endpoint-uat')),
      'https://uat.example/upload',
    );
    await tester.enterText(
      find.byKey(const ValueKey('einvoice-token-uat')),
      'uat-secret',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('einvoice-save')));
    await tester.tap(find.byKey(const ValueKey('einvoice-save')));
    await tester.pumpAndSettle();

    expect(money.einvoiceConfig['endpoint'], 'https://prod.example/upload');
    expect(money.einvoiceConfig['endpoint_uat'], 'https://uat.example/upload');
    expect(money.einvoiceConfig['auth_value_uat'], 'uat-secret');
  });

  // ── Destinations (#568) ────────────────────────────────────────────

  /// The gateway as the NEW function reports it: government AND the
  /// customer's delivery service, each its own leg.
  const gatewayBothLegs = EInvoiceGatewayConfig(
    configured: true,
    destinations: {
      'government': EInvoiceDestination(configured: true),
      'customer': EInvoiceDestination(configured: true),
    },
  );

  testWidgets(
      'with BOTH legs configured the sheet offers government and customer, '
      'and the customer send posts destination=customer and says whose '
      'service took it', (tester) async {
    final money = await _seeded()..einvoiceGateway = gatewayBothLegs;
    await _pumpArchive(tester, money: money);
    final invoice = money.invoices.single;

    await _openEInvoiceSheet(tester, invoice.id);
    expect(find.byKey(const ValueKey('invoice-einvoice-send')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-einvoice-send-customer')),
        findsOneWidget);

    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(const ValueKey('invoice-einvoice-send-customer')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final sent = money.sentEInvoices.single;
    expect(sent.invoiceId, invoice.id);
    expect(sent.destination, 'customer');
    expect(find.text("Sent — the customer's service accepted it."),
        findsOneWidget);
    expect(money.transmissions[invoice.id]!.destination, 'customer');
  });

  testWidgets(
      'the government send still posts destination=government',
      (tester) async {
    final money = await _seeded()..einvoiceGateway = gatewayBothLegs;
    await _pumpArchive(tester, money: money);

    await _openEInvoiceSheet(tester, money.invoices.single.id);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('invoice-einvoice-send')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(money.sentEInvoices.single.destination, 'government');
  });

  testWidgets(
      'the DEPLOYED function predates destinations → no customer button, '
      'the latch against misrouting to the government platform',
      (tester) async {
    // An old function's probe carries no destinations map at all.
    final money = await _seeded()
      ..einvoiceGateway = const EInvoiceGatewayConfig(configured: true);
    await _pumpArchive(tester, money: money);

    await _openEInvoiceSheet(tester, money.invoices.single.id);

    expect(find.byKey(const ValueKey('invoice-einvoice-send')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-einvoice-send-customer')),
        findsNothing);
  });

  testWidgets(
      'the einvoiceCustomerDelivery flag OFF hides the customer leg even '
      'when its endpoint is configured', (tester) async {
    final money = await _seeded()..einvoiceGateway = gatewayBothLegs;
    await _pumpArchive(
      tester,
      money: money,
      workspace:
          _identified(featureFlags: {'einvoiceCustomerDelivery': false}),
    );

    await _openEInvoiceSheet(tester, money.invoices.single.id);

    expect(find.byKey(const ValueKey('invoice-einvoice-send')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-einvoice-send-customer')),
        findsNothing);
  });

  testWidgets(
      'the platform screen saves the customer endpoint as customer_-prefixed '
      'keys — the shape the function slices per destination (#568)',
      (tester) async {
    final money = FakeMoneyRepository();
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/einvoice-config');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('einvoice-customer-endpoint')),
      'https://ap.example/peppol',
    );
    await tester.enterText(
      find.byKey(const ValueKey('einvoice-customer-token')),
      'customer-secret',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('einvoice-save')));
    await tester.tap(find.byKey(const ValueKey('einvoice-save')));
    await tester.pumpAndSettle();

    expect(
        money.einvoiceConfig['customer_endpoint'], 'https://ap.example/peppol');
    expect(money.einvoiceConfig['customer_auth_value'], 'customer-secret');
  });
}
