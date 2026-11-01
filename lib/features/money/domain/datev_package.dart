// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The DATEV export as an accountant imports it: one Buchungsstapel per
// calendar month and journal (the sales, and every booking that moves the
// bank), each at most DATEV's row limit, each under the header of its own
// month (fiscal-year start from the book profile, Festschreibung when the
// month is closed), the member's Debitor on every customer row, and the
// Debitoren-Stammdaten that name them. Nothing is written while anything
// would make DATEV refuse or misbook a row: the problems are returned
// instead.
import '../../../core/time/date_text.dart';
import 'billing_rules.dart';
import 'book_profile.dart';
import 'datev.dart';
import 'datev_creditors.dart';
import 'datev_debtors.dart';
import 'datev_fields.dart';
import 'datev_problem.dart';
import 'datev_stammdaten.dart';
import 'datev_writer.dart';
import 'invoice.dart';
import 'number_sequence.dart';

/// What one DATEV export is built from: the request of the year with the
/// person's numbers and accounts, and what its sub-ledger rows need.
class DatevPackageRequest {
  const DatevPackageRequest({
    required this.request,
    required this.bookProfiles,
    required this.closed,
    required this.memberSequence,
    required this.debtorBase,
    this.memberNumbers = const {},
    this.memberNames = const {},
    this.purchases,
    this.rowsPerBatch = DatevFormatRules.rowsPerBatch,
  });

  /// The year's books, accounts and the accountant's numbers.
  final DatevRequest request;

  /// The book profiles of the same snapshot: each month's fiscal-year start.
  final List<BookProfile> bookProfiles;

  /// Whether every day of [from]..[to] lies in a closed period.
  final bool Function(DateTime from, DateTime to) closed;

  /// The space's member number series: the counter each Debitor is
  /// numbered from.
  final NumberSequence memberSequence;

  /// The Debitor of member counter 0: the accountant's first free one.
  final int debtorBase;

  /// Member numbers and names today, for a member whose documents froze
  /// none.
  final Map<String, String> memberNumbers;
  final Map<String, String> memberNames;

  /// The purchases side the posting engine made, for a space that keeps a
  /// local book; null when none was read (the export then has no supplier
  /// rows).
  final DatevPurchases? purchases;
  final int rowsPerBatch;
}

/// The files of a DATEV export by name, or what stopped it.
class DatevPackage {
  const DatevPackage._({
    this.files = const {},
    this.problems = const [],
    this.vouchers = const [],
    this.rows = 0,
  });

  /// Each Buchungsstapel and the Stammdaten, by file name, BOM included.
  final Map<String, String> files;
  final List<DatevProblem> problems;

  /// The documents whose rows link a voucher.
  final List<Invoice> vouchers;

  /// The booking rows over every Buchungsstapel.
  final int rows;
}

/// `EXTF_Buchungsstapel_<yyyymm>_<journal>[_<part>].csv`.
String _batchFileName(DatevSlice slice) {
  final part = slice.part == 0 ? '' : '_${slice.part + 1}';
  return 'EXTF_Buchungsstapel_'
      '${yearMonth(slice.from.year, slice.from.month, separator: '')}'
      '_${slice.journal.name}$part.csv';
}

/// The name a Buchungsstapel of [journal] is listed under in DATEV.
String _batchName(DatevJournal journal, String name) => switch (journal) {
  DatevJournal.sales => 'Erlöse $name',
  DatevJournal.bank => 'Bank $name',
  DatevJournal.purchases => 'Eingang $name',
};

