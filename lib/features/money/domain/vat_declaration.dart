// SPDX-License-Identifier: 0BSD
import 'package:xml/xml.dart';

import 'billing_rules.dart';
import 'invoice.dart';
import 'vat_rate.dart';

/// One per-rate line of a VAT declaration (#534): everything the period's
/// issued invoices taxed at [percent].
class VatDeclarationLine {
  const VatDeclarationLine({
    required this.percent,
    required this.grossCents,
    required this.netCents,
    required this.vatCents,
    required this.invoiceCount,
  });

  final double percent;
  final int grossCents;
  final int netCents;
  final int vatCents;
  final int invoiceCount;

  Map<String, dynamic> toJson() => {
        'percent': percent,
        'gross_cents': grossCents,
        'net_cents': netCents,
        'vat_cents': vatCents,
        'invoice_count': invoiceCount,
      };

  factory VatDeclarationLine.fromJson(Map<String, dynamic> json) =>
      VatDeclarationLine(
        percent: (json['percent'] as num).toDouble(),
        grossCents: (json['gross_cents'] as num?)?.toInt() ?? 0,
        netCents: (json['net_cents'] as num).toInt(),
        vatCents: (json['vat_cents'] as num).toInt(),
        invoiceCount: (json['invoice_count'] as num?)?.toInt() ?? 0,
      );
}

/// A periodic VAT declaration (0107): the per-rate output-VAT summary of
/// one filing period, with its draft → submitted lifecycle.
class VatDeclaration {
  const VatDeclaration({
    required this.id,
    required this.workspaceId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.lines,
    required this.totalNetCents,
    required this.totalVatCents,
    required this.currency,
    required this.invoiceCount,
    required this.createdAt,
    this.submittedAt,
    this.submittedChannel = '',
    this.submittedReceipt = '',
  });

  final String id;
  final String workspaceId;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// 'draft' | 'submitted'.
  final String status;
  final List<VatDeclarationLine> lines;
  final int totalNetCents;
  final int totalVatCents;
  final String currency;
  final int invoiceCount;
  final DateTime createdAt;
  final DateTime? submittedAt;

  /// 'platform' | 'export' | 'manual' once submitted.
  final String submittedChannel;
  final String submittedReceipt;

  bool get isSubmitted => status == 'submitted';

  factory VatDeclaration.fromRow(Map<String, dynamic> row) => VatDeclaration(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        periodStart: DateTime.parse(row['period_start'] as String),
        periodEnd: DateTime.parse(row['period_end'] as String),
        status: row['status'] as String? ?? 'draft',
        lines: [
          for (final line in (row['lines'] as List? ?? const []))
            VatDeclarationLine.fromJson(
                Map<String, dynamic>.from(line as Map)),
        ],
        totalNetCents: (row['total_net_cents'] as num).toInt(),
        totalVatCents: (row['total_vat_cents'] as num).toInt(),
        currency: row['currency'] as String? ?? '',
        invoiceCount: (row['invoice_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
        submittedAt: row['submitted_at'] == null
            ? null
            : DateTime.parse(row['submitted_at'] as String).toUtc(),
        submittedChannel: row['submitted_channel'] as String? ?? '',
        submittedReceipt: row['submitted_receipt'] as String? ?? '',
      );
}

/// Aggregates a period's ISSUED invoices into declaration lines with the
/// EXACT arithmetic the invoices were built with: per-line [vatSplit]
/// (gross-inclusive → net + tax, rounded per line), summed per rate —
/// the declaration therefore matches every issued document to the cent.
///
/// Voided invoices are excluded (their replacement, if issued in the
/// period, counts on its own). Credit notes (negative invoices) count
/// with their sign, exactly as the authority nets them. Lines at 0 %
/// (credits, exempt positions) are reported as the zero-rate base.
List<VatDeclarationLine> computeVatDeclarationLines(
  Iterable<Invoice> invoices,
  DateTime periodStart,
  DateTime periodEnd,
) {
  final gross = <double, int>{};
  final net = <double, int>{};
  final count = <double, Set<String>>{};
  for (final invoice in invoices) {
    if (invoice.voidedAt != null) continue;
    // #831 — a settlement carries its sources' lines; they are declared once.
    if (invoice.kind == InvoiceKind.settlement) continue;
    final day = DateTime(
        invoice.issuedAt.year, invoice.issuedAt.month, invoice.issuedAt.day);
    if (day.isBefore(periodStart) || day.isAfter(periodEnd)) continue;
    for (final line in invoice.lines) {
      final split = vatSplit(line.amountCents, line.vatPercent);
      gross[line.vatPercent] =
          (gross[line.vatPercent] ?? 0) + line.amountCents;
      net[line.vatPercent] = (net[line.vatPercent] ?? 0) + split.netCents;
      count.putIfAbsent(line.vatPercent, () => <String>{}).add(invoice.id);
    }
  }
  final percents = gross.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final p in percents)
      VatDeclarationLine(
        percent: p,
        grossCents: gross[p]!,
        netCents: net[p]!,
        vatCents: gross[p]! - net[p]!,
        invoiceCount: count[p]!.length,
      ),
  ];
}

