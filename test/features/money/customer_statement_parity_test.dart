// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the customer statement and the customer page agree. For the same
// rows (pgTAP 398's second customer: a payment shared by two invoices, a
// part awaiting approval, a credit note, a voided document, a currency with
// three decimals), the page's own figures — its receivables
// (receivables_adapter.dart) and the payments no invoice has taken
// (unassigned_money.dart) — give the summary in
// test/fixtures/customer_statement_parity.json, and pgTAP 398 asserts that
// the server's snapshot (customer_statement_v1) gives the very same text.
// A row counted on one side and not the other fails one of the two: the
// parity holds in both directions. The pgTAP file carrying the fixture
// verbatim is checked here too, so the two cannot drift apart.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/application/customer_statement_of_page.dart';
import 'package:deskilo/features/money/application/unassigned_money.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/receivables_adapter.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = 'test/fixtures/customer_statement_parity.json';
const _pgTap = 'supabase/tests/database/398_customer_statement.sql';

final _day = DateTime.utc(2026, 10);

Invoice _invoice(
  String number,
  int total, {
  String currency = 'EUR',
  DateTime? voidedAt,
}) => Invoice(
  id: number,
  workspaceId: 'ws',
  memberId: 'm2',
  number: number,
  issuedAt: _day,
  title: 'Two',
  lines: const [],
  totalCents: total,
  currency: currency,
  memberName: 'Two',
  memberAddress: '',
  workspaceName: 'Statement',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 'sig',
  voidedAt: voidedAt,
);

LedgerEntry _payment(String id, int amount) => LedgerEntry(
  id: id,
  memberId: 'm2',
  kind: LedgerKind.credit,
  category: LedgerCategory.payment,
  amountCents: amount,
  description: id,
  period: '2026-09',
  createdAt: _day.subtract(const Duration(days: 1)),
);

/// The summary the fixture holds: per currency the totals, each document's
/// still due by number and each credit's left by its description.
Map<String, Object?> _summary(CustomerStatement statement) => {
  for (final c in statement.currencies)
    c.currency: {
      'balance_cents': c.balanceCents,
      'credits': {for (final cr in c.credits) cr.description: cr.leftCents},
      'invoices': {for (final l in c.lines) l.number: l.stillDueCents},
      'still_due_cents': c.stillDueCents,
      'unapplied_cents': c.unappliedCents,
    },
};

/// The fixture's rows, read as the customer page reads them.
CustomerStatement _pageStatement({List<Invoice> extra = const []}) {
  final invoices = [
    _invoice('ST-2A', 10000),
    _invoice('ST-2B', 2000),
    _invoice('ST-2C', 3000),
    _invoice('ST-2D', -1500),
    _invoice('ST-2E', 5000, voidedAt: _day),
    _invoice('ST-2G', 12345, currency: 'KWD'),
    ...extra,
  ];
  final matches = {
    'ST-2A': InvoiceMatch(
      invoiceId: 'ST-2A',
      paidCents: 4000,
      resolution: 'under_accepted',
      matchedAt: _day,
    ),
    'ST-2B': InvoiceMatch(
      invoiceId: 'ST-2B',
      paidCents: 2000,
      resolution: 'exact',
      matchedAt: _day,
    ),
    'ST-2C': InvoiceMatch(
      invoiceId: 'ST-2C',
      paidCents: 3000,
      resolution: 'exact',
      status: 'pending',
      matchedAt: _day,
    ),
  };
  final ledger = [_payment('P', 7000), _payment('Q', 3000)];
  final receivables = ReceivablesReader(
    matches: matches,
    reminders: const {},
    rules: const DunningRules(),
    now: _day,
    dayOf: (instant) => instant,
  ).read(invoices);
  final unassigned = unassignedPaymentsByCustomer(
    ledger: ledger,
    use: paymentUseOf(
      junction: const [('P', 4000), ('P', 2000), ('Q', 3000)],
      moved: const {},
    ),
    invoices: invoices,
  );
  return customerStatementOfPage(
    customerId: 'm2',
    asOf: _day,
    receivables: receivables,
    unassigned: unassigned['m2'] ?? const [],
    ledgerCurrency: 'EUR',
  );
}

void main() {
  final fixture = File(_fixture).readAsStringSync().trim();

  test('the customer page\'s figures are the shared parity fixture\'s', () {
    expect(_summary(_pageStatement()), jsonDecode(fixture));
  });

  test('pgTAP 398 asserts the server against the same fixture, verbatim', () {
    expect(File(_pgTap).readAsStringSync(), contains("'$fixture'::jsonb"));
  });

  test('a document only one side counts breaks the parity', () {
    // The page now holds one more open document than the fixture, which
    // the server's answer for the fixture's rows does not hold: caught.
    final more = _summary(_pageStatement(extra: [_invoice('ST-2H', 700)]));
    expect(more, isNot(jsonDecode(fixture)));
  });
}
