// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The tables of the GoBD data handover (gobd_package.dart): each with its
// file, its described columns (the key columns first), its rows and the
// joins it declares. The names and descriptions are German, the language of
// the auditor who reads the index.
import '../../../core/vat/tax_reference.dart';
import 'gobd_package.dart';
import 'invoice.dart';
import 'vat_tax_point.dart';

/// How a column is typed in the index.
enum GobdType { text, amount, number, percent, date }

/// One described column; the key columns of a table come first.
class GobdColumn {
  const GobdColumn(this.name, this.description, this.type, {this.key = false});

  final String name;
  final String description;
  final GobdType type;
  final bool key;
}

/// One table of the package: its file, what it holds, its columns, its rows
/// (cells already written in the column's type) and its joins.
class GobdTable {
  const GobdTable({
    required this.url,
    required this.name,
    required this.description,
    required this.columns,
    required this.rows,
    this.foreignKeys = const [],
  });

  final String url;
  final String name;
  final String description;
  final List<GobdColumn> columns;
  final List<List<Object?>> rows;

  /// Each join: the columns of this table and the table they reference.
  final List<(List<String>, String)> foreignKeys;
}

const _invoices = 'rechnungen';
const _customers = 'kunden';
const _purchases = 'eingangsbelege';

GobdColumn _k(String n, String d, GobdType t) => GobdColumn(n, d, t, key: true);
GobdColumn _c(String n, String d, GobdType t) => GobdColumn(n, d, t);

const _text = GobdType.text;
const _amount = GobdType.amount;
const _number = GobdType.number;
const _date = GobdType.date;

const _yesNo = {true: 'ja', false: 'nein'};

String _status(Invoice i) => i.isVoided
    ? 'storniert'
    : i.isCreditNote
    ? 'gutschrift'
    : 'ausgestellt';

