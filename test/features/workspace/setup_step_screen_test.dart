// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2870 — the setup guide's step pages. Member rights: the "members can
// book" preset writes exactly the four member essentials to the members
// role and the preview, read back from the stored matrix, then lists them
// in the matrix's words; an administrative right a member holds is said.
// Invite: the preview is the invite sheet's own message in the chosen
// language, the ID is copied, and a personal invitation is minted and
// shared. Every page is one column on a phone and two panes when wide.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/share/text_sharer.dart';
import 'package:deskilo/features/workspace/application/grant_member_essentials.dart';
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 1600);
const _wide = Size(1200, 1600);

/// The fixture workspace with the members role holding [member].
FakeWorkspaceRepository _repo({List<String> member = const []}) {
  final repo = FakeWorkspaceRepository.withWorkspace();
  final ws = repo.workspaces.first;
  repo.workspaces[0] = ws.copyWith(
    rolePermissions: {...ws.rolePermissions, 'member': member},
  );
  return repo;
}

Future<void> _pump(
  WidgetTester tester,
  String stepId, {
  FakeWorkspaceRepository? repo,
  Size size = _phone,
  List<Override> extra = const [],
}) async {
  await pumpApp(
    tester,
    SetupStepScreen(stepId: stepId),
    size: size,
    overrides: [
      ...standardTestOverrides(workspace: repo ?? _repo()),
      ...extra,
    ],
  );
  await tester.pumpAndSettle();
}

String _message(WidgetTester tester) => tester
    .widget<SelectableText>(find.byKey(const ValueKey('setup-invite-message')))
    .data!;

void main() {
  group('member rights', () {
    testWidgets('the preset grants exactly the member essentials, and the '
        'preview lists them once stored', (tester) async {
      final repo = _repo();
      await _pump(tester, 'member_rights', repo: repo);
      expect(
        find.byKey(const ValueKey('setup-rights-preview-none')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('setup-rights-apply')));
      await tester.pumpAndSettle();

      expect(
        repo.workspaces.first.rolePermissions['member'],
        unorderedEquals([for (final p in memberEssentials) p.wireName]),
      );
      expect(memberEssentials.toSet(), {
        WorkspacePermission.makeReservations,
        WorkspacePermission.viewCalendar,
        WorkspacePermission.useMessages,
        WorkspacePermission.viewMyMoney,
      }, reason: 'book, calendar, messages, own account: nothing else');
      expect(
        find.byKey(const ValueKey('setup-rights-preview-none')),
        findsNothing,
      );
      for (final p in memberEssentials) {
        expect(
          find.byKey(ValueKey('setup-rights-can-${p.wireName}')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('setup-rights-applied')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('setup-rights-apply')), findsNothing);
    });

    testWidgets('the preview names what a member can do in the matrix '
        'words, and says when it is more than everyday use', (tester) async {
      await _pump(
        tester,
        'member_rights',
        repo: _repo(member: ['makeReservations', 'manageMembers']),
      );
      final preview = find.byKey(const ValueKey('setup-rights-preview'));
      expect(
        find.descendant(
          of: preview,
          matching: find.text('Book and use reservations'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-rights-can-manageMembers')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-rights-preview-admin')),
        findsOneWidget,
      );
    });

    testWidgets('one column on a phone, the form above the preview', (
      tester,
    ) async {
      await _pump(tester, 'member_rights');
      expect(
        find.byKey(const ValueKey('setup-step-one-column')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('setup-step-two-panes')), findsNothing);
      final apply = tester.getRect(
        find.byKey(const ValueKey('setup-rights-apply')),
      );
      final preview = tester.getRect(
        find.byKey(const ValueKey('setup-step-preview')),
      );
      expect(preview.top, greaterThan(apply.bottom));
      expect(preview.width, lessThanOrEqualTo(_phone.width));
      expect(tester.takeException(), isNull);
    });

    testWidgets('two panes side by side when wide', (tester) async {
      await _pump(tester, 'member_rights', size: _wide);
      expect(
        find.byKey(const ValueKey('setup-step-two-panes')),
        findsOneWidget,
      );
      final apply = tester.getRect(
        find.byKey(const ValueKey('setup-rights-apply')),
      );
      final preview = tester.getRect(
        find.byKey(const ValueKey('setup-step-preview')),
      );
      expect(preview.left, greaterThan(apply.right));
    });
  });

  group('invite', () {
    testWidgets('the preview is the message as sent, in the chosen language', (
      tester,
    ) async {
      final repo = _repo();
      await _pump(tester, 'invite', repo: repo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetupStepScreen)),
      );
      String expected(String language) => buildInvitationMessage(
        workspace: repo.workspaces.first,
        code: 'GOODCODE22',
        role: InviteRole.user,
        languageCode: language,
        target: container.read(activeBackendProvider).value,
      );
      expect(_message(tester), expected('en'));

      await tester.tap(find.byKey(const ValueKey('setup-invite-lang-fr')));
      await tester.pumpAndSettle();
      expect(_message(tester), expected('fr'));
      expect(_message(tester), isNot(expected('en')));
    });

    testWidgets('copy puts the space ID on the clipboard', (tester) async {
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester, 'invite');
      await tester.tap(find.byKey(const ValueKey('setup-invite-copy')));
      await tester.pumpAndSettle();
      expect(copied, [
        {'text': 'GOODCODE22'},
      ]);
    });

    testWidgets('invite someone mints a personal code and shares the '
        'message around it', (tester) async {
      final repo = _repo();
      final shared = <String>[];
      await _pump(
        tester,
        'invite',
        repo: repo,
        extra: [
          textSharerProvider.overrideWithValue((text) async {
            shared.add(text);
          }),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('setup-invite-someone')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invite-share')));
      await tester.pumpAndSettle();

      final minted = repo.mintedInvitations.single;
      expect(minted.isAdmin, isFalse);
      expect(shared.single, contains(minted.code));
    });

    testWidgets('one column on a phone', (tester) async {
      await _pump(tester, 'invite');
      expect(
        find.byKey(const ValueKey('setup-step-one-column')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a step without a page opens the screen the catalogue names', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SetupStepScreen(stepId: 'recovery'),
        ),
        GoRoute(
          path: '/workspace-settings',
          builder: (_, _) => const Text('workspace settings screen'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpApp(
      tester,
      null,
      router: router,
      size: _phone,
      overrides: standardTestOverrides(workspace: _repo()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup-step-elsewhere')), findsOneWidget);
    await tester.tap(find.text('Open it'));
    await tester.pumpAndSettle();
    expect(find.text('workspace settings screen'), findsOneWidget);
  });
}
