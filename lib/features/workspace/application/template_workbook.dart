// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1661 — templates as an offline workbook: the inspected settings
// (#1655) of up to [maxTemplates] templates, compared (#1659), in typed
// rows. Configuration only: never members, bookings, invoices or
// credentials — this is not the operational Excel export and never calls
// it. Every cell is data (inline strings or numbers); nothing becomes a
// formula, link or macro.
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/files/file_types.dart';
import '../../../core/files/xlsx.dart';
import '../domain/template_capabilities.dart';
import '../domain/template_inspection.dart';
import '../domain/workspace_repository.dart';

/// The largest named batch one workbook carries; more is refused, never
/// cut short.
const maxTemplates = 50;

/// A cell's value as data, with its state kept apart so false/zero is
/// never confused with "not in this template".
Object? _value(Object? v) => switch (v) {
  null => null,
  num n when n.isFinite => n,
  num _ => '$v',
  bool b => b ? 'true' : 'false',
  String s => s,
  List<Object?> l =>
    l.map((e) => e is Map || e is List ? jsonEncode(e) : '$e').join(', '),
  _ => jsonEncode(v),
};

String _state(TemplateFieldDisposition d, TemplateAbsentMeaning? a) =>
    switch (d) {
      TemplateFieldDisposition.absent =>
        'absent:${(a ?? TemplateAbsentMeaning.unknown).name}',
      _ => d.name,
    };

/// The workbook's sheets for [inspections], captured at [capturedAt].
List<XlsxSheet> templateWorkbook(
  List<TemplateInspection> inspections, {
  required DateTime capturedAt,
}) {
  if (inspections.isEmpty) throw ArgumentError('no template to export');
  if (inspections.length > maxTemplates) {
    throw ArgumentError('at most $maxTemplates templates per workbook');
  }
  final keys = [for (final t in inspections) t.key];
  final rows = compareTemplates(inspections);
  return [
    XlsxSheet(
      name: 'Readme',
      rows: [
        ['DesKilo template export'],
        ['captured_at', capturedAt.toUtc().toIso8601String()],
        ['templates', inspections.length],
        [
          'note',
          'A snapshot of template definitions. Editing this file changes nothing in DesKilo, '
              'and it is not a backup of any workspace: it holds no members, bookings, invoices or credentials.',
        ],
        ['state present', 'the template sets this value'],
        [
          'state absent:inherit',
          'the template does not say; the target keeps its own',
        ],
        [
          'state absent:product_default / registry_default',
          'the template does not say; the default applies',
        ],
        ['state absent:required', 'to be set locally'],
        ['state unknown', 'could not be read; nothing is claimed'],
        ['state excluded / stripped', 'deliberately never published'],
      ],
    ),
    XlsxSheet(
      name: 'Templates',
      rows: [
        [
          'template_key',
          'name',
          'template_id',
          'template_version',
          'schema_version',
          'registry_revision',
          'digest',
          'profile',
          'compatibility',
          'entities',
        ],
        for (final t in inspections)
          [
            t.key,
            t.name,
            t.templateId,
            t.templateVersion,
            t.schemaVersion,
            t.registryRevision,
            t.digest ?? '',
            t.profile.name,
            t.compatibility.name,
            t.entities.join(', '),
          ],
      ],
    ),
    XlsxSheet(
      name: 'Comparison',
      rows: [
        [
          'path',
          'field_id',
          'difference',
          for (final k in keys) ...['$k value', '$k state'],
        ],
        for (final r in rows)
          [
            r.path,
            r.id,
            r.difference.name,
            for (final c in r.cells) ...[
              _value(c.value),
              _state(c.disposition, c.absent),
            ],
          ],
      ],
    ),
    XlsxSheet(
      name: 'Features',
      rows: [
        [
          'feature',
          for (final k in keys) ...['$k value', '$k state'],
        ],
        for (final r in rows)
          if (r.id.startsWith('workspace.feature_flags.'))
            [
              r.id.substring('workspace.feature_flags.'.length),
              for (final c in r.cells) ...[
                _value(c.value),
                _state(c.disposition, c.absent),
              ],
            ],
      ],
    ),
    XlsxSheet(
      name: 'Settings',
      rows: [
        ['template_key', 'path', 'field_id', 'state', 'value', 'reason'],
        for (final t in inspections)
          for (final f in t.fields)
            [
              t.key,
              f.path,
              f.id,
              _state(f.disposition, f.absent),
              _value(f.value),
              f.reason ?? '',
            ],
      ],
    ),
    XlsxSheet(
      name: 'Requirements',
      rows: [
        ['template_key', 'field_id', 'path', 'binding', 'reason'],
        for (final t in inspections)
          for (final r in t.requiredInputs)
            [t.key, r.id, r.path, r.binding, r.reason ?? ''],
      ],
    ),
    XlsxSheet(
      name: 'Provenance',
      rows: [
        [
          'template_key',
          'registered',
          'present',
          'absent',
          'unknown',
          'required_inputs',
          'excluded',
        ],
        for (final t in inspections)
          [
            t.key,
            t.coverage.registered,
            t.coverage.present,
            t.coverage.absent,
            t.coverage.unknown,
            t.coverage.requiredInputs,
            t.exclusions.length,
          ],
        <Object?>[],
        ['template_key', 'excluded_field', 'portability', 'reason'],
        for (final t in inspections)
          for (final e in t.exclusions)
            [t.key, e.id, e.portability, e.reason ?? ''],
      ],
    ),
  ];
}

/// The file name: no template name, no person, just the date.
String templateWorkbookName(DateTime capturedAt) {
  final d = capturedAt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'deskilo-templates-${d.year}${two(d.month)}${two(d.day)}.xlsx';
}

/// Reads each template's inspection and saves the workbook.
class TemplateWorkbookExport {
  const TemplateWorkbookExport(this._workspaces, this._save);
  final WorkspaceRepository _workspaces;
  final FileSaver _save;

  /// The saved location, or null when the person cancelled.
  Future<String?> export(
    List<String> templateIds, {
    required DateTime now,
  }) async {
    if (templateIds.length > maxTemplates) {
      throw ArgumentError('at most $maxTemplates templates per workbook');
    }
    final inspections = [
      for (final id in templateIds)
        await _workspaces.inspectWorkspaceTemplate(id),
    ];
    final Uint8List bytes = buildXlsx(
      templateWorkbook(inspections, capturedAt: now),
    );
    return _save(bytes: bytes, fileName: templateWorkbookName(now));
  }
}
