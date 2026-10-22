// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/time/date_text.dart';
import '../../../core/time/workspace_time.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'datev_fields.dart';
import 'datev_revenue.dart';
import 'datev_writer.dart';
import 'expense_repartition.dart';
import 'invoice.dart';
import 'ledger_entry.dart';
import 'vat_tax_point.dart';

/// DATEV-Format **EXTF Buchungsstapel** (#669) — the file a German or
/// Austrian *Steuerberater* imports into DATEV Rechnungswesen. It is an
/// ACCOUNTANT-EXCHANGE format, not a filing to an authority: the
/// accountant reviews and posts what it contains. That distinction is
/// why this can be written honestly, while several national SAF-T
/// variants cannot — see the note at the end of this comment.
///
/// Same bargain as the FEC (`fec.dart`): DesKilo does not own a chart of
/// accounts, so the account numbers are ASKED FOR at export time and
/// shown before the file is written, rather than invented. SKR03 is the
/// default because it is the commonest German chart for a small service
/// business; SKR04 is one field change.
///
/// THREE THINGS THE FORMAT GETS UNUSUALLY WRONG IF COPIED CARELESSLY:
///
///  1. `Belegdatum` is **DDMM** — four digits, no year. The year comes
///     from the header's fiscal-year start. A booking exported with a
///     full date lands in the wrong period, silently.
///  2. Amounts use a **comma** decimal separator and are always
///     POSITIVE; direction is carried by `Soll/Haben-Kennzeichen`
///     ('S'/'H'), not by a minus sign.
///  3. `Festschreibung` = 1 marks the batch as final. We write **0**:
///     locking someone else's books is the accountant's decision, not an
///     exporting app's.
///  4. The file is read as **Windows-1252 unless it carries a UTF-8 BOM**.
///     This is the one that corrupts silently and in the accountant's
///     books rather than ours: without the three-byte mark, "Bürogemein-
///     schaft München" imports as "BÃ¼rogemeinschaft MÃ¼nchen" in every
///     Buchungstext and every customer name, and nothing anywhere
///     errors. [_datevBom] is prepended for that reason — and UTF-8 with
///     the mark rather than transcoding to Windows-1252, because a
///     coworking in Munich bills members called Kowalczyk and Škoda, and
///     Windows-1252 cannot spell either.
///  5. The TAX PERIOD of a booking is its Belegdatum's unless field 116,
///     `Datum Zuord. Steuerperiode`, says otherwise (#2355). A
///     subscription invoiced on 25 August for September is taxed in
///     September under § 13 UStG, so its sale carries 30.09. there; one
///     paid in instalments on a cash basis is split into one booking per
///     payment day. The dates come from the tax-point engine
///     (`vat_tax_point.dart`), the same the declaration sums. Every row
///     therefore runs to column 116.
///
/// WHY THERE IS NO GENERALLEDGER-COMPLETE SAF-T HERE. Portugal's
/// accounting SAF-T, Romania's D406 and Poland's JPK_KR all mandate
/// `GeneralLedgerEntries` over a full chart of accounts. This app holds
/// invoices and payments, not a ledger. A file that claimed to be a
/// compliant national SAF-T while omitting the ledger would be a false
/// statement to a tax authority — worse than shipping nothing. The
/// existing `saf_t.dart` is deliberately the invoicing subset and says
/// so.
class DatevAccounts {
  const DatevAccounts({
    String? customers,
    String? revenue,
    String? bank,
    String? vat,
    String? chart,
    String? expenses,
    this.reference,
    this.fiscalYearStart,
  }) : _givenCustomers = customers,
       _givenRevenue = revenue,
       _givenBank = bank,
       _givenVat = vat,
       _givenChart = chart,
       _givenExpenses = expenses;

  /// #2481 -- the snapshot the defaults are read from (the German chart's
  /// rows); the installed one when null.
  final TaxReferenceSet? reference;
  /// The book profile's fiscal-year start, when known (#2365).
  final DateTime? fiscalYearStart;
  final String? _givenCustomers;
  final String? _givenRevenue;
  final String? _givenBank;
  final String? _givenVat;
  final String? _givenChart;
  final String? _givenExpenses;

  TaxReferenceSet get _ref => reference ?? ActiveTaxReference.current;

  /// #2365 — the SKR04 plan's own row when the chart given is SKR04
  /// ([datevChartAccount]), the German chart's otherwise.
  String _default(String role) =>
      (_givenChart == null ? null : datevChartAccount(_ref, _givenChart, role)) ??
      _ref.accountOf('coa', role, 'DE');

