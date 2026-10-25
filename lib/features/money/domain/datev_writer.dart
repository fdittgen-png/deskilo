// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2492 — the EXTF Buchungsstapel of `datev.dart`, one method per section:
// the header, the column line, the sales, the purchases side and the file.
// The format notes live on `buildDatevFile`.
import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import 'billing_rules.dart';
import 'datev.dart';
import 'datev_fields.dart';
import 'datev_problem.dart';
import 'datev_revenue.dart';
import 'expense_repartition.dart';
import 'invoice.dart';
import 'invoice_line_cash.dart';
import 'ledger_entry.dart';
import 'vat_tax_point.dart';

/// Writes one period's Buchungsstapel; [buildDatevFile] is its entry point.
class DatevWriter {
  DatevWriter({
    required this.invoices,
    required this.matches,
    required this.accounts,
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.consultantNumber,
    required this.clientNumber,
    required this.currency,
    required this.batchName,
    required this.accountLength,
    required this.ledger,
    required this.repartitions,
    required this.development,
    required this.taxPoints,
    required this.dayOf,
    required this.detail,
    this.slice,
  });

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
  final List<LedgerEntry> ledger;
  final List<ExpenseRepartition> repartitions;
  final bool development;
  final List<VatTaxPointAmount>? taxPoints;
  final DateTime Function(DateTime instant) dayOf;

  /// #2375 — the sub-ledger detail: each member's Debitor, the cost
  /// centre, the voucher links.
  final DatevDetail detail;

  /// #2375 — the one Buchungsstapel to write; null writes them all.
  final DatevSlice? slice;

  // DATEV is CSV with ';' and quoted text. A ';' or a newline inside a
  // label would shift every following column: the DATEV dialect of the
  // shared cell writer (#2385) makes them a space.
  static const _datev = CsvDialect.datev;

  final List<DatevBooking> _bookings = [];

  /// Every booking of the request, in the order they were made.
  List<DatevBooking> get bookings => List.unmodifiable(_bookings);

  /// The account a member's side of a row is booked on: their Debitor. An
  /// export resolves every member's before it books (datev_package.dart).
  String _customer(String memberId) =>
      detail.debtors[memberId] ??
      (throw StateError('no Debitor for member $memberId'));

  /// KOST1 of [b]: its document's site, else the person's default.
  String costCentreOf(DatevBooking b) {
    final site = b.invoice?.sellerParty?.site ?? '';
    return site.isEmpty ? detail.defaultCostCentre : site;
  }

  /// Which Buchungsstapel [b] belongs in.
  DatevJournal journalOf(DatevBooking b) =>
      b.debit == accounts.bank || b.credit == accounts.bank
      ? DatevJournal.bank
      : DatevJournal.sales;

  // #2355 — the engine's tax points per invoice; with a ledger given, an
  // invoice it holds nothing for has no tax due yet.
  late final VatTaxPointIndex? _index = taxPoints == null
      ? null
      : VatTaxPointIndex(taxPoints!);

  /// The currency the amounts are written in: DATEV EXTF is a German and
  /// Austrian format, both eurozone; an export in another refuses
  /// (datev_package.dart), it is never written with euro digits.
  static const amountCurrency = 'EUR';

  /// Always positive, comma decimal — see the header note.
  String _amount(int cents) => minorToText(
    cents,
    amountCurrency,
    decimalSeparator: ',',
    absolute: true,
  );

  String _quoted(String text) =>
      csvCell(text, dialect: _datev, quoteEmpty: true);

  /// The header line. Field order is fixed by DATEV; positions, not names,
  /// are what the importer reads. Belegdatum is DDMM (`ddmm`): the year is
  /// the header's, not the booking's.
  String header() {
    final from = slice?.from ?? this.from;
    final to = slice?.to ?? this.to;
    final fiscalYearStart = accounts.fiscalYearStartFor(from);
    final stamp = '${ymd(generatedAt)}${hhmmss(generatedAt, separator: '')}000';
    return [
      '"EXTF"',
      '700',
      '21',
      '"Buchungsstapel"',
      '13',
      stamp,
      '',
      '""',
      '""',
      '',
      consultantNumber,
      clientNumber,
      ymd(fiscalYearStart),
      '$accountLength',
      ymd(from),
      ymd(to),
      _quoted(datevClip(
        (development ? 'ENTWICKLUNG ' : '') + batchName,
        DatevFormatRules.batchNameLength,
      )),
      '""',
      '1',
      '',
      if (slice?.locked ?? false) '1' else '0',
      _quoted(currency),
      '',
      '',
      '',
      '',
      accounts.skr,
      '',
      '',
      '',
      '',
    ].join(';');
  }

