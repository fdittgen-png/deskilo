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
import '../domain/workbook_origin.dart';

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

/// #1661 — the words a person reads in the workbook, in the language they
/// chose. Technical keys, field ids, states and values stay the same in
/// every language; only these explanations and labels change.
class WorkbookLabels {
  const WorkbookLabels({
    required this.language,
    required this.note,
    required this.states,
    required this.feature,
    required this.wide,
  });

  /// English, for callers without a reader's language.
  static WorkbookLabels english() => WorkbookLabels(
    language: 'en',
    note:
        'A snapshot of template definitions. Editing this file changes '
        'nothing in DesKilo, and it is not a backup of any workspace: it '
        'holds no members, bookings, invoices or credentials.',
    states: const {
      'present': 'the template sets this value',
      'absent:inherit': 'the template does not say; the target keeps its own',
      'absent:product_default': 'the template does not say; the default applies',
      'absent:required': 'to be set locally',
      'unknown': 'could not be read; nothing is claimed',
      'excluded': 'deliberately never published',
    },
    feature: (key) => key,
    wide:
        'Catalogs, RolePermissions, Validations and Fields show a value where '
        'the template sets it, and its state otherwise',
  );

  /// ISO language code of the labels.
  final String language;
  final String note;

  /// State (as written in the sheets) → what it means.
  final Map<String, String> states;

  /// A feature's registry key → its name for the reader.
  final String Function(String featureKey) feature;

  /// How the wide sheets read.
  final String wide;
}

/// The workbook's sheets for [inspections], captured at [capturedAt].
List<XlsxSheet> templateWorkbook(
  List<TemplateInspection> inspections, {
  required DateTime capturedAt,
  WorkbookLabels? labels,
  WorkbookOrigin? origin,
}) {
  final words = labels ?? WorkbookLabels.english();
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
        ['language', words.language],
        ['note', words.note],
        for (final s in words.states.entries) ['state ${s.key}', s.value],
        ['wide sheets', words.wide],
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
          'source_id', 'installation_id', 'scoped_template_id', 'captured_at',
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
            origin?.sourceId ?? 'unknown', origin?.installationId ?? 'unknown',
            origin?.scopedTemplate(t.templateId) ?? 'unknown',
            capturedAt.toUtc().toIso8601String(),
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
          'label',
          for (final k in keys) ...['$k value', '$k state'],
        ],
        for (final r in rows)
          if (r.id.startsWith('workspace.feature_flags.'))
            [
              r.id.substring('workspace.feature_flags.'.length),
              words.feature(r.id.substring('workspace.feature_flags.'.length)),
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
          'source_id', 'installation_id', 'scoped_template_id',
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
            origin?.sourceId ?? 'unknown', origin?.installationId ?? 'unknown',
            origin?.scopedTemplate(t.templateId) ?? 'unknown',
          ],
        <Object?>[],
        ['template_key', 'excluded_field', 'portability', 'reason'],
        for (final t in inspections)
          for (final e in t.exclusions)
            [t.key, e.id, e.portability, e.reason ?? ''],
      ],
    ),
    XlsxSheet(
      name: 'Catalogs',
      rows: [
        ['template_key', 'catalog', 'row', 'attribute', 'state', 'value'],
        for (final t in inspections)
          for (final table in _catalogTables)
            for (final row in _tableRows(t, table).entries)
              for (final attr in row.value.entries)
                [
                  t.key,
                  table,
                  row.key,
                  attr.key,
                  _state(attr.value.disposition, attr.value.absent),
                  _value(attr.value.value),
                ],
      ],
    ),
    XlsxSheet(
      name: 'RolePermissions',
      rows: [
        ['template_key', 'role', 'kind', 'permissions', 'state'],
        for (final t in inspections) ...[
          for (final f in t.fields)
            if (f.id.startsWith('workspace.role_permissions.'))
              [
                t.key,
                f.id.substring('workspace.role_permissions.'.length),
                'base',
                _cell(f),
                _state(f.disposition, f.absent),
              ],
          for (final row in _tableRows(t, 'workspace_roles').entries)
            [
              t.key,
              row.key,
              'custom',
              _cell(row.value['permissions']),
              _state(
                row.value['permissions']?.disposition ??
                    TemplateFieldDisposition.absent,
                row.value['permissions']?.absent,
              ),
            ],
        ],
      ],
    ),
    XlsxSheet(
      name: 'Validations',
      rows: [
        ['template_key', 'event_type', ..._validationColumns],
        for (final t in inspections)
          for (final row in _tableRows(t, 'validation_policies').entries)
            [
              t.key,
              row.key,
              for (final c in _validationColumns) _cell(row.value[c]),
            ],
      ],
    ),
    XlsxSheet(
      name: 'Fields',
      rows: [
        ['template_key', 'field_key', ..._fieldColumns],
        for (final t in inspections)
          for (final row
              in _tableRows(t, 'workspace_field_definitions').entries)
            [
              t.key,
              row.key,
              for (final c in _fieldColumns) _cell(row.value[c]),
            ],
      ],
    ),
  ];
}