/// One box of a country's official return form the declaration lines map
/// onto (#534) — e.g. CA3 line 08 or UStVA Kennzahl 81.
class VatFormBox {
  const VatFormBox({
    required this.code,
    required this.label,
    required this.netCents,
    required this.vatCents,
  });

  final String code;
  final String label;
  final int netCents;
  final int vatCents;
}

/// Maps declaration lines onto the country's official form boxes, so the
/// owner copies numbers straight onto the EFI/ELSTER screen (or the file
/// their EDI partner uploads).
///
///  * FR — CA3 (form 3310): base+VAT per rate on lines 08 (20 %),
///    9B (5,5 %), 09 (10 %), 11 (2,1 %); everything else on line 14
///    ("opérations imposables à un autre taux").
///  * DE — UStVA (USt 1 A): Kz 81 (19 %) / Kz 86 (7 %) carry the NET
///    base, the tax computes on the form; other rates on Kz 35/36.
///  * Anywhere else — a generic per-rate listing, one box per rate.
List<VatFormBox> vatFormBoxes(
  String countryCode,
  List<VatDeclarationLine> lines,
) {
  final code = countryCode.toUpperCase();
  VatDeclarationLine? at(double percent) =>
      lines.where((l) => l.percent == percent).firstOrNull;
  List<VatDeclarationLine> others(Set<double> named) =>
      [for (final l in lines) if (!named.contains(l.percent)) l];

  switch (code) {
    case 'FR':
      final named = {20.0, 10.0, 5.5, 2.1, 0.0};
      final rest = others(named);
      return [
        if (at(20.0) case final l?)
          VatFormBox(
              code: '08',
              label: 'Taux normal 20 %',
              netCents: l.netCents,
              vatCents: l.vatCents),
        if (at(10.0) case final l?)
          VatFormBox(
              code: '09',
              label: 'Taux réduit 10 %',
              netCents: l.netCents,
              vatCents: l.vatCents),
        if (at(5.5) case final l?)
          VatFormBox(
              code: '9B',
              label: 'Taux réduit 5,5 %',
              netCents: l.netCents,
              vatCents: l.vatCents),
        if (at(2.1) case final l?)
          VatFormBox(
              code: '11',
              label: 'Taux particulier 2,1 %',
              netCents: l.netCents,
              vatCents: l.vatCents),
        for (final l in rest)
          VatFormBox(
              code: '14',
              label: 'Autre taux ${_pct(l.percent)}',
              netCents: l.netCents,
              vatCents: l.vatCents),
        if (at(0.0) case final l?)
          VatFormBox(
              code: '05',
              label: 'Opérations non imposées / taux 0',
              netCents: l.netCents,
              vatCents: 0),
      ];
    case 'DE':
      final named = {19.0, 7.0, 0.0};
      final rest = others(named);
      return [
        if (at(19.0) case final l?)
          VatFormBox(
              code: 'Kz 81',
              label: 'Umsätze 19 %',
              netCents: l.netCents,
              vatCents: l.vatCents),
        if (at(7.0) case final l?)
          VatFormBox(
              code: 'Kz 86',
              label: 'Umsätze 7 %',
              netCents: l.netCents,
              vatCents: l.vatCents),
        for (final l in rest)
          VatFormBox(
              code: 'Kz 35',
              label: 'Andere Steuersätze ${_pct(l.percent)}',
              netCents: l.netCents,
              vatCents: l.vatCents),
        if (at(0.0) case final l?)
          VatFormBox(
              code: 'Kz 48',
              label: 'Nicht steuerbare / 0 %-Umsätze',
              netCents: l.netCents,
              vatCents: 0),
      ];
    default:
      return [
        for (final l in lines)
          VatFormBox(
              code: _pct(l.percent),
              label: l.percent == 0
                  ? '0 % / out of scope'
                  : 'Rate ${_pct(l.percent)}',
              netCents: l.netCents,
              vatCents: l.vatCents),
      ];
  }
}

