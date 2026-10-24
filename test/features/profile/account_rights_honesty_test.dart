// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 acceptance "Account rights target/pending/retention statuses
// honest": a rights request names the exact space it is addressed to (and
// says so when that space is no longer listed), a pending one stays visibly
// pending with its due date, and an answered one says what the space kept
// (with the period it recorded) and what is still open elsewhere instead of
// reading as "all gone". Erasing names the one space it erases, and its
// confirmation does not claim more than that space.
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

RightsRequest _request(Map<String, dynamic> row) => RightsRequest.fromJson({
  'kind': 'erasure',
  'received_at': '2025-01-31T11:00:00Z',
  'due_on': '2025-02-28',
  ...row,
});

Future<({FakeProfileRepository profile, FakeCalendarRepository calendar})>
_pump(
  WidgetTester tester, {
  List<RightsRequest> requests = const [],
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
  )..rightsRequests.addAll(requests);
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
  final calendar = FakeCalendarRepository();
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        profile: profile,
        workspace: workspace,
        calendar: calendar,
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (profile: profile, calendar: calendar);
}

Future<void> _openRequests(WidgetTester tester) async {
  await openMyPrivacy(tester);
  final tile = find.byKey(const ValueKey('privacy-rights-requests'));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  group('Account rights target/pending/retention', () {
    testWidgets('each request names the space it is addressed to, and one '
        'to a space no longer listed says so', (tester) async {
      await _pump(
        tester,
        requests: [
          _request({'id': 'r1', 'workspace_id': 'ws-1', 'status': 'received'}),
          _request({
            'id': 'r2',
            'workspace_id': 'ws-gone',
            'kind': 'access',
            'status': 'received',
          }),
        ],
      );
      await _openRequests(tester);
      final listed = find.byKey(const ValueKey('rights-request-r1'));
      expect(
        find.descendant(
          of: listed,
          matching: find.textContaining('To Test Space'),
        ),
        findsOneWidget,
      );
      final gone = find.byKey(const ValueKey('rights-request-r2'));
      expect(
        find.descendant(
          of: gone,
          matching: find.textContaining('To a space no longer in your list'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: gone, matching: find.textContaining('Test Space')),
        findsNothing,
        reason: 'an unknown target is never guessed as the current space',
      );
    });

    testWidgets('a pending request stays pending with its due date; an '
        'answered erasure says what was kept, for how long, and what is '
        'still open elsewhere', (tester) async {
      await _pump(
        tester,
        requests: [
          _request({'id': 'r1', 'workspace_id': 'ws-1', 'status': 'received'}),
          _request({
            'id': 'r2',
            'workspace_id': 'ws-1',
            'status': 'completed',
            'outcome': {
              'removed': [
                {'store': 'messages_sent'},
              ],
              'retained': [
                {
                  'store': 'invoices',
                  'basis': 'accounting evidence',
                  'period': '10 years',
                },
              ],
              'pending_external': [
                {'store': 'other_installations'},
              ],
              'failed': [
                {'store': 'device_caches'},
              ],
            },
          }),
        ],
      );
      await _openRequests(tester);
      final pending = find.byKey(const ValueKey('rights-request-r1'));
      expect(
        find.descendant(
          of: pending,
          matching: find.textContaining('Received — answer due by'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pending, matching: find.textContaining('Kept:')),
        findsNothing,
        reason: 'a pending request claims no result',
      );
      final answered = find.byKey(const ValueKey('rights-request-r2'));
      Finder line(String text) =>
          find.descendant(of: answered, matching: find.textContaining(text));
      expect(line('Answered'), findsOneWidget);
      expect(line('Kept: Invoices and ledger'), findsOneWidget);
      expect(
        line('(10 years)'),
        findsOneWidget,
        reason: 'the period is the one the space recorded, not invented',
      );
      expect(
        line('Still open elsewhere: Another DesKilo installation'),
        findsOneWidget,
      );
      expect(line('Not done: Copies on your devices'), findsOneWidget);
    });

    testWidgets('a new request asks in the name of its space and confirms '
        'where it went', (tester) async {
      final fakes = await _pump(tester);
      await _openRequests(tester);
      await tester.tap(find.byKey(const ValueKey('rights-request-new')));
      await tester.pumpAndSettle();
      expect(find.text('What do you ask Test Space?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rights-request-send')));
      await tester.pump();
      expect(find.textContaining('Request sent to Test Space'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(fakes.profile.rightsRequests.single.workspaceId, 'ws-1');
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey(
              'rights-request-${fakes.profile.rightsRequests.single.id}',
            ),
          ),
          matching: find.textContaining('To Test Space'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('erasing names the one space it erases, and its confirmation '
        'keeps retention and other installations honest', (tester) async {
      final fakes = await _pump(tester, owner: false);
      await openMyPrivacy(tester);
      final erase = find.byKey(const ValueKey('privacy-erase'));
      await tester.ensureVisible(erase);
      await tester.tap(erase);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This erases your data in Test Space only. Your other spaces and '
          'other installations keep their own records.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('privacy-erase-phrase')),
        'ERASE',
      );
      await tester.tap(find.byKey(const ValueKey('privacy-erase-confirm')));
      await tester.pump();
      expect(fakes.calendar.erased, isTrue);
      expect(
        find.textContaining('Your data in Test Space is erased'),
        findsOneWidget,
      );
      expect(find.textContaining('retention period'), findsOneWidget);
      expect(
        find.textContaining('other installations are not affected'),
        findsOneWidget,
      );
      expect(
        find.text('Your data has been erased.'),
        findsNothing,
        reason: 'never a claim that every copy everywhere is gone',
      );
      await tester.pumpAndSettle();
    });
  });
}
