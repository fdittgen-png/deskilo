// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — the reference business sends e-invoices through the generic
// channel the app offers a country without a national profile installed
// (France has none): its channel is configured and its test document was
// accepted, so the issuing gate is open. One invoice has already gone and
// its receipt says delivered; Chiara's submission, whose answer was lost, is
// the one an issuer settles (demo_money_seed.dart). The address is the
// reserved `.test` domain: it can never reach anybody.
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';

import '../data/money_repository.dart';

/// Configures the channel and records the invoice of Ada that already went.
void seedDemoEInvoiceChannel(FakeMoneyRepository money, DateTime now) {
  money
    ..einvoiceGateway = const EInvoiceGatewayConfig(configured: true)
    ..einvoiceConfig['endpoint'] = 'https://einvoice.example.test/inbox';
  money.eInvoices
    ..testId = 'demo-einvoice-test'
    ..testVerdict = EInvoiceTestVerdict.accepted;
  final sent = money.invoices.where((i) => i.id == 'demo-invoice-ada');
  if (sent.isEmpty) return;
  final at = sent.first.issuedAt.add(const Duration(hours: 2));
  money.transmissions['demo-invoice-ada'] = InvoiceTransmission(
    id: 'demo-transmission-ada',
    invoiceId: 'demo-invoice-ada',
    status: EInvoiceSubmissionStatus.accepted,
    sentAt: at,
    format: 'ubl',
    externalId: 'platform-demo-ada',
    receipt: const {'state': 'delivered'},
    receiptAt: at.add(const Duration(hours: 1)),
  );
}
