// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'billing_rules.dart';
import 'invoice.dart';
import 'invoice_line_cash.dart';
import 'vat_rate.dart';

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
    String? debtors,
    String? sales,
    String? bank,
    String? taxCode,
    this.reference,
  }) : _givenDebtors = debtors,
       _givenSales = sales,
       _givenBank = bank,
       _givenTaxCode = taxCode;

  /// #2481 -- the snapshot the defaults and codes are read from (the `sage`
  /// rows); the installed one when null.
  final TaxReferenceSet? reference;
  final String? _givenDebtors;
  final String? _givenSales;
  final String? _givenBank;
  final String? _givenTaxCode;

  TaxReferenceSet get _data => reference ?? ActiveTaxReference.current;

  String _account(String role) => _data.accountOf('sage', role, 'GB');

  String _tax(String role) => _data.accountOf('sage', role, 'GB', tax: true);

  /// Sage's shipped chart: the Debtors Control Account.
  String get debtors => _givenDebtors ?? _account('debtors');

  /// The Sales nominal — Type A. The accountant re-points this when the
  /// workspace sells something Sage classes differently.
  String get sales => _givenSales ?? _account('sales');

  /// The Bank Current Account.
  String get bank => _givenBank ?? _account('bank');

  /// #2365 -- Sage's Bad Debt Write Off nominal (8100): what the owner gave
  /// up of an invoice, cleared from the debtor by a sales credit (T9).
  String get writeOff => _account('write_off');

  /// The VAT code for the standard rate: Sage's shipped standard rate. The
  /// zero-rated code and the out-of-scope code are the other ends of it —
  /// out of scope is the one an exempt workspace wants, and getting it wrong
  /// puts turnover on a VAT return that should never have seen it.
  String get taxCode => _givenTaxCode ?? _tax('tax_standard');

  /// #2359 — Sage 50 UK's own codes by treatment: zero-rated, exempt and the
  /// reduced rate. A zero-rated supply stays on the VAT return (Box 6) and
  /// so does an exempt one, but they are not the same line on a
  /// partial-exemption calculation. Read from the installed snapshot; an
  /// instance reads the one it was given.
  static String get zeroRatedCode => _installed('tax_zero');
  static String get exemptCode => _installed('tax_exempt');
  static String get reducedCode => _installed('tax_reduced');

  /// The code for a line that carries no tax: out of scope rather than
  /// zero-rated, because a zero-RATED supply still belongs on the VAT return
  /// and an out-of-scope one does not.
  static String get noTaxCode => _installed('tax_none');

  static String _installed(String role) => ActiveTaxReference.current
      .accountOf('sage', role, 'GB', tax: true);

  /// This instance's out-of-scope code.
  String get noTax => _tax('tax_none');

  /// The Sage code of one VAT breakdown line. The reduced code is the one of
  /// the lines taxed in the United Kingdom's `reduced` rate group.
  String codeFor(InvoiceVatTotal total) {
    if (total.category == 'S' &&
        total.percent > 0 &&
        _data.groupOfRate('GB', total.percent, 'S') == 'reduced') {
      return _tax('tax_reduced');
    }
    return switch (total.category) {
      'Z' => _tax('tax_zero'),
      'E' => _tax('tax_exempt'),
      'S' when total.percent > 0 => taxCode,
      'S' => _tax('tax_zero'),
      _ => noTax,
    };
  }
}

