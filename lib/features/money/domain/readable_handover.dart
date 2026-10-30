// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The readable handover of a British, Irish, Canadian or US archive: the
// tables of the GoBD data handover (gobd_package.dart) without its German
// index and DTD, and a README that describes every table and column in
// English. HMRC (VAT Notice 700/21), the CRA (ETA s.286, ITA s.230: records
// in English or French, electronically readable) and the IRS (Rev. Proc.
// 98-25) read the files with their own audit software; the README is what
// tells that software, and the person running it, what each column holds.
//
// The table and column names stay the handover's stable identifiers; their
// meaning is the English description below, one per name.
import 'dart:convert';

import '../../../core/time/date_text.dart';
import 'gobd_package.dart';
import 'gobd_tables.dart';
import 'records_location.dart';

/// The countries whose archive carries the readable handover: those that
/// prescribe no national audit file and ask for readable electronic
/// records in English (GB, IE, US) or English or French (CA).
const Set<String> _readableHandoverCountries = {'GB', 'IE', 'CA', 'US'};

/// Where the tables and their README sit in the archive.
const String _handoverFolder = 'tables';

/// The README's name in the archive.
const String _readmePath = '$_handoverFolder/README.txt';

bool archiveCarriesReadableHandover(String countryCode) =>
    _readableHandoverCountries.contains(countryCode.toUpperCase());

/// One table's English description and its columns', by column name.
typedef _English = ({String table, Map<String, String> columns});

const _documentId = 'Identifier of the document';
const _gross = 'Gross amount';
const _net = 'Net amount';
const _rate = 'Tax rate in percent';
const _currency = 'Currency (ISO 4217)';
const _country = 'Country (ISO 3166)';
const _category = 'Tax category (UNCL5305)';
const _line = 'Line number';
const _paymentDay = 'Day of the payment';
const _recorded = 'Day it was recorded';
const _description = 'Description';
const _status = 'Status';
const _amount = 'Amount';

/// Every table of [gobdTables] in English, by table name. A table or column
/// added there without its English here stops the archive (see
/// [readableHandoverFiles]), so the README never describes less than the
/// files hold.
const Map<String, _English> _english = {
  'rechnungen': (
    table: 'Sales invoices and credit notes, as issued',
    columns: {
      'id': _documentId,
      'nummer': 'Invoice number',
      'datum': 'Invoice date',
      'zeitraum': 'Period of the service',
      'art': 'Kind of document',
      'kunde_id': 'Identifier of the customer (see kunden)',
      'kundennummer': 'Customer number at issue',
      'kunde': 'Customer name at issue',
      'brutto': 'Gross amount of the services',
      'netto': _net,
      'ust': 'Tax amount (VAT, GST/HST/QST or sales tax)',
      'zahlbetrag': 'Amount payable after set-off',
      'waehrung': _currency,
      'status': 'issued, credit_note or voided',
      'ersetzt_nummer': 'Number of the document it replaces',
      'faellig': 'Due date',
      'standort': 'Site (cost centre)',
      'signatur': 'Signature of the document chain',
    },
  ),
  'rechnungspositionen': (
    table: 'Lines of the invoices and credit notes',
    columns: {
      'rechnung_id': _documentId,
      'position': _line,
      'art': 'Kind of line',
      'text': _description,
      'betrag': 'Gross amount of the line',
      'ust_satz': _rate,
    },
  ),
  'steuerbetraege': (
    table: 'Tax amounts per rate and category (EN 16931)',
    columns: {
      'rechnung_id': _documentId,
      'ust_satz': _rate,
      'kategorie': _category,
      'brutto': _gross,
      'netto': _net,
      'ust': 'Tax amount',
    },
  ),
  'zahlungen': (
    table: 'Payment state per document',
    columns: {
      'rechnung_id': _documentId,
      'bezahlt': 'Amount paid',
      'ergebnis': 'paid, partial, writeoff or refund',
      'datum': _paymentDay,
      'vorlaeufig': 'yes while the payment awaits confirmation',
    },
  ),
  'teilzahlungen': (
    table: 'Single payments on a document',
    columns: {
      'rechnung_id': _documentId,
      'lfd': _line,
      'datum': _paymentDay,
      'betrag': _amount,
    },
  ),
  'abschreibungen': (
    table: 'Bad debts: the remainder of a document written off',
    columns: {
      'rechnung_id': _documentId,
      'datum': 'Day of the write-off',
      'betrag': 'Gross amount written off',
    },
  ),
  'kontobewegungen': (
    table: 'Movements of the member accounts',
    columns: {
      'id': 'Identifier of the movement',
      'kunde_id': 'Identifier of the member (see kunden)',
      'art': 'credit or charge',
      'kategorie': 'Category of the movement',
      'betrag': _amount,
      'text': _description,
      'zeitraum': 'Billing period',
      'datum': 'Day of the movement',
      'erfasst': _recorded,
    },
  ),
  'umlagen': (
    table: 'Shared costs passed on to members',
    columns: {
      'id': 'Identifier of the shared cost',
      'titel': _description,
      'betrag': _amount,
      'status': _status,
      'angewendet': 'Day it was applied',
      'erfasst': _recorded,
    },
  ),
  'eingangsbelege': (
    table: 'Approved purchase documents',
    columns: {
      'id': _documentId,
      'art': 'Kind of document',
      'waehrung': _currency,
      'datum': 'Document date',
    },
  ),
  'eingangsbelegpositionen': (
    table: 'Lines of the purchase documents',
    columns: {
      'beleg_id': 'Identifier of the purchase document',
      'position': _line,
      'brutto': _gross,
      'netto': 'Net amount, when split',
      'vorsteuer': 'Input tax amount, when split',
      'erfassung': 'How the line was recorded',
    },
  ),
  'kunden': (
    table: 'Customers (members) as on their latest document',
    columns: {
      'id': 'Identifier of the customer',
      'nummer': 'Customer number',
      'name': 'Name',
      'firma': 'Company',
      'strasse': 'Street',
      'plz': 'Postal code',
      'ort': 'City',
      'land': _country,
      'ustid': 'Tax registration number',
    },
  ),
  'steuersaetze': (
    table: 'Tax rates with their validity',
    columns: {
      'land': _country,
      'schluessel': 'Key of the rate',
      'gueltig_ab': 'Valid from',
      'gueltig_bis': 'Valid to',
      'bezeichnung': _description,
      'satz': 'Rate in percent',
      'gruppe': 'Tax group',
      'kategorie': _category,
      'quelle': 'Legal source',
    },
  ),
  'nummernkreise': (
    table: 'Number sequences of the documents and their state at handover',
    columns: {
      'journal': 'Number sequence',
      'praefix': 'Prefix',
      'suffix': 'Suffix',
      'datumsteil': 'Date part of the number',
      'stellen': 'Digits of the counter',
      'neubeginn': 'When the counter restarts',
      'naechste': 'Next number to be issued',
      'periode': 'Period of the counter',
    },
  ),
  'pruefpfad': (
    table: 'Audit trail: who did what to the documents, and when',
    columns: {
      'lfd': _line,
      'datum': 'Day of the event',
      'zeitpunkt': 'Time (ISO 8601)',
      'art': 'Kind of event',
      'beleg': 'Document number',
      'text': _description,
      'betrag': 'Signed amount',
      'akteur': 'Person who acted',
      'gegenpartei': 'Counterparty',
      'bezug': 'Related document',
      'status': _status,
    },
  ),
  'belege': (
    table: 'Document files per invoice in this archive',
    columns: {
      'rechnung_id': _documentId,
      'datei': 'Path of the document file from the archive root',
    },
  ),
};