  /// SKR03 debtor range starts at 10000. A real chart numbers each
  /// customer; one collective account keeps the export honest about
  /// what the app actually knows.
  String get customers => _givenCustomers ?? _default('customers');

  /// SKR03 8400 — Erlöse 19 % USt. The accountant re-points this when
  /// the workspace charges a different rate or none.
  String get revenue => _givenRevenue ?? _default('revenue');

  /// SKR03 1200 — Bank.
  String get bank => _givenBank ?? _default('bank');

  /// SKR03 1776 — Umsatzsteuer 19 %. Only reached when the workspace is
  /// VAT-registered; an exempt one never books to it.
  String get vat => _givenVat ?? _default('vat');

  /// Named on the export sheet so the accountant can see which chart the
  /// numbers belong to before importing.
  String get chart => _givenChart ?? _default('chart');

  /// #936 — reimbursed expenses and shared costs; 4900 "sonstige
  /// betriebliche Aufwendungen" in SKR03.
  String get expenses => _givenExpenses ?? _default('expenses');

  /// #2365 — SKR03 2400, Forderungsverluste: what the owner gave up of an
  /// invoice, booked at the gross amount it was still owed.
  String get writeOff =>
      datevChartAccount(_ref, chart, 'write_off') ??
      _ref.accountOf('datev', 'write_off', 'DE');

  /// #2365 — the automatic revenue account of the rate [percent]
  /// ([datevRevenueAt]).
  String revenueAt(double percent) =>
      datevRevenueAt(_ref, percent, revenue, chart: chart);

  /// #2365 — header field 27, the Standardkontenrahmen as DATEV writes it:
  /// the digits of the chart's name ('03' for SKR03), empty when it has
  /// none.
  String get skr => datevSkrDigits(chart);

  /// #2365 — the first day of the fiscal year (header field 13): the book
  /// profile's, set with [withFiscalYearStart], else 1 January of [from]'s
  /// year.
  DateTime fiscalYearStartFor(DateTime from) =>
      fiscalYearStart ?? DateTime(from.year);

  /// These accounts with the fiscal year starting on [start].
  DatevAccounts withFiscalYearStart(DateTime start) => DatevAccounts(
    customers: _givenCustomers,
    revenue: _givenRevenue,
    bank: _givenBank,
    vat: _givenVat,
    chart: _givenChart,
    expenses: _givenExpenses,
    reference: reference,
    fiscalYearStart: start,
  );
}

/// The UTF-8 byte-order mark, as the character that encodes to it.
///
/// DATEV's importer treats an unmarked file as Windows-1252. Declaring
/// format version 700 in the header — as this exporter does — is what
/// makes the marked UTF-8 form recognised, so the two belong together.
const String _datevBom = '\u{FEFF}';

/// DATEV expects `EXTF_<something>.csv`; the name is free-form after the
/// prefix, and DATEV keys on the header, not the filename.
String datevFileName(int year, int month) =>
    'EXTF_Buchungsstapel_${yearMonth(year, month, separator: '')}.csv';

/// Builds the EXTF Buchungsstapel for one period.
///
/// [consultantNumber] (Beraternummer) and [clientNumber] (Mandantennummer)
/// come from the accountant — DATEV refuses an import whose numbers do
/// not match the target client, which is a good refusal: it stops a file
/// landing in the wrong company's books.
String buildDatevFile({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required DatevAccounts accounts,
  required DateTime from,
  required DateTime to,
  required DateTime generatedAt,
  required String consultantNumber,
  required String clientNumber,
  String currency = 'EUR',
  String batchName = 'DesKilo',
  /// Length of the account numbers in the target chart (DATEV field 14).
  int accountLength = 4,
  // #936 — the purchases side, and the development mark.
  List<LedgerEntry> ledger = const [],
  List<ExpenseRepartition> repartitions = const [],
  bool development = false,
  List<VatTaxPointAmount>? taxPoints,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) {
  final writer = DatevWriter(
    invoices: invoices,
    matches: matches,
    accounts: accounts,
    from: from,
    to: to,
    generatedAt: generatedAt,
    consultantNumber: consultantNumber,
    clientNumber: clientNumber,
    currency: currency,
    batchName: batchName,
    accountLength: accountLength,
    ledger: ledger,
    repartitions: repartitions,
    development: development,
    taxPoints: taxPoints,
    dayOf: dayOf,
  )
    ..bookInvoices()
    ..bookExpenses()
    ..bookRepartitions();
  return '$_datevBom${writer.lines()}';
}
