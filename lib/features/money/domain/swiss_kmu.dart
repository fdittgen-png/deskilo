// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';

import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import '../../../core/text/number_text.dart';
import '../../../core/time/date_text.dart';
import 'billing_rules.dart';
import 'invoice.dart';
import 'vat_rate.dart';

/// The accountant's booking file of a Swiss space (#2360): one row per
/// booking, with the Swiss accounts of the Kontenrahmen KMU and the
/// Ziffer of the MWST-Abrechnung each turnover lands on.
///
/// An ACCOUNTANT-EXCHANGE file, like the DATEV and Sage ones: a person
/// reviews and posts what it holds, nothing is told to an authority. It is
/// NOT a native import template of Banana or bexio — neither publishes its
/// column specification, and a file claiming to be theirs would be a guess.
/// What it offers instead is a flat, self-describing journal whose columns
/// (date, document, text, debit account, credit account, amount, VAT rate,
/// VAT amount, Ziffer) are the ones their import wizards let a person map.
///
/// The accounts are ASKED FOR at export time and shown before the file is
/// written, like every file of this kind; the defaults are the suggestions
/// of the KMU chart (`ActiveTaxReference.chartOf('CH')`).
class SwissKmuAccounts {
  const SwissKmuAccounts({
    this.debtors = '1100',
    this.bank = '1020',
    this.revenueNormal = '3400',
    this.revenueReduced = '3401',
    this.revenueExempt = '3402',
    this.vatDue = '2200',
  });

  /// Forderungen aus Lieferungen und Leistungen.
  final String debtors;

  /// Bank (Kontokorrent).
  final String bank;

  /// Dienstleistungsertrag at the normal rate.
  final String revenueNormal;

  /// Dienstleistungsertrag at the reduced and the accommodation rate.
  final String revenueReduced;

  /// Dienstleistungsertrag from the exempt letting (art. 21 MWSTG), exports
  /// and services abroad.
  final String revenueExempt;

  /// Geschuldete MWST (Umsatzsteuer).
  final String vatDue;

  /// The revenue account of one VAT breakdown line.
  String revenueFor(InvoiceVatTotal total) {
    if (total.category == 'S' && total.percent > 0) {
      return total.percent >= 7 ? revenueNormal : revenueReduced;
    }
    return revenueExempt;
  }
}

/// The Ziffer of the MWST-Abrechnung a breakdown line lands on: the rate
/// line of its turnover (303, 313, 343) or the deduction it falls under
/// (220 exempt, 221 abroad, 230 exempt under art. 21); '' for a rate the
/// form has no line for.
@visibleForTesting
String swissZifferOf(InvoiceVatTotal total) => switch (total.category) {
  'S' when total.percent == 8.1 => '303',
  'S' when total.percent == 2.6 => '313',
  'S' when total.percent == 3.8 => '343',
  'Z' || 'G' => '220',
  'AE' || 'O' => '221',
  'E' => '230',
  _ => '',
};

String swissKmuFileName(int year, int month) =>
    'MWST_Buchungen_${yearMonth(year, month, separator: '')}.csv';

const _header =
    'Datum;Beleg;Text;Soll;Haben;Betrag;Waehrung;MWST-Satz;MWST-Betrag;'
    'MWST-Konto;Ziffer;Kunde';

/// The journal of [invoices] and their payments, a UTF-8 file with a byte
/// order mark (Excel and the Swiss accounting tools read umlauts with it),
/// `;` separated, `.` decimals, dates as `dd.MM.yyyy`, CRLF.
///
/// An invoice is debtors / revenue, one row per VAT rate and category; the
/// amount is the gross, the VAT amount and the rate say how the tool splits
/// it. A credit note swaps the two accounts and keeps the amounts positive.
/// A payment is bank / debtors with no VAT. A voided invoice was never
/// booked; a settlement regroups booked revenue — both are left out, as in
/// the other exchange files.
String buildSwissKmuFile({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required SwissKmuAccounts accounts,
  required String Function(Invoice invoice) customerRef,
}) {
  final rows = <String>[_header];

  String dotted(DateTime on) =>
      '${twoDigits(on.day)}.${twoDigits(on.month)}.${on.year}';

  void row({
    required DateTime on,
    required String reference,
    required String text,
    required String debit,
    required String credit,
    required int cents,
    required String currency,
    String rate = '',
    String vat = '',
    String vatAccount = '',
    String ziffer = '',
    required String customer,
  }) => rows.add([
    dotted(on),
    csvCell(reference),
    csvCell(text),
    debit,
    credit,
    minorToText(cents, currency),
    currency,
    rate,
    vat,
    vatAccount,
    ziffer,
    csvCell(customer),
  ].join(';'));

  for (final invoice in invoices) {
    if (invoice.isVoided || invoice.kind == InvoiceKind.settlement) continue;
    final customer = customerRef(invoice);
    final parts = invoice.vatTotals.isEmpty
        ? [
            InvoiceVatTotal(
              // A pre-0072 invoice carries no breakdown: the rate is read
              // back from its own figures, to one decimal.
              percent: invoice.vatCents > 0 && invoice.netCents > 0
                  ? (invoice.vatCents * 1000 / invoice.netCents).round() / 10
                  : 0,
              category: invoice.vatCents > 0 ? 'S' : 'O',
              grossCents: invoice.netCents + invoice.vatCents,
              netCents: invoice.netCents,
              vatCents: invoice.vatCents,
            ),
          ]
        : invoice.vatTotals;
    for (final part in parts) {
      final revenue = accounts.revenueFor(part);
      final credit = invoice.isCreditNote;
      row(
        on: invoice.issuedAt,
        reference: invoice.number,
        text: invoice.title,
        debit: credit ? revenue : accounts.debtors,
        credit: credit ? accounts.debtors : revenue,
        cents: (part.netCents + part.vatCents).abs(),
        currency: invoice.currency,
        rate: part.category == 'S' ? percentText(part.percent) : '',
        vat: minorToText(part.vatCents.abs(), invoice.currency),
        vatAccount: part.vatCents != 0 ? accounts.vatDue : '',
        ziffer: swissZifferOf(part),
        customer: customer,
      );
    }
    final match = matches[invoice.id];
    // A pending match is a settlement still awaiting validation: not booked.
    if (match != null && !match.pending) {
      row(
        on: match.matchedAt,
        reference: invoice.number,
        text: 'Zahlung ${invoice.number}',
        debit: accounts.bank,
        credit: accounts.debtors,
        cents: match.paidCents,
        currency: invoice.currency,
        customer: customer,
      );
    }
  }
  return '\u{FEFF}${rows.join('\r\n')}\r\n';
}