/// How a column type reads in the README.
String _typeWord(GobdType type) => switch (type) {
  GobdType.text => 'text',
  GobdType.amount => 'amount',
  GobdType.number => 'number',
  GobdType.percent => 'percent',
  GobdType.date => 'date',
};

/// The English of table [name], or a [StateError] naming what is missing.
_English _englishOf(GobdTable t) {
  final english = _english[t.name];
  final missing = [
    if (english == null) t.name,
    for (final c in t.columns)
      if (english != null && !english.columns.containsKey(c.name))
        '${t.name}.${c.name}',
  ];
  if (missing.isNotEmpty) {
    throw StateError('no English description for ${missing.join(', ')}');
  }
  return english!;
}

String _readme(
  GobdRequest r,
  List<GobdTable> tables,
  RecordsLocation location,
) {
  final b = StringBuffer()
    ..write('Readable handover: ${r.supplierName}, ')
    ..write('${isoDay(r.from)} to ${isoDay(r.to)}\r\n\r\n');
  for (final line in location.archiveLines) {
    b.write('$line\r\n');
  }
  b
    ..write('\r\n')
    ..write(
      'These tables are the sub-ledger of the invoicing kept in DesKilo: '
      'invoices, credit notes, payments, member accounts, shared costs and '
      'purchase documents. They are not the complete general ledger of the '
      'business.\r\n\r\n',
    )
    ..write(
      'Every file: UTF-8, fields separated by ";", records ended by CR LF, '
      'text in double quotes (a quote inside text is doubled), no header '
      'line; the columns are in the order listed below. Amounts and rates: '
      'a decimal comma and two places, the minus sign first; an amount is in '
      'the currency of its document. Dates: DD.MM.YYYY, the calendar day of '
      'the business.\r\n',
    );
  for (final t in tables) {
    final english = _englishOf(t);
    b.write('\r\n$_handoverFolder/${t.url}: ${english.table}\r\n');
    for (final (i, c) in t.columns.indexed) {
      b.write(
        '  ${i + 1}. ${c.name} (${_typeWord(c.type)}${c.key ? ', key' : ''})'
        ': ${english.columns[c.name]}\r\n',
      );
    }
    for (final (columns, table) in t.foreignKeys) {
      b.write('  Joins ${columns.join(', ')} to $table\r\n');
    }
  }
  return b.toString();
}

/// The readable handover of [r]: every table under `tables/` and its
/// README, which states where the records are kept as [location] says.
/// The voucher files themselves are not repeated; the `belege` table names
/// where the archive holds them.
Map<String, List<int>> readableHandoverFiles(
  GobdRequest r,
  RecordsLocation location,
) {
  final tables = gobdTables(r);
  return {
    _readmePath: utf8.encode(_readme(r, tables, location)),
    for (final t in tables)
      '$_handoverFolder/${t.url}': utf8.encode(gobdTableCsv(t, r.dayOf)),
  };
}
