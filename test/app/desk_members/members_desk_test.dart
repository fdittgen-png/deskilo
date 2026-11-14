// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — the members' table at the desk: a column the person may not see is
// not there at all, not an empty one (the acceptance, with two roles); the
// chips filter; a member opens beside the table at their address with their
// tabs; the owner's selection runs the change task with its outcomes.
// #3858 — the Plan tab lists the scheduled changes with the money they
// mean in words, and the table names each member's next change.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_term_change.dart';
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
  List<MemberTermChange> terms = const [],
}) async {
  final space = _space(owner: owner)..memberTermChanges.addAll(terms);
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

  group('#3858 dated terms', () {
    MemberTermChange change(
      String id,
      MemberTermKind kind,
      DateTime due,
      MemberTermState state, {
      int? pct,
      String? status,
      DateTime? effective,
      String reason = '',
      String? group,
    }) => MemberTermChange(
      id: id,
      memberId: 'member-2',
      kind: kind,
      toPct: pct,
      toStatus: status,
      dueOn: due,
      state: state,
      effectiveOn: effective,
      reason: reason,
      groupId: group,
    );

    final terms = [
      change(
        'share',
        MemberTermKind.share,
        DateTime(2027, 2, 10),
        MemberTermState.scheduled,
        pct: 75,
      ),
      change(
        'pause',
        MemberTermKind.status,
        DateTime(2027, 3, 15),
        MemberTermState.pending,
        status: 'paused',
      ),
      change(
        'late',
        MemberTermKind.share,
        DateTime(2026, 12),
        MemberTermState.applied,
        pct: 50,
        effective: DateTime(2027),
      ),
      change(
        'refused',
        MemberTermKind.status,
        DateTime(2026, 11),
        MemberTermState.refused,
        status: 'paused',
        reason: 'the member is not active',
      ),
    ];

    Future<void> openPlan(WidgetTester tester) async {
      await _open(tester, owner: true, terms: terms);
      await tester.tap(find.byKey(const ValueKey('records-row-member-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member-tab-plan')));
      await tester.pumpAndSettle();
    }

    String said(String key) => [
      for (final t in find
          .descendant(
            of: find.byKey(ValueKey('member-term-$key')),
            matching: find.byType(Text),
          )
          .evaluate()
          .map((e) => e.widget as Text))
        t.data ?? '',
    ].join('\n');

    testWidgets('a share change names the first statement it shows on', (
      tester,
    ) async {
      await openPlan(tester);
      expect(said('share'), contains('first on the statement of March 2027'));
      expect(said('share'), contains('Scheduled'));
    });

    testWidgets('a pause from the 15th says which month is charged and '
        'which is free, and that it waits for approval', (tester) async {
      await openPlan(tester);
      expect(said('pause'), contains('until resumed'));
      expect(
        said('pause'),
        contains(
          'March 2027 is charged in full; no subscription fee for '
          'April 2027 and every month after, until resumed',
        ),
      );
      expect(said('pause'), contains('Waiting for approval'));
    });

    testWidgets('a late change shows both dates and a refused one its '
        'reason', (tester) async {
      await openPlan(tester);
      expect(said('late'), contains('Due on'));
      expect(said('late'), contains('took effect on'));
      expect(said('refused'), contains('Refused: the member is not active'));
    });

    testWidgets('the table names the next change', (tester) async {
      await _open(tester, owner: true, terms: terms);
      // The share is written the locale's way (its percent sign and space).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').contains('75') &&
              (w.data ?? '').contains(' from '),
        ),
        findsOneWidget,
      );
    });
  });
}
