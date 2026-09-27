// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1661 — the template workbook: configuration only, typed, every
// template's fields present, false kept apart from "not in this
// template", more than the batch limit refused, and nothing that a
// spreadsheet would run.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/xlsx.dart';
import 'package:deskilo/features/workspace/application/template_workbook.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:flutter_test/flutter_test.dart';

TemplateInspection _i(String key, List<TemplateFieldRecord> fields) =>
    TemplateInspection(
      templateId: 'id-$key',
      key: key,
      name: key,
      status: TemplateInspectionStatus.ok,
      profile: TemplateProfile.partial,
      compatibility: TemplateCompatibility.supported,
      outline: const TemplateOutline(
        compatibility: TemplateCompatibility.supported,
        groups: [],
      ),
      fields: fields,
    );

TemplateFieldRecord _f(String id, Object? v) => TemplateFieldRecord(
  path: id,
  id: id,
  disposition: TemplateFieldDisposition.present,
  value: v,
);

void main() {
  final at = DateTime.utc(2026, 9, 27, 10);

  test(
    'eleven sheets, the fields of every template, false kept apart from missing',
    () {
      final sheets = templateWorkbook([
        _i('a', [
          _f('workspace.feature_flags.kioskMode', false),
          _f('workspace.name_hint', '=HYPERLINK("x")'),
        ]),
        _i('b', const []),
      ], capturedAt: at);
      expect(sheets.map((s) => s.name), [
        'Readme',
        'Templates',
        'Comparison',
        'Features',
        'Settings',
        'Requirements',
        'Provenance',
        'Catalogs',
        'RolePermissions',
        'Validations',
        'Fields',
      ]);
      final features = sheets.firstWhere((s) => s.name == 'Features').rows;
      expect(features[1], [
        'kioskMode',
        'false',
        'present',
        null,
        'absent:unknown',
      ]);
      final settings = sheets.firstWhere((s) => s.name == 'Settings').rows;
      expect(settings.length, 3, reason: 'a header and both of a\'s fields');
    },
  );

  test('more than the batch limit is refused, not cut short', () {
    expect(
      () => templateWorkbook([
        for (var i = 0; i <= maxTemplates; i++) _i('t$i', const []),
      ], capturedAt: at),
      throwsArgumentError,
    );
  });

  test('the file holds data only: no formula, link or macro part', () {
    final bytes = buildXlsx(
      templateWorkbook([
        _i('a', [_f('x', '=HYPERLINK("http://evil")')]),
      ], capturedAt: at),
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(
      archive.files
          .map((f) => f.name)
          .where((n) => n.contains('vba') || n.contains('externalLink')),
      isEmpty,
    );
    final sheetXml = archive.files
        .where((f) => f.name.startsWith('xl/worksheets/'))
        .map((f) => utf8.decode(f.content as List<int>))
        .join();
    expect(sheetXml.contains('<f>'), isFalse, reason: 'a leading = stays text');
    expect(templateWorkbookName(at), 'deskilo-templates-20260927.xlsx');
  });

  test('catalogs, roles, validations and fields read row by row', () {
    TemplateFieldRecord rec(String path, String id, Object? v) =>
        TemplateFieldRecord(
          path: path,
          id: id,
          disposition: TemplateFieldDisposition.present,
          value: v,
        );
    final sheets = templateWorkbook([
      _i('asso', [
        rec('tables.plans[Nomade].name', 'tables.plans[].name', 'Nomade'),
        rec(
          'tables.plans[Nomade].base_fee_cents',
          'tables.plans[].base_fee_cents',
          5000,
        ),
        rec(
          'workspace.role_permissions.admin',
          'workspace.role_permissions.admin',
          ['manageMembers', 'viewFinances'],
        ),
        rec(
          'tables.workspace_roles[tresorier].permissions',
          'tables.workspace_roles[].permissions',
          ['viewFinances'],
        ),
        rec(
          'tables.validation_policies[expense].required_count',
          'tables.validation_policies[].required_count',
          2,
        ),
        const TemplateFieldRecord(
          path: 'tables.validation_policies[expense].eligible_admin_ids',
          id: 'tables.validation_policies[].eligible_admin_ids',
          disposition: TemplateFieldDisposition.stripped,
        ),
        rec(
          'tables.workspace_field_definitions[committee].type',
          'tables.workspace_field_definitions[].type',
          'choice',
        ),
        rec(
          'tables.workspace_field_definitions[committee].labels.fr.label',
          'tables.workspace_field_definitions[].labels.{locale}.label',
          'Rôle',
        ),
      ]),
    ], capturedAt: at);
    List<List<Object?>> rows(String name) =>
        sheets.firstWhere((s) => s.name == name).rows;

    expect(rows('Catalogs').skip(1), [
      ['asso', 'plans', 'Nomade', 'name', 'present', 'Nomade'],
      ['asso', 'plans', 'Nomade', 'base_fee_cents', 'present', 5000],
    ]);
    expect(rows('RolePermissions').skip(1), [
      ['asso', 'admin', 'base', 'manageMembers, viewFinances', 'present'],
      ['asso', 'tresorier', 'custom', 'viewFinances', 'present'],
    ]);
    final validation = rows('Validations')[1];
    expect(validation[0], 'asso');
    expect(validation[1], 'expense');
    expect(validation[2], 2, reason: 'required_count as a number');
    expect(
      validation.last,
      'stripped',
      reason: 'named validators never travel, and the sheet says so',
    );
    expect(validation[3], 'absent:unknown', reason: 'not in this template');
    final field = rows('Fields')[1];
    expect(field.take(3), ['asso', 'committee', 'choice']);
    expect(
      field.contains('Rôle'),
      isFalse,
      reason: 'nested labels are Settings rows, not a wide column',
    );
  });
}
