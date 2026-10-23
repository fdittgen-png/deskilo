// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide's sample invoice: the owner's own identity, an invented
// member and one invented line, built into the same data map a real
// invoice prints from (`invoiceReportData`). It is never issued: it has no
// id and no number, so its clauses qualify live like any preview, and the
// word the caller hands in stands where the number goes. Pure, like every
// builder here: the facts come from presentation/report_facts_of.dart.
import 'invoice.dart';
import 'invoice_legal.dart';
import 'report_data.dart';
import 'report_facts.dart';
import 'report_strings.dart';
import 'vat_rate.dart';
import 'vat_regime.dart';

/// The words a sample invoice prints where a real one prints a number, a
/// member and a position.
typedef SampleInvoiceWords = ({String number, String member, String line});

/// The sample line's price, VAT included: an example for the setup
/// guide's previews, not a price anyone is charged.
abstract final class SampleInvoice {
  static const int grossCents = 12000;
}

/// The rate the sample line is taxed at: the workspace's default rate while
/// it charges VAT, none otherwise, as an issued invoice would tax it.
double sampleVatPercentOf(String vatRegime, List<VatRate> rates) =>
    vatRegimeFromWire(vatRegime) == VatRegime.vatRegistered
    ? rates.where((r) => r.isDefault).firstOrNull?.percent ?? 0
    : 0;

/// The data map of [facts]' sample invoice, [SellerDraft] laid over the
/// stored identity, [words] where a real invoice prints its own.
Map<String, Object?> sampleInvoiceReportData(
  ReportStrings strings,
  SampleInvoiceFacts facts,
  SampleInvoiceWords words,
) {
  final seller = facts.seller;
  final stored = facts.workspace;
  final workspace = seller == null
      ? stored
      : stored?.copyWith(
          vatRegime: seller.vatRegime,
          vatId: seller.vatId.trim(),
          legalId: seller.legalId.trim(),
          invoiceLegal: withSellerLines(
            stored.invoiceLegal,
            legalForm: seller.legalForm,
            registration: seller.registration,
          ),
        );
  final split = vatSplit(SampleInvoice.grossCents, facts.vatPercent);
  final invoice = Invoice(
    id: '',
    workspaceId: workspace?.id ?? '',
    memberId: '',
    number: '',
    issuedAt: facts.now,
    title: '',
    lines: [
      InvoiceLine(
        label: words.line,
        amountCents: SampleInvoice.grossCents,
        vatPercent: facts.vatPercent,
      ),
    ],
    totalCents: SampleInvoice.grossCents,
    currency: workspace?.currencyCode ?? '',
    memberName: words.member,
    memberAddress: '',
    workspaceName: workspace?.name ?? '',
    // What `create_invoice` snapshots as the issuer's address.
    workspaceAddress: workspace?.address ?? '',
    issuerName: '',
    signature: '',
    vatTotals: [
      if (split.vatCents != 0)
        InvoiceVatTotal(
          percent: facts.vatPercent,
          category: VatGroup.standard.category,
          grossCents: SampleInvoice.grossCents,
          netCents: split.netCents,
          vatCents: split.vatCents,
        ),
    ],
  );
  return {
    ...invoiceReportData(
      strings,
      invoice,
      proforma: false,
      copy: false,
      workspace: workspace,
    ),
    'number': words.number,
  };
}
