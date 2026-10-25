// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The GoBD data handover (Datenträgerüberlassung, Z3) of one fiscal year in
// the Beschreibungsstandard: an index.xml that describes every table, the
// DTD it names, one CSV per table, the vouchers and the
// Verfahrensdokumentation. A tax auditor's tool reads the index and imports
// the tables with their keys, so every column is described and every join
// is declared; nothing is inferred from a header line (the files have none).
//
// What it holds is DesKilo's sub-ledger: invoices, credit notes, payments,
// member accounts, shared costs and purchase documents. The index says so
// in its own words: it is the handover of these books, not the company's
// complete general ledger.
import 'dart:convert';

import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import 'accounting_source_snapshot.dart';
import 'audit_trail.dart';
import 'expense_repartition.dart';
import 'gobd_dtd.dart';
import 'gobd_tables.dart';
import 'invoice.dart';
import 'ledger_entry.dart';
import 'number_sequence.dart';
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

/// What one fiscal year's package is built from: the books of the one
/// export snapshot and the reads beside it.
class GobdRequest {
  const GobdRequest({
    required this.supplierName,
    required this.supplierLocation,
    required this.from,
    required this.to,
    required this.invoices,
    required this.matches,
    this.instalments = const {},
    this.ledger = const [],
    this.repartitions = const [],
    this.purchases = const [],
    this.memberNames = const {},
    this.sequences = const [],
    this.auditEvents = const [],
    this.taxRates = const [],
    this.vouchers = const {},
    this.procedure = const {},
  });

  final String supplierName;
  final String supplierLocation;
  final DateTime from;
  final DateTime to;
  final List<Invoice> invoices;
  final Map<String, InvoiceMatch> matches;
  final Map<String, List<TaxPointPayment>> instalments;
  final List<LedgerEntry> ledger;
  final List<ExpenseRepartition> repartitions;
  final List<SourcePurchase> purchases;

  /// The members' names today, for a member with no invoice in the year.
  final Map<String, String> memberNames;
  final List<NumberSequence> sequences;
  final List<AuditEvent> auditEvents;

  /// The country's tax rate rows, every version.
  final List<TaxReferenceRow> taxRates;

  /// The voucher files of each invoice, by invoice id: path in the package
  /// to bytes (the structured e-invoice, the PDF/A-3 that embeds it).
  final Map<String, Map<String, List<int>>> vouchers;

  /// The Verfahrensdokumentation, path to bytes.
  final Map<String, List<int>> procedure;
}

/// The index's own file name.
const String _gobdIndexFileName = 'index.xml';

/// The package's files, path to bytes.
Map<String, List<int>> buildGobdPackage(GobdRequest r) {
  final tables = gobdTables(r);
  return {
    _gobdIndexFileName: utf8.encode(_gobdIndexXml(r, tables)),
    gobdDtdFileName: utf8.encode(gobdDtd),
    for (final t in tables) t.url: utf8.encode(_gobdCsv(t)),
    for (final files in r.vouchers.values) ...files,
    ...r.procedure,
  };
}

const _d = 'DD.MM.YYYY';

String _day(DateTime d) => dmy(d, separator: '.');

/// The cell of [value] in a column of [type]: text quoted with its quotes
/// doubled and control characters as spaces, an amount in cents as a comma
/// decimal with two places, a date as DD.MM.YYYY, nothing for null.
String _cell(Object? value, GobdType type) {
  if (value == null) return '';
  return switch (type) {
    GobdType.text =>
      '"${'$value'.replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ').replaceAll('"', '""')}"',
    GobdType.amount => _cents(value as int),
    GobdType.number => '$value',
    GobdType.percent => _rate(value as double),
    GobdType.date => _day(value as DateTime),
  };
}

/// An amount in cents as a comma decimal with two places, '-' when
/// negative: the index declares every amount column with Accuracy 2,
/// whatever the document's currency.
String _cents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100},${(abs % 100).toString().padLeft(2, '0')}';
}

