// SPDX-License-Identifier: 0BSD
import 'invoice.dart';

/// Sage 50's **audit-trail CSV** (#669) — the import shape the British
/// and Irish Sage lines read.
///
/// An ACCOUNTANT-EXCHANGE format, like the DATEV file beside it: a
/// person opens it in Sage, reviews the transactions and posts them.
/// Nothing here is told to an authority, which is exactly why it can be
/// produced honestly by an app that keeps no ledger.
///
/// Same bargain as the FEC and DATEV: the nominal codes are ASKED FOR at
/// export time and shown before the file is written. Sage's defaults
/// below are the standard nominal ranges of its own shipped chart, which
/// is what most small businesses run — but a chart is the accountant's,
/// and every wrong code is unbooked by hand.
///
/// TWO THINGS SAGE PUNISHES:
///
///  1. The **transaction type** is the first column and decides
///     everything downstream. `SI` is a sales invoice, `SC` a sales
///     credit, `SR` a receipt against the sales ledger. Getting SI/SC
///     backwards does not error — it doubles the debtor balance in the
///     wrong direction, silently.
///  2. Sage 50 reads `Net` and `Tax` as SEPARATE columns and does NOT
///     derive one from the other. DesKilo's prices are VAT-inclusive, so
///     the split has to happen here; handing it the gross as `Net` would
///     overstate turnover by the tax on every line.
class SageAccounts {
  const SageAccounts({
    this.debtors = '1100',
    this.sales = '4000',
    this.bank = '1200',
    this.taxCode = 'T1',
  });

  /// Sage's shipped chart: 1100 Debtors Control Account.
  final String debtors;

  /// 4000 Sales — Type A. The accountant re-points this when the
  /// workspace sells something Sage classes differently.
  final String sales;

  /// 1200 Bank Current Account.
  final String bank;

  /// The VAT code for the standard rate. `T1` is Sage's shipped standard
  /// rate; `T0` is zero-rated and `T9` is outside the scope of VAT —
  /// which is the one an exempt workspace wants, and getting it wrong
  /// puts turnover on a VAT return that should never have seen it.
  final String taxCode;

  /// The code for a line that carries no tax. `T9` — out of scope —
  /// rather than `T0`, because a zero-RATED supply still belongs on the
  /// VAT return and an out-of-scope one does not.
  static const String noTaxCode = 'T9';
}

String sageFileName(int year, int month) =>
    'Sage_Audit_$year${month.toString().padLeft(2, '0')}.csv';

/// Builds the Sage 50 audit-trail CSV for one period.
///
/// [reference] is what shows in Sage's Reference column — the invoice
/// number, which is how an accountant ties a row back to a document.
String buildSageFile({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required SageAccounts accounts,
  required String Function(Invoice invoice) customerRef,
}) {
  // Sage's own import header. The names are what its wizard maps on, so
  // they are not free-form.
  const header = 'Type,Account Reference,Nominal A/C Ref,Department Code,'
      'Date,Reference,Details,Net Amount,Tax Code,Tax Amount';

  String q(String value) =>
      '"${value.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll('"', "'")}"';
  String money(int cents) => (cents / 100).toStringAsFixed(2);
  // Sage 50 is a UK product and reads DD/MM/YYYY. An ISO date imports as
  // a different day for the first twelve of every month, which is the
  // kind of error nobody notices until a VAT quarter is wrong.
  String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  final rows = <String>[header];

  void row({
    required String type,
    required String nominal,
    required DateTime on,
    required String reference,
    required String details,
    required int netCents,
    required String taxCode,
    required int taxCents,
    required String customer,
  }) =>
      rows.add([
        type,
        q(customer),
        nominal,
        '0', // no departmental analysis; Sage requires the column
        date(on),
        q(reference),
        q(details),
        money(netCents),
        taxCode,
        money(taxCents),
      ].join(','));

  for (final invoice in invoices) {
    // A voided invoice was never booked, so it is not exported as one.
    // It is not silently dropped either — the audit trail export carries
    // it, which is the file that is supposed to show what happened.
    if (invoice.isVoided) continue;

    final customer = customerRef(invoice);
    // The tax split comes from the invoice's own 0072 snapshot, which is
    // what the signature covers. Deriving it here would risk disagreeing
    // with the document the customer holds.
    final net = invoice.netCents;
    final tax = invoice.vatCents;
    row(
      type: 'SI',
      nominal: accounts.sales,
      on: invoice.issuedAt,
      reference: invoice.number,
      details: invoice.title,
      netCents: net,
      taxCode: tax > 0 ? accounts.taxCode : SageAccounts.noTaxCode,
      taxCents: tax,
      customer: customer,
    );

    final match = matches[invoice.id];
    // A PENDING match is a settlement still awaiting validation (0067).
    // Booking it would put money in Sage the workspace has not agreed it
    // received — the same exclusion the FEC and DATEV make.
    if (match != null && !match.pending) {
      // A receipt carries NO tax: the tax was accounted for on the
      // invoice, and repeating it here would double it on the VAT
      // return. T9 is what says so.
      row(
        type: 'SR',
        nominal: accounts.bank,
        on: match.matchedAt,
        reference: invoice.number,
        details: 'Payment ${invoice.number}',
        netCents: match.paidCents,
        taxCode: SageAccounts.noTaxCode,
        taxCents: 0,
        customer: customer,
      );
    }
  }

  // CRLF and a trailing newline: Sage's importer is a Windows tool and
  // has been seen to drop a last line that does not end in one.
  return '${rows.join('\r\n')}\r\n';
}
