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
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
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
  List<Reservation> bookings = const [],
  Size size = const Size(1440, 900),
}) async {
  final space = _space(owner: owner)
    ..memberTermChanges.addAll(terms)
    // the demo's dated commands read the test's day
    ..termClock = FixedClock(kTestNow);
  await pumpRoute(
    tester,
    path,
    size: size,
    overrides: [
      ...standardTestOverrides(
        workspace: space,
        reservations: FakeReservationRepository()..reservations.addAll(bookings),
      ),
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
      find.byKey(const ValueKey('member-change-pause-from')),
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
      String reason = '',
    }) => MemberTermChange(
      id: id,
      memberId: 'member-2',
      kind: kind,
      toPct: pct,
      toStatus: status,
      dueOn: due,
      state: state,
      reason: reason,
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
        'applied',
        MemberTermKind.share,
        DateTime(2026, 12),
        MemberTermState.applied,
        pct: 50,
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

    // Two kept bookings and a cancelled one in May 2027, the first month
    // the waiting pause frees.
    Reservation booking(String id, int day, ReservationStatus status) =>
        Reservation(
          id: id,
          workspaceId: 'ws-1',
          memberId: 'member-2',
          seatId: 'seat',
          startsAt: DateTime(2027, 5, day, 9),
          endsAt: DateTime(2027, 5, day, 13),
          status: status,
        );
    final bookings = [
      booking('b1', 4, ReservationStatus.reserved),
      booking('b2', 5, ReservationStatus.reserved),
      booking('b3', 6, ReservationStatus.cancelled),
    ];

    Future<void> openPlan(WidgetTester tester) async {
      final space = await _open(
        tester,
        owner: true,
        terms: terms,
        bookings: bookings,
      );
      // April is already invoiced: it stays charged in full.
      space.memberInvoicedMonths['member-2'] = {DateTime(2027, 4)};
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

    testWidgets('a pause from the 15th says which months stay charged, an '
        'invoiced one with them, and which is the first free; and that it '
        'waits for approval', (tester) async {
      await openPlan(tester);
      expect(said('pause'), contains('until resumed'));
      expect(
        said('pause'),
        contains(
          'March 2027 to April 2027 is charged in full; no subscription fee '
          'for May 2027 and every month after, until resumed',
        ),
      );
      expect(said('pause'), contains('Waiting for approval'));
      expect(
        said('pause'),
        contains(
          '2 bookings fall in the paused months — they stay and are '
          'charged as use',
        ),
      );
    });

    testWidgets('a change in force shows its date and a refused one its '
        'reason', (tester) async {
      await openPlan(tester);
      expect(said('applied'), contains('Took effect on'));
      expect(said('refused'), contains('Refused: the member is not active'));
    });

    testWidgets('a wide table names the next change', (tester) async {
      await _open(
        tester,
        owner: true,
        terms: terms,
        size: const Size(2000, 900),
      );
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

    testWidgets('a narrow table gives the next change up first, and keeps '
        'the amounts whole', (tester) async {
      await _open(
        tester,
        owner: true,
        terms: terms,
        size: const Size(1024, 900),
      );
      expect(find.text('NEXT CHANGE'), findsNothing);
      expect(find.text('PLAN FEE'), findsOneWidget);
    });
  });

  group('#3858 the change task takes its date', () {
    Future<void> openTab(
      WidgetTester tester,
      FakeWorkspaceRepository space,
    ) async {
      await tester.tap(find.byKey(const ValueKey('records-row-member-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member-tab-plan')));
      await tester.pumpAndSettle();
    }

    String textOf(Finder f) => [
      for (final t
          in find
              .descendant(of: f, matching: find.byType(Text))
              .evaluate()
              .map((e) => e.widget as Text))
        t.data ?? '',
    ].join('\n');

    testWidgets('a pause says what it costs before and after it is applied', (
      tester,
    ) async {
      final space = await _open(tester, owner: true);
      await openTab(tester, space);
      await tester.tap(find.byKey(const ValueKey('member-plan-pause')));
      await tester.pumpAndSettle();
      // From today, the 13th, until resumed: May is charged, June is the
      // first month it frees.
      expect(
        tester
                .widget<Text>(
                  find.byKey(const ValueKey('member-change-preview')),
                )
                .data ??
            '',
        contains(
          'May 2026 is charged in full; no subscription fee for June 2026 '
          'and every month after, until resumed',
        ),
      );
      await tester.tap(find.byKey(const ValueKey('member-change-apply')));
      await tester.pumpAndSettle();
      expect(
        textOf(find.byKey(const ValueKey('member-change-outcome-member-2'))),
        allOf(
          contains('Changed'),
          contains('no subscription fee for June 2026'),
        ),
      );
      expect(space.memberOf('member-2')?.status, MemberStatus.paused);
    });

    testWidgets('a share from the first of a month waits for that day and '
        'says it', (tester) async {
      final space = await _open(tester, owner: true);
      await openTab(tester, space);
      await tester.tap(find.byKey(const ValueKey('member-plan-change')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member-change-share-0')));
      await tester.tap(find.byKey(const ValueKey('member-change-from-month')));
      await tester.pumpAndSettle();
      expect(
        tester
                .widget<Text>(
                  find.byKey(const ValueKey('member-change-preview')),
                )
                .data ??
            '',
        contains('first on the statement of June 2026'),
      );
      await tester.tap(find.byKey(const ValueKey('member-change-apply')));
      await tester.pumpAndSettle();
      expect(
        textOf(find.byKey(const ValueKey('member-change-outcome-member-2'))),
        contains('Takes effect on'),
      );
      // Waiting for its day: the share has not changed yet.
      expect(space.memberOf('member-2')?.subscriptionPct, 50);
      expect(space.memberTermChanges.single.state, MemberTermState.scheduled);
    });

    testWidgets('a date the server refuses names the earliest it can take', (
      tester,
    ) async {
      final space = await _open(tester, owner: true);
      // June and July are already invoiced for this member.
      space.memberInvoicedMonths['member-2'] = {
        DateTime(2026, 6),
        DateTime(2026, 7),
      };
      for (final id in ['member-2', 'member-3']) {
        await tester.tap(
          find.descendant(
            of: find.byKey(ValueKey('records-row-$id')),
            matching: find.byType(Checkbox),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('records-bulk-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member-change-share-0')));
      await tester.tap(find.byKey(const ValueKey('member-change-from-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member-change-apply')));
      await tester.pumpAndSettle();
      expect(
        textOf(find.byKey(const ValueKey('member-change-outcome-member-2'))),
        contains('Not changed: the earliest date it can take is'),
      );
      expect(space.memberOf('member-2')?.subscriptionPct, 50);
    });
  });
}