/// The tables of [r], each with its rows; the key columns first.
List<GobdTable> gobdTables(GobdRequest r) {
  final invoices = [...r.invoices]
    ..sort((a, b) {
      final byDay = a.issuedAt.compareTo(b.issuedAt);
      return byDay != 0 ? byDay : a.number.compareTo(b.number);
    });
  final matches = [
    for (final i in invoices)
      if (r.matches[i.id] case final m?) (i, m),
  ];
  return [
    GobdTable(
      url: '$_invoices.csv',
      name: _invoices,
      description: 'Ausgangsrechnungen und Gutschriften, wie ausgestellt',
      columns: [
        _k('id', 'Kennung des Belegs', _text),
        _c('nummer', 'Rechnungsnummer', _text),
        _c('datum', 'Rechnungsdatum', _date),
        _c('zeitraum', 'Leistungszeitraum', _text),
        _c('art', 'Belegart', _text),
        _c('kunde_id', 'Kennung des Kunden', _text),
        _c('kundennummer', 'Mitgliedsnummer bei Ausstellung', _text),
        _c('kunde', 'Name des Kunden bei Ausstellung', _text),
        _c('brutto', 'Bruttobetrag der Leistungen', _amount),
        _c('netto', 'Nettobetrag', _amount),
        _c('ust', 'Umsatzsteuer', _amount),
        _c('zahlbetrag', 'Zahlbetrag nach Verrechnung', _amount),
        _c('waehrung', 'Währung (ISO 4217)', _text),
        _c('status', 'ausgestellt, gutschrift oder storniert', _text),
        _c('ersetzt_nummer', 'Nummer des ersetzten Belegs', _text),
        _c('faellig', 'Fälligkeit', _date),
        _c('standort', 'Standort (Kostenstelle)', _text),
        _c('signatur', 'Signatur der Belegkette', _text),
      ],
      rows: [
        for (final i in invoices)
          [
            i.id, i.number, i.issuedAt, i.period, i.kind.name, i.memberId,
            i.buyerParty?.memberNumber, i.clientName, i.chargesCents,
            i.netCents, i.vatCents, i.totalCents, i.currency, _status(i),
            i.replacesNumber, i.dueOn, i.sellerParty?.site, i.signature,
          ],
      ],
      foreignKeys: const [
        (['kunde_id'], _customers),
      ],
    ),
    GobdTable(
      url: 'rechnungspositionen.csv',
      name: 'rechnungspositionen',
      description: 'Positionen der Rechnungen und Gutschriften',
      columns: [
        _k('rechnung_id', 'Kennung des Belegs', _text),
        _k('position', 'Laufende Nummer der Position', _number),
        _c('art', 'Art der Position', _text),
        _c('text', 'Bezeichnung', _text),
        _c('betrag', 'Bruttobetrag der Position', _amount),
        _c('ust_satz', 'Umsatzsteuersatz in Prozent', GobdType.percent),
      ],
      rows: [
        for (final i in invoices)
          for (final (n, l) in i.lines.indexed)
            [i.id, n + 1, l.kind, l.label, l.amountCents, l.vatPercent],
      ],
      foreignKeys: const [
        (['rechnung_id'], _invoices),
      ],
    ),
    GobdTable(
      url: 'steuerbetraege.csv',
      name: 'steuerbetraege',
      description: 'Steuerbeträge je Satz und Kategorie (EN 16931)',
      columns: [
        _k('rechnung_id', 'Kennung des Belegs', _text),
        _k('ust_satz', 'Umsatzsteuersatz in Prozent', GobdType.percent),
        _k('kategorie', 'Steuerkategorie (UNCL5305)', _text),
        _c('brutto', 'Bruttobetrag', _amount),
        _c('netto', 'Nettobetrag', _amount),
        _c('ust', 'Steuerbetrag', _amount),
      ],
      rows: [
        for (final i in invoices)
          for (final t in i.vatTotals)
            [i.id, t.percent, t.category, t.grossCents, t.netCents, t.vatCents],
      ],
      foreignKeys: const [
        (['rechnung_id'], _invoices),
      ],
    ),
    GobdTable(
      url: 'zahlungen.csv',
      name: 'zahlungen',
      description: 'Zahlungsstand je Beleg',
      columns: [
        _k('rechnung_id', 'Kennung des Belegs', _text),
        _c('bezahlt', 'Gezahlter Betrag', _amount),
        _c('ergebnis', 'paid, partial, writeoff, refund', _text),
        _c('datum', 'Tag der Zahlung', _date),
        _c('vorlaeufig', 'ja, wenn die Zahlung noch zu bestätigen ist', _text),
      ],
      rows: [
        for (final (i, m) in matches)
          [i.id, m.paidCents, m.resolution, m.matchedAt, _yesNo[m.pending]],
      ],
      foreignKeys: const [
        (['rechnung_id'], _invoices),
      ],
    ),
    GobdTable(
      url: 'teilzahlungen.csv',
      name: 'teilzahlungen',
      description: 'Einzelne Zahlungen auf einen Beleg',
      columns: [
        _k('rechnung_id', 'Kennung des Belegs', _text),
        _k('lfd', 'Laufende Nummer', _number),
        _c('datum', 'Tag der Zahlung', _date),
        _c('betrag', 'Betrag', _amount),
      ],
      rows: [
        for (final i in invoices)
          for (final (n, p) in (r.instalments[i.id] ?? const <TaxPointPayment>[]).indexed)
            [i.id, n + 1, p.on, p.cents],
      ],
      foreignKeys: const [
        (['rechnung_id'], _invoices),
      ],
    ),
    GobdTable(
      url: 'abschreibungen.csv',
      name: 'abschreibungen',
      description: 'Forderungsverluste: der aufgegebene Rest eines Belegs',
      columns: [
        _k('rechnung_id', 'Kennung des Belegs', _text),
        _c('datum', 'Tag der Abschreibung', _date),
        _c('betrag', 'Abgeschriebener Bruttobetrag', _amount),
      ],
      rows: [
        for (final (i, m) in matches)
          if (m.writeoffAt case final day?)
            [i.id, day, i.totalCents - m.paidCents],
      ],
      foreignKeys: const [
        (['rechnung_id'], _invoices),
      ],
    ),
    GobdTable(
      url: 'kontobewegungen.csv',
      name: 'kontobewegungen',
      description: 'Bewegungen der Mitgliederkonten',
      columns: [
        _k('id', 'Kennung der Bewegung', _text),
        _c('kunde_id', 'Kennung des Mitglieds', _text),
        _c('art', 'credit oder charge', _text),
        _c('kategorie', 'Kategorie der Bewegung', _text),
        _c('betrag', 'Betrag', _amount),
        _c('text', 'Beschreibung', _text),
        _c('zeitraum', 'Abrechnungszeitraum', _text),
        _c('datum', 'Tag der Bewegung', _date),
        _c('erfasst', 'Tag der Erfassung', _date),
      ],
      rows: [
        for (final e in r.ledger)
          [
            e.id, e.memberId, e.kind.name, e.category.name, e.amountCents,
            e.description, e.period, e.on, e.createdAt,
          ],
      ],
      foreignKeys: const [
        (['kunde_id'], _customers),
      ],
    ),
    GobdTable(
      url: 'umlagen.csv',
      name: 'umlagen',
      description: 'Umgelegte gemeinsame Kosten',
      columns: [
        _k('id', 'Kennung der Umlage', _text),
        _c('titel', 'Bezeichnung', _text),
        _c('betrag', 'Betrag', _amount),
        _c('status', 'Status', _text),
        _c('angewendet', 'Tag der Anwendung', _date),
        _c('erfasst', 'Tag der Erfassung', _date),
      ],
      rows: [
        for (final x in r.repartitions)
          [x.id, x.title, x.amountCents, x.status, x.appliedAt, x.createdAt],
      ],
    ),
    GobdTable(
      url: '$_purchases.csv',
      name: _purchases,
      description: 'Genehmigte Eingangsbelege',
      columns: [
        _k('id', 'Kennung des Belegs', _text),
        _c('art', 'Belegart', _text),
        _c('waehrung', 'Währung (ISO 4217)', _text),
        _c('datum', 'Belegdatum', _date),
      ],
      rows: [
        for (final p in r.purchases) [p.id, p.kind, p.currency, p.dated],
      ],
    ),
    GobdTable(
      url: 'eingangsbelegpositionen.csv',
      name: 'eingangsbelegpositionen',
      description: 'Positionen der Eingangsbelege',
      columns: [
        _k('beleg_id', 'Kennung des Eingangsbelegs', _text),
        _k('position', 'Nummer der Position', _number),
        _c('brutto', 'Bruttobetrag', _amount),
        _c('netto', 'Nettobetrag, wenn aufgeteilt', _amount),
        _c('vorsteuer', 'Steuerbetrag, wenn aufgeteilt', _amount),
        _c('erfassung', 'Art der Erfassung', _text),
      ],
      rows: [
        for (final p in r.purchases)
          for (final l in p.lines)
            [p.id, l.lineNo, l.grossCents, l.netCents, l.taxCents, l.recognitionKind],
      ],
      foreignKeys: const [
        (['beleg_id'], _purchases),
      ],
    ),
    _customerTable(r, invoices),
    GobdTable(
      url: 'steuersaetze.csv',
      name: 'steuersaetze',
      description: 'Umsatzsteuersätze mit ihren Gültigkeiten',
      columns: [
        _k('land', 'Land (ISO 3166)', _text),
        _k('schluessel', 'Schlüssel des Satzes', _text),
        _k('gueltig_ab', 'Gültig ab', _date),
        _c('gueltig_bis', 'Gültig bis', _date),
        _c('bezeichnung', 'Bezeichnung', _text),
        _c('satz', 'Satz in Prozent', GobdType.percent),
        _c('gruppe', 'Steuergruppe', _text),
        _c('kategorie', 'Steuerkategorie (UNCL5305)', _text),
        _c('quelle', 'Rechtsquelle', _text),
      ],
      rows: [
        for (final row in r.taxRates)
          if (row.value case final RateValue v)
            [
              row.country, row.key, DateTime.parse(row.validFrom),
              switch (row.validTo) { final t? => DateTime.parse(t), null => null },
              v.label, v.percent, v.group, v.category, row.source,
            ],
      ],
    ),
    GobdTable(
      url: 'nummernkreise.csv',
      name: 'nummernkreise',
      description: 'Nummernkreise der Belege und ihr Stand bei der Ausgabe',
      columns: [
        _k('journal', 'Nummernkreis', _text),
        _c('praefix', 'Präfix', _text),
        _c('suffix', 'Suffix', _text),
        _c('datumsteil', 'Datumsteil der Nummer', _text),
        _c('stellen', 'Stellen des Zählers', _number),
        _c('neubeginn', 'Wann der Zähler neu beginnt', _text),
        _c('naechste', 'Nächste zu vergebende Nummer', _number),
        _c('periode', 'Periode des Zählers', _text),
      ],
      rows: [
        for (final s in r.sequences)
          [
            s.journal, s.prefix, s.suffix, s.datePart.name, s.digits,
            s.reset.name, s.nextValue, s.periodKey,
          ],
      ],
    ),
    GobdTable(
      url: 'pruefpfad.csv',
      name: 'pruefpfad',
      description: 'Prüfpfad: wer wann was an den Belegen getan hat',
      columns: [
        _k('lfd', 'Laufende Nummer', _number),
        _c('datum', 'Tag des Ereignisses', _date),
        _c('zeitpunkt', 'Zeitpunkt (ISO 8601)', _text),
        _c('art', 'Art des Ereignisses', _text),
        _c('beleg', 'Belegnummer', _text),
        _c('text', 'Beschreibung', _text),
        _c('betrag', 'Betrag mit Vorzeichen', _amount),
        _c('akteur', 'Handelnde Person', _text),
        _c('gegenpartei', 'Gegenpartei', _text),
        _c('bezug', 'Bezugsbeleg', _text),
        _c('status', 'Status', _text),
      ],
      rows: [
        for (final (n, e) in r.auditEvents.indexed)
          [
            n + 1, e.at, e.at.toIso8601String(), e.kind, e.reference,
            e.description, e.amountCents, e.actor, e.counterparty,
            e.relatesTo, e.status,
          ],
      ],
    ),
    GobdTable(
      url: 'belege.csv',
      name: 'belege',
      description: 'Belegdateien je Rechnung in diesem Paket',
      columns: [
        _k('rechnung_id', 'Kennung des Belegs', _text),
        _k('datei', 'Pfad der Belegdatei im Paket', _text),
      ],
      rows: [
        for (final i in invoices)
          for (final path in (r.vouchers[i.id]?.keys.toList() ?? <String>[])..sort())
            [i.id, path],
      ],
      foreignKeys: const [
        (['rechnung_id'], _invoices),
      ],
    ),
  ];
}

