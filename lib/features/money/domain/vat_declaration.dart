// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:xml/xml.dart';

import '../../../core/data/json_reader.dart';
import '../../../core/data/system_columns.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'invoice.dart';
import 'vat_components.dart';
import 'vat_form_boxes.dart';
import 'vat_form_catalogue.dart';
import 'vat_forms.dart';
import 'vat_tax_point.dart';

export 'vat_forms.dart' show VatFormBox;

/// One per-rate line of a VAT declaration (#534): everything the period's
/// issued invoices taxed at [percent].
class VatDeclarationLine {
  const VatDeclarationLine({
    required this.percent,
    required this.grossCents,
    required this.netCents,
    required this.vatCents,
    required this.invoiceCount,
    this.category = '',
    this.corrects = '',
    this.correctsStart,
    this.correctsEnd,
    this.direction = 'output',
    this.components = const [],
    this.group = '',
  });

  final double percent;

  /// #2480 -- the fiscal group (`VatGroup.wire`) the rate this line was taxed
  /// at belongs to, read from the country's rate rows when a return form is
  /// filled; '' where the rate is in none of them. Never stored.
  final String group;

  /// This line, tagged with the fiscal group of its rate.
  VatDeclarationLine inGroup(String group) => VatDeclarationLine(
        percent: percent,
        grossCents: grossCents,
        netCents: netCents,
        vatCents: vatCents,
        invoiceCount: invoiceCount,
        category: category,
        corrects: corrects,
        correctsStart: correctsStart,
        correctsEnd: correctsEnd,
        direction: direction,
        components: components,
        group: group,
      );

  /// #2357 — the UNCL5305 category the server keeps apart at one rate
  /// (S, AE, E, Z, G, O); '' on a line an older client computed.
  final String category;
  final int grossCents;
  final int netCents;
  final int vatCents;
  final int invoiceCount;

  /// #2357 (0406) — a CORRECTION line: what changed, after it was filed,
  /// in the return [corrects] names (its period [correctsStart] ..
  /// [correctsEnd]). '' on the period's own lines.
  final String corrects;
  final DateTime? correctsStart;
  final DateTime? correctsEnd;

  /// Whether this line corrects an earlier, filed return.
  bool get isCorrection => corrects.isNotEmpty;

  /// #2357 — 'output' (VAT collected on sales) or 'input' (deductible VAT
  /// on expenses: [vatCents] is the deductible share, [netCents] the
  /// expense's base).
  final String direction;
  bool get isInput => direction == 'input';

  /// #2361 — the taxes this line is made of (GST and QST of a Canadian
  /// line), as the server froze them (0425); empty when it did not split.
  final List<VatComponent> components;

  Map<String, dynamic> toJson() => {
        'percent': percent,
        if (category.isNotEmpty) 'category': category,
        'gross_cents': grossCents,
        'net_cents': netCents,
        'vat_cents': vatCents,
        'invoice_count': invoiceCount,
        if (isInput) 'direction': 'input',
        if (components.isNotEmpty)
          'components': [for (final c in components) c.toJson()],
        if (isCorrection) ...{
          'correction': true,
          'corrects': corrects,
          'corrects_start': ?_day(correctsStart),
          'corrects_end': ?_day(correctsEnd),
        },
      };

  factory VatDeclarationLine.fromJson(Map<String, dynamic> json) {
    final row = JsonReader.of(json, context: 'vat_declarations.lines');
    final correction = row.boolOr('correction', fallback: false);
    return VatDeclarationLine(
      percent: row.doubleOrNull('percent') ?? 0,
      category: row.stringOr('category'),
      grossCents: row.intOrNull('gross_cents') ?? 0,
      netCents: row.intOrNull('net_cents') ?? 0,
      vatCents: row.intOrNull('vat_cents') ?? 0,
      invoiceCount: row.intOrNull('invoice_count') ?? 0,
      corrects: correction ? row.stringOr('corrects') : '',
      correctsStart: correction ? row.dateTimeOrNull('corrects_start') : null,
      correctsEnd: correction ? row.dateTimeOrNull('corrects_end') : null,
      direction: row.stringOr('direction') == 'input' ? 'input' : 'output',
      components: row.objects('components', VatComponent.fromReader),
    );
  }
}

String? _day(DateTime? day) => day?.toIso8601String().substring(0, 10);

/// A periodic VAT declaration (0107): the per-rate output-VAT summary of
/// one filing period. #2357 (0402): the server computes the figures
/// (`compute_vat_return`) and the lifecycle is draft (figures an older
/// client sent) → prepared (the server's figures) → filed (by the owner,
/// with the authority's receipt reference).
class VatDeclaration implements SystemStamped {
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
    this.number = '',
    this.system = SystemColumns.none,
  });

  /// #992 — the server's stamp on this row.
  @override
  final SystemColumns system;

  final String id;
  final String workspaceId;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// 'draft' | 'prepared' | 'filed' ('submitted' before 0402).
  final String status;
  final List<VatDeclarationLine> lines;
  final int totalNetCents;
  final int totalVatCents;
  final String currency;
  final int invoiceCount;
  final DateTime createdAt;
  final DateTime? submittedAt;

  /// 'manual' | 'export' once filed ('platform' on a return an upload
  /// stamped before 0402).
  final String submittedChannel;
  final String submittedReceipt;
  /// #928 — DECL-2026-0001, drawn when the declaration is filed; '' for a draft.
  final String number;

  /// Filed with the tax authority: immutable from then on.
  bool get isFiled => status == 'filed' || status == 'submitted';

  /// The server's figures, ready to be filed.
  bool get isPrepared => status == 'prepared';

  factory VatDeclaration.fromRow(Map<String, dynamic> row) => VatDeclaration(
        system: SystemColumns.fromRow(row),
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
        number: row['number'] as String? ?? '',
      );
}

