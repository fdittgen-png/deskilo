// SPDX-License-Identifier: 0BSD
//
// #825 — one page per member: identity and presence spelled out, the
// "right now" sentence and the upcoming list, quick actions by right,
// the admin controls grouped with their current values, and the
// directory row leading there when the flag is on.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/members/presentation/screens/member_page.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Member _member(
  int n, {
  MemberStatus status = MemberStatus.active,
  bool isAdmin = false,
  bool isOwner = false,
  DateTime? joinedAt,
}) =>
    Member(
      id: 'member-$n',
      workspaceId: 'ws-1',
      userId: 'user-$n',
      isAdmin: isAdmin,
      isOwner: isOwner,
      status: status,
      joinedAt: joinedAt,
    );

/// Me (member-1) as the OWNER unless [viewerOwner] is false; Anna
/// (owner, checked in at A1 now), Ben (online, WhatsApp, a status line,
/// one booking next Tuesday), Cara (never seen), Dora (seen two hours
/// ago, upcoming booking).
({
  FakeWorkspaceRepository workspace,
  FakeReservationRepository reservations,
  FakeFloorPlanRepository floorPlan,
  FakeProfileRepository profile,
}) _seed({bool viewerOwner = true, Map<String, dynamic> flags = const {}}) {
  final now = kTestNow;
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..myMember = _member(1, isOwner: viewerOwner, isAdmin: viewerOwner)
    ..otherMembers.addAll([
      _member(2, isOwner: true),
      _member(3, joinedAt: DateTime.utc(2026, 5, 12)),
      _member(4),
      _member(5),
    ])
    ..memberNames = {
      'member-1': 'Flo',
      'member-2': 'Anna',
      'member-3': 'Ben',
      'member-4': 'Cara',
      'member-5': 'Dora',
    }
    ..memberEmails = {
      'member-3': 'ben@example.org',
    };
  final floorPlan = FakeFloorPlanRepository()..seedSmallPlan();
  final seatId = floorPlan.seats.single.id; // named 'A1'
  final tuesday = now.add(Duration(
      days: ((DateTime.tuesday - now.weekday + 7) % 7) == 0
          ? 7
          : (DateTime.tuesday - now.weekday + 7) % 7));
  final reservations = FakeReservationRepository()
    ..reservations.addAll([
      Reservation(
        id: 'res-anna',
        workspaceId: 'ws-1',
        seatId: seatId,
        memberId: 'member-2',
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 1)),
        status: ReservationStatus.checkedIn,
        checkedInAt: now.subtract(const Duration(hours: 1)),
      ),
      Reservation(
        id: 'res-ben',
        workspaceId: 'ws-1',
        seatId: seatId,
        memberId: 'member-3',
        startsAt: DateTime(tuesday.year, tuesday.month, tuesday.day, 9),
        endsAt: DateTime(tuesday.year, tuesday.month, tuesday.day, 11),
        status: ReservationStatus.reserved,
      ),
    ]);
  final profile = FakeProfileRepository(profiles: [
    Profile(id: 'user-1', displayName: 'Flo', lastSeenAt: now),
    Profile(id: 'user-2', displayName: 'Anna', lastSeenAt: now),
    Profile(
      id: 'user-3',
      displayName: 'Ben',
      whatsapp: '+491701234567',
      statusText: 'In a call · back at 14:00',
      lastSeenAt: now.subtract(const Duration(minutes: 1)),
    ),
    const Profile(id: 'user-4', displayName: 'Cara'),
    Profile(
      id: 'user-5',
      displayName: 'Dora',
      lastSeenAt: now.subtract(const Duration(hours: 2, minutes: 5)),
    ),
  ]);
  return (
    workspace: workspace,
    reservations: reservations,
    floorPlan: floorPlan,
    profile: profile,
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  String memberId, {
  bool viewerOwner = true,
  Map<String, dynamic> flags = const {},
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = _seed(viewerOwner: viewerOwner, flags: flags);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: s.workspace,
        reservations: s.reservations,
        floorPlan: s.floorPlan,
        profile: s.profile,
      ),
      child: MaterialApp(home: MemberPage(memberId: memberId)),
    ),
  );
  await tester.pumpAndSettle();
}

String _subtitle(WidgetTester tester, String key) =>
    (tester.widget<ListTile>(find.byKey(ValueKey(key))).subtitle as Text)
        .data!;