/// Every member the tables name, as their latest invoice froze them, else
/// by their name today.
GobdTable _customerTable(GobdRequest r, List<Invoice> invoices) {
  final latest = <String, Invoice>{};
  for (final i in invoices) {
    latest[i.memberId] = i;
  }
  final members = {
    ...latest.keys,
    for (final e in r.ledger) e.memberId,
  }.toList()..sort();
  return GobdTable(
    url: '$_customers.csv',
    name: _customers,
    description: 'Kunden (Mitglieder) wie auf ihrem letzten Beleg',
    columns: [
      _k('id', 'Kennung des Kunden', _text),
      _c('nummer', 'Mitgliedsnummer', _text),
      _c('name', 'Name', _text),
      _c('firma', 'Firma', _text),
      _c('strasse', 'Straße', _text),
      _c('plz', 'Postleitzahl', _text),
      _c('ort', 'Ort', _text),
      _c('land', 'Land (ISO 3166)', _text),
      _c('ustid', 'USt-IdNr.', _text),
    ],
    rows: [
      for (final m in members)
        () {
          final i = latest[m];
          final p = i?.buyerParty;
          return [
            m, p?.memberNumber, i?.clientName ?? r.memberNames[m] ?? '',
            p?.company, p?.street, p?.postalCode, p?.city, p?.country,
            p?.vatId,
          ];
        }(),
    ],
  );
}
