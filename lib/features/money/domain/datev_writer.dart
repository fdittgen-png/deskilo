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

  // DATEV is CSV with ';' and quoted text. A ';' or a newline inside a
  // label would shift every following column: the DATEV dialect of the
  // shared cell writer (#2385) makes them a space.
  static const _datev = CsvDialect.datev;

  final List<String> _rows = [];

  // #2355 — the engine's tax points per invoice; with a ledger given, an
  // invoice it holds nothing for has no tax due yet.
  late final VatTaxPointIndex? _index = taxPoints == null
      ? null
      : VatTaxPointIndex(taxPoints!);

  /// Always positive, comma decimal — see the header note.
  String _amount(int cents) =>
      // #1077 — two decimals is CORRECT here: DATEV EXTF is a German
      // and Austrian format, both eurozone. Not a hardcoded-euro bug.
      minorToText(cents, 'EUR', decimalSeparator: ',', absolute: true);

  String _quoted(String text) =>
      csvCell(text, dialect: _datev, quoteEmpty: true);

  /// The header line. Field order is fixed by DATEV; positions, not names,
  /// are what the importer reads. Belegdatum is DDMM (`ddmm`): the year is
  /// the header's, not the booking's.
  String header() {
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
      _quoted((development ? 'ENTWICKLUNG ' : '') + batchName),
      '""',
      '1',
      '',
      '0',
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

  /// The column line: fields 1 to 116.
  static String columns() => [
    'Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;'
        'WKZ Umsatz;Kurs;Basisumsatz;WKZ Basisumsatz;Konto;'
        'Gegenkonto (ohne BU-Schlüssel);BU-Schlüssel;Belegdatum;Belegfeld 1;'
        'Belegfeld 2;Skonto;Buchungstext;Postensperre;Diverse Adressnummer;'
        'Geschäftspartnerbank;Sachverhalt;Zinssperre;Beleglink',
    ..._datevColumns21To116,
  ].join(';');

  /// One booking line. DATEV's minimum is amount, direction, the two
  /// accounts, the document date and a text.
  void book(DatevBooking b) {
    final taxPeriodDate = b.taxPeriodDate;
    // Always 'S': the DEBIT account in `Konto`, the credit in `Gegenkonto`
    // (the pair the other way round with 'H' posts it twice-mirrored).
    _rows.add(
      [
        _amount(b.cents), '"S"',
        _quoted(currency), '', '', '',
        b.debit, b.credit, '',
        ddmm(b.date),
        _quoted(datevClip(b.documentRef, 36)), '', '',
        _quoted(datevClip(b.text, 60)),
        '', '', '', '', '', '',
        // Fields 21–115 stay empty; 116 is the tax period's date, TTMMJJJJ.
        for (var i = 21; i <= 115; i++) '',
        if (taxPeriodDate == null)
          ''
        else
          '${ddmm(taxPeriodDate)}${taxPeriodDate.year}',
      ].join(';'),
    );
  }

  /// A booking of [invoice] on its issue date.
  void _bookOn(
    Invoice invoice,
    int cents,
    (String, String) debitCredit,
    String text, [
    DateTime? taxPeriodDate,
  ]) {
    book(
      DatevBooking(
        cents: cents,
        debit: debitCredit.$1,
        credit: debitCredit.$2,
        date: invoice.issuedAt,
        documentRef: invoice.number,
        text: text,
        taxPeriodDate: taxPeriodDate,
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
  ) {
    final index = _index;
    final issued = dayOf(invoice.issuedAt);
    final total = invoice.lines.fold(0, (s, l) => s + l.amountCents);
    final byDay = index?.byDay(invoice.id, (a) => a.grossCents) ?? const {};
    final days = byDay.keys.toList();
    final whole = days.length == 1 && byDay[days.single] == total;
    if (index == null || total == 0 || (whole && days.single == issued)) {
      _bookOn(invoice, cents, debitCredit, text);
      return;
    }
    var covered = 0;
    var booked = 0;
    for (final day in days) {
      covered += byDay[day]!;
      final upTo = (cents * covered / total).round();
      if (upTo - booked == 0) continue;
      _bookOn(invoice, upTo - booked, debitCredit, text, day);
      booked = upTo;
    }
    if (cents - booked != 0) {
      _bookOn(invoice, cents - booked, debitCredit, text);
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
    for (final (account, cents) in datevRevenueParts(
      invoice,
      -invoice.totalCents,
      accounts.revenueAt,
    )) {
      _bookSale(invoice, cents, (
        account,
        accounts.customers,
      ), 'Gutschrift ${invoice.number}');
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
    // #2365 — one booking per automatic revenue account (datev_revenue.dart).
    for (final (account, cents) in datevRevenueParts(
      invoice,
      charges,
      accounts.revenueAt,
    )) {
      _bookSale(invoice, cents, (
        accounts.customers,
        account,
      ), 'Rechnung ${invoice.number}');
    }
    // The credits the document itself carries: money in, receivable
    // cleared, on the invoice's own date. The FEC's BQ journal books
    // exactly these.
    for (final line in invoice.lines) {
      if (!line.isMoneyIn) continue;
      _bookOn(invoice, -line.amountCents, (
        accounts.bank,
        accounts.customers,
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
        credit: accounts.customers,
        date: match.matchedAt,
        documentRef: invoice.number,
        text: 'Zahlung ${invoice.number}',
      ),
    );
    bookDatevWriteOff(
      book,
      invoice,
      match,
      accounts.writeOff,
      accounts.customers,
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
        debit: accounts.customers,
        credit: accounts.bank,
        date: match!.matchedAt,
        documentRef: invoice.number,
        text: 'Erstattung ${invoice.number}',
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
          credit: accounts.customers,
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
  String lines() => '${header()}\r\n${columns()}\r\n${_rows.join('\r\n')}\r\n';
}

/// Fields 21 to 116 of the EXTF Buchungsstapel (format 700, category 21),
/// in DATEV's order: the importer reads by position, so field 116,
/// `Datum Zuord. Steuerperiode`, needs every field before it (#2355).
final List<String> _datevColumns21To116 = List.unmodifiable([
  for (var i = 1; i <= 8; i++) ...[
    'Beleginfo - Art $i',
    'Beleginfo - Inhalt $i',
  ],
  'KOST1 - Kostenstelle',
  'KOST2 - Kostenstelle',
  'Kost-Menge',
  'EU-Land u. UStID (Bestimmung)',
  'EU-Steuersatz (Bestimmung)',
  'Abw. Versteuerungsart',
  'Sachverhalt L+L',
  'Funktionsergänzung L+L',
  'BU 49 Hauptfunktionstyp',
  'BU 49 Hauptfunktionsnummer',
  'BU 49 Funktionsergänzung',
  for (var i = 1; i <= 20; i++) ...[
    'Zusatzinformation - Art $i',
    'Zusatzinformation - Inhalt $i',
  ],
  'Stück',
  'Gewicht',
  'Zahlweise',
  'Forderungsart',
  'Veranlagungsjahr',
  'Zugeordnete Fälligkeit',
  'Skontotyp',
  'Auftragsnummer',
  'Buchungstyp',
  'USt-Schlüssel (Anzahlungen)',
  'EU-Mitgliedstaat (Anzahlungen)',
  'Sachverhalt L+L (Anzahlungen)',
  'EU-Steuersatz (Anzahlungen)',
  'Erlöskonto (Anzahlungen)',
  'Herkunft-Kz',
  'Buchungs GUID',
  'KOST-Datum',
  'SEPA-Mandatsreferenz',
  'Skontosperre',
  'Gesellschaftername',
  'Beteiligtennummer',
  'Identifikationsnummer',
  'Zeichnernummer',
  'Postensperre bis',
  'Bezeichnung SoBil-Sachverhalt',
  'Kennzeichen SoBil-Buchung',
  'Festschreibung',
  'Leistungsdatum',
  'Datum Zuord. Steuerperiode',
]);