/// Aggregates a period's ISSUED invoices into declaration lines — the
/// tax-point engine on the invoice-date rule (`vat_tax_point.dart`),
/// with the EXACT arithmetic the invoices were built with: per-line
/// `vatSplit`, summed per rate, so the lines match every issued document
/// to the cent. Voided invoices and settlements are excluded; credit
/// notes count with their sign. A declaration on another basis reads
/// [vatDeclarationLinesOf] over [vatTaxPointLedger] with that basis.
List<VatDeclarationLine> computeVatDeclarationLines(
  Iterable<Invoice> invoices,
  DateTime periodStart,
  DateTime periodEnd,
) =>
    vatDeclarationLinesOf(
        vatTaxPointLedger(invoices), periodStart, periodEnd);

/// Maps declaration lines onto the country's official form boxes, so the
/// owner copies numbers straight onto the EFI/ELSTER screen (or the file
/// their EDI partner uploads). #2357 — the forms are data, per country
/// and year (`vat_form_catalogue.dart`), rounded as each form rounds;
/// [periodEnd] picks the layout in force (the latest when null).
List<VatFormBox> vatFormBoxes(
  String countryCode,
  List<VatDeclarationLine> lines, {
  DateTime? periodEnd,
  TaxReferenceSet? reference,
}) {
  final data = reference ?? ActiveTaxReference.current;
  final end = periodEnd ?? DateTime(9999);
  final spec =
      vatFormSpecFor(countryCode, end, reference: data) ?? genericVatForm(lines);
  final groupOf = lineGroupsFor(data, spec.country, end);
  return fillVatForm(spec, [for (final l in lines) l.inGroup(groupOf(l))]);
}

/// #2361 — the QST part of Revenu Québec's FPZ-500, for a Canadian
/// declaration that charged or claimed the QST; empty otherwise.
List<VatFormBox> vatQstFormBoxes(List<VatDeclarationLine> lines) {
  final hasQst = lines.any((l) => (l.components.isNotEmpty
          ? l.components
          : vatComponentsOf(
              qstFormSpec.country.split('-').first, l.percent, l.netCents, l.vatCents))
      .any((c) => c.scheme == 'QST' && c.taxCents != 0));
  return hasQst ? fillVatForm(qstFormSpec, lines) : const [];
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
  final builder = XmlBuilder()
    ..processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('vat-declaration', nest: () {
    builder.attribute('schema', 'deskilo-vat-1');
    builder.element('seller', nest: () {
      builder
        ..element('name', nest: workspaceName)
        ..element('vat-id', nest: vatId)
        ..element('country', nest: countryCode.toUpperCase());
    });
    builder.element('period', nest: () {
      builder
        ..element('start',
          nest: declaration.periodStart.toIso8601String().substring(0, 10))
        ..element('end',
          nest: declaration.periodEnd.toIso8601String().substring(0, 10));
    });
    builder.element('currency', nest: declaration.currency);
    builder.element('rates', nest: () {
      for (final line in declaration.lines) {
        _rateXml(builder, line);
      }
    });
    builder.element('boxes', nest: () {
      for (final box in vatFormBoxes(countryCode, declaration.lines,
          periodEnd: declaration.periodEnd)) {
        _boxXml(builder, box);
      }
    });
    builder.element('totals', nest: () {
      builder
        ..element('net-cents',
          nest: declaration.totalNetCents.toString())
        ..element('vat-cents',
          nest: declaration.totalVatCents.toString());
    });
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

void _rateXml(XmlBuilder builder, VatDeclarationLine line) {
  builder.element('rate', nest: () {
    builder.attribute('percent', line.percent.toString());
    if (line.category.isNotEmpty) {
      builder.attribute('category', line.category);
    }
    if (line.isInput) builder.attribute('direction', 'input');
    if (line.isCorrection) {
      builder
        ..attribute('correction', 'true')
        ..attribute('corrects', line.corrects);
      if (_day(line.correctsStart) case final start?) {
        builder.attribute('corrects-start', start);
      }
      if (_day(line.correctsEnd) case final end?) {
        builder.attribute('corrects-end', end);
      }
    }
    builder
      ..element('net-cents', nest: line.netCents.toString())
      ..element('vat-cents', nest: line.vatCents.toString())
      ..element('invoice-count', nest: line.invoiceCount.toString());
  });
}

void _boxXml(XmlBuilder builder, VatFormBox box) {
  builder.element('box', nest: () {
    builder
      ..attribute('code', box.code)
      ..attribute('label', box.label);
    if (box.hasBase && box.baseKey.isNotEmpty) {
      builder.attribute('base-key', box.baseKey);
    }
    if (box.hasTax && box.taxKey.isNotEmpty) {
      builder.attribute('tax-key', box.taxKey);
    }
    if (box.hasBase) {
      builder.element('net-cents', nest: box.netCents.toString());
    }
    if (box.hasTax) {
      builder.element('vat-cents', nest: box.vatCents.toString());
    }
  });
}
