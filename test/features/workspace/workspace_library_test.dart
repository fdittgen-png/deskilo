// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1120 — the workspace library, as a member sees it.
//
// What is worth testing is that the screen only SHOWS and ASKS: the
// server decides who may read a template and who may write a grant.
// Here the fake stands in for the server, so the assertions are about
// what the owner is offered, what a save writes, and that a new space
// really does start from a template.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/local_setup.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pumpLibrary(WidgetTester tester,
    {FakeLocalSetupRepository? localSetup}) async {
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
    overrides: standardTestOverrides(workspace: workspace, localSetup: localSetup),
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

  group('#1658 widening a template is confirmed against what it carries', () {
    Future<FakeWorkspaceRepository> withMine(WidgetTester tester) async {
      final workspace = await _pumpLibrary(tester);
      workspace.templates.add(const WorkspaceTemplate(
        id: 'tpl-mine',
        key: 'mine',
        name: 'Mine',
        visibility: TemplateVisibility.private,
        ownerWorkspaceId: 'ws-1',
      ));
      workspace.templateInspections['tpl-mine'] = const TemplateInspection(
        templateId: 'tpl-mine',
        key: 'mine',
        name: 'Mine',
        status: TemplateInspectionStatus.ok,
        profile: TemplateProfile.partial,
        compatibility: TemplateCompatibility.supported,
        outline: TemplateOutline(
          compatibility: TemplateCompatibility.supported,
          groups: [TemplateGroup.hoursBooking],
        ),
        coverage: TemplateCoverage(present: 7),
        exclusions: [
          TemplateExclusion(id: 'payment_instructions', portability: 'never'),
        ],
      );
      // Reopen so the library lists it.
      await tester.pageBack();
      await tester.pumpAndSettle();
      unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push('/library'));
      await tester.pumpAndSettle();
      return workspace;
    }

    Future<void> choose(WidgetTester tester, String label) async {
      final menu = find.byKey(const ValueKey('library-menu-mine'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    TemplateVisibility visibility(FakeWorkspaceRepository w) =>
        w.templates.firstWhere((t) => t.id == 'tpl-mine').visibility;

    testWidgets('Cancel leaves it where it was', (tester) async {
      final w = await withMine(tester);
      await choose(tester, 'Everyone (the library)');
      expect(find.byKey(const ValueKey('template-widen')), findsOneWidget);
      expect(find.textContaining('7 settings become readable'), findsOneWidget);
      expect(find.byKey(const ValueKey('template-widen-excluded')), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(visibility(w), TemplateVisibility.private);
    });

    testWidgets('confirming widens it; narrowing asks nothing', (tester) async {
      final w = await withMine(tester);
      await choose(tester, 'Everyone (the library)');
      await tester.tap(find.byKey(const ValueKey('template-widen-confirm')));
      await tester.pumpAndSettle();
      expect(visibility(w), TemplateVisibility.public);
      await choose(tester, 'Only me');
      expect(find.byKey(const ValueKey('template-widen')), findsNothing);
      expect(visibility(w), TemplateVisibility.private);
    });
  });

  testWidgets('#1658 the save sheet names its profile and what an applying '
      'space will set up itself', (tester) async {
    await _pumpLibrary(tester,
        localSetup: FakeLocalSetupRepository(missing: const [
          LocalSlot(kind: LocalSlotKind.legalIdentity, required: true,
              route: '/settings', filled: true),
          LocalSlot(kind: LocalSlotKind.paymentDetails, required: false,
              route: '/settings', filled: false),
        ]));
    await tester.tap(find.byKey(const ValueKey('library-save')));
    await tester.pumpAndSettle();
    expect(find.text('Full configuration profile'), findsOneWidget);
    final needs = find.byKey(const ValueKey('save-template-local-needs'));
    await tester.ensureVisible(needs);
    expect(find.textContaining('Your legal identity'), findsOneWidget,
        reason: 'a filled slot is still one an applying space needs');
    final box = find.byKey(const ValueKey('save-template-group-space'));
    await tester.ensureVisible(box);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(find.textContaining('Selected groups:'), findsOneWidget);
  });

  testWidgets('#1658 a retry after a lost answer publishes once, not twice',
      (tester) async {
    final workspace = await _pumpLibrary(tester);
    workspace.loseNextPublishResponse = true;
    await tester.tap(find.byKey(const ValueKey('library-save')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('save-template-name')), 'Our loft');
    await tester.pump();
    final confirm = find.byKey(const ValueKey('save-template-confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirm, findsOneWidget, reason: 'the answer was lost; the sheet stays');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirm, findsNothing, reason: 'the retry got the first answer');
    expect(workspace.savedTemplateGroups, hasLength(1),
        reason: 'published once: the retry replayed the same request');
    expect(workspace.publishRequests, hasLength(1));
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

    testWidgets('invitation texts travel only when ticked, naming every group '
        '(#1656)', (tester) async {
      final workspace = await openPublish(tester);
      final box = find.byKey(const ValueKey('save-template-invitations'));
      await tester.ensureVisible(box);
      expect(tester.widget<CheckboxListTile>(box).value, isFalse,
          reason: 'never implied by publishing everything');
      await tester.tap(box);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('save-template-confirm')));
      await tester.tap(find.byKey(const ValueKey('save-template-confirm')));
      await tester.pumpAndSettle();
      expect(workspace.savedTemplateGroups.single,
          ['hours_booking', 'invitation_texts', 'space', 'wording']);
    });

    testWidgets('without the wording group there is no invitation choice',
        (tester) async {
      await openPublish(tester);
      final wording = find.byKey(const ValueKey('save-template-group-wording'));
      await tester.ensureVisible(wording);
      await tester.tap(wording);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('save-template-invitations')), findsNothing);
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
