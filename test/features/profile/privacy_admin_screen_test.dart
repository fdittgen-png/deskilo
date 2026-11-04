// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3278 — the personal data admin's screen: the rights requests addressed to
// the workspace (record, extend, complete, refuse), the privacy incident, the
// SERVER's own words when it refuses (the sheet stays open and says why), and
// recovery (the same sheet saves once the server accepts). It is offered to
// whoever may decide a request and to nobody else.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/profile/domain/rights_request.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_calendar_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/open_my_account.dart';

RightsRequest _seed(String id, {String status = 'received'}) => RightsRequest(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  kind: 'access',
  status: status,
  receivedAt: DateTime(2026, 10, 20),
  dueOn: DateTime(2026, 11, 20),
  details: 'a copy of what you hold',
);

Future<FakeProfileRepository> _pump(
  WidgetTester tester, {
  bool owner = true,
}) async {
  final profile = FakeProfileRepository(
    profiles: [
      const Profile(
        id: 'user-1',
        displayName: 'Test User',
        privacyAcceptedVersion: kPrivacyPolicyVersion,
      ),
    ],
  )..rightsRequests.addAll([_seed('rr-seed')]);
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: const {'memberDataExport': true},
  );
  if (!owner) {
    workspace.myMember = const Member(
      id: 'member-1',
      workspaceId: 'ws-1',
      userId: 'user-1',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    );
  }
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        profile: profile,
        workspace: workspace,
        calendar: FakeCalendarRepository(),
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return profile;
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _openScreen(WidgetTester tester) async {
  await openMyPrivacy(tester);
  final tile = _key('privacy-admin-open');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the screen lists what was asked, with where each stands', (
    tester,
  ) async {
    await _pump(tester);
    await _openScreen(tester);
    expect(find.text('Personal data and rights requests'), findsWidgets);
    expect(_key('privacy-admin-request-rr-seed'), findsOneWidget);
    expect(find.text('a copy of what you hold'), findsOneWidget);
  });

  testWidgets('it is offered to a person who may decide requests, and to '
      'nobody else', (tester) async {
    await _pump(tester, owner: false);
    await openMyPrivacy(tester);
    expect(_key('privacy-admin-open'), findsNothing);
  });

  testWidgets('record a request received elsewhere: it joins the list '
      'with its answer date', (tester) async {
    final profile = await _pump(tester);
    await _openScreen(tester);
    await _tap(tester, _key('privacy-admin-record'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Details (optional)'),
      'asked at the front desk',
    );
    await _tap(tester, _key('privacy-admin-record-save'));
    expect(profile.rightsRequests.length, 2);
    expect(profile.rightsRequests.first.details, 'asked at the front desk');
    expect(profile.rightsRequests.first.memberId, 'member-1');
    expect(find.text('asked at the front desk'), findsOneWidget);
  });

  testWidgets('extend: a reason is required, then the request is extended '
      'and says so', (tester) async {
    final profile = await _pump(tester);
    await _openScreen(tester);
    await _tap(tester, _key('privacy-admin-extend-rr-seed'));
    // A short reason is refused under its field; nothing is sent.
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason for the extension (at least 10 characters)'),
      'too short',
    );
    await _tap(tester, _key('privacy-admin-extend-save'));
    expect(profile.rightsRequests.single.status, 'received');
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason for the extension (at least 10 characters)'),
      'the file is large and the controller is away',
    );
    await _tap(tester, _key('privacy-admin-extend-save'));
    expect(profile.rightsRequests.single.status, 'extended');
    expect(find.textContaining('the controller is away'), findsOneWidget);
  });

  testWidgets('complete: one store and what happened to it closes the '
      'request', (tester) async {
    final profile = await _pump(tester);
    await _openScreen(tester);
    await _tap(tester, _key('privacy-admin-complete-rr-seed'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Where (a store or a list)'),
      'member profile',
    );
    await _tap(tester, _key('privacy-admin-complete-save'));
    final done = profile.rightsRequests.single;
    expect(done.status, 'completed');
    expect(done.outcome['removed'], isNotEmpty);
    // A closed request offers no more decisions.
    expect(_key('privacy-admin-complete-rr-seed'), findsNothing);
  });

  testWidgets('refuse needs its reason; the refusal is recorded with it', (
    tester,
  ) async {
    final profile = await _pump(tester);
    await _openScreen(tester);
    await _tap(tester, _key('privacy-admin-refuse-rr-seed'));
    await _tap(tester, _key('privacy-admin-refuse-save'));
    expect(profile.rightsRequests.single.status, 'received');
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason for the refusal (at least 10 characters)'),
      'the person could not be identified',
    );
    await _tap(tester, _key('privacy-admin-refuse-save'));
    expect(profile.rightsRequests.single.status, 'refused');
    expect(
      profile.rightsRequests.single.refusalReason,
      'the person could not be identified',
    );
  });

  testWidgets('a refusal by the server is shown in its own words, the sheet '
      'stays open, and the same sheet saves once the server accepts', (
    tester,
  ) async {
    final profile = await _pump(tester);
    await _openScreen(tester);
    profile.failing = true;
    await _tap(tester, _key('privacy-admin-record'));
    await _tap(tester, _key('privacy-admin-record-save'));
    expect(find.textContaining('The server refused:'), findsOneWidget);
    expect(
      find.textContaining("only the space's controller records a rights request"),
      findsOneWidget,
    );
    expect(profile.rightsRequests.length, 1, reason: 'nothing was recorded');
    // Recovery: the server accepts now; the same sheet saves.
    profile.failing = false;
    await _tap(tester, _key('privacy-admin-record-save'));
    expect(profile.rightsRequests.length, 2);
  });

  testWidgets('a privacy incident tells whoever holds the privacy right and '
      'says how many were told', (tester) async {
    final profile = await _pump(tester);
    profile.privacyHolders = 2;
    await _openScreen(tester);
    await _tap(tester, _key('privacy-admin-incident'));
    await tester.enterText(
      find.widgetWithText(TextField, 'What happened (optional, 1000 characters at most)'),
      'a list was e-mailed to the wrong address',
    );
    await _tap(tester, _key('privacy-admin-incident-send'));
    expect(profile.privacyIncidents.single.kind, 'data_breach');
    expect(profile.privacyIncidents.single.note, contains('wrong address'));
    expect(find.text('Recorded. 2 people were told.'), findsOneWidget);
  });
}
