// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3292 — the main Demo space keeps its own book (local authority, euros) but
// had no chart of accounts: every posting of Pézenas was blocked on an
// unmapped role, so the journal, the book reports and the accounting exports
// had nothing to show. It now carries a small French chart (the PCG accounts
// of each booking role) and the mapping of every role, from the start of the
// book's history. The codes are the plan comptable général's own, not a
// choice of the Demo.
import '../../../features/money/domain/book_chart.dart';
import '../data/book_profile_repository.dart';
import '../demo_fixture.dart';
import 'demo_purchase_seed.dart';
import 'demo_setup_seed.dart';

/// The PCG account of each booking role.
const _pcg = <BookRole, (String, String)>{
  BookRole.customers: ('411000', 'Clients'),
  BookRole.revenue: ('706000', 'Prestations de services'),
  BookRole.bank: ('512000', 'Banque'),
  BookRole.vatOutput: ('445710', 'TVA collectée'),
  BookRole.vatInput: ('445660', 'TVA déductible sur autres biens et services'),
  BookRole.expenses: ('606000', 'Achats non stockés'),
  BookRole.suppliers: ('401000', 'Fournisseurs'),
  BookRole.vatPending: ('445800', 'TVA à régulariser'),
  BookRole.writeOff: ('654000', 'Pertes sur créances irrécouvrables'),
  BookRole.cashDiscount: ('665000', 'Escomptes accordés'),
  BookRole.clearing: ('580000', 'Virements internes'),
  BookRole.fees: ('627000', 'Services bancaires'),
  BookRole.fixedAssets: ('218300', 'Matériel de bureau et informatique'),
  BookRole.stock: ('370000', 'Stocks de marchandises'),
  BookRole.prepayments: ('409000', 'Fournisseurs débiteurs'),
  BookRole.deposits: ('275000', 'Dépôts et cautionnements versés'),
};

/// Adds the chart and the mappings of the main space's book to [books].
void _seedDemoMainChart(
  FakeBookProfileRepository books, {
  required String workspaceId,
  required String issuerSiteId,
  required DateTime from,
}) {
  for (final role in BookRole.values) {
    final (code, name) = _pcg[role]!;
    books.accounts.add(
      BookAccount(
        id: '$workspaceId-pcg-$code',
        workspaceId: workspaceId,
        issuerSiteId: issuerSiteId,
        code: code,
        name: name,
        type: role.type,
        isPosting: true,
        origin: AccountOrigin.manual,
        revision: 1,
      ),
    );
    books.mappings.add(
      BookMapping(
        id: '$workspaceId-mapping-${role.wire}',
        workspaceId: workspaceId,
        issuerSiteId: issuerSiteId,
        role: role,
        accountId: '$workspaceId-pcg-$code',
        effectiveFrom: from,
        revision: 1,
      ),
    );
  }
}

/// The main space's book as the Demo composes it: its money and its supplier
/// bills, the book profile, and the chart above (#3292).
FakeBookProfileRepository demoMainBooks(
  DemoFixture fixture,
  DemoPurchasing purchasing,
) {
  final profile = demoBookProfile(fixture.seededAt);
  final books = FakeBookProfileRepository(
    money: fixture.money,
    purchases: purchasing.purchases,
  )..profiles.add(profile);
  _seedDemoMainChart(
    books,
    workspaceId: profile.workspaceId,
    issuerSiteId: profile.issuerSiteId,
    from: profile.effectiveFrom,
  );
  return books;
}