  /// The column line: fields 1 to 125.
  static String columns() => [
    'Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;'
        'WKZ Umsatz;Kurs;Basisumsatz;WKZ Basisumsatz;Konto;'
        'Gegenkonto (ohne BU-Schlüssel);BU-Schlüssel;Belegdatum;Belegfeld 1;'
        'Belegfeld 2;Skonto;Buchungstext;Postensperre;Diverse Adressnummer;'
        'Geschäftspartnerbank;Sachverhalt;Zinssperre;Beleglink',
    ...datevColumns21To125,
  ].join(';');

  /// One booking line. DATEV's minimum is amount, direction, the two
  /// accounts, the document date and a text.
  /// Every row is dated on the workspace's calendar ([dayOf]): its
  /// Belegdatum, its month's Buchungsstapel and its Beleginfo agree
  /// wherever the export is made.
  void book(DatevBooking b) => _bookings.add(b.on(dayOf(b.date)));

  /// The 125 fields of [b].
  String _row(DatevBooking b) {
    final taxPeriodDate = b.taxPeriodDate;
    final fields = List<String>.filled(DatevFormatRules.rowFields, '');
    // Always 'S': the DEBIT account in `Konto`, the credit in `Gegenkonto`
    // (the pair the other way round with 'H' posts it twice-mirrored).
    fields[0] = _amount(b.cents);
    fields[1] = '"S"';
    fields[2] = _quoted(currency);
    fields[6] = b.debit;
    fields[7] = b.credit;
    fields[8] = b.taxKey.isEmpty ? '' : _quoted(b.taxKey);
    fields[9] = ddmm(b.date);
    fields[10] = _quoted(
      datevClip(b.documentRef, DatevFormatRules.documentRefLength),
    );
    fields[13] = _quoted(datevClip(b.text, DatevFormatRules.textLength));
    _detail(fields, b);
    if (slice?.locked ?? false) fields[113] = '1';
    // Field 116 is the tax period's date, TTMMJJJJ.
    if (taxPeriodDate != null) {
      fields[115] = '${ddmm(taxPeriodDate)}${taxPeriodDate.year}';
    }
    return fields.join(';');
  }

  /// The sub-ledger fields of a row of [invoice] (none when null): the
  /// voucher link (20), the number, date and due date as Beleginfo
  /// (21-26), the site as KOST1 (37) and the buyer's VAT id for a reverse
  /// charge (40).
  void _detail(List<String> fields, DatevBooking b) {
    final costCentre = costCentreOf(b);
    if (costCentre.isNotEmpty) {
      fields[36] = _quoted(
        datevClip(costCentre, DatevFormatRules.costCentreLength),
      );
    }
    final invoice = b.invoice;
    if (invoice == null) return;
    // `BEDI "<guid>"`, its quotes doubled inside the quoted cell: the
    // DATEV dialect would turn them into apostrophes. The id is a uuid.
    if (detail.voucherLinks) fields[19] = '"BEDI ""${invoice.id}"""';
    final due = invoice.dueOn;
    final info = [
      ('Rechnungsnummer', invoice.number),
      ('Belegdatum', dmy(dayOf(invoice.issuedAt), separator: '.')),
      if (due != null) ('Fälligkeit', dmy(due, separator: '.')),
    ];
    for (final (k, (art, content)) in info.indexed) {
      fields[20 + 2 * k] = _quoted(art);
      fields[21 + 2 * k] = _quoted(
        datevClip(content, DatevFormatRules.documentInfoLength),
      );
    }
    final vatId = invoice.buyerParty?.vatId ?? '';
    if (invoice.isReverseCharged && vatId.isNotEmpty) {
      fields[39] = _quoted(vatId.replaceAll(' ', ''));
    }
  }

