// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the sales-tax summary of a period, the figures a seller in the
// United States keys into each state's portal (the app files nothing: state
// portals, SST and Avalara services need accounts of the owner).
//
// The server states them (`sales_tax_return`, migration 0439: pgTAP 191) from
// the jurisdictions frozen on the issued invoices; the worksheet CSV below
// writes them for the owner.
import '../../../core/data/json_reader.dart';
import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import '../../../core/text/number_text.dart';
import '../../../core/time/date_text.dart';

/// What a row of the summary states.
enum SalesTaxLine {
  /// A state's taxed sales and the tax collected on them.
  taxable('taxable'),

  /// One jurisdiction's base, rate and tax within a state.
  tax('tax'),

  /// Sales the state's law exempts.
  exemptStatute('exempt_statute'),

  /// Sales a customer's exemption certificate exempted.
  exemptCertificate('exempt_certificate'),

  /// What is outside the tax (a licence to occupy space, a payment).
  outside('outside');

  const SalesTaxLine(this.wire);
  final String wire;

  static SalesTaxLine? tryWire(String wire) {
    for (final l in values) {
      if (l.wire == wire) return l;
    }
    return null;
  }
}

/// One row of the summary: a [line] of a [state], for a jurisdiction when it
/// is a `tax` line.
class SalesTaxReturnRow {
  const SalesTaxReturnRow({
    required this.state,
    required this.line,
    this.level = '',
    this.name = '',
    this.percent = 0,
    required this.baseCents,
    required this.taxCents,
    required this.invoiceCount,
  });

  final String state;
  final SalesTaxLine line;
  final String level;
  final String name;
  final double percent;
  final int baseCents;
  final int taxCents;
  final int invoiceCount;

  /// A row of `sales_tax_return`; null for a kind this app does not know
  /// (a newer server), which the worksheet then leaves out.
  static SalesTaxReturnRow? fromJson(Map<Object?, Object?> json) {
    final r = JsonReader.of(json, context: 'sales_tax_return');
    final line = SalesTaxLine.tryWire(r.string('kind'));
    if (line == null) return null;
    return SalesTaxReturnRow(
      state: r.string('state'),
      line: line,
      level: r.stringOr('level'),
      name: r.stringOr('name'),
      percent: r.doubleOrNull('percent') ?? 0,
      baseCents: r.intOrNull('base_cents') ?? 0,
      taxCents: r.intOrNull('tax_cents') ?? 0,
      invoiceCount: r.intOrNull('invoice_count') ?? 0,
    );
  }
}

/// The worksheet as a CSV for the owner to key into the state portal:
/// `period_start, period_end, state, line, level, jurisdiction, rate_percent,
/// sales, tax, invoices` -- amounts with a dot, never quoted, in the grain of
/// [currency] (dollars by default).
String salesTaxWorksheetCsv(
  List<SalesTaxReturnRow> rows, {
  required DateTime start,
  required DateTime end,
  String currency = 'USD',
}) {
  final out = StringBuffer(
    'period_start,period_end,state,line,level,jurisdiction,rate_percent,sales,tax,invoices\r\n',
  );
  for (final r in rows) {
    final cells = [
      isoDay(start),
      isoDay(end),
      csvCell(r.state),
      r.line.wire,
      csvCell(r.level),
      csvCell(r.name),
      if (r.line == SalesTaxLine.tax) percentText(r.percent) else '',
      minorToText(r.baseCents, currency),
      minorToText(r.taxCents, currency),
      '${r.invoiceCount}',
    ];
    out.write('${cells.join(',')}\r\n');
  }
  return out.toString();
}
