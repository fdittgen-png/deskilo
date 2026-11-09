// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) item 3 -- the country decisions of the VAT filing and the
// e-invoice, pinned BEFORE they move into the add-ons.
//
// Four rules, each with every branch it has today:
//   * which e-reporting flow a sale to a business lands in (the buyer's
//     country decides; its VAT-id prefix when the country is blank);
//   * the buyer's legal id (SIREN) a French business-to-business e-invoice
//     asks for -- a refusal from a VAT-registered seller, advice otherwise;
//   * the exemption reason code a seller's VAT regime names, by country;
//   * the nine boxes of the British Making Tax Digital return.
//
// Row -> branch table (the golden files carry the rows):
//   ereporting_flows.txt   country 'FR'/'fr'/' fr ' x VAT id FR..: domestic;
//                          blank country decided by the id prefix; a foreign
//                          country with an FR-prefixed id: abroad; no id: b2c
//   siren_gap.txt          seller FR|fr|' fr '|DE|blank x buyer FR|fr|DE|blank x
//                          company set|blank x legal id set|blank x regime
//   exemption_codes.txt    each regime x FR|fr| fr |DE|blank
//   mtd_boxes.txt          one declaration, the nine HMRC boxes in cents
import 'package:deskilo/core/jurisdiction/installed_invoice_rules.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/domain/fr_ereporting.dart';
import 'package:deskilo/features/money/domain/mtd_boxes.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

const _dir = 'test/parity/golden/vat_country_rules';

Invoice _invoice(InvoiceParty? buyer, {InvoiceParty? seller}) => Invoice(
  id: 'i',
  workspaceId: 'ws',
  memberId: 'm',
  number: 'F-1',
  issuedAt: DateTime.utc(2026, 9, 2, 10),
  period: '2026-09',
  title: 'i',
  lines: const [InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20)],
  totalCents: 12000,
  currency: 'EUR',
  memberName: 'Ada',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  buyerParty: buyer,
  sellerParty: seller,
);

String _flow(String country, String vatId) {
  final report = frEReport(
    [
      _invoice(
        InvoiceParty(name: 'B', country: country, vatId: vatId),
      ),
    ],
    start: DateTime(2026, 9),
    end: DateTime(2026, 9, 30),
    reference: ActiveTaxReference.current,
    dayOf: (instant) => DateTime(instant.year, instant.month, instant.day),
    basis: EReportingBasis(homeCountry: eReportingCountry, onReceipts: false),
  );
  if (report.internationalTransactions.isNotEmpty) return 'international';
  if (report.b2cTransactions.isNotEmpty) return 'b2c';
  return 'none';
}

String _ereportingFlows() {
  const rows = <(String, String)>[
    ('FR', 'FR12345678901'),
    ('fr', 'FR12345678901'),
    (' fr ', 'FR12345678901'),
    ('', 'FR12345678901'),
    ('', 'fr12345678901'),
    ('', 'DE123456789'),
    ('', 'F'),
    ('DE', 'FR12345678901'),
    ('FR', 'DE123456789'),
    ('BE', 'BE0123456789'),
    ('FR', ''),
    ('DE', ''),
    ('', ''),
  ];
  return [
    for (final (country, vatId) in rows)
      "country='$country' vatId='$vatId' -> ${_flow(country, vatId)}",
  ].join('\n');
}

String _sirenGaps() {
  final out = <String>[];
  for (final seller in ['FR', 'fr', ' fr ', 'DE', '']) {
    for (final buyer in ['FR', ' fr ', 'DE', '']) {
      for (final company in ['Acme SAS', '']) {
        for (final legalId in ['123456789', '']) {
          for (final regime in ['vat_registered', 'exempt']) {
            final sellerParty = InvoiceParty(
              name: 'S',
              street: '1 rue',
              city: 'Paris',
              postalCode: '75001',
              country: seller,
              vatRegime: regime,
              taxExemptionReason: 'franchise',
            );
            final buyerParty = InvoiceParty(
              name: 'B',
              company: company,
              country: buyer,
              legalId: legalId,
            );
            final readiness = checkEInvoiceReadiness(
              account: installedInvoiceAccount(),
              invoice: _invoice(buyerParty, seller: sellerParty),
              seller: sellerParty,
              buyer: buyerParty,
              reference: ActiveTaxReference.current,
            );
            final gaps = readiness.gaps
                .where(
                  (g) =>
                      g == EInvoiceGap.missingBuyerLegalId ||
                      g == EInvoiceGap.buyerLegalIdAdvisable,
                )
                .map((g) => g.name)
                .toList();
            out.add(
              "seller='$seller' buyer='$buyer' company='$company' "
              "legalId='$legalId' regime=$regime -> ${gaps.join(',')}",
            );
          }
        }
      }
    }
  }
  return out.join('\n');
}

String _exemptionCodes() => [
  for (final regime in VatRegime.values)
    for (final country in ['FR', 'fr', ' fr ', 'DE', 'GB', ''])
      "${regime.name} country='$country' -> "
          "'${regime.exemptionReasonCode(country, rules: installedNationalInvoiceRules)}'",
].join('\n');

String _mtdBoxes() {
  VatDeclarationLine line(
    double percent,
    int net,
    int vat,
    String direction, {
    String category = 'S',
  }) => VatDeclarationLine(
    percent: percent,
    category: category,
    grossCents: net + vat,
    netCents: net,
    vatCents: vat,
    invoiceCount: 1,
    direction: direction,
  );
  final declaration = VatDeclaration(
    id: 'mtd',
    workspaceId: 'ws',
    periodStart: DateTime.utc(2026, 7),
    periodEnd: DateTime.utc(2026, 9, 30),
    status: 'prepared',
    lines: [
      line(20, 123456, 24691, 'output'),
      line(0, 50050, 0, 'output', category: 'Z'),
      line(20, 40000, 8000, 'input'),
      line(5, 10099, 505, 'input'),
    ],
    totalNetCents: 0,
    totalVatCents: 0,
    currency: 'GBP',
    invoiceCount: 4,
    createdAt: DateTime.utc(2026, 10, 2),
    number: 'MTD-1',
  );
  final cents = mtdBoxCents(declaration, reference: ActiveTaxReference.current);
  return (cents.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      .map((e) => '${e.key}=${e.value}')
      .join('\n');
}

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  test('the country decisions of the VAT filing and the e-invoice are what '
      'they were before they moved', () {
    expectParity(
      dir: _dir,
      text: {
        'ereporting_flows.txt': '${_ereportingFlows()}\n',
        'siren_gap.txt': '${_sirenGaps()}\n',
        'exemption_codes.txt': '${_exemptionCodes()}\n',
        'mtd_boxes.txt': '${_mtdBoxes()}\n',
      },
    );
  });

  test('INTENDED NORMALISATION: an exempt seller whose country is written '
      "' fr ' names the French franchise code, as 'FR' and 'fr' did (the "
      'country is trimmed and upper-cased like every other rule)', () {
    expect(
      VatRegime.exempt.exemptionReasonCode(
        ' fr ',
        rules: installedNationalInvoiceRules,
      ),
      'VATEX-FR-FRANCHISE',
    );
  });
}
