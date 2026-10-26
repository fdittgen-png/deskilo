// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';

import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'accounting_format.dart';

/// Sage 50 Accounts' **audit-trail CSV** (#669, #2373) — the import shape
/// the British and Irish Sage 50 reads, in the 18 columns of its current
/// template.
///
/// An ACCOUNTANT-EXCHANGE format, like the DATEV file beside it: a
/// person opens it in Sage, reviews the transactions and posts them.
/// Nothing here is told to an authority.
///
/// Two sources write the same rows: the documents (`sage_documents.dart`:
/// an issuer without a local book, nominal codes asked for at export time)
/// and, for a local book, its postings (`sage_postings.dart`, on the
/// book's own chart).
///
/// THREE THINGS SAGE PUNISHES:
///
///  1. The **transaction type** is the first column and decides
///     everything downstream. `SI` is a sales invoice, `SC` a sales
///     credit (positive amounts), `SR` a receipt against the sales
///     ledger, `SP` a payment to a customer, `PI`/`PC`/`PP` the purchase
///     side, `JD`/`JC` a journal debit or credit. Getting SI/SC backwards
///     does not error — it doubles the debtor balance in the wrong
///     direction, silently.
///  2. Sage 50 reads `Net Amount` and `Tax Amount` as SEPARATE columns
///     and does NOT derive one from the other: the split is the
///     document's own, per rate line, each with its own tax code.
///  3. The **Account Reference** keys a row to a customer or supplier
///     record and holds at most eight capitals and digits: the party's
///     number, never an internal id. A party without one stops the file.
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
  /// up of an invoice, journalled off the debtors control (JD/JC, T9).
  String get writeOff => _account('write_off');

  /// The VAT code for the standard rate: Sage's shipped standard rate.
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

  /// The Sage code of a supply in the rate group [group] ('' when its rate
  /// has none) of the VAT category [category]; null when Sage 50 has no
  /// code for it (a rate group it does not know). [euCustomer]: the
  /// customer is a business in another EU member state.
  String? codeOf(String group, String category, {bool euCustomer = false}) =>
      switch (group) {
        'standard' => taxCode,
        'reduced' => _tax('tax_reduced'),
        'zero' => _tax('tax_zero'),
        'exempt' => _tax('tax_exempt'),
        '' => switch (category) {
          'Z' => _tax('tax_zero'),
          'E' => _tax('tax_exempt'),
          'AE' => euCustomer ? sageEuServicesCode : sageReverseChargeCode,
          'K' => _sageEuGoodsCode,
          // A taxed rate no rate row names has no Sage code.
          'S' => null,
          _ => noTax,
        },
        _ => null,
      };
}

/// Sage 50 UK's shipped VAT codes of the cross-border and reverse-charge
/// treatments, fixed by the product's default VAT code table: services to
/// an EU business customer, goods to one, and the domestic reverse charge.
@visibleForTesting
const sageEuServicesCode = 'T22';
const _sageEuGoodsCode = 'T4';
@visibleForTesting
const sageReverseChargeCode = 'T20';

/// Whether [code] is a supply to a customer in another EU member state,
/// which Sage reports with the customer's Country of VAT.
bool sageCrossBorder(String code) =>
    code == sageEuServicesCode || code == _sageEuGoodsCode;

/// The column widths Sage 50's import takes (its audit-trail template).
const int _sageNominalLength = 8;
@visibleForTesting
const int sageReferenceLength = 30;
const int _sageDetailsLength = 60;

/// The 18 columns of Sage 50's audit-trail template, in its order. The
/// names are what its import wizard maps on, so they are not free-form.
@visibleForTesting
const List<String> sageColumns = [
  'Type',
  'Account Reference',
  'Nominal A/C Ref',
  'Department Code',
  'Date',
  'Reference',
  'Details',
  'Net Amount',
  'Tax Code',
  'Tax Amount',
  'Exchange Rate',
  'Extra Reference',
  'User Name',
  'Project Refn',
  'Cost Code Refn',
  'Country of VAT',
  'Report Type',
  'Fund',
];

