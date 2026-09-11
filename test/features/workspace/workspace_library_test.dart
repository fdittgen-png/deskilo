// SPDX-License-Identifier: 0BSD
//
// #1120 — the workspace library, as a member sees it.
//
// What is worth testing is that the screen only SHOWS and ASKS: the
// server decides who may read a template and who may write a grant.
// Here the fake stands in for the server, so the assertions are about
// what the owner is offered, what a save writes, and that a new space
// really does start from a template.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pumpLibrary(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'workspaceLibrary': true},
  );
  workspace.templates.add(const WorkspaceTemplate(
    id: 'tpl-shared',
    key: 'studio',
    name: 'Studio',
    visibility: TemplateVisibility.shared,
    ownerWorkspaceId: 'ws-other',
    floorPlan: <Object?>[
      <String, Object?>{'name': 'L', 'offices': <Object?>[]},
    ],
  ));
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(workspace: workspace),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/library'));
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('the library lists what I may start from and what I own',
      (tester) async {
    await _pumpLibrary(tester);
    expect(find.byKey(const ValueKey('library-template-tiny')), findsOneWidget,
        reason: 'the builtin is always readable');
    expect(find.byKey(const ValueKey('library-template-studio')), findsOneWidget,
        reason: 'a template shared with me is in the library half');
    expect(find.byKey(const ValueKey('library-save')), findsOneWidget,
        reason: 'an owner may publish');
  });

  testWidgets('saving snapshots the space as a private template by default',
      (tester) async {
    final workspace = await _pumpLibrary(tester);
    await tester.tap(find.byKey(const ValueKey('library-save')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('save-template-name')), 'Our loft');
    await tester.tap(find.byKey(const ValueKey('save-template-confirm')));
    await tester.pumpAndSettle();
    final mine = workspace.templates.where((t) => t.key == 'our_loft').single;
    expect(mine.visibility, TemplateVisibility.private,
        reason: 'sharing is asked for, never assumed');
    expect(mine.ownerWorkspaceId, 'ws-1');
    expect(find.byKey(const ValueKey('library-template-our_loft')), findsOneWidget);
  });

  testWidgets('applying merges by name after a confirmation', (tester) async {
    final workspace = await _pumpLibrary(tester);
    await tester.tap(find.byKey(const ValueKey('library-apply-studio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-apply-confirm')));
    await tester.pumpAndSettle();
    expect(workspace.appliedTemplates.single.templateId, 'tpl-shared');
  });

  test('a template key is what the column accepts', () {
    expect(templateKeyFrom('Our loft!'), 'our_loft');
    expect(templateKeyFrom('  2 rooms '), 't_2_rooms');
    expect(templateKeyFrom(''), 't_');
    expect(RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(templateKeyFrom('x' * 80)), isTrue);
  });
}