  /// A booking of [invoice] on its issue date.
  void _bookOn(
    Invoice invoice,
    int cents,
    (String, String) debitCredit,
    String text, {
    DateTime? taxPeriodDate,
    String taxKey = '',
  }) {
    book(
      DatevBooking(
        cents: cents,
        debit: debitCredit.$1,
        credit: debitCredit.$2,
        date: invoice.issuedAt,
        documentRef: invoice.number,
        text: text,
        taxPeriodDate: taxPeriodDate,
        taxKey: taxKey,
        invoice: invoice,
      ),
    );
  }

  /// The sale of [invoice] ([cents], always positive), booked once per
  /// tax point date: each part is the share of the document that falls
  /// due that day, the last part what is not due yet (no field 116 —
  /// the Belegdatum's period, or DATEV's own Ist-Versteuerung).
  void _bookSale(
    Invoice invoice,
    int cents,
    (String, String) debitCredit,
    String text,
    String taxKey,
  ) {
    final index = _index;
    final issued = dayOf(invoice.issuedAt);
    final total = invoice.lines.fold(0, (s, l) => s + l.amountCents);
    final byDay = index?.byDay(invoice.id, (a) => a.grossCents) ?? const {};
    final days = byDay.keys.toList();
    final whole = days.length == 1 && byDay[days.single] == total;
    if (index == null || total == 0 || (whole && days.single == issued)) {
      _bookOn(invoice, cents, debitCredit, text, taxKey: taxKey);
      return;
    }
    var covered = 0;
    var booked = 0;
    for (final day in days) {
      covered += byDay[day]!;
      final upTo = (cents * covered / total).round();
      if (upTo - booked == 0) continue;
      _bookOn(
        invoice,
        upTo - booked,
        debitCredit,
        text,
        taxPeriodDate: day,
        taxKey: taxKey,
      );
      booked = upTo;
    }
    if (cents - booked != 0) {
      _bookOn(invoice, cents - booked, debitCredit, text, taxKey: taxKey);
    }
  }

  /// The sales: every invoice and credit note of the period.
  void bookInvoices() {
    for (final invoice in invoices) {
      if (invoice.isVoided) continue; // a cancelled invoice was never booked
      // #831 — a settlement regroups booked revenue; booking it again doubles it.
      if (invoice.kind == InvoiceKind.settlement) continue;
      if (invoice.isCreditNote) {
        _bookCreditNote(invoice);
      } else {
        _bookInvoice(invoice);
      }
    }
  }

  /// #936 — a credit note is a sale reversed: the accounts swap and the
  /// amount is positive, as a Buchungsstapel wants it.
  void _bookCreditNote(Invoice invoice) {
    for (final (:account, :taxKey, :cents) in datevRevenueParts(
      invoice,
      -invoice.totalCents,
      accounts.revenueTargetAt,
    )) {
      _bookSale(invoice, cents, (
        account,
        _customer(invoice.memberId),
      ), 'Gutschrift ${invoice.number}', taxKey);
    }
    _bookRefund(invoice, matches[invoice.id]);
  }

  void _bookInvoice(Invoice invoice) {
    // Receivable against revenue, at what the invoice CHARGES — DATEV
    // derives the tax split from the BU-Schlüssel/Steuersatz on the
    // revenue account, which is the accountant's configuration, not
    // ours.
    //
    // `chargesCents`, not `totalCents`, and the difference is money. An
    // invoice may NET payments the member already made during the month
    // (0070): 300 charged, 120 already paid, 180 left. `totalCents` is
    // the 180. Booking that as revenue understated the year by every
    // euro anybody paid mid-month, and the 120 that actually arrived was
    // booked nowhere at all — so the bank was short too, and the VAT
    // base under it. The FEC has always split these; this did not.
    final charges = invoice.chargesCents;
    if (charges == 0) return;
    // One booking per revenue account and BU-Schlüssel (datev_revenue.dart).
    final customer = _customer(invoice.memberId);
    for (final (:account, :taxKey, :cents) in datevRevenueParts(
      invoice,
      charges,
      accounts.revenueTargetAt,
    )) {
      _bookSale(invoice, cents, (
        customer,
        account,
      ), 'Rechnung ${invoice.number}', taxKey);
    }
    // The credits the document itself carries: money in, receivable
    // cleared, on the invoice's own date. The FEC's BQ journal books
    // exactly these.
    for (final line in invoice.lines) {
      if (!line.isMoneyIn) continue;
      _bookOn(invoice, -line.amountCents, (
        accounts.bank,
        customer,
      ), 'Zahlung ${invoice.number}');
    }
    _bookSettlement(invoice, matches[invoice.id]);
  }