/// The rows of [table] in [t], by natural row key: each row's top-level
/// attributes, as the inspection recorded them.
Map<String, Map<String, TemplateFieldRecord>> _tableRows(
  TemplateInspection t,
  String table,
) {
  final shape = RegExp('^tables\\.${RegExp.escape(table)}\\[(.*)\\]\\.([a-z_]+)\$');
  final rows = <String, Map<String, TemplateFieldRecord>>{};
  for (final f in t.fields) {
    final m = shape.firstMatch(f.path);
    if (m == null) continue;
    (rows[m.group(1)!] ??= {})[m.group(2)!] = f;
  }
  return rows;
}

/// A wide cell: the value when the template sets it, otherwise its
/// state (absent:inherit, unknown, ...), so a blank never hides which.
Object? _cell(TemplateFieldRecord? f) => f == null
    ? 'absent:unknown'
    : f.disposition == TemplateFieldDisposition.present
    ? _value(f.value)
    : _state(f.disposition, f.absent);

const _catalogTables = [
  'plans',
  'fee_bands',
  'credit_products',
  'packages',
  'services',
  'accessories',
];

const _validationColumns = [
  'required_count',
  'owner_required',
  'admins_may_validate',
  'owner_may_self_validate',
  'sequential',
  'validator_scope',
  'min_amount_cents',
  'auto_validate_admin',
  'auto_validate_owner',
  'eligible_admin_ids',
];

const _fieldColumns = [
  'type',
  'required',
  'personal_data',
  'visibility',
  'contexts',
  'group_key',
  'active',
  'sort_order',
];

/// The file name: no template name, no person, just the date.
String templateWorkbookName(DateTime capturedAt) {
  final d = capturedAt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'deskilo-templates-${d.year}${two(d.month)}${two(d.day)}.xlsx';
}

/// #1661 — where an export stands: reading template [done] of [total],
/// building the workbook, or waiting on the save dialog. No ETA: only
/// what has actually happened.
enum WorkbookStage { reading, building, saving }

class WorkbookProgress {
  const WorkbookProgress(this.stage, this.done, this.total);
  final WorkbookStage stage;
  final int done;
  final int total;
}

/// Asked between steps. Once the save dialog is open the export can no
/// longer be cancelled from here; the dialog's own cancel answers.
class WorkbookCancel {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Thrown when [WorkbookCancel] was asked before the save: nothing was
/// saved, and nothing is left behind.
class WorkbookCancelled implements Exception {
  const WorkbookCancelled();
}

/// Reads each template's inspection and saves the workbook.
class TemplateWorkbookExport {
  const TemplateWorkbookExport(this._workspaces, this._save,
      {required this.origin, this.isCurrent});
  final WorkspaceRepository _workspaces;
  final FileSaver _save;
  final WorkbookOriginRepository origin;
  final bool Function()? isCurrent;

  /// The saved location, or null when the person cancelled the save
  /// dialog. Throws [WorkbookCancelled] when [cancel] was asked first.
  Future<String?> export(
    List<String> templateIds, {
    required DateTime now,
    WorkbookLabels? labels,
    void Function(WorkbookProgress progress)? onProgress,
    WorkbookCancel? cancel,
  }) async {
    final ids = List<String>.unmodifiable(templateIds);
    if (ids.isEmpty || ids.toSet().length != ids.length || ids.length > maxTemplates) {
      throw ArgumentError('at most $maxTemplates templates per workbook');
    }
    void check() {
      if (cancel?.isCancelled ?? false) throw const WorkbookCancelled();
      if (!(isCurrent?.call() ?? true)) throw StateError('workbook_source_changed');
    }
    check();
    final capturedOrigin = await origin.read();
    check();
    final total = ids.length;
    final inspections = <TemplateInspection>[];
    for (final id in ids) {
      check();
      onProgress?.call(
        WorkbookProgress(WorkbookStage.reading, inspections.length, total),
      );
      final inspection = await _workspaces.inspectWorkspaceTemplate(id);
      check();
      if (inspection.templateId != id || !inspection.usable) {
        throw StateError('workbook_inspection_changed');
      }
      inspections.add(inspection);
    }
    if (!capturedOrigin.sameContext(await origin.read())) throw StateError('workbook_source_changed');
    check();
    onProgress?.call(WorkbookProgress(WorkbookStage.building, total, total));
    final Uint8List bytes = buildXlsx(
      templateWorkbook(inspections, capturedAt: now, labels: labels, origin: capturedOrigin),
    );
    check();
    onProgress?.call(WorkbookProgress(WorkbookStage.saving, total, total));
    check();
    return _save(bytes: bytes, fileName: templateWorkbookName(now));
  }
}