DatevPackage buildDatevPackage(DatevPackageRequest p) {
  final r = p.request;
  final header = _numberProblems(r);
  if (header.isNotEmpty) return DatevPackage._(problems: header);
  final debtors = DatevDebtors.of(
    invoices: r.invoices,
    ledger: r.ledger,
    accountLength: r.accountLength,
    sequence: p.memberSequence,
    base: p.debtorBase,
    memberNumbers: p.memberNumbers,
    memberNames: p.memberNames,
  );
  if (debtors.problems.isNotEmpty) {
    return DatevPackage._(problems: debtors.problems);
  }
  final purchases = p.purchases;
  if (purchases != null && purchases.blocked.isNotEmpty) {
    return DatevPackage._(problems: [DatevBooksBlocked(purchases.blocked)]);
  }
  final creditors = DatevCreditors.of(
    purchases ?? const DatevPurchases(creditorBase: 0),
    accountLength: r.accountLength,
  );
  if (creditors.problems.isNotEmpty) {
    return DatevPackage._(problems: creditors.problems);
  }
  final detailed = r
      .withDebtors(debtors.accounts)
      .withSupplierBookings(creditors.bookings);
  final writer = datevWriterOf(detailed);
  final problems = [
    ..._taxProblems(r),
    ..._accountProblems(
      writer.bookings,
      {...debtors.accounts.values, ...creditors.parties.keys},
      r.accountLength,
    ),
    ..._referenceProblems(writer),
    if (_fiscalStartsDisagree(p, writer.bookings))
      const DatevFiscalYearStarts(),
  ];
  if (problems.isNotEmpty) return DatevPackage._(problems: problems);

  final counts = <(int, int, DatevJournal), int>{};
  for (final b in writer.bookings) {
    final key = (b.date.year, b.date.month, writer.journalOf(b));
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byYear = a.$1.compareTo(b.$1);
      if (byYear != 0) return byYear;
      final byMonth = a.$2.compareTo(b.$2);
      return byMonth != 0 ? byMonth : a.$3.index.compareTo(b.$3.index);
    });
  final files = <String, String>{};
  DateTime? firstStart;
  for (final (year, month, journal) in keys) {
    final from = DateTime(year, month);
    final to = DateTime(year, month + 1, 0);
    final start =
        datevProfileFiscalStart(p.bookProfiles, from, to) ?? DateTime(year);
    firstStart ??= start;
    final parts =
        (counts[(year, month, journal)]! + p.rowsPerBatch - 1) ~/
        p.rowsPerBatch;
    for (var part = 0; part < parts; part++) {
      final slice = DatevSlice(
        journal: journal,
        from: from,
        to: to,
        part: part,
        rowsPerPart: p.rowsPerBatch,
        locked: p.closed(from, to),
      );
      files[_batchFileName(slice)] = buildDatevFile(
        detailed.withSlice(
          slice,
          accounts: r.accounts.withFiscalYearStart(start),
          batchName: _batchName(journal, r.batchName),
        ),
      );
    }
  }
  final used = {
    for (final b in writer.bookings) ...{b.debit, b.credit},
  };
  files[datevStammdatenFileName] = buildDatevStammdaten(
    {
      for (final MapEntry(key: member, value: account)
          in debtors.accounts.entries)
        if (used.contains(account)) account: debtors.parties[member]!,
      for (final MapEntry(key: account, value: party)
          in creditors.parties.entries)
        if (used.contains(account)) account: party,
    },
    (
      generatedAt: r.generatedAt,
      consultantNumber: r.consultantNumber,
      clientNumber: r.clientNumber,
      fiscalYearStart: firstStart ?? r.accounts.fiscalYearStartFor(r.from),
      accountLength: r.accountLength,
      skr: r.accounts.skr,
    ),
  );
  final linked = {for (final b in writer.bookings) ?b.invoice};
  return DatevPackage._(
    files: files,
    vouchers: r.detail.voucherLinks ? linked.toList() : const [],
    rows: writer.bookings.length,
  );
}

/// The Berater- and Mandantennummer DATEV accepts, and a Sachkontenlänge
/// it knows.
List<DatevProblem> _numberProblems(DatevRequest r) {
  bool inRange(String text, (int, int) range) {
    final n = RegExp(r'^\d+$').hasMatch(text) ? int.tryParse(text) : null;
    return n != null && n >= range.$1 && n <= range.$2;
  }

  final (shortest, longest) = DatevFormatRules.accountLengths;
  return [
    if (!inRange(r.consultantNumber, DatevFormatRules.consultantRange))
      DatevConsultantNumber(r.consultantNumber),
    if (!inRange(r.clientNumber, DatevFormatRules.clientRange))
      DatevClientNumber(r.clientNumber),
    if (r.accountLength < shortest || r.accountLength > longest)
      DatevSachkontenlaenge(r.accountLength),
    if (r.currency.toUpperCase() != DatevWriter.amountCurrency)
      DatevCurrency(r.currency),
  ];
}

/// Every rate the year books as revenue that DATEV could not post as
/// asked: the positions of each document's own sign, as the sale books
/// them (an invoice's charges, a credit note's credits).
List<DatevProblem> _taxProblems(DatevRequest r) {
  final percents = <double>{
    for (final i in r.invoices)
      if (!i.isVoided && i.kind != InvoiceKind.settlement)
        for (final l in i.lines)
          if (i.isCreditNote ? l.amountCents < 0 : l.amountCents > 0)
            l.vatPercent,
  };
  return [
    for (final percent in percents.toList()..sort())
      ?r.accounts.taxGapAt(percent),
  ];
}

/// A Belegfeld 1 or a KOST1 longer than its field: DATEV matches open
/// items on the first and groups costs by the second, so neither is cut.
List<DatevProblem> _referenceProblems(DatevWriter writer) {
  final seen = <(String, String)>{};
  for (final b in writer.bookings) {
    if (b.documentRef.runes.length > DatevFormatRules.documentRefLength) {
      seen.add(('Belegfeld 1', b.documentRef));
    }
    final kost = writer.costCentreOf(b);
    if (kost.runes.length > DatevFormatRules.costCentreLength) {
      seen.add(('KOST1', kost));
    }
  }
  return [
    for (final (field, value) in seen) DatevReferenceTooLong(field, value),
  ];
}

/// Whether the issuers' book profiles start the fiscal year of a month the
/// bookings fall in on different days.
bool _fiscalStartsDisagree(DatevPackageRequest p, List<DatevBooking> bookings) {
  final months = {
    for (final b in bookings) DateTime(b.date.year, b.date.month),
  };
  return months.any(
    (from) =>
        datevProfileFiscalStarts(
          p.bookProfiles,
          from,
          DateTime(from.year, from.month + 1, 0),
        ).length >
        1,
  );
}

/// Every Sachkonto a row uses must be as long as the header says; the
/// Debitors are one longer by construction.
List<DatevProblem> _accountProblems(
  List<DatevBooking> bookings,
  Set<String> personal,
  int accountLength,
) {
  final accounts = {
    for (final b in bookings) ...{b.debit, b.credit},
  }.difference(personal);
  return [
    for (final account in accounts.toList()..sort())
      if (!RegExp(r'^\d+$').hasMatch(account) ||
          account.length != accountLength)
        DatevAccountLength(account, accountLength),
  ];
}
