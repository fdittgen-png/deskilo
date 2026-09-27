// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1660 — a shortlist of up to four templates, compared from their
// inspected settings: differences first, every setting on request, a
// missing value shown as missing (never "No"), different currencies not
// compared, and on a narrow screen a baseline against one alternative.
import 'package:deskilo/features/workspace/domain/template_capabilities.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/screens/template_compare_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

TemplateInspection _inspection(String id, List<TemplateFieldRecord> fields) =>
    TemplateInspection(
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
      fields: fields,
    );

TemplateFieldRecord _f(String path, Object? value) => TemplateFieldRecord(
  path: path,
  id: path,
  disposition: TemplateFieldDisposition.present,
  value: value,
);

const _a = WorkspaceTemplate(id: 'a', key: 'a', name: 'Alpha');
const _b = WorkspaceTemplate(id: 'b', key: 'b', name: 'Beta');
const _c = WorkspaceTemplate(id: 'c', key: 'c', name: 'Gamma');

Future<void> _pump(
  WidgetTester tester,
  List<WorkspaceTemplate> templates, {
  double width = 1000,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository()
    ..templates.addAll(templates)
    ..templateInspections['a'] = _inspection('a', [
      _f('workspace.feature_flags.kioskMode', true),
      _f('workspace.booking_rules.open_weekdays', [1, 2, 3]),
    ])
    ..templateInspections['b'] = _inspection('b', [
      _f('workspace.feature_flags.kioskMode', false),
      _f('workspace.booking_rules.open_weekdays', [1, 2, 3]),
    ])
    ..templateInspections['c'] = _inspection('c', [
      _f('workspace.booking_rules.open_weekdays', [1, 2, 3]),
    ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TemplateCompareScreen(templates: templates),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a cell says what it is, never false for a missing value', () {
    String t(ComparisonCell c) => comparisonCellText(null, c);
    expect(
      t(
        const ComparisonCell(
          disposition: TemplateFieldDisposition.present,
          value: false,
        ),
      ),
      'No',
    );
    expect(t(ComparisonCell.none), 'Not in this template');
    expect(
      t(
        const ComparisonCell(
          disposition: TemplateFieldDisposition.absent,
          absent: TemplateAbsentMeaning.inherit,
        ),
      ),
      'Keeps the space\'s own',
    );
    expect(
      t(
        const ComparisonCell(
          disposition: TemplateFieldDisposition.present,
          value: [1, 2],
        ),
      ),
      '1, 2',
    );
  });

  testWidgets('differences first; all settings on request', (tester) async {
    await _pump(tester, const [_a, _b]);
    expect(
      find.byKey(
        const ValueKey('compare-row-workspace.feature_flags.kioskMode'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('compare-row-workspace.booking_rules.open_weekdays'),
      ),
      findsNothing,
      reason: 'the same in both: hidden among the differences',
    );
    await tester.tap(find.text('All settings'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('compare-row-workspace.booking_rules.open_weekdays'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a setting one template does not carry is missing, not No', (
    tester,
  ) async {
    await _pump(tester, const [_a, _c]);
    final row = find.byKey(
      const ValueKey('compare-row-workspace.feature_flags.kioskMode'),
    );
    expect(
      find.descendant(of: row, matching: find.text('Not in this template')),
      findsOneWidget,
    );
    expect(find.descendant(of: row, matching: find.text('No')), findsNothing);
  });

  testWidgets('narrow: a baseline against one chosen alternative', (
    tester,
  ) async {
    await _pump(tester, const [_a, _b, _c], width: 400);
    expect(find.byKey(const ValueKey('compare-baseline')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-other')), findsOneWidget);
    expect(
      find.text('Gamma'),
      findsNothing,
      reason: 'two columns, the third chosen on demand',
    );
  });
}
