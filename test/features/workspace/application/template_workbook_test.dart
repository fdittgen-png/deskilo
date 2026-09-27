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
    'seven sheets, the fields of every template, false kept apart from missing',
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
}