/// A rate in percent with two places, as the column declares.
String _rate(double p) => _cents((p * 100).round());

/// [t]'s rows, `;`-separated and CRLF-terminated, as the index declares.
String _gobdCsv(GobdTable t) => [
  for (final row in t.rows)
    '${[for (final (i, c) in t.columns.indexed) _cell(row[i], c.type)].join(';')}\r\n',
].join();

String _x(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _type(GobdType type) => switch (type) {
  GobdType.text => '<AlphaNumeric/>',
  GobdType.amount ||
  GobdType.percent => '<Numeric><Accuracy>2</Accuracy></Numeric>',
  GobdType.number => '<Numeric/>',
  GobdType.date => '<Date><Format>$_d</Format></Date>',
};

/// The index of [tables] in the Beschreibungsstandard, valid against the
/// DTD of 1 August 2002.
String _gobdIndexXml(GobdRequest r, List<GobdTable> tables) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8"?>\r\n')
    ..write('<!DOCTYPE DataSet SYSTEM "$gobdDtdFileName">\r\n')
    ..write('<DataSet>\r\n')
    ..write('  <Version>1.0</Version>\r\n')
    ..write('  <DataSupplier>\r\n')
    ..write('    <Name>${_x(r.supplierName)}</Name>\r\n')
    ..write('    <Location>${_x(r.supplierLocation)}</Location>\r\n')
    ..write('    <Comment>${_x(_scope)}</Comment>\r\n')
    ..write('  </DataSupplier>\r\n')
    ..write('  <Media>\r\n')
    ..write(
      '    <Name>${_x(r.supplierName)} ${_day(r.from)} - ${_day(r.to)}</Name>\r\n',
    );
  for (final t in tables) {
    b
      ..write('    <Table>\r\n')
      ..write('      <URL>${_x(t.url)}</URL>\r\n')
      ..write('      <Name>${_x(t.name)}</Name>\r\n')
      ..write('      <Description>${_x(t.description)}</Description>\r\n')
      ..write(
        '      <Validity><Range><From>${_day(r.from)}</From>'
        '<To>${_day(r.to)}</To></Range><Format>$_d</Format></Validity>\r\n',
      )
      ..write('      <UTF8/>\r\n')
      ..write('      <DecimalSymbol>,</DecimalSymbol>\r\n')
      ..write('      <DigitGroupingSymbol>.</DigitGroupingSymbol>\r\n')
      ..write('      <VariableLength>\r\n')
      ..write('        <ColumnDelimiter>;</ColumnDelimiter>\r\n')
      ..write('        <RecordDelimiter>&#13;&#10;</RecordDelimiter>\r\n')
      ..write('        <TextEncapsulator>&quot;</TextEncapsulator>\r\n');
    for (final c in t.columns) {
      final tag = c.key ? 'VariablePrimaryKey' : 'VariableColumn';
      b.write(
        '        <$tag><Name>${_x(c.name)}</Name>'
        '<Description>${_x(c.description)}</Description>'
        '${_type(c.type)}</$tag>\r\n',
      );
    }
    for (final (columns, table) in t.foreignKeys) {
      b.write(
        '        <ForeignKey>'
        '${[for (final c in columns) '<Name>${_x(c)}</Name>'].join()}'
        '<References>${_x(table)}</References></ForeignKey>\r\n',
      );
    }
    b
      ..write('      </VariableLength>\r\n')
      ..write('    </Table>\r\n');
  }
  b
    ..write('  </Media>\r\n')
    ..write('</DataSet>\r\n');
  return b.toString();
}

/// The scope the index states: these books, not the complete ledger.
const _scope =
    'Nebenbuch der Fakturierung aus DesKilo: Rechnungen, Gutschriften, '
    'Zahlungen, Mitgliederkonten, Umlagen und Eingangsbelege. Nicht die '
    'vollständige Finanzbuchhaltung des Unternehmens.';
