// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/time/workspace_time.dart';
import 'billing_rules.dart';
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
    this.customers = '10000',
    this.revenue = '8400',
    this.bank = '1200',
    this.vat = '1776',
    this.chart = 'SKR03',
    this.expenses = '4900',
  });

  /// SKR03 debtor range starts at 10000. A real chart numbers each
  /// customer; one collective account keeps the export honest about
  /// what the app actually knows.
  final String customers;

  /// SKR03 8400 — Erlöse 19 % USt. The accountant re-points this when
  /// the workspace charges a different rate or none.
  final String revenue;

  /// SKR03 1200 — Bank.
  final String bank;

  /// SKR03 1776 — Umsatzsteuer 19 %. Only reached when the workspace is
  /// VAT-registered; an exempt one never books to it.
  final String vat;

  /// Named on the export sheet so the accountant can see which chart the
  /// numbers belong to before importing.
  final String chart;

  /// #936 — reimbursed expenses and shared costs; 4900 "sonstige
  /// betriebliche Aufwendungen" in SKR03.
  final String expenses;
}

/// The UTF-8 byte-order mark, as the character that encodes to it.
///
/// DATEV's importer treats an unmarked file as Windows-1252. Declaring
/// format version 700 in the header — as this exporter does — is what
/// makes the marked UTF-8 form recognised, so the two belong together.
const String datevBom = '\u{FEFF}';

