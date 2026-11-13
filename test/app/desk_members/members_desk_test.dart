// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — the members' table at the desk: a column the person may not see is
// not there at all, not an empty one (the acceptance, with two roles); the
// chips filter; a member opens beside the table at their address with their
// tabs; the owner's selection runs the change task with its outcomes.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../ux/experience_guards.dart';

const _bob = Member(
  id: 'member-2',
  workspaceId: 'ws-1',
  userId: 'user-2',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
  subscriptionPct: 50,
);

const _ana = Member(
  id: 'member-3',
  workspaceId: 'ws-1',
  userId: 'user-3',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.pending,
);

FakeWorkspaceRepository _space({required bool owner}) {
  final features = {for (final f in WorkspaceFeature.values) f.name: true};
  final space = FakeWorkspaceRepository.withWorkspace(featureFlags: features)
    ..otherMembers.addAll([_bob, _ana])
    ..memberEmails = {'member-2': 'bob@example.test'};
  if (!owner) {
    space.myMember = space.myMember.copyWith(isAdmin: false, isOwner: false);
  }
  return space;
}

Future<FakeWorkspaceRepository> _open(
  WidgetTester tester, {
  required bool owner,
  String path = '/members',
}) async {
  final space = _space(owner: owner);
  await pumpRoute(
    tester,
    path,
    size: const Size(1440, 900),
    overrides: [
      ...standardTestOverrides(workspace: space),
      enabledFeaturesSyncProvider.overrideWithValue(
        WorkspaceFeature.values.toSet(),
      ),
      if (!owner)
        // A member who manages members and nothing of the money.
        myPermissionsProvider.overrideWithValue({
          WorkspacePermission.manageMembers,
        }),
    ],
  );
  return space;
}

/// The column labels in the table's header (drawn in capitals).
Set<String> _headers(WidgetTester tester) => {
  for (final label in [
    'E-mail',
    'Plan fee',
    'Open',
    'Plan and share',
    'Status',
  ])
    if (find.text(label.toUpperCase()).evaluate().isNotEmpty) label,
};

void main() {
  testWidgets('the owner sees the e-mail, the plan fee and the open amount', (
    tester,
  ) async {
    await _open(tester, owner: true);
    expect(_headers(tester), {
      'E-mail',
      'Plan fee',
      'Open',
      'Plan and share',
      'Status',
    });
    expect(find.text('bob@example.test'), findsOneWidget);
  });

  testWidgets('a member manager without money rights has no such columns', (
    tester,
  ) async {
    await _open(tester, owner: false);
    // Absent, not empty: no header, and no chip that would filter on it.
    expect(_headers(tester), {'Plan and share', 'Status'});
    expect(find.text('With an open amount'), findsNothing);
    expect(find.byKey(const ValueKey('records-row-member-2')), findsOneWidget);
  });

  testWidgets('the Pending chip keeps the pending member only', (tester) async {
    await _open(tester, owner: true);
    await tester.tap(find.byKey(const ValueKey('records-chip-pending')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('records-row-member-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('records-row-member-2')), findsNothing);
  });

  testWidgets('a member opens beside the table at their address, with tabs', (
    tester,
  ) async {
    await _open(tester, owner: true);
    await tester.tap(find.byKey(const ValueKey('records-row-member-2')));
    await tester.pumpAndSettle();
    final router = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloApp)),
    ).read(routerProvider);
    expect(router.routeInformationProvider.value.uri.path, '/members/member-2');
    expect(find.byKey(const ValueKey('member-panel-member-2')), findsOneWidget);
    for (final tab in ['profile', 'plan', 'bookings', 'invoices', 'notes']) {
      expect(
        find.byKey(ValueKey('member-tab-$tab')),
        findsOneWidget,
        reason: tab,
      );
    }
    await tester.tap(find.byKey(const ValueKey('member-tab-plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-plan-joined')), findsOneWidget);
  });

  testWidgets('a pause of a selection lists each member with its outcome', (
    tester,
  ) async {
    final space = await _open(tester, owner: true);
    for (final id in ['member-2', 'member-3']) {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('records-row-$id')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('records-bulk-pause')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('member-change-from-today')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('member-change-apply')));
    await tester.pumpAndSettle();
    expect(find.text('1 changed out of 2 members'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('member-change-outcome-member-3')),
        matching: find.text('Waiting to be accepted: not changed'),
      ),
      findsOneWidget,
    );
    expect(space.memberOf('member-2')?.status, MemberStatus.paused);
    expect(space.memberOf('member-3')?.status, MemberStatus.pending);
  });
}
