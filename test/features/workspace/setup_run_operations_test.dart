// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the Run step pages of the workspace feature: new members, kiosk
// and look. New members: the settings screen's rows arrive with the stored
// rule, a change shows in the preview before saving and Save stores it;
// the join questions are listed and the preview draws the join form with
// them. Kiosk: the active members who could run the tablet are offered by
// e-mail, owners never; making one the kiosk stores it and lists it; the
// badge switch writes the NFC feature; the preview is the kiosk's own
// greeting. Look: the stored colour arrives in the field, a pick redraws
// the sample before saving, Save stores the seed, and an unreadable colour is
// refused before anything is sent. Every page is one column on a phone.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/demo/data/workspace_fields_repository.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/domain/workspace_branding.dart';
import 'package:deskilo/features/workspace/domain/workspace_field.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/workspace_fields_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

Future<void> _pump(
  WidgetTester tester,
  String stepId,
  FakeWorkspaceRepository repo, {
  FakeWorkspaceFields? fields,
}) async {
  await pumpApp(
    tester,
    SetupStepScreen(stepId: stepId, runPages: setupRunPages),
    size: _phone,
    overrides: standardTestOverrides(workspace: repo, fields: fields),
  );
  await tester.pumpAndSettle();
}

Finder _inPreview(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('setup-step-preview')),
  matching: f,
);

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void _oneColumn(WidgetTester tester) {
  expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  group('new members', () {
    FakeWorkspaceRepository repo() =>
        FakeWorkspaceRepository.withWorkspace(
            featureFlags: const {'customFields': true},
          )
          ..newMemberDefaults['ws-1'] = const NewMemberDefaults(
            subscriptionPct: 50,
            overagePolicy: OveragePolicy.payg,
            configured: true,
          );

    FakeWorkspaceFields fields() => FakeWorkspaceFields()
      ..fields.addAll(const [
        WorkspaceField(
          id: 'f1',
          key: 'company',
          type: WorkspaceFieldType.text,
          labels: {'en': 'Your company'},
          personalData: false,
          contexts: {WorkspaceFieldContext.joinRequest},
        ),
        WorkspaceField(
          id: 'f2',
          key: 'shirt',
          type: WorkspaceFieldType.text,
          labels: {'en': 'Shirt size'},
          personalData: false,
        ),
      ]);

    testWidgets('prefilled; a change shows before saving and Save stores '
        'it; the join form carries the join questions only', (tester) async {
      final r = repo();
      await _pump(tester, 'new_members', r, fields: fields());
      expect(find.text('50%'), findsOneWidget);
      expect(
        _text(tester, 'setup-new-members-preview-start'),
        'A new member starts on a 50 % subscription (Pay as you go).',
      );
      expect(
        find.byKey(const ValueKey('setup-new-members-question-company')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-new-members-question-shirt')),
        findsNothing,
      );
      expect(
        _inPreview(find.byKey(WorkspaceFieldsSection.keyOf('company'))),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('new-member-pct-up')));
      await tester.pump();
      expect(
        _text(tester, 'setup-new-members-preview-start'),
        startsWith('A new member starts on a 55 %'),
      );
      expect(r.newMemberDefaults['ws-1']!.subscriptionPct, 50);

      await tester.tap(find.byKey(const ValueKey('setup-new-members-save')));
      await tester.pumpAndSettle();
      expect(r.newMemberDefaults['ws-1']!.subscriptionPct, 55);
      expect(r.newMemberDefaults['ws-1']!.overagePolicy, OveragePolicy.payg);
      _oneColumn(tester);
    });

    testWidgets('no join question: the page and the preview say so', (
      tester,
    ) async {
      await _pump(tester, 'new_members', repo());
      expect(
        find.byKey(const ValueKey('setup-new-members-no-questions')),
        findsOneWidget,
      );
      expect(find.byKey(WorkspaceFieldsSection.sectionKey), findsNothing);
    });
  });

  group('kiosk', () {
    FakeWorkspaceRepository repo() {
      final r = FakeWorkspaceRepository.withWorkspace(
        featureFlags: const {'kioskMode': true, 'nfcBadges': false},
      );
      r.otherMembers.addAll(const [
        Member(
          id: 'member-tablet',
          workspaceId: 'ws-1',
          userId: 'user-tablet',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.active,
        ),
        Member(
          id: 'member-gone',
          workspaceId: 'ws-1',
          userId: 'user-gone',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.exited,
        ),
      ]);
      r.memberEmails = {
        'member-1': 'owner@example.org',
        'member-tablet': 'tablet@example.org',
      };
      return r;
    }

    testWidgets('only an active non-owner is offered; making it the kiosk '
        'stores and lists it; the preview is the kiosk greeting', (
      tester,
    ) async {
      final r = repo();
      await _pump(tester, 'kiosk', r);
      expect(find.byKey(const ValueKey('setup-kiosk-none')), findsOneWidget);
      expect(
        _inPreview(find.byKey(const ValueKey('kiosk-greeting'))),
        findsOneWidget,
      );
      expect(_inPreview(find.text('Test Space')), findsOneWidget);
      expect(_inPreview(find.text('Tap a seat to check in')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('setup-kiosk-pick')));
      await tester.pumpAndSettle();
      expect(find.text('owner@example.org'), findsNothing);
      await tester.tap(find.text('tablet@example.org').last);
      await tester.pumpAndSettle();
      expect(r.otherMembers.first.isKiosk, isFalse, reason: 'not saved yet');

      await tester.tap(find.byKey(const ValueKey('setup-kiosk-make')));
      await tester.pumpAndSettle();
      expect(r.otherMembers.first.isKiosk, isTrue);
      expect(
        find.byKey(const ValueKey('setup-kiosk-account-member-tablet')),
        findsOneWidget,
      );
      _oneColumn(tester);
    });

    testWidgets('the badge switch writes the NFC feature', (tester) async {
      final r = repo();
      await _pump(tester, 'kiosk', r);
      await tester.tap(find.byKey(const ValueKey('setup-kiosk-badges')));
      await tester.pumpAndSettle();
      expect(r.workspaces.first.featureFlags['nfcBadges'], isTrue);
    });
  });

  group('look', () {
    FakeWorkspaceRepository repo() {
      final r = FakeWorkspaceRepository.withWorkspace();
      r.workspaces[0] = r.workspaces[0].copyWith(
        branding: const {BrandingKeys.seedColor: '#1F3A5F'},
      );
      return r;
    }

    testWidgets('the stored colour arrives; a pick redraws the sample before '
        'saving; Save stores the seed', (tester) async {
      final r = repo();
      await _pump(tester, 'look', r);
      final field = find.descendant(
        of: find.byKey(const ValueKey('setup-look-hex')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).controller!.text, '#1F3A5F');
      // The colour the sample's buttons and accents are drawn in.
      Color primary() => tester
          .widget<Theme>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('setup-look-preview-light')),
                  matching: find.byType(Theme),
                )
                .first,
          )
          .data
          .colorScheme
          .primary;
      final navy = primary();

      await tester.tap(find.byKey(const ValueKey('setup-look-pick-#1B5E20')));
      await tester.pump();
      expect(primary(), isNot(navy));
      expect(r.workspaces.first.branding[BrandingKeys.seedColor], '#1F3A5F');

      await tester.tap(find.byKey(const ValueKey('setup-look-save')));
      await tester.pumpAndSettle();
      expect(r.workspaces.first.branding[BrandingKeys.seedColor], '#1B5E20');
      expect(_inPreview(find.text('Test Space')), findsNWidgets(2));
      _oneColumn(tester);
    });

    testWidgets('an unreadable colour is refused before anything is sent', (
      tester,
    ) async {
      final r = repo();
      await _pump(tester, 'look', r);
      // The first of these the app cannot make readable.
      final unreadable = ['#FFFF00', '#FFFFFF', '#F5F5F5', '#000000']
          .firstWhere(
            (hex) =>
                DeskiloTheme.refusals(Color(parseHexColor(hex)!)).isNotEmpty,
          );
      await tester.enterText(
        find.byKey(const ValueKey('setup-look-hex')),
        unreadable,
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('setup-look-refusal')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('setup-look-save')))
            .onPressed,
        isNull,
      );
    });
  });
}
