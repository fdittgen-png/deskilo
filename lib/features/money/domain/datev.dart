// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/time/workspace_time.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'datev_fields.dart';
import 'datev_problem.dart';
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
///  3. `Festschreibung` = 1 marks the batch as final. It is written only
///     for a month that lies in a period the space closed: an open month
///     stays 0, the accountant's to lock.
///  4. The file is read as **Windows-1252 unless it carries a UTF-8 BOM**.
///     This is the one that corrupts silently and in the accountant's
///     books rather than ours: without the three-byte mark, "Bürogemein-
///     schaft München" imports as "BÃ¼rogemeinschaft MÃ¼nchen" in every
///     Buchungstext and every customer name, and nothing anywhere
///     errors. [datevBom] is prepended for that reason — and UTF-8 with
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
    String? revenue,
    String? bank,
    String? chart,
    String? expenses,
    this.reference,
    this.fiscalYearStart,
  }) : _givenRevenue = revenue,
       _givenBank = bank,
       _givenChart = chart,
       _givenExpenses = expenses;

  /// #2481 -- the snapshot the defaults are read from (the German chart's
  /// rows); the installed one when null.
  final TaxReferenceSet? reference;
  /// The book profile's fiscal-year start, when known (#2365).
  final DateTime? fiscalYearStart;
  final String? _givenRevenue;
  final String? _givenBank;
  final String? _givenChart;
  final String? _givenExpenses;

  TaxReferenceSet get _ref => reference ?? ActiveTaxReference.current;

  /// #2365 — the SKR04 plan's own row when the chart given is SKR04
  /// ([datevChartAccount]), the German chart's otherwise.
  String _default(String role) =>
      (_givenChart == null ? null : datevChartAccount(_ref, _givenChart, role)) ??
      _ref.accountOf('coa', role, 'DE');

  /// SKR03 8400 — Erlöse 19 % USt. The accountant re-points this when
  /// the workspace charges a different rate or none.
  String get revenue => _givenRevenue ?? _default('revenue');

  /// SKR03 1200 — Bank.
  String get bank => _givenBank ?? _default('bank');

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

  /// Every automatic revenue account of the chart: the standard rate's and
  /// each rate group's `revenue:<group>` row.
  Set<String> get _automaticRevenue => {
    _default('revenue'),
    for (final row in _ref.ownRows(TaxDomain.rate, 'DE'))
      ?datevAutomaticRevenue(
        _ref,
        chart,
        (row.value as RateValue).group,
        _default('revenue'),
      ),
  };

  /// #2375 — where a position at [percent] is booked: on the rate's
  /// automatic account with no BU-Schlüssel (DATEV derives the tax from
  /// the account), on any other account with the rate group's key. An
  /// account that is automatic for another rate, or a group the reference
  /// has no key for, gets none here; [taxGapAt] names it.
  DatevRevenueTarget revenueTargetAt(double percent) {
    final account = revenueAt(percent);
    if (_automaticRevenue.contains(account)) {
      return (account: account, taxKey: '');
    }
    final group = _ref.groupOfRate('DE', percent, 'S');
    return (account: account, taxKey: datevGroupTaxKey(_ref, group) ?? '');
  }

  /// Why a position at [percent] cannot be booked as DATEV posts it: its
  /// account is automatic for another rate, or it needs a BU-Schlüssel the
  /// reference does not hold; null when it can.
  DatevProblem? taxGapAt(double percent) {
    final account = revenueAt(percent);
    final group = _ref.groupOfRate('DE', percent, 'S');
    final own = datevAutomaticRevenue(_ref, chart, group, _default('revenue'));
    if (account == own) return null;
    if (_automaticRevenue.contains(account)) {
      return DatevAutomaticClash(percent, account);
    }
    return datevGroupTaxKey(_ref, group) == null
        ? DatevTaxKeyMissing(percent, account)
        : null;
  }

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
    revenue: _givenRevenue,
    bank: _givenBank,
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
const String datevBom = '\u{FEFF}';


/// Builds the EXTF Buchungsstapel for one period.
///
/// [consultantNumber] (Beraternummer) and [clientNumber] (Mandantennummer)
/// come from the accountant — DATEV refuses an import whose numbers do
/// not match the target client, which is a good refusal: it stops a file
/// landing in the wrong company's books.
String buildDatevFile(DatevRequest request) =>
    '$datevBom${datevWriterOf(request).lines()}';

/// The writer of [request] with every booking made: what [buildDatevFile]
/// writes, and what an export cuts into its Buchungsstapel.
DatevWriter datevWriterOf(DatevRequest request) => DatevWriter(
    invoices: request.invoices,
    matches: request.matches,
    accounts: request.accounts,
    from: request.from,
    to: request.to,
    generatedAt: request.generatedAt,
    consultantNumber: request.consultantNumber,
    clientNumber: request.clientNumber,
    currency: request.currency,
    batchName: request.batchName,
    accountLength: request.accountLength,
    ledger: request.ledger,
    repartitions: request.repartitions,
    development: request.development,
    taxPoints: request.taxPoints,
    dayOf: request.dayOf,
    detail: request.detail,
    slice: request.slice,
  )
    ..bookInvoices()
    ..bookExpenses()
    ..bookRepartitions()
    ..bookSupplierBookings();

