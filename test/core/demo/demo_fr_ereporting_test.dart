// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4163 -- the French Demo's e-reporting, from the Demo's own invoices: a
// business customer with no VAT number is a domestic business (left to its
// e-invoice), a private customer's goods and service at one rate are two
// categories, the goods on their delivery day, and nothing is unresolved.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/domain/fr_ereporting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  test('the Demo reports a business with no VAT id as domestic and keeps goods apart from services', () async {
    final journey = DemoJourney.start();
    addTearDown(journey.dispose);
    final money = journey.fixture.money;
    final invoices = await money.fetchInvoices('ws-1');
    final goods = invoices.singleWhere((i) => i.id == 'demo-invoice-goods');
    final chiara = invoices.singleWhere((i) => i.id == 'demo-invoice-chiara');
    final month = WorkspaceTime.dateOf(goods.issuedAt);
    final report = frEReport(
      invoices,
      start: DateTime(month.year, month.month),
      end: DateTime(month.year, month.month + 1, 0),
      matches: {
        for (final e in money.invoiceMatchesStore.entries) e.key: e.value,
      },
      basis: EReportingBasis(homeCountry: eReportingCountry, onReceipts: false),
      dayOf: WorkspaceTime.dateOf,
      reference: ActiveTaxReference.current,
    );
    expect(report.unresolved, isEmpty, reason: 'every Demo invoice froze its capacity');
    expect(chiara.buyerParty?.vatId ?? '', isEmpty);
    final mine = report.b2cTransactions.where((t) => t.on.month == month.month).toList();
    expect(
      mine.where((t) => t.category == 'TLB1').map((t) => (t.on.day, t.netCents, t.vatCents)),
      [(goods.issuedAt.day - 3, 3000, 600)],
      reason: 'the goods on their delivery day',
    );
    // aggregated per day with the Demo's other private services of that day
    expect(
      mine.where((t) => t.category == 'TPS1' && t.on.day == goods.issuedAt.day && t.netCents >= 2000),
      isNotEmpty,
      reason: 'the service on the invoice day',
    );
    // Chiara's invoice (a business, no VAT id) is not in the B2C flow
    expect(report.b2cTransactions.fold(0, (s, t) => s + t.count) >= 2, isTrue);
    expect(report.internationalTransactions.any((t) => t.invoiceNumber == chiara.number), isFalse);
  });
}
