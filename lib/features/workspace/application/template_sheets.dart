// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The sheets of the template workbook (#1661): one method per tab, every
// cell data. [templateWorkbook] checks the batch and hands it here.
import 'dart:convert';

import '../../../core/files/xlsx.dart';
import '../domain/template_capabilities.dart';
import '../domain/template_inspection.dart';
import '../domain/workbook_origin.dart';

/// A cell's value as data, with its state kept apart so false/zero is
/// never confused with "not in this template".
Object? _value(Object? v) => switch (v) {
  null => null,
  final num n when n.isFinite => n,
  num _ => '$v',
  final bool b => b ? 'true' : 'false',
  final String s => s,
  final List<Object?> l =>
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
    this.stage = _noStage,
  });

  static String _noStage(String featureKey) => '';

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
      'absent:product_default':
          'the template does not say; the default applies',
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

  /// #1851 B — a feature's review stage for the reader (alpha, beta, …),
  /// so a template that switches on an experimental feature says so
  /// before anyone applies it. Empty where the caller has no ledger.
  final String Function(String featureKey) stage;
}

/// What every sheet reads: the templates, their comparison and the
/// labels. One method per sheet keeps each tab a unit.
class TemplateSheets {
  TemplateSheets(
    this.inspections, {
    required this.capturedAt,
    required this.words,
    required this.origin,
  }) : keys = [for (final t in inspections) t.key],
       rows = compareTemplates(inspections);

  final List<TemplateInspection> inspections;
  final DateTime capturedAt;
  final WorkbookLabels words;
  final WorkbookOrigin? origin;
  final List<String> keys;
  final List<ComparisonRow> rows;

  List<XlsxSheet> sheets() => [
    _readme(),
    _templates(),
    _comparison(),
    _features(),
    _settings(),
    _requirements(),
    _provenance(),
    _catalogs(),
    _rolepermissions(),
    _validations(),
    _fields(),
  ];

  XlsxSheet _readme() => XlsxSheet(
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
  );

  XlsxSheet _templates() => XlsxSheet(
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
        'source_id',
        'installation_id',
        'scoped_template_id',
        'captured_at',
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
          origin?.sourceId ?? 'unknown',
          origin?.installationId ?? 'unknown',
          origin?.scopedTemplate(t.templateId) ?? 'unknown',
          capturedAt.toUtc().toIso8601String(),
        ],
    ],
  );

  XlsxSheet _comparison() => XlsxSheet(
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
  );

  XlsxSheet _features() => XlsxSheet(
    name: 'Features',
    rows: [
      [
        'feature',
        'label',
        'stage',
        for (final k in keys) ...['$k value', '$k state'],
      ],
      for (final r in rows)
        if (r.id.startsWith('workspace.feature_flags.'))
          [
            r.id.substring('workspace.feature_flags.'.length),
            words.feature(r.id.substring('workspace.feature_flags.'.length)),
            words.stage(r.id.substring('workspace.feature_flags.'.length)),
            for (final c in r.cells) ...[
              _value(c.value),
              _state(c.disposition, c.absent),
            ],
          ],
    ],
  );

  XlsxSheet _settings() => XlsxSheet(
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
  );

  XlsxSheet _requirements() => XlsxSheet(
    name: 'Requirements',
    rows: [
      ['template_key', 'field_id', 'path', 'binding', 'reason'],
      for (final t in inspections)
        for (final r in t.requiredInputs)
          [t.key, r.id, r.path, r.binding, r.reason ?? ''],
    ],
  );

  XlsxSheet _provenance() => XlsxSheet(
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
        'source_id',
        'installation_id',
        'scoped_template_id',
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
          origin?.sourceId ?? 'unknown',
          origin?.installationId ?? 'unknown',
          origin?.scopedTemplate(t.templateId) ?? 'unknown',
        ],
      <Object?>[],
      ['template_key', 'excluded_field', 'portability', 'reason'],
      for (final t in inspections)
        for (final e in t.exclusions)
          [t.key, e.id, e.portability, e.reason ?? ''],
    ],
  );

  XlsxSheet _catalogs() => XlsxSheet(
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
  );

  XlsxSheet _rolepermissions() => XlsxSheet(
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
  );

  XlsxSheet _validations() => XlsxSheet(
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
  );

  XlsxSheet _fields() => XlsxSheet(
    name: 'Fields',
    rows: [
      ['template_key', 'field_key', ..._fieldColumns],
      for (final t in inspections)
        for (final row in _tableRows(t, 'workspace_field_definitions').entries)
          [t.key, row.key, for (final c in _fieldColumns) _cell(row.value[c])],
    ],
  );
}

/// The rows of [table] in [t], by natural row key: each row's top-level
/// attributes, as the inspection recorded them.
Map<String, Map<String, TemplateFieldRecord>> _tableRows(
  TemplateInspection t,
  String table,
) {
  final shape = RegExp(
    '^tables\\.${RegExp.escape(table)}\\[(.*)\\]\\.([a-z_]+)\$',
  );
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
