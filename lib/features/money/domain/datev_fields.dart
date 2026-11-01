// SPDX-License-Identifier: AGPL-3.0-or-later

import 'book_profile.dart';
import 'datev.dart';
import 'invoice.dart';

/// #2365 — DATEV's field limits: `Belegfeld 1` holds 36 characters and
/// `Buchungstext` 60. The importer rejects the row, or the whole stack,
/// above them, so the text is cut here, by character and never in the
/// middle of one.
String datevClip(String text, int max) {
  final chars = text.runes.toList();
  return chars.length <= max ? text : String.fromCharCodes(chars.take(max));
}

/// Header field 27, the SKR: the digits of the chart's name ('SKR03' ->
/// '03'), or empty when the name carries none.
String datevSkrDigits(String chart) =>
    RegExp(r'\d+').firstMatch(chart)?.group(0) ?? '';

/// #2365 — header field 13: the first day of the fiscal year that contains
/// [from], for a fiscal year starting on [month]/[day] (the book profile).
DateTime _fiscalYearStart(int month, int day, DateTime from) {
  final thisYear = DateTime(from.year, month, day);
  return thisYear.isAfter(from)
      ? DateTime(from.year - 1, month, day)
      : thisYear;
}

/// The fiscal-year start the book profiles agree on for the period
/// [from]..[to]: each issuer's latest version in force at [to]; null when
/// there is none or the issuers disagree ([datevProfileFiscalStarts]).
DateTime? datevProfileFiscalStart(
  List<BookProfile> profiles,
  DateTime from,
  DateTime to,
) {
  final starts = datevProfileFiscalStarts(profiles, from, to);
  return starts.length == 1 ? starts.single : null;
}

/// The fiscal-year starts of the issuers' latest profiles in force at [to].
Set<DateTime> datevProfileFiscalStarts(
  List<BookProfile> profiles,
  DateTime from,
  DateTime to,
) {
  final latest = <String, BookProfile>{};
  for (final p in profiles) {
    if (p.effectiveFrom.isAfter(to)) continue;
    final seen = latest[p.issuerSiteId];
    if (seen == null || p.effectiveFrom.isAfter(seen.effectiveFrom)) {
      latest[p.issuerSiteId] = p;
    }
  }
  return {
    for (final p in latest.values)
      _fiscalYearStart(p.fiscalYearStartMonth, p.fiscalYearStartDay, from),
  };
}

/// One booking line of the Buchungsstapel: amount (always positive), the
/// debit and credit accounts, the document date and reference, a text and,
/// when it differs from the Belegdatum's, the tax period's date (#2355).
class DatevBooking {
  const DatevBooking({
    required this.cents,
    required this.debit,
    required this.credit,
    required this.date,
    required this.documentRef,
    required this.text,
    this.taxPeriodDate,
    this.taxKey = '',
    this.invoice,
    this.journal,
  });

  /// This booking dated [day].
  DatevBooking on(DateTime day) => DatevBooking(
    cents: cents,
    debit: debit,
    credit: credit,
    date: day,
    documentRef: documentRef,
    text: text,
    taxPeriodDate: taxPeriodDate,
    taxKey: taxKey,
    invoice: invoice,
    journal: journal,
  );

  final int cents;
  final String debit;
  final String credit;
  final DateTime date;
  final String documentRef;
  final String text;
  final DateTime? taxPeriodDate;

  /// The BU-Schlüssel; '' on an automatic account and where none applies.
  final String taxKey;

  /// The document the row books, when it books one: its site, number,
  /// dates and voucher travel with the row.
  final Invoice? invoice;

  /// The Buchungsstapel the row belongs in when it is not decided by the
  /// bank account: a supplier row names its own.
  final DatevJournal? journal;
}

/// Where the builder's bookings go.
typedef DatevBook = void Function(DatevBooking booking);

/// #2365 — the rest of [invoice] the owner gave up leaves the receivable for
/// the loss account, on the write-off day, at the gross amount; the VAT
/// correction is the tax adviser's.
void bookDatevWriteOff(
  DatevBook book,
  Invoice invoice,
  InvoiceMatch match,
  String lossAccount,
  String customersAccount,
) {
  final owed = invoice.totalCents - match.paidCents;
  final day = match.writeoffAt;
  if (day == null || owed <= 0) return;
  book(DatevBooking(
    cents: owed, debit: lossAccount, credit: customersAccount, date: day,
    documentRef: invoice.number, text: 'Forderungsverlust ${invoice.number}',
    invoice: invoice,
  ));
}

/// Fields 21 to 125 of the EXTF Buchungsstapel (format 700, category 21),
/// in DATEV's order: the importer reads by position, so field 116,
/// `Datum Zuord. Steuerperiode`, needs every field before it (#2355).
final List<String> datevColumns21To125 = List.unmodifiable([
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
  'Fälligkeit',
  'Generalumkehr (GU)',
  'Steuersatz',
  'Land',
  'Abrechnungsreferenz',
  'BVV-Position (Betriebsvermögensvergleich)',
  'EU-Land u. UStID (Ursprung)',
  'EU-Steuersatz (Ursprung)',
  'Abw. Skontokonto',
]);
