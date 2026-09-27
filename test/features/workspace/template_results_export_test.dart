// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1661 — what a template search or filter shows exports as an offline
// workbook; with nothing narrowed there is no bulk button, and more than
// the batch limit is refused rather than cut short.
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/workspace/application/template_workbook.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_gallery.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _button = ValueKey('template-export-results');

TemplateInspection _inspection(String id) => TemplateInspection(
  templateId: id,
  key: id,
  name: id,
  status: TemplateInspectionStatus.ok,
  profile: TemplateProfile.partial,
  compatibility: TemplateCompatibility.supported,
  outline: const TemplateOutline(
    compatibility: TemplateCompatibility.supported,
    groups: [],
  ),
  fields: const [],
);

Future<List<({String name, Uint8List bytes})>> _pump(
  WidgetTester tester,
  List<WorkspaceTemplate> templates, {
  bool picker = false,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final saved = <({String name, Uint8List bytes})>[];
  final workspace = FakeWorkspaceRepository()..templates.addAll(templates);
  for (final t in templates) {
    workspace.templateInspections[t.id] = _inspection(t.id);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        fileSaverProvider.overrideWithValue(({
          required bytes,
          required fileName,
        }) async {
          saved.add((name: fileName, bytes: bytes));
          return fileName;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TemplateGallery(
            sections: [
              TemplateGallerySection(title: 'All', templates: templates),
            ],
            selectedId: null,
            onSelected: picker ? (_) {} : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('template-search')), text);
  await tester.pump(
    TemplateGallery.debounce + const Duration(milliseconds: 50),
  );
  await tester.pumpAndSettle();
}

List<String> _templateKeys(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final names = [for (final f in archive.files) f.name];
  expect(names, contains('xl/workbook.xml'));
  final sheet = archive.files.firstWhere(
    (f) => f.name == 'xl/worksheets/sheet2.xml',
  );
  final xml = String.fromCharCodes(sheet.content as List<int>);
  return [
    for (final m in RegExp(r'<t[^>]*>(tpl-[^<]+)</t>').allMatches(xml))
      m.group(1)!,
  ];
}

void main() {
  const alpha = WorkspaceTemplate(
    id: 'tpl-alpha',
    key: 'tpl-alpha',
    name: 'Alpha',
  );
  const beta = WorkspaceTemplate(id: 'tpl-beta', key: 'tpl-beta', name: 'Beta');
  const gamma = WorkspaceTemplate(
    id: 'tpl-gamma',
    key: 'tpl-gamma',
    name: 'Gamma',
  );

  testWidgets('nothing narrowed, no bulk button', (tester) async {
    await _pump(tester, const [alpha, beta, gamma]);
    expect(find.byKey(_button), findsNothing);
  });

  testWidgets('a picker is for choosing one: no bulk button there', (
    tester,
  ) async {
    await _pump(tester, const [alpha, beta, gamma], picker: true);
    await _search(tester, 'gamma');
    expect(find.byKey(_button), findsNothing);
  });

  testWidgets('the results of a search export as one workbook, and only them', (
    tester,
  ) async {
    final saved = await _pump(tester, const [alpha, beta, gamma]);
    await _search(tester, 'gamma');
    expect(find.text('Export these results (1)'), findsOneWidget);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.name, endsWith('.xlsx'));
    expect(_templateKeys(saved.single.bytes), contains('tpl-gamma'));
    expect(_templateKeys(saved.single.bytes), isNot(contains('tpl-alpha')));
  });

  testWidgets('more than the batch limit is refused, not cut short', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i <= maxTemplates; i++)
        WorkspaceTemplate(id: 'tpl-$i', key: 'tpl-$i', name: 'Room $i'),
    ];
    final saved = await _pump(tester, many);
    await _search(tester, 'room');
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(
      find.textContaining('At most $maxTemplates templates'),
      findsOneWidget,
    );
  });
}