String sageFileName(int year, int month) =>
    'Sage_Audit_${yearMonth(year, month, separator: '')}.csv';

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

  // Sage 50 is a UK product and reads DD/MM/YYYY (`dmy`). An ISO date
  // imports as a different day for the first twelve of every month,
  // which is the kind of error nobody notices until a VAT quarter is
  // wrong.

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
        csvCell(customer, dialect: CsvDialect.sage, quoteEmpty: true),
        nominal,
        '0', // no departmental analysis; Sage requires the column
        dmy(on),
        csvCell(reference, dialect: CsvDialect.sage, quoteEmpty: true),
        csvCell(details, dialect: CsvDialect.sage, quoteEmpty: true),
        // #1077 — two decimals is CORRECT here: Sage 50's audit-trail CSV
        // is the British and Irish shape, and both GBP and EUR carry two.
        minorToText(netCents, 'EUR'),
        taxCode,
        minorToText(taxCents, 'EUR'),
      ].join(','));

  for (final invoice in invoices) {
    // A voided invoice was never booked, so it is not exported as one.
    // It is not silently dropped either — the audit trail export carries
    // it, which is the file that is supposed to show what happened.
    if (invoice.isVoided) continue;
    // #831 — a settlement regroups booked revenue.
    if (invoice.kind == InvoiceKind.settlement) continue;

    final customer = customerRef(invoice);
    // The tax split comes from the invoice's own 0072 snapshot, which is
    // what the signature covers. Deriving it here would risk disagreeing
    // with the document the customer holds.
    //
    // #2359 — a credit note is an SC with POSITIVE amounts; a negative SI
    // is read by Sage as an invoice of negative value and the debtor
    // balance moves the wrong way. One row per VAT rate and category, each
    // with its own code (T1, T5, T0, T2).
    int amount(int cents) => invoice.isCreditNote ? cents.abs() : cents;
    final type = invoice.isCreditNote ? 'SC' : 'SI';
    final parts = invoice.vatTotals.isEmpty
        ? [(net: invoice.netCents, tax: invoice.vatCents,
            code: invoice.vatCents > 0 ? accounts.taxCode : accounts.noTax)]
        : [
            for (final t in invoice.vatTotals)
              (net: t.netCents, tax: t.vatCents, code: accounts.codeFor(t)),
          ];
    for (final part in parts) {
      row(
        type: type,
        nominal: accounts.sales,
        on: invoice.issuedAt,
        reference: invoice.number,
        details: invoice.title,
        netCents: amount(part.net),
        taxCode: part.code,
        taxCents: amount(part.tax),
        customer: customer,
      );
    }

    _bookNettedReceipts(row, invoice, accounts, customer);

    final match = matches[invoice.id];
    // A PENDING match is a settlement still awaiting validation (0067).
    // Booking it would put money in Sage the workspace has not agreed it
    // received — the same exclusion the FEC and DATEV make.
    if (match != null && !match.pending) {
      // A receipt carries NO tax: the tax was accounted for on the
      // invoice, and repeating it here would double it on the VAT
      // return. T9 is what says so.
      // #2365 — a refunded credit note is money OUT: SP, never a receipt.
      final (type: settleType, :details) = _settlement(invoice, match);
      row(
        type: settleType,
        nominal: accounts.bank,
        on: match.matchedAt,
        reference: invoice.number,
        details: details,
        netCents: match.paidCents,
        taxCode: accounts.noTax,
        taxCents: 0,
        customer: customer,
      );
      _bookWriteOff(row, invoice, match, accounts, customer);
    }
  }

  // CRLF and a trailing newline: Sage's importer is a Windows tool and
  // has been seen to drop a last line that does not end in one.
  return '${rows.join('\r\n')}\r\n';
}

typedef _SageRow = void Function({
  required String type,
  required String nominal,
  required DateTime on,
  required String reference,
  required String details,
  required int netCents,
  required String taxCode,
  required int taxCents,
  required String customer,
});

/// #2365 -- the payments an invoice itself netted were money in on its
/// date; without them the debtor stays open on a document whose total is
/// already net of them. A receipt carries no tax (T9).
void _bookNettedReceipts(
  _SageRow row,
  Invoice invoice,
  SageAccounts accounts,
  String customer,
) {
  if (invoice.isCreditNote) return;
  for (final line in invoice.lines.where((l) => l.isMoneyIn)) {
    row(
      type: 'SR',
      nominal: accounts.bank,
      on: invoice.issuedAt,
      reference: invoice.number,
      details: 'Payment ${invoice.number}',
      netCents: -line.amountCents,
      taxCode: accounts.noTax,
      taxCents: 0,
      customer: customer,
    );
  }
}

/// #2365 -- what a standing match is in Sage: a receipt (SR), or for a
/// refunded credit note a payment to the customer (SP).
({String type, String details}) _settlement(Invoice invoice, InvoiceMatch m) =>
    refundedCents(invoice, m) > 0
    ? (type: 'SP', details: 'Refund ${invoice.number}')
    : (type: 'SR', details: 'Payment ${invoice.number}');

/// #2365 -- the rest of an invoice the owner gave up: a sales credit (SC)
/// against the customer posted to the bad-debt nominal, positive and
/// without tax (T9), on the write-off day. The VAT bad debt relief is the
/// accountant's.
void _bookWriteOff(
  _SageRow row,
  Invoice invoice,
  InvoiceMatch match,
  SageAccounts accounts,
  String customer,
) {
  final owed = invoice.totalCents - match.paidCents;
  final day = match.writeoffAt;
  if (day == null || owed <= 0) return;
  row(
    type: 'SC',
    nominal: accounts.writeOff,
    on: day,
    reference: invoice.number,
    details: 'Write-off ${invoice.number}',
    netCents: owed,
    taxCode: accounts.noTax,
    taxCents: 0,
    customer: customer,
  );
}
