// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1652 — the invitation journey through the real app and router, with
// fakes behind the repositories: one field, one read-only review, one
// explicit Join, the typed result, and a waiting screen that is a usable
// state. Every assertion that "nothing was written" counts the calls the
// fake received, so it would differ if the step had written.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/features/workspace/application/pending_invitation.dart';
import 'package:deskilo/features/workspace/domain/invitation_answer.dart';
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/pending_approval_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _here = BackendEndpoint(
  'https://here.example.org',
  'sb_publishable_here_key_0001',
);
const _there = BackendEndpoint(
  'https://there.example.org',
  'sb_publishable_there_key_0002',
);

/// The plan cache the waiting screen must clear first; it can fail like
/// a lost connection.
class _Plans extends FakeFloorPlanRepository {
  bool offline = false;
  @override
  Future<void> invalidateCache() async {
    if (offline) throw StateError('offline');
  }
}

class _Repo extends FakeWorkspaceRepository {
  _Repo() : super();
  _Repo.withWorkspace() : super.withWorkspace();
  Completer<void>? gate;

  @override
  Future<InvitationAnswer> joinByInvitation(String inviteCode) async {
    await gate?.future;
    return super.joinByInvitation(inviteCode);
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeWorkspaceRepository repo, {
  BackendEndpoint active = _here,
  PendingInvitationStore? kept,
  FakeQrScanner? scanner,
  FakeFloorPlanRepository? plans,
  Size size = const Size(800, 1400),
  double textScale = 1,
  String locale = 'en',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: repo,
          backendSettings: InMemoryBackendSettingsStore()..value = active,
          pendingInvitation: kept,
          qrScan: scanner,
          floorPlan: plans,
        ),
        localeStoreProvider.overrideWithValue(
          InMemoryLocaleStore()..languageCode = locale,
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const DeskiloApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

Future<void> _openJoin(WidgetTester tester, GoRouter router) async {
  router.go('/onboarding?join=1');
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('invitation-input')), findsOneWidget);
}

Future<void> _review(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('invitation-input')), text);
  await tester.tap(find.byKey(const ValueKey('invitation-review-button')));
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const ValueKey('invitation-input')))
    .controller!
    .text;

