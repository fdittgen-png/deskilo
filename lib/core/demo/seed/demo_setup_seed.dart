// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the demo's main space saved while it set itself up, beyond its
// people, plan and money: the invoice footer and the reminder rhythm, and
// the profile of the books it keeps. The setup guide reads each of them as
// the evidence of its step (`data/demo_setup_repository.dart`), so Pézenas
// holds every step that applies to it.
import '../../../features/money/domain/book_profile.dart';
import '../../../features/money/domain/dunning.dart';
import '../../../features/money/domain/invoice_pdf_template.dart';
import '../data/money_repository.dart';

/// The space's own invoice footer, and reminders ten days apart.
void seedDemoInvoiceSettings(FakeMoneyRepository money) {
  money
    ..pdfTemplate = const InvoicePdfTemplate(
      footer:
          'Atelier du Marché · 4 place du Marché, 34120 Pézenas · '
          'SIRET 812 345 678 00017',
    )
    ..dunningRules = const DunningRules(betweenDays: 10);
}

/// The books the space keeps itself, from January three years back: the
/// years the demo's history covers.
BookProfile demoBookProfile(DateTime now) => BookProfile(
  id: 'demo-book-profile',
  workspaceId: 'ws-1',
  issuerSiteId: 'demo-site-studio',
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'EUR',
  fiscalYearStartMonth: 1,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime.utc(now.year - 3),
  revision: 1,
);
