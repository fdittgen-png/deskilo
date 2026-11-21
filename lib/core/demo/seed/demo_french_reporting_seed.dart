// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4163 -- what the French Demo shows of the e-reporting: a business with no
// VAT number and a private customer's goods-and-service invoice.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/application/jurisdiction/installed_vat_filings.dart';
import '../data/money_repository.dart';
import 'demo_frozen_capacity.dart';
import 'demo_people_seed.dart';

/// Seeds the two examples into [money], dated from [lastMonth].
void seedDemoFrenchReporting(FakeMoneyRepository money, DateTime lastMonth) {
  // #4163 -- Chiara is a French business with no VAT number: the capacity her
  // invoice froze (not a VAT id) makes it a domestic business sale, reported
  // by its e-invoice and left out of the e-reporting. A private customer's
  // invoice with a goods line and a service line at one rate, the goods
  // delivered three days before it was issued: the e-reporting keeps them two
  // categories, the goods on their delivery day.
  final chiara = money.invoices.indexWhere((x) => x.id == 'demo-invoice-chiara');
  if (chiara >= 0) {
    money.invoices[chiara] = money.invoices[chiara].copyWith(
      buyerParty: InvoiceParty(name: 'Chiara Rossi', country: eReportingCountry),
      legalSnapshot: demoFrozenCapacity('business'),
    );
  }
  CommercialLine? demoLine(String id, String supply, int net, int tax, String? on) =>
      commercialLineFromSnapshot({
        'version': 1,
        'line_id': id,
        'quantity': '1',
        'unit': {'code': 'piece', 'un_ece_code': 'C62', 'label': 'pc'},
        'unit_price': {'amount': '${net / 100}', 'currency': 'EUR', 'basis': 'net', 'base_quantity': '1'},
        'supply': supply,
        'tax_facts': {'tax_point': ?on},
        'amounts': {'currency': 'EUR', 'net_minor': '$net', 'tax_minor': '$tax', 'gross_minor': '${net + tax}'},
      });
  final delivered = lastMonth.subtract(const Duration(days: 3));
  final deliveredOn = isoDay(delivered);
  money.invoices.add(
    Invoice(
      id: 'demo-invoice-goods',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'G-${lastMonth.year}-0001',
      issuedAt: lastMonth,
      title: 'Welcome kit and day pass',
      lines: [
        InvoiceLine(label: 'Welcome kit', amountCents: 3600, vatPercent: 20, commercial: demoLine('demo-goods-1', 'goods', 3000, 600, deliveredOn)),
        InvoiceLine(label: 'Day pass', amountCents: 2400, vatPercent: 20, commercial: demoLine('demo-goods-2', 'general', 2000, 400, null)),
      ],
      totalCents: 6000,
      currency: 'EUR',
      memberName: 'Ada Lindqvist',
      memberAddress: '',
      workspaceName: demoSpaceName,
      workspaceAddress: demoSpaceAddress,
      issuerName: 'Ada Lindqvist',
      signature: 'demo',
      buyerParty: InvoiceParty(name: 'Ada Lindqvist', country: eReportingCountry),
      legalSnapshot: demoFrozenCapacity('consumer'),
      dueOn: lastMonth.add(const Duration(days: 10)),
    ),
  );
  // Paid by transfer the day it was issued, so the register's open amounts
  // and the monthly story stay as they were.
  const paidId = 'demo-payment-demo-invoice-goods';
  money.ledger.add(
    LedgerEntry(
      id: paidId,
      memberId: 'member-1',
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: 6000,
      description: 'Bank transfer',
      period: yearMonth(lastMonth.year, lastMonth.month),
      createdAt: lastMonth,
      occurredOn: lastMonth,
    ),
  );
  money.usePayment(paidId, 6000);
  money.invoiceMatchesStore['demo-invoice-goods'] = InvoiceMatch(
    invoiceId: 'demo-invoice-goods',
    paidCents: 6000,
    resolution: 'exact',
    paymentLedgerId: paidId,
    matchedAt: lastMonth,
    byName: 'Ada Lindqvist',
  );
}
