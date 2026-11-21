// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the reference organisation's quotes: one sent to Atelier Lumi
// (1.5 hours of consulting, valid for a month), one draft for Hanna Weiss that
// was never sent. They are synthetic and belong to the Demo's seller space alone.
import '../../../features/money/domain/standalone_invoice.dart';
import '../data/fake_customer_quotes.dart';

const _consulting = StandaloneLine(
  description: 'Consulting',
  quantity: '1.5',
  unitCode: 'hour',
  unitLabel: 'h',
  unEceCode: 'HUR',
  unitPrice: '80',
);

const _workshop = StandaloneLine(
  description: 'Workshop day',
  quantity: '1',
  unitCode: 'day',
  unitLabel: 'd',
  unEceCode: 'DAY',
  unitPrice: '650',
);

FakeCustomerQuoteRepository seedDemoCustomerQuotes(
  String workspaceId, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  return FakeCustomerQuoteRepository(clock: () => now)
    ..seedSent(
      workspaceId,
      subjectId: 'demo-customer-lumi',
      lines: const [_consulting],
      issuedOn: today.subtract(const Duration(days: 5)),
      validUntil: today.add(const Duration(days: 25)),
      notes: 'Payable within 30 days of the invoice.',
    )
    ..seedDraft(
      workspaceId,
      subjectId: 'demo-customer-weiss',
      lines: const [_workshop],
      issuedOn: today,
      validUntil: today.add(const Duration(days: 30)),
    )
    // a third offer the customer answered: the issuer recorded its acceptance,
    // and it waits to be invoiced
    ..seedSent(
      workspaceId,
      subjectId: 'demo-customer-nordlicht',
      lines: const [_workshop],
      issuedOn: today.subtract(const Duration(days: 12)),
      validUntil: today.add(const Duration(days: 18)),
    )
    ..seedAccepted(workspaceId, 2, decidedOn: today.subtract(const Duration(days: 3)));
}