  /// A PENDING match is a settlement still awaiting validation (0067) —
  /// booking it would put money in the ledger that the workspace has
  /// not agreed it received. The FEC makes the same exclusion.
  /// Skipped when the document already settled itself: that money is
  /// the credit lines above, and booking it twice inflates the bank.
  void _bookSettlement(Invoice invoice, InvoiceMatch? match) {
    if (match == null || match.pending || invoice.totalCents == 0) return;
    // The settlement: money in, receivable cleared. Booked on the day
    // the money moved (0070), not the day it was recorded.
    book(
      DatevBooking(
        cents: match.paidCents,
        debit: accounts.bank,
        credit: _customer(invoice.memberId),
        date: match.matchedAt,
        documentRef: invoice.number,
        text: 'Zahlung ${invoice.number}',
        invoice: invoice,
      ),
    );
    bookDatevWriteOff(
      book,
      invoice,
      match,
      accounts.writeOff,
      _customer(invoice.memberId),
    );
  }

  /// #2365 — the refund of a credit note is money OUT: customers debited,
  /// bank credited, on the day it moved.
  void _bookRefund(Invoice invoice, InvoiceMatch? match) {
    final refund = refundedCents(invoice, match);
    if (refund == 0) return;
    book(
      DatevBooking(
        cents: refund,
        debit: _customer(invoice.memberId),
        credit: accounts.bank,
        date: match!.matchedAt,
        documentRef: invoice.number,
        text: 'Erstattung ${invoice.number}',
        invoice: invoice,
      ),
    );
  }

  /// #936 — the purchases side: reimbursed expenses, by date.
  void bookExpenses() {
    for (final entry in [...ledger]..sort((a, b) => a.on.compareTo(b.on))) {
      if (entry.kind != LedgerKind.credit ||
          entry.category != LedgerCategory.expense) {
        continue;
      }
      book(
        DatevBooking(
          cents: entry.amountCents,
          debit: accounts.expenses,
          credit: _customer(entry.memberId),
          date: entry.on,
          documentRef: entry.id,
          text: entry.description.isEmpty
              ? 'Auslagenerstattung'
              : 'Auslagen ${entry.description}',
        ),
      );
    }
  }

  /// #936 — the confirmed shared costs.
  void bookRepartitions() {
    for (final r in repartitions) {
      if (r.status != 'confirmed' || r.amountCents <= 0) continue;
      book(
        DatevBooking(
          cents: r.amountCents,
          debit: accounts.expenses,
          credit: accounts.bank,
          date: r.appliedAt ?? r.createdAt,
          documentRef: r.id,
          text: r.title,
        ),
      );
    }
  }

  /// The header, the columns and every booking, CRLF-separated: DATEV's
  /// importer is a Windows tool and a bare LF has been seen to fold the
  /// last two lines together.
  String lines() =>
      '${header()}\r\n${columns()}\r\n${[for (final b in _sliced()) _row(b)].join('\r\n')}\r\n';

  /// The bookings [slice] holds, every booking without one.
  List<DatevBooking> _sliced() {
    final slice = this.slice;
    if (slice == null) return _bookings;
    final from = isoDay(slice.from);
    final to = isoDay(slice.to);
    final of = [
      for (final b in _bookings)
        if (journalOf(b) == slice.journal &&
            isoDay(b.date).compareTo(from) >= 0 &&
            isoDay(b.date).compareTo(to) <= 0)
          b,
    ];
    return of
        .skip(slice.part * slice.rowsPerPart)
        .take(slice.rowsPerPart)
        .toList();
  }
}