void main() {
  testWidgets(
    'review writes nothing; one explicit Join (double tap) lands on the '
    'named waiting screen; checking again never resubmits and offline says not updated',
    (tester) async {
      final repo = _Repo()
        ..joinsArePending = true
        ..gate = Completer<void>();
      final plans = _Plans();
      final router = await _pump(tester, repo, plans: plans);
      await _openJoin(tester, router);

      await _review(
        tester,
        'Hi! Join Le Bocal on DesKilo.\nYour ID:\n```GOODCODE22```\nSee you!',
      );
      expect(find.byKey(const ValueKey('invitation-review')), findsOneWidget);
      expect(find.text('Joined Space'), findsOneWidget);
      expect(find.text('Server: here.example.org'), findsOneWidget);
      expect(find.text('Offered role: member'), findsOneWidget);
      expect(
        find.textContaining('An administrator approves new members'),
        findsOneWidget,
      );
      expect(repo.previewCalls, 1);
      expect(repo.joinByInvitationCalls, 0);
      expect(repo.workspaces, isEmpty, reason: 'a review is not a join');

      final join = find.byKey(const ValueKey('invitation-join'));
      await tester.ensureVisible(join);
      await tester.tap(join);
      await tester.tap(join, warnIfMissed: false);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(join).onPressed,
        isNull,
        reason: 'busy until answered',
      );
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.joinByInvitationCalls, 1, reason: 'a double tap joins once');
      expect(repo.workspaces, hasLength(1));

      expect(find.byType(PendingApprovalScreen), findsOneWidget);
      expect(
        find.text('Workspace membership awaiting approval'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pending-workspace')), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-help')), findsOneWidget);
      expect(find.byType(ShellBottomBar), findsNothing);

      await tester.tap(find.byKey(const ValueKey('pending-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Still awaiting approval.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pending-last-checked')),
        findsOneWidget,
      );

      plans.offline = true;
      await tester.tap(find.byKey(const ValueKey('pending-refresh')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Status not updated'), findsOneWidget);
      expect(
        find.byType(PendingApprovalScreen),
        findsOneWidget,
        reason: 'no connection is neither approved nor rejected',
      );
      expect(
        repo.joinByInvitationCalls,
        1,
        reason: 'checking never asks for admission again',
      );

      plans.offline = false;
      repo.myMember = repo.myMember.copyWith(status: MemberStatus.active);
      await tester.tap(find.byKey(const ValueKey('pending-refresh')));
      await tester.pumpAndSettle();
      expect(find.byType(ShellBottomBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  final refusals = {
    InvitationState.expired: 'invitation-expired',
    InvitationState.revoked: 'invitation-revoked',
    InvitationState.wrongAccount: 'invitation-wrong-account',
    InvitationState.paused: 'invitation-paused',
    InvitationState.invalid: 'invitation-invalid',
    InvitationState.unknown: 'invitation-unknown',
  };
  for (final entry in refusals.entries) {
    testWidgets('${entry.key.name}: its own answer, no Join, the input kept', (
      tester,
    ) async {
      final repo = _Repo()
        ..invitationAnswers['GOODCODE22'] = InvitationAnswer(
          entry.key,
          workspaceName: 'Joined Space',
        );
      final router = await _pump(tester, repo);
      await _openJoin(tester, router);
      await _review(tester, 'GOODCODE22');
      expect(find.byKey(ValueKey(entry.value)), findsOneWidget);
      for (final other in refusals.values.where((k) => k != entry.value)) {
        expect(find.byKey(ValueKey(other)), findsNothing);
      }
      expect(find.byKey(const ValueKey('invitation-join')), findsNothing);
      expect(
        find.byKey(const ValueKey('invitation-switch-account')),
        entry.key == InvitationState.wrongAccount
            ? findsOneWidget
            : findsNothing,
      );
      expect(repo.joinByInvitationCalls, 0);
      await tester.tap(find.byKey(const ValueKey('invitation-another')));
      await tester.pumpAndSettle();
      expect(_field(tester), 'GOODCODE22');
    });
  }

  testWidgets(
    'already a member: Continue opens that workspace, never a second join',
    (tester) async {
      final repo = _Repo.withWorkspace()
        ..invitationAnswers['GOODCODE22'] = const InvitationAnswer(
          InvitationState.alreadyMember,
          workspaceId: 'ws-1',
          workspaceName: 'Test Space',
          memberStatus: MemberStatus.active,
        );
      final router = await _pump(tester, repo);
      await _openJoin(tester, router);
      await _review(tester, 'GOODCODE22');
      expect(
        find.byKey(const ValueKey('invitation-already-member')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('invitation-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(ShellBottomBar), findsOneWidget);
      expect(repo.joinByInvitationCalls, 0);
    },
  );

  testWidgets(
    'an invitation for another server is never sent here; it is kept '
    'securely for that server and comes back in the field there, not joined',
    (tester) async {
      final kept = InMemoryPendingInvitationStore();
      final repo = _Repo();
      final router = await _pump(tester, repo, kept: kept);
      await _openJoin(tester, router);
      final link = InviteUriCodec.encode(
        code: 'GOODCODE22',
        role: InviteRole.user,
        target: _there,
        targetLabel: 'Le Bocal',
      );
      await _review(tester, link);
      expect(
        find.byKey(const ValueKey('invitation-other-server')),
        findsOneWidget,
      );
      expect(find.textContaining('there.example.org'), findsWidgets);
      expect(
        repo.previewCalls,
        0,
        reason: 'the code is a secret of the other server',
      );

      await tester.tap(find.byKey(const ValueKey('invitation-use-server')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/server');
      expect(
        find.widgetWithText(TextField, _there.url),
        findsOneWidget,
        reason:
            'the candidate is on the form, to verify and save like a typed one',
      );
      expect(kept.value, contains('there.example.org'));

      // The restart on the other server, signed in there.
      await tester.pumpWidget(const SizedBox.shrink());
      final there = _Repo();
      await _pump(tester, there, active: _there, kept: kept);
      expect(
        find.byKey(const ValueKey('invitation-input')),
        findsOneWidget,
        reason: 'Join is selected by the kept invitation',
      );
      expect(_field(tester), link);
      expect(
        there.previewCalls + there.joinByInvitationCalls,
        0,
        reason: 'arriving never checks or joins by itself',
      );
      await tester.tap(find.byKey(const ValueKey('invitation-review-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invitation-review')), findsOneWidget);
      expect(
        find.text('Named “Le Bocal” by whoever shared it'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'scan cancelled keeps the typed input; Paste reads the clipboard only '
    'on the tap; Cancel from the review keeps it too',
    (tester) async {
      var clipboardReads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            clipboardReads++;
            return {'text': 'deskilo://join?role=user&code=GOODCODE22'};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final scanner = FakeQrScanner();
      final router = await _pump(tester, _Repo(), scanner: scanner);
      await _openJoin(tester, router);
      expect(clipboardReads, 0, reason: 'no clipboard inspection on arrival');
      await tester.enterText(
        find.byKey(const ValueKey('invitation-input')),
        'GOOD',
      );
      await tester.tap(find.byKey(const ValueKey('invitation-scan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scan-join-camera')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_field(tester), 'GOOD');

      await tester.tap(find.byKey(const ValueKey('invitation-paste')));
      await tester.pumpAndSettle();
      expect(clipboardReads, 1);
      expect(find.byKey(const ValueKey('invitation-review')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('invitation-cancel')));
      await tester.pumpAndSettle();
      expect(_field(tester), 'deskilo://join?role=user&code=GOODCODE22');
    },
  );

  testWidgets(
    '360dp at twice the text size: the review and its Join stay reachable',
    (tester) async {
      final router = await _pump(
        tester,
        _Repo(),
        size: const Size(360, 640),
        textScale: 2,
      );
      await _openJoin(tester, router);
      await _review(tester, 'GOODCODE22');
      final join = find.byKey(const ValueKey('invitation-join'));
      await tester.ensureVisible(join);
      expect(tester.getSize(join).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an invitation link opened from outside selects Join with the link '
    'in the field, out of the location, and joins nothing',
    (tester) async {
      final repo = _Repo();
      final router = await _pump(tester, repo);
      await router.routeInformationProvider.didPushRouteInformation(
        RouteInformation(
          uri: Uri.parse('deskilo://join?role=user&code=GOODCODE22'),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/onboarding?join=1');
      expect(_field(tester), 'deskilo://join?role=user&code=GOODCODE22');
      expect(repo.previewCalls + repo.joinByInvitationCalls, 0);
    },
  );

  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$locale: the review speaks the language', (tester) async {
      final router = await _pump(tester, _Repo(), locale: locale);
      await _openJoin(tester, router);
      await _review(tester, 'GOODCODE22');
      final l10n = lookupAppLocalizations(Locale(locale));
      expect(find.text(l10n.invitationJoinButton), findsOneWidget);
      expect(find.text(l10n.invitationReviewTitle), findsOneWidget);
      expect(find.text(l10n.invitationRoleMember), findsOneWidget);
    });
  }
}