String _pct(double percent) {
  final text = percent == percent.roundToDouble()
      ? percent.toStringAsFixed(0)
      : percent.toString();
  return '$text %';
}

/// The machine-readable export (#534): a compact self-describing XML any
/// EDI partner, accountant tool or spreadsheet can ingest. Amounts in
/// cents, period as ISO dates, one `<rate>` per declaration line plus the
/// country's official-box mapping — the exact numbers to key into
/// EFI/ELSTER when no upload channel exists.
String vatDeclarationXml({
  required VatDeclaration declaration,
  required String workspaceName,
  required String vatId,
  required String countryCode,
}) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('vat-declaration', nest: () {
    builder.attribute('schema', 'deskilo-vat-1');
    builder.element('seller', nest: () {
      builder.element('name', nest: workspaceName);
      builder.element('vat-id', nest: vatId);
      builder.element('country', nest: countryCode.toUpperCase());
    });
    builder.element('period', nest: () {
      builder.element('start',
          nest: declaration.periodStart.toIso8601String().substring(0, 10));
      builder.element('end',
          nest: declaration.periodEnd.toIso8601String().substring(0, 10));
    });
    builder.element('currency', nest: declaration.currency);
    builder.element('rates', nest: () {
      for (final line in declaration.lines) {
        builder.element('rate', nest: () {
          builder.attribute('percent', line.percent.toString());
          builder.element('net-cents', nest: line.netCents.toString());
          builder.element('vat-cents', nest: line.vatCents.toString());
          builder.element('invoice-count',
              nest: line.invoiceCount.toString());
        });
      }
    });
    builder.element('boxes', nest: () {
      for (final box in vatFormBoxes(countryCode, declaration.lines)) {
        builder.element('box', nest: () {
          builder.attribute('code', box.code);
          builder.attribute('label', box.label);
          builder.element('net-cents', nest: box.netCents.toString());
          builder.element('vat-cents', nest: box.vatCents.toString());
        });
      }
    });
    builder.element('totals', nest: () {
      builder.element('net-cents',
          nest: declaration.totalNetCents.toString());
      builder.element('vat-cents',
          nest: declaration.totalVatCents.toString());
    });
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// Filing periods (#534): month or quarter, walked backwards from [now].
/// (France: réel normal files monthly, réel simplifié yearly with
/// acomptes; Germany: monthly or quarterly by tax volume — the owner
/// picks what their regime requires.)
List<({DateTime start, DateTime end, bool isQuarter})> vatFilingPeriods(
  DateTime now, {
  int monthsBack = 12,
}) {
  final periods = <({DateTime start, DateTime end, bool isQuarter})>[];
  for (var i = 0; i < monthsBack; i++) {
    final start = DateTime(now.year, now.month - i);
    periods.add((
      start: start,
      end: DateTime(start.year, start.month + 1, 0),
      isQuarter: false,
    ));
  }
  final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
  for (var i = 0; i < 4; i++) {
    final start = DateTime(now.year, quarterStartMonth - 3 * i);
    periods.add((
      start: start,
      end: DateTime(start.year, start.month + 3, 0),
      isQuarter: true,
    ));
  }
  return periods;
}