/// DATEV expects `EXTF_<something>.csv`; the name is free-form after the
/// prefix, and DATEV keys on the header, not the filename.
String datevFileName(int year, int month) =>
    'EXTF_Buchungsstapel_$year${month.toString().padLeft(2, '0')}.csv';

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
  // DATEV is CSV with ');' and quoted text. A ';' or a newline inside a
  // label would shift every following column.
  String clean(String text) =>
      text.replaceAll(RegExp(r'[;\r\n]+'), ' ').trim();
  String q(String text) => '"${clean(text).replaceAll('"', "'")}"';

  /// Always positive, comma decimal — see the header note.
  String money(int cents) =>
      // #1077 — two decimals is CORRECT here: DATEV EXTF is a German
      // and Austrian format, both eurozone. Not a hardcoded-euro bug.
      (cents.abs() / 100).toStringAsFixed(2).replaceAll('.', ',');

  /// DDMM. The year is the header's, not the booking's.
  String dayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}';

  String ddmmyyyy(DateTime d) => '${dayMonth(d)}${d.year}';

  String ymd(DateTime d) => '${d.year}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  final fiscalYearStart = DateTime(from.year, 1, 1);
  final stamp = '${ymd(generatedAt)}'
      '${generatedAt.hour.toString().padLeft(2, '0')}'
      '${generatedAt.minute.toString().padLeft(2, '0')}'
      '${generatedAt.second.toString().padLeft(2, '0')}000';

  // Field order is fixed by DATEV; positions, not names, are what the
  // importer reads.
  final header = [
    '"EXTF"', '700', '21', '"Buchungsstapel"', '13', stamp, '',
    '""', '""', '',
    consultantNumber, clientNumber,
    ymd(fiscalYearStart), '$accountLength',
    ymd(from), ymd(to),
    q((development ? 'ENTWICKLUNG ' : '') + batchName), '""', '1', '', '0', q(currency),
    '', '', '', '', '', '', '', '', '',
  ].join(';');

  final columns = [
    'Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;'
        'WKZ Umsatz;Kurs;Basisumsatz;WKZ Basisumsatz;Konto;'
        'Gegenkonto (ohne BU-Schlüssel);BU-Schlüssel;Belegdatum;Belegfeld 1;'
        'Belegfeld 2;Skonto;Buchungstext;Postensperre;Diverse Adressnummer;'
        'Geschäftspartnerbank;Sachverhalt;Zinssperre;Beleglink',
    ..._datevColumns21To116,
  ].join(';');

  final rows = <String>[];

  /// One booking line. DATEV's minimum is amount, direction, the two
  /// accounts, the document date and a text.
  void book({
    required int cents,
    required String debit,
    required String credit,
    required DateTime date,
    required String documentRef,
    required String text,
    DateTime? taxPeriodDate,
  }) {
    // Direction: we always state the DEBIT account in `Konto` and the
    // credit in `Gegenkonto`, so the flag is always 'S'. Writing the
    // pair the other way round with 'H' would post the same booking
    // twice-mirrored, which is the classic DATEV import error.
    rows.add([
      money(cents), '"S"', q(currency), '', '', '',
      debit, credit, '',
      dayMonth(date),
      q(documentRef), '', '',
      q(text),
      '', '', '', '', '', '',
      // Fields 21–115 stay empty; 116 is the tax period's date, TTMMJJJJ.
      for (var i = 21; i <= 115; i++) '',
      if (taxPeriodDate == null) '' else ddmmyyyy(taxPeriodDate),
    ].join(';'));
  }

  // #2355 — the engine's tax points per invoice; with a ledger given, an
  // invoice it holds nothing for has no tax due yet.
  final index = taxPoints == null ? null : VatTaxPointIndex(taxPoints);

  /// The sale of [invoice] ([cents], always positive), booked once per
  /// tax point date: each part is the share of the document that falls
  /// due that day, the last part what is not due yet (no field 116 —
  /// the Belegdatum's period, or DATEV's own Ist-Versteuerung).
  void bookSale({
    required Invoice invoice,
    required int cents,
    required String debit,
    required String credit,
    required String text,
  }) {
    final issued = dayOf(invoice.issuedAt);
    final total = invoice.lines.fold(0, (s, l) => s + l.amountCents);
    final byDay = index?.byDay(invoice.id, (a) => a.grossCents) ?? const {};
    final days = byDay.keys.toList();
    final whole = days.length == 1 && byDay[days.single] == total;
    if (index == null || total == 0 || (whole && days.single == issued)) {
      book(cents: cents, debit: debit, credit: credit,
          date: invoice.issuedAt, documentRef: invoice.number, text: text);
      return;
    }
    var covered = 0;
    var booked = 0;
    for (final day in days) {
      covered += byDay[day]!;
      final upTo = (cents * covered / total).round();
      if (upTo - booked == 0) continue;
      book(cents: upTo - booked, debit: debit, credit: credit,
          date: invoice.issuedAt, documentRef: invoice.number, text: text,
          taxPeriodDate: day);
      booked = upTo;
    }
    if (cents - booked != 0) {
      book(cents: cents - booked, debit: debit, credit: credit,
          date: invoice.issuedAt, documentRef: invoice.number, text: text);
    }
  }

  for (final invoice in invoices) {
    if (invoice.isVoided) continue; // a cancelled invoice was never booked
    // #831 — a settlement regroups booked revenue; booking it again doubles it.
    if (invoice.kind == InvoiceKind.settlement) continue;
    // #936 — a credit note is a sale reversed: the accounts swap and the
    // amount is positive, as a Buchungsstapel wants it.
    if (invoice.isCreditNote) {
      bookSale(
        invoice: invoice,
        cents: -invoice.totalCents,
        debit: accounts.revenue,
        credit: accounts.customers,
        text: 'Gutschrift ${invoice.number}',
      );
      continue;
    }
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
    if (charges == 0) continue;
    bookSale(
      invoice: invoice,
      cents: charges,
      debit: accounts.customers,
      credit: accounts.revenue,
      text: 'Rechnung ${invoice.number}',
    );
    // The credits the document itself carries: money in, receivable
    // cleared, on the invoice's own date. The FEC's BQ journal books
    // exactly these.
    for (final line in invoice.lines) {
      if (line.amountCents >= 0) continue;
      book(
        cents: -line.amountCents,
        debit: accounts.bank,
        credit: accounts.customers,
        date: invoice.issuedAt,
        documentRef: invoice.number,
        text: 'Zahlung ${invoice.number}',
      );
    }
    final match = matches[invoice.id];
    // A PENDING match is a settlement still awaiting validation (0067) —
    // booking it would put money in the ledger that the workspace has
    // not agreed it received. The FEC makes the same exclusion.
    // Skipped when the document already settled itself: that money is
    // the credit lines above, and booking it twice inflates the bank.
    // The FEC makes the same exclusion.
    if (match != null && !match.pending && invoice.totalCents != 0) {
      // The settlement: money in, receivable cleared. Booked on the day
      // the money moved (0070), not the day it was recorded.
      book(
        cents: match.paidCents,
        debit: accounts.bank,
        credit: accounts.customers,
        date: match.matchedAt,
        documentRef: invoice.number,
        text: 'Zahlung ${invoice.number}',
      );
    }
  }

  // CRLF: DATEV's importer is a Windows tool and a bare LF has been seen
  // to fold the last two lines together.
  // #936 — the purchases side.
  for (final entry in [...ledger]..sort((a, b) => a.on.compareTo(b.on))) {
    if (entry.kind != LedgerKind.credit ||
        entry.category != LedgerCategory.expense) {
      continue;
    }
    book(
      cents: entry.amountCents,
      debit: accounts.expenses,
      credit: accounts.customers,
      date: entry.on,
      documentRef: entry.id,
      text: entry.description.isEmpty
          ? 'Auslagenerstattung'
          : 'Auslagen ${entry.description}',
    );
  }
  for (final r in repartitions) {
    if (r.status != 'confirmed' || r.amountCents <= 0) continue;
    book(
      cents: r.amountCents,
      debit: accounts.expenses,
      credit: accounts.bank,
      date: r.appliedAt ?? r.createdAt,
      documentRef: r.id,
      text: r.title,
    );
  }
  return '$datevBom$header\r\n$columns\r\n${rows.join('\r\n')}\r\n';
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