void main() {
  testWidgets('the header says who they are and when they were last seen '
      '— in words, not a bare number', (tester) async {
    await _pumpPage(tester, 'member-5');
    expect(find.byKey(const ValueKey('member-page-header')), findsOneWidget);
    expect(find.text('Dora'), findsWidgets);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('member-page-presence')))
            .data,
        'Seen 2 h ago');

    await _pumpPage(tester, 'member-3');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('member-page-presence')))
            .data,
        'Online');
    expect(find.byKey(const ValueKey('member-page-status-text')),
        findsOneWidget);
    expect(find.textContaining('Member since'), findsOneWidget);

    await _pumpPage(tester, 'member-4');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('member-page-presence')))
            .data,
        'Not seen yet');
    expect(find.byKey(const ValueKey('member-page-since')), findsNothing);

    await _pumpPage(tester, 'member-2');
    expect(find.text('Owner'), findsOneWidget);
  });

  testWidgets('"Right now" is one sentence: checked in with the seat and '
      'the time, or the next booking; tapping opens the reservation',
      (tester) async {
    await _pumpPage(tester, 'member-2');
    expect(find.textContaining('Checked in · A1 · since'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member-page-now-line')));
    await tester.pumpAndSettle();
    expect(find.byType(ReservationDetailSheet), findsOneWidget);

    await _pumpPage(tester, 'member-3');
    expect(find.textContaining('Next: '), findsOneWidget);
    expect(find.textContaining('09:00 · A1'), findsOneWidget);

    await _pumpPage(tester, 'member-4');
    expect(find.text('No upcoming reservations'), findsOneWidget);
  });

  testWidgets('quick actions follow the viewer\'s rights: an admin sees '
      'e-mail and the agreement, a plain member neither', (tester) async {
    await _pumpPage(tester, 'member-3');
    expect(find.byKey(const ValueKey('member-page-action-email')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('member-page-action-wa')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('member-page-action-message')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('member-page-manage')), findsOneWidget);

    await _pumpPage(tester, 'member-3', viewerOwner: false);
    expect(find.byKey(const ValueKey('member-page-action-email')),
        findsNothing);
    expect(find.byKey(const ValueKey('member-page-manage')), findsNothing);
    expect(find.byKey(const ValueKey('member-page-action-wa')),
        findsOneWidget);
  });

  testWidgets('the Manage rows carry their CURRENT value, and a change '
      'shows on the row at once', (tester) async {
    await _pumpPage(tester, 'member-3', flags: const {'levelBooking': true});
    expect(_subtitle(tester, 'member-page-reservation-limit'), 'No limit');
    expect(_subtitle(tester, 'member-page-simultaneous'),
        'Workspace default (1)');
    expect(_subtitle(tester, 'member-page-subscription'), '100%');
    expect(_subtitle(tester, 'member-page-overage'), 'Block further booking');
    expect(_subtitle(tester, 'member-page-role'), 'Member');
    expect(_subtitle(tester, 'member-page-pause'), 'Active');

    await tester.ensureVisible(
        find.byKey(const ValueKey('member-page-simultaneous')));
    await tester.tap(find.byKey(const ValueKey('member-page-simultaneous')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('simultaneous-3')));
    await tester.pumpAndSettle();
    expect(_subtitle(tester, 'member-page-simultaneous'), '3');

    // The whole-level right is a switch that flips through the RPC.
    await tester.ensureVisible(find.byKey(const ValueKey('member-page-level')));
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('member-page-level')))
            .value,
        isFalse);
    await tester.tap(find.byKey(const ValueKey('member-page-level')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('member-page-level')))
            .value,
        isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('member-page-pause')));
    await tester.tap(find.byKey(const ValueKey('member-page-pause')));
    await tester.pumpAndSettle();
    expect(_subtitle(tester, 'member-page-pause'), 'Paused');
  });

  Future<void> openDoraFromDirectory(WidgetTester tester, {required bool on}) async {
    final s = _seed(viewerOwner: false, flags: {'memberPage': on});
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: s.workspace,
          reservations: s.reservations,
          floorPlan: s.floorPlan,
          profile: s.profile,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    // The directory, the way its own tests reach it.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dora'));
    await tester.pumpAndSettle();
  }

  testWidgets('the directory row opens the PAGE when the flag is on',
      (tester) async {
    await openDoraFromDirectory(tester, on: true);
    expect(find.byKey(const ValueKey('member-page')), findsOneWidget);
    expect(find.text('Seen 2 h ago'), findsOneWidget);
  });

  testWidgets('with the flag off the row keeps the profile sheet',
      (tester) async {
    await openDoraFromDirectory(tester, on: false);
    expect(find.byKey(const ValueKey('member-page')), findsNothing);
    expect(find.byKey(const ValueKey('directory-sheet-status-member-5')),
        findsOneWidget);
  });
}
