// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1661 — what a template search or filter shows exports as an offline
// workbook; with nothing narrowed there is no bulk button, and more than
// the batch limit is refused rather than cut short.
import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/workspace/application/template_workbook.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_gallery.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
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

/// Holds every inspection until [gate] completes, or fails it.
class _GatedWorkspace extends FakeWorkspaceRepository {
  final gate = Completer<void>();
  bool fail = false;

  @override
  Future<TemplateInspection> inspectWorkspaceTemplate(
    String templateId,
  ) async {
    await gate.future;
    if (fail) throw Exception('inspection refused');
    return super.inspectWorkspaceTemplate(templateId);
  }
}

Future<List<({String name, Uint8List bytes})>> _pump(
  WidgetTester tester,
  List<WorkspaceTemplate> templates, {
  bool picker = false,
  FakeWorkspaceRepository? repository,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final saved = <({String name, Uint8List bytes})>[];
  final workspace = (repository ?? FakeWorkspaceRepository())
    ..templates.addAll(templates);
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

  test('progress is what happened, in order; a cancel before the save '
      'saves nothing', () async {
    final repo = FakeWorkspaceRepository()
      ..templates.addAll(const [alpha, beta]);
    for (final t in const [alpha, beta]) {
      repo.templateInspections[t.id] = _inspection(t.id);
    }
    var saves = 0;
    Future<String?> saver({
      required Uint8List bytes,
      required String fileName,
    }) async {
      saves++;
      return fileName;
    }

    final seen = <String>[];
    final export = TemplateWorkbookExport(repo, saver);
    await export.export(
      const ['tpl-alpha', 'tpl-beta'],
      now: DateTime.utc(2026, 9, 28),
      onProgress: (p) => seen.add('${p.stage.name} ${p.done}/${p.total}'),
    );
    expect(seen, ['reading 0/2', 'reading 1/2', 'building 2/2', 'saving 2/2']);
    expect(saves, 1);

    final cancel = WorkbookCancel();
    await expectLater(
      export.export(
        const ['tpl-alpha', 'tpl-beta'],
        now: DateTime.utc(2026, 9, 28),
        cancel: cancel,
        onProgress: (p) {
          if (p.done == 1) cancel.cancel();
        },
      ),
      throwsA(isA<WorkbookCancelled>()),
    );
    expect(saves, 1, reason: 'a cancelled export never reaches the saver');
  });

  testWidgets('the dialog shows the reading, and Cancel saves nothing and '
      'says so', (tester) async {
    final repo = _GatedWorkspace();
    final saved = await _pump(
      tester,
      const [alpha, beta, gamma],
      repository: repo,
    );
    await _search(tester, 'a');
    await tester.tap(find.byKey(_button));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('workbook-export-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('Reading templates: 0 of'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workbook-export-cancel')));
    await tester.pump();
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.byKey(const ValueKey('workbook-export-dialog')), findsNothing);
    expect(find.text('Export cancelled. Nothing was saved.'), findsOneWidget);
  });

  testWidgets('a failure is a failure, not a cancel', (tester) async {
    final repo = _GatedWorkspace()..fail = true;
    final saved = await _pump(tester, const [alpha, beta], repository: repo);
    await _search(tester, 'a');
    await tester.tap(find.byKey(_button));
    await tester.pump();
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.byKey(const ValueKey('workbook-export-dialog')), findsNothing);
    expect(find.text('Export cancelled. Nothing was saved.'), findsNothing);
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

  testWidgets('#1660 a search that matches nothing says so, and Clear '
      'brings every template back', (tester) async {
    await _pump(tester, const [alpha, beta, gamma]);
    await _search(tester, 'zzzz');
    expect(find.byKey(const ValueKey('template-no-match')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('template-gallery-empty')),
      findsNothing,
      reason: 'the library is not empty; the search is',
    );
    await tester.tap(find.byKey(const ValueKey('template-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateCard), findsNWidgets(3));
    expect(find.byKey(const ValueKey('template-no-match')), findsNothing);
  });

  testWidgets('#1660 an empty library is not a failed search', (tester) async {
    await _pump(tester, const []);
    await _search(tester, 'anything');
    expect(find.byKey(const ValueKey('template-no-match')), findsNothing);
    expect(
      find.byKey(const ValueKey('template-gallery-empty')),
      findsOneWidget,
    );
  });

  testWidgets('#1660 a template\'s detail groups every setting, names '
      'features, and finds "refund" in its validations', (tester) async {
    const refunds = WorkspaceTemplate(
      id: 'tpl-refunds',
      key: 'tpl-refunds',
      name: 'Refunds',
    );
    final saved = await _pump(tester, const [refunds]);
    // The pumped repository answers the inspection seeded here.
    final element = tester.element(find.byType(TemplateGallery));
    final repo = ProviderScope.containerOf(
      element,
    ).read(workspaceRepositoryProvider) as FakeWorkspaceRepository;
    repo.templateInspections['tpl-refunds'] = const TemplateInspection(
      templateId: 'tpl-refunds',
      key: 'tpl-refunds',
      name: 'Refunds',
      status: TemplateInspectionStatus.ok,
      profile: TemplateProfile.partial,
      compatibility: TemplateCompatibility.supported,
      outline: TemplateOutline(
        compatibility: TemplateCompatibility.supported,
        groups: [],
      ),
      fields: [
        TemplateFieldRecord(
          path: 'workspace.feature_flags.kioskMode',
          id: 'workspace.feature_flags.kioskMode',
          disposition: TemplateFieldDisposition.present,
          value: false,
        ),
        TemplateFieldRecord(
          path: 'tables.validation_policies[refund].required_count',
          id: 'tables.validation_policies[].required_count',
          disposition: TemplateFieldDisposition.present,
          value: 2,
        ),
      ],
    );
    await tester.tap(
      find.byKey(const ValueKey('template-details-tpl-refunds')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('template-detail-section-workspace.feature_flags'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('template-detail-section-tables.validation_policies'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('No'),
      findsOneWidget,
      reason: 'an OFF feature is shown, as No',
    );
    await tester.enterText(
      find.byKey(const ValueKey('template-detail-search')),
      'refund',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'template-detail-row-tables.validation_policies[refund].required_count',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('template-detail-section-workspace.feature_flags'),
      ),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('template-detail-search')),
      'zzz',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('template-detail-none')), findsOneWidget);
    expect(saved, isEmpty, reason: 'reading writes nothing');
  });
}
