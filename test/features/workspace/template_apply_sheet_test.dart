// SPDX-License-Identifier: 0BSD
//
// #1330 — the apply preview shows a group's feature flips under their
// business process, from the server's own change-set.
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_apply_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _template = WorkspaceTemplate(
  id: 'tpl-1',
  key: 'assoc',
  name: 'Association',
  entities: ['floor_plan', 'features'],
);

Future<void> _pump(WidgetTester tester, TemplatePreview preview) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository()
    ..templates.add(_template)
    ..templatePreviews['tpl-1'] = preview;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TemplateApplySheet(workspaceId: 'ws-1', template: _template),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a group that flips features lists them by process; a group '
      'that does not shows no process', (tester) async {
    await _pump(
      tester,
      TemplatePreview.fromJson(<String, dynamic>{
        'compatibility': 'supported',
        'groups': [
          {
            'group': 'documents_operations',
            'state': 'change',
            'items': [
              {
                'scope': 'workspace',
                'op': 'change',
                'key': 'feature_flags',
                'before': {'kioskMode': false, 'invoicing': true},
                'after': {'kioskMode': true, 'invoicing': false},
              },
            ],
          },
          {
            'group': 'space',
            'state': 'new',
            'items': [<String, Object?>{}, <String, Object?>{}],
          },
        ],
      }),
    );

    expect(
      find.byKey(const ValueKey('template-process-documents_operations-workspaceAccess')),
      findsOneWidget,
    );
    expect(find.text('Kiosk mode on'), findsOneWidget);
    expect(find.text('Invoices off'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('template-process-feature-kioskMode')),
      findsOneWidget,
    );
    // The space group carries rows, not flags: nothing by process there.
    expect(
      find.byKey(const ValueKey('template-process-space-workspaceAccess')),
      findsNothing,
    );
    // The button still counts the server's items — the view adds none.
    expect(find.text('Apply 2 changes'), findsOneWidget);
  });

  testWidgets('no feature item, no process view', (tester) async {
    await _pump(
      tester,
      TemplatePreview.fromJson(<String, dynamic>{
        'compatibility': 'supported',
        'groups': [
          {'group': 'space', 'state': 'new', 'items': [<String, Object?>{}]},
        ],
      }),
    );
    expect(find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('template-process-');
    }), findsNothing);
  });
}