/// The Account Reference rule of the Sage 50 target (at most eight
/// capitals and digits).
final CustomerIdRule sageAccountReferenceRule = accountingTargets
    .firstWhere((t) => t.id == 'sage50')
    .customerIdRule;

/// One transaction of the audit trail. Amounts are positive minor units
/// of the base currency (the exchange rate is 1).
class SageRow {
  const SageRow({
    required this.type,
    required this.nominal,
    required this.date,
    required this.reference,
    required this.details,
    required this.netMinor,
    required this.taxCode,
    required this.currency,
    this.taxMinor = 0,
    this.account = '',
    this.countryOfVat = '',
  });

  final String type;

  /// The customer's or supplier's Account Reference; '' on a journal.
  final String account;
  final String nominal;
  final DateTime date;
  final String reference;
  final String details;
  final int netMinor;
  final String taxCode;
  final int taxMinor;
  final String currency;

  /// The EU member state of a cross-border supply's customer.
  final String countryOfVat;
}

/// Why the file was not written.
enum SageBlock {
  /// A customer or supplier has no number Sage can take as its Account
  /// Reference.
  accountReference,

  /// A reference or a nominal code is longer than Sage's column.
  fieldTooLong,

  /// Output tax waits for its tax point (`vat_pending`): Sage 50 does not
  /// import deferred tax; its own VAT cash accounting decides that.
  deferredTax,

  /// An amount in another currency than the base currency.
  currency,

  /// A rate line with no Sage tax code.
  taxCode,
}

class SageBlocker {
  const SageBlocker(this.block, this.subject);
  final SageBlock block;
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is SageBlocker && other.block == block && other.subject == subject;

  @override
  int get hashCode => Object.hash(block, subject);

  @override
  String toString() => 'SageBlocker(${block.name}: $subject)';
}

/// The rows of a period, or every blocker that stops them (the rows are
/// then empty: nothing is written around a blocker).
typedef SageAuditTrail = ({List<SageRow> rows, List<SageBlocker> blockers});

/// [rows] with [blockers], and the blockers of the rows' column widths.
SageAuditTrail sageAuditTrail(List<SageRow> rows, Set<SageBlocker> blockers) {
  final all = {
    ...blockers,
    for (final r in rows) ...[
      if (r.reference.length > sageReferenceLength)
        SageBlocker(SageBlock.fieldTooLong, r.reference),
      if (r.nominal.length > _sageNominalLength)
        SageBlocker(SageBlock.fieldTooLong, r.nominal),
    ],
  };
  return all.isEmpty
      ? (rows: rows, blockers: const <SageBlocker>[])
      : (rows: const <SageRow>[], blockers: all.toList());
}

String sageFileName(int year, int month) =>
    'Sage_Audit_${yearMonth(year, month, separator: '')}.csv';

String _cell(String text) =>
    csvCell(text, dialect: CsvDialect.sage, quoteEmpty: true);

String _line(SageRow r) => [
  r.type,
  _cell(r.account),
  r.nominal,
  // No departmental analysis: Sage requires the column.
  '0',
  // Sage 50 is a UK product and reads DD/MM/YYYY: an ISO date imports as
  // a different day for the first twelve of every month.
  dmy(r.date),
  _cell(r.reference),
  _cell(
    r.details.length > _sageDetailsLength
        ? r.details.substring(0, _sageDetailsLength)
        : r.details,
  ),
  minorToText(r.netMinor, r.currency),
  r.taxCode,
  minorToText(r.taxMinor, r.currency),
  // The amounts are the base currency's.
  '1',
  // Extra Reference: the period the row belongs to.
  yearMonth(r.date.year, r.date.month),
  '',
  '',
  '',
  r.countryOfVat,
  '',
  '',
].join(',');

/// The audit-trail CSV of [rows]: the template's header, CRLF and a
/// trailing newline (Sage's importer is a Windows tool and has been seen
/// to drop a last line that does not end in one).
String sageFile(List<SageRow> rows) =>
    '${[sageColumns.join(','), ...rows.map(_line)].join('\r\n')}\r\n';
