// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/level.dart';

/// One member row in the configuration PDF — every string pre-resolved at
/// the call site (the domain layer stays l10n-free, ADR 0007).
typedef ConfigPdfMember = ({String name, String role, String status});

/// One level's plan, paired with its [Level] for the section header.
typedef ConfigPdfLevel = ({Level level, FloorPlan plan});

/// Pre-resolved labels for the workspace-configuration PDF (#…): the owner
/// exports a complete, human-readable snapshot of the workspace — settings,
/// every member and their role, and the whole floor plan — from the
/// owner-only settings screen. All strings arrive resolved so the builder
/// stays pure Dart (ADR 0007/0008, same shape as [buildBillPdf]).
class WorkspaceConfigPdfStrings {
  const WorkspaceConfigPdfStrings({
    required this.title,
    required this.overview,
    required this.country,
    required this.currency,
    required this.timezone,
    required this.granularity,
    required this.members,
    required this.colName,
    required this.colRole,
    required this.colStatus,
    required this.features,
    required this.none,
    required this.availability,
    required this.openDays,
    required this.closures,
    required this.floorPlan,
    required this.bookableWhole,
    required this.seatsLabel,
    required this.emptyLevel,
  });

  final String title;
  final String overview;
  final String country;
  final String currency;
  final String timezone;
  final String granularity;
  final String members;
  final String colName;
  final String colRole;
  final String colStatus;
  final String features;
  final String none;
  final String availability;
  final String openDays;
  final String closures;
  final String floorPlan;

  /// Suffix marking an office bookable as a whole room.
  final String bookableWhole;

  /// Prefix of the per-desk seat line, e.g. "Seats".
  final String seatsLabel;

  /// Placeholder for a level with no rooms yet.
  final String emptyLevel;
}

/// Renders the complete workspace configuration as an A4 PDF: an overview,
/// the full member roster with roles and statuses, enabled features,
/// availability, and the level → room → desk → seat floor plan.
///
/// [baseFont]/[boldFont] must be real TTFs (the app embeds Roboto): the
/// base-14 Type1 fonts cannot encode accented member names or the '·'
/// separators the layout uses.
Future<Uint8List> buildWorkspaceConfigPdf({
  required WorkspaceConfigPdfStrings strings,
  required String workspaceName,
  required String generatedOnLabel,
  required String countryLabel,
  required String currencyCode,
  required String timezone,
  required String granularityLabel,
  required List<ConfigPdfMember> members,
  required List<String> featureLabels,
  required String openDaysLabel,
  required List<String> closureLabels,
  required List<ConfigPdfLevel> levels,
  required pw.Font baseFont,
  required pw.Font boldFont,
}) async {
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        _header(
          workspaceName: workspaceName,
          title: strings.title,
          generatedOnLabel: generatedOnLabel,
        ),
        pw.SizedBox(height: 16),
        _section(strings.overview, [
          _line(strings.country, countryLabel),
          _line(strings.currency, currencyCode),
          _line(strings.timezone, timezone),
          _line(strings.granularity, granularityLabel),
        ]),
        _section(strings.members, [
          _memberRow(
            strings.colName,
            strings.colRole,
            strings.colStatus,
            bold: true,
          ),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          if (members.isEmpty)
            _line(strings.none, '')
          else
            for (final member in members)
              _memberRow(member.name, member.role, member.status),
        ]),
        _section(strings.features, [
          if (featureLabels.isEmpty)
            _line(strings.none, '')
          else
            for (final label in featureLabels) _bullet(label),
        ]),
        _section(strings.availability, [
          _line(strings.openDays, openDaysLabel),
          _line(
            strings.closures,
            closureLabels.isEmpty ? strings.none : '',
          ),
          for (final closure in closureLabels) _bullet(closure),
        ]),
        _section(strings.floorPlan, [
          for (final entry in levels) ..._levelBlock(entry, strings),
        ]),
      ],
    ),
  );

  return Uint8List.fromList(await document.save());
}

List<pw.Widget> _levelBlock(
  ConfigPdfLevel entry,
  WorkspaceConfigPdfStrings strings,
) {
  final plan = entry.plan;
  return [
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
      child: pw.Text(
        entry.level.name,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      ),
    ),
    if (plan.offices.isEmpty)
      _line(strings.emptyLevel, '')
    else
      for (final office in plan.offices) ...[
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 3, bottom: 1),
          child: pw.Text(
            office.bookableAsWhole
                ? '${office.name}  (${strings.bookableWhole})'
                : office.name,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        for (final desk in plan.desksOf(office.id))
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 20, bottom: 1),
            child: pw.Text(
              () {
                final seats = plan.seatsOf(desk.id).map((s) => s.name).toList();
                final seatList =
                    seats.isEmpty ? '—' : seats.join(', ');
                return '${desk.name} — ${strings.seatsLabel}: $seatList';
              }(),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
          ),
      ],
  ];
}

pw.Widget _header({
  required String workspaceName,
  required String title,
  required String generatedOnLabel,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        workspaceName,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
      ),
      pw.SizedBox(height: 2),
      pw.Text(title, style: const pw.TextStyle(fontSize: 13)),
      pw.SizedBox(height: 2),
      pw.Text(
        generatedOnLabel,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.Divider(thickness: 1, color: PdfColors.grey800),
    ],
  );
}

pw.Widget _section(String title, List<pw.Widget> children) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ),
          ...children,
        ],
      ),
    );

pw.Widget _line(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
}

pw.Widget _bullet(String text) {
  final line = '•  $text';
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 6, top: 1, bottom: 1),
    child: pw.Text(line, style: const pw.TextStyle(fontSize: 10)),
  );
}

pw.Widget _memberRow(
  String name,
  String role,
  String status, {
  bool bold = false,
}) {
  final style = pw.TextStyle(
    fontSize: 10,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 4, child: pw.Text(name, style: style)),
        pw.Expanded(flex: 3, child: pw.Text(role, style: style)),
        pw.Expanded(flex: 3, child: pw.Text(status, style: style)),
      ],
    ),
  );
}