/// #2492 — what one Buchungsstapel is built from.
class DatevRequest {
  const DatevRequest({
    required this.invoices,
    required this.matches,
    required this.accounts,
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.consultantNumber,
    required this.clientNumber,
    required this.detail,
    this.currency = 'EUR',
    this.batchName = 'DesKilo',
    this.accountLength = 4,
    this.ledger = const [],
    this.repartitions = const [],
    this.development = false,
    this.taxPoints,
    this.dayOf = WorkspaceTime.dateOf,
    this.slice,
  });

  /// This request with each member on the Debitor [debtors] names.
  DatevRequest withDebtors(Map<String, String> debtors) =>
      _copy(detail: detail.withDebtors(debtors));

  /// This request with the supplier side [bookings] (#2375).
  DatevRequest withSupplierBookings(List<DatevBooking> bookings) =>
      _copy(detail: detail.withSupplierBookings(bookings));

  /// This request for the Buchungsstapel [slice] alone, under the header
  /// [accounts] (its fiscal-year start) and the name [batchName].
  DatevRequest withSlice(
    DatevSlice slice, {
    required DatevAccounts accounts,
    required String batchName,
  }) => _copy(slice: slice, accounts: accounts, batchName: batchName);

  DatevRequest _copy({
    DatevDetail? detail,
    DatevSlice? slice,
    DatevAccounts? accounts,
    String? batchName,
  }) => DatevRequest(
    invoices: invoices,
    matches: matches,
    accounts: accounts ?? this.accounts,
    from: from,
    to: to,
    generatedAt: generatedAt,
    consultantNumber: consultantNumber,
    clientNumber: clientNumber,
    detail: detail ?? this.detail,
    currency: currency,
    batchName: batchName ?? this.batchName,
    accountLength: accountLength,
    ledger: ledger,
    repartitions: repartitions,
    development: development,
    taxPoints: taxPoints,
    dayOf: dayOf,
    slice: slice ?? this.slice,
  );

  final List<Invoice> invoices;
  final Map<String, InvoiceMatch> matches;
  final DatevAccounts accounts;
  final DateTime from;
  final DateTime to;
  final DateTime generatedAt;
  final String consultantNumber;
  final String clientNumber;
  final String currency;
  final String batchName;

  /// Length of the account numbers in the target chart (DATEV field 14).
  final int accountLength;

  /// #936 — the purchases side, and the development mark.
  final List<LedgerEntry> ledger;
  final List<ExpenseRepartition> repartitions;
  final bool development;
  final List<VatTaxPointAmount>? taxPoints;
  final DateTime Function(DateTime instant) dayOf;

  /// #2375 — the sub-ledger detail of every row: each member's Debitor,
  /// the cost centre, the voucher links.
  final DatevDetail detail;

  /// #2375 — the one Buchungsstapel of the bookings to write; null writes
  /// every booking of [from]..[to] in one.
  final DatevSlice? slice;
}

/// The journal a Buchungsstapel holds: the sales side, or every booking
/// that moves the bank account, and (#2375) the supplier bills, so the
/// accountant imports each on its own.
enum DatevJournal { sales, bank, purchases }

/// #2375 — one Buchungsstapel of an export: the bookings of [journal] dated
/// [from]..[to], the [part]-th run of [rowsPerPart] of them, written as
/// final (Festschreibung) when [locked].
class DatevSlice {
  const DatevSlice({
    required this.journal,
    required this.from,
    required this.to,
    this.part = 0,
    this.rowsPerPart = DatevFormatRules.rowsPerBatch,
    this.locked = false,
  });

  final DatevJournal journal;
  final DateTime from;
  final DateTime to;
  final int part;
  final int rowsPerPart;
  final bool locked;
}

/// #2375 — what makes each row a sub-ledger row: the member's Debitor, the
/// site as cost centre, the voucher details and, when the vouchers travel
/// with the file, their link. The cost centre and the links are the
/// person's choices in the DATEV dialog; the Debitors are the export's.
class DatevDetail {
  const DatevDetail({
    required this.defaultCostCentre,
    required this.voucherLinks,
    this.debtors = const {},
    this.supplierBookings = const [],
  });

  /// This detail with [debtors].
  DatevDetail withDebtors(Map<String, String> debtors) => DatevDetail(
    defaultCostCentre: defaultCostCentre,
    voucherLinks: voucherLinks,
    debtors: debtors,
    supplierBookings: supplierBookings,
  );

  /// This detail with the supplier side [bookings], already on the
  /// Kreditors (datev_creditors.dart).
  DatevDetail withSupplierBookings(List<DatevBooking> bookings) => DatevDetail(
    defaultCostCentre: defaultCostCentre,
    voucherLinks: voucherLinks,
    debtors: debtors,
    supplierBookings: bookings,
  );

  /// The posting engine's purchases entries as rows against each
  /// supplier's Kreditor: bills, credit notes and their payments.
  final List<DatevBooking> supplierBookings;

  /// The Debitor of each member, by member id.
  final Map<String, String> debtors;

  /// KOST1 of a row whose document names no site, and of a row with no
  /// document.
  final String defaultCostCentre;
  final bool voucherLinks;
}
