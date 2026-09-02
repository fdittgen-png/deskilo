// SPDX-License-Identifier: 0BSD
import 'billing_rules.dart';
import 'invoice.dart';

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
}

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
}) {
  // DATEV is CSV with ';' and quoted text. A ';' or a newline inside a
  // label would shift every following column.
  String clean(String text) =>
      text.replaceAll(RegExp(r'[;\r\n]+'), ' ').trim();
  String q(String text) => '"${clean(text).replaceAll('"', "'")}"';

  /// Always positive, comma decimal — see the header note.
  String money(int cents) =>
      (cents.abs() / 100).toStringAsFixed(2).replaceAll('.', ',');

  /// DDMM. The year is the header's, not the booking's.
  String dayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}';

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
    q(batchName), '""', '1', '', '0', q(currency),
    '', '', '', '', '', '', '', '', '',
  ].join(';');

  const columns = 'Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;'
      'WKZ Umsatz;Kurs;Basisumsatz;WKZ Basisumsatz;Konto;'
      'Gegenkonto (ohne BU-Schlüssel);BU-Schlüssel;Belegdatum;Belegfeld 1;'
      'Belegfeld 2;Skonto;Buchungstext;Postensperre;Diverse Adressnummer;'
      'Geschäftspartnerbank;Sachverhalt;Zinssperre;Beleglink';

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
    ].join(';'));
  }

  for (final invoice in invoices) {
    if (invoice.isVoided) continue; // a cancelled invoice was never booked
    // #831 — a settlement regroups booked revenue; booking it again doubles it.
    if (invoice.kind == InvoiceKind.settlement) continue;
    // Receivable against revenue, at the GROSS amount — DATEV derives
    // the tax split from the BU-Schlüssel/Steuersatz on the revenue
    // account, which is the accountant's configuration, not ours.
    book(
      cents: invoice.totalCents,
      debit: accounts.customers,
      credit: accounts.revenue,
      date: invoice.issuedAt,
      documentRef: invoice.number,
      text: 'Rechnung ${invoice.number}',
    );
    final match = matches[invoice.id];
    // A PENDING match is a settlement still awaiting validation (0067) —
    // booking it would put money in the ledger that the workspace has
    // not agreed it received. The FEC makes the same exclusion.
    if (match != null && !match.pending) {
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
  return '$header\r\n$columns\r\n${rows.join('\r\n')}\r\n';
}
