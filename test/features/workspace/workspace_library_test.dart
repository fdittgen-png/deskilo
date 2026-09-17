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
import 'package:deskilo/features/workspace/domain/template_preview.dart';
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
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('save-template-confirm')));
    await tester.tap(find.byKey(const ValueKey('save-template-confirm')));
    await tester.pumpAndSettle();
    expect(workspace.savedTemplateGroups.single, isNull,
        reason: 'every group ticked publishes whatever the server allows');
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

  group('#1280 S3 — publishing chooses its groups and shows what stays home',
      () {
    Future<FakeWorkspaceRepository> openPublish(WidgetTester tester) async {
      final workspace = await _pumpLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library-save')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('save-template-name')), 'Hours');
      await tester.pump();
      return workspace;
    }

    testWidgets('what never travels is named, and the plan names are shown',
        (tester) async {
      await openPublish(tester);
      final never = tester
          .widget<Text>(find.byKey(const ValueKey('save-template-never')))
          .data!;
      expect(never, contains('Bank details'));
      expect(never, contains('legal identifiers'),
          reason: 'identity travels with its legal keys stripped — say so');
      expect(find.textContaining('Ground floor'), findsOneWidget);
    });

    testWidgets('unticking groups publishes only the rest, and the plan names '
        'leave with the plan', (tester) async {
      final workspace = await openPublish(tester);
      for (final g in ['space', 'wording']) {
        final box = find.byKey(ValueKey('save-template-group-$g'));
        await tester.ensureVisible(box);
        await tester.tap(box);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('save-template-plan-names')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('save-template-confirm')));
      await tester.tap(find.byKey(const ValueKey('save-template-confirm')));
      await tester.pumpAndSettle();
      expect(workspace.savedTemplateGroups.single, ['hours_booking']);
    });

    testWidgets('nothing ticked cannot be published', (tester) async {
      await openPublish(tester);
      for (final g in ['space', 'wording', 'hours_booking']) {
        final box = find.byKey(ValueKey('save-template-group-$g'));
        await tester.ensureVisible(box);
        await tester.tap(box);
        await tester.pumpAndSettle();
      }
      final button = tester.widget<ButtonStyleButton>(
          find.byKey(const ValueKey('save-template-confirm')));
      expect(button.onPressed, isNull);
    });
  });

  group('#1280 S2 — preview changes, apply only what was chosen', () {
    TemplatePreview preview() => const TemplatePreview(
          compatibility: TemplateCompatibility.supported,
          groups: [
            TemplateGroupPreview(
                group: TemplateGroup.space,
                wire: 'space',
                state: TemplateGroupState.isNew,
                itemCount: 3),
            TemplateGroupPreview(
                group: TemplateGroup.hoursBooking,
                wire: 'hours_booking',
                state: TemplateGroupState.change,
                itemCount: 2),
            TemplateGroupPreview(
                group: TemplateGroup.wording,
                wire: 'wording',
                state: TemplateGroupState.matching,
                itemCount: 0),
            TemplateGroupPreview(
                group: TemplateGroup.rolesAccess,
                wire: 'roles_access',
                state: TemplateGroupState.change,
                itemCount: 1),
            TemplateGroupPreview(
                group: TemplateGroup.pricingCredits,
                wire: 'pricing_credits',
                state: TemplateGroupState.needsAttention,
                itemCount: 1,
                reason: 'fee_schedule_replaced_whole'),
          ],
        );

    Future<FakeWorkspaceRepository> openSheet(WidgetTester tester) async {
      final workspace = await _pumpLibrary(tester);
      workspace.templatePreviews['tpl-shared'] = preview();
      await tester.tap(find.byKey(const ValueKey('library-apply-studio')));
      await tester.pumpAndSettle();
      return workspace;
    }

    testWidgets('new is chosen, changes are not, and the button names the '
        'count', (tester) async {
      final workspace = await openSheet(tester);
      expect(find.text('Apply 3 changes'), findsOneWidget,
          reason: 'only the new group is ticked: existing configuration is '
              'kept unless chosen');

      await tester.tap(find.byKey(const ValueKey('template-group-hours_booking')));
      await tester.pumpAndSettle();
      expect(find.text('Apply 5 changes'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('library-apply-confirm')));
      await tester.pumpAndSettle();
      expect(workspace.appliedTemplates.single.groups,
          ['hours_booking', 'space'],
          reason: 'the request names exactly the chosen groups');
      expect(find.text('5 changes applied.'), findsOneWidget);
    });

    testWidgets('#1280 S4 — what was customized here says so and is not '
        'ticked', (tester) async {
      final workspace = await _pumpLibrary(tester);
      workspace.templatePreviews['tpl-shared'] = const TemplatePreview(
        compatibility: TemplateCompatibility.supported,
        groups: [
          TemplateGroupPreview(
              group: TemplateGroup.calendarNavigation,
              wire: 'calendar_navigation',
              state: TemplateGroupState.isNew,
              itemCount: 2,
              customized: true),
          TemplateGroupPreview(
              group: TemplateGroup.space,
              wire: 'space',
              state: TemplateGroupState.isNew,
              itemCount: 1),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('library-apply-studio')));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('template-group-calendar_navigation'));
      expect(find.descendant(of: row, matching: find.textContaining('Customized here')),
          findsOneWidget);
      expect(find.text('Apply 1 change'), findsOneWidget,
          reason: 'only the untouched group is ticked');
    });

    testWidgets('a group needing attention shows why and cannot be chosen',
        (tester) async {
      await openSheet(tester);
      final row = find.byKey(const ValueKey('template-group-pricing_credits'));
      expect(find.descendant(of: row, matching: find.byType(Checkbox)),
          findsNothing);
      expect(
          find.descendant(
              of: row, matching: find.textContaining('replaced as a whole')),
          findsOneWidget);
    });

    testWidgets('roles ask once more, and cancelling applies nothing',
        (tester) async {
      final workspace = await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('template-group-roles_access')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library-apply-confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Roles & access'), findsWidgets);
      expect(find.byKey(const ValueKey('library-apply-sensitive-confirm')),
          findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(workspace.appliedTemplates, isEmpty);

      await tester.tap(find.byKey(const ValueKey('library-apply-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library-apply-sensitive-confirm')));
      await tester.pumpAndSettle();
      expect(workspace.appliedTemplates.single.groups,
          ['roles_access', 'space']);
    });

    testWidgets('a template this server cannot apply says so and offers no '
        'button', (tester) async {
      final workspace = await _pumpLibrary(tester);
      workspace.templatePreviews['tpl-shared'] = const TemplatePreview(
        compatibility: TemplateCompatibility.notSupported,
        reason: 'template schema 9 is newer than this server',
        groups: [],
      );
      await tester.tap(find.byKey(const ValueKey('library-apply-studio')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('template-apply-not-supported')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('library-apply-confirm')), findsNothing);
    });
  });

  test('a template key is what the column accepts', () {
    expect(templateKeyFrom('Our loft!'), 'our_loft');
    expect(templateKeyFrom('  2 rooms '), 't_2_rooms');
    expect(templateKeyFrom(''), 't_');
    expect(RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(templateKeyFrom('x' * 80)), isTrue);
  });
}
