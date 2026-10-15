// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The member directory fixture and pump, formerly in directory_screen_test.dart
// and borrowed by importing that test file (#2601).

import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import '../fake_profile_repository.dart';
import '../fake_reservation_repository.dart';
import '../mock_providers.dart';

// A 1×1 transparent PNG for avatar-image tests.
final directoryPngBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Member directoryMember(
  int n, {
  MemberStatus status = MemberStatus.active,
  bool isAdmin = false,
  bool isOwner = false,
}) => Member(
  id: 'member-$n',
  workspaceId: 'ws-1',
  userId: 'user-$n',
  isAdmin: isAdmin,
  isOwner: isOwner,
  status: status,
);

/// Seeds the canonical directory workspace: I am a PLAIN member (no owner
/// or admin role — the directory and its settings entry are open to
/// everyone). Anna is the OWNER, online AND checked in on seat A1 (both
/// chips, #237), Ben is online, shares WhatsApp and set a custom status
/// line (#231), Cara has an unchecked reservation covering now, Dora was
/// last seen ~2 h ago and holds the next upcoming booking (a Tuesday at
/// 01:15 on A1, [upcomingStart]), Eve was never seen and her only booking
/// starts 15 days out (outside the window — no chip at all), Paula is
/// paused (hidden).
({
  FakeWorkspaceRepository workspace,
  FakeReservationRepository reservations,
  FakeFloorPlanRepository floorPlan,
  FakeProfileRepository profile,
  DateTime upcomingStart,
})
seedDirectory() {
  final now = kTestNow;

  // Dora's upcoming booking: the NEXT Tuesday at 01:15 strictly after
  // now — 1..7 days out, always inside the 14-day window.
  final daysToTuesday = (DateTime.tuesday - now.weekday + 7) % 7;
  final upcomingStart = DateTime(
    now.year,
    now.month,
    now.day + (daysToTuesday == 0 ? 7 : daysToTuesday),
    1,
    15,
  );
  final workspace =
      FakeWorkspaceRepository.withWorkspace(
          // #825 — these tests drive the legacy sheets; the page has its own.
          featureFlags: const {'memberPage': false},
        )
        ..myMember = directoryMember(1)
        ..otherMembers.addAll([
          directoryMember(2, isOwner: true),
          directoryMember(3),
          directoryMember(4),
          directoryMember(5),
          directoryMember(6),
          directoryMember(7, status: MemberStatus.paused),
        ])
        ..memberNames = {
          'member-1': 'Flo',
          'member-2': 'Anna',
          'member-3': 'Ben',
          'member-4': 'Cara',
          'member-5': 'Dora',
          'member-6': 'Eve',
          'member-7': 'Paula',
        };

  final floorPlan = FakeFloorPlanRepository()..seedSmallPlan();
  final seatId = floorPlan.seats.single.id; // named 'A1'

  final reservations = FakeReservationRepository();
  reservations.reservations.addAll([
    // Anna: checked in right now on A1.
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
    // Cara: active reservation covering now, not checked in — the seat
    // is unknown to the plan, so the chip carries no seat name.
    Reservation(
      id: 'res-cara',
      workspaceId: 'ws-1',
      seatId: 'seat-other',
      memberId: 'member-4',
      startsAt: now.subtract(const Duration(minutes: 5)),
      endsAt: now.add(const Duration(minutes: 30)),
      status: ReservationStatus.reserved,
    ),
    // Dora: nothing now, next booking on a Tuesday at 01:15 on A1.
    Reservation(
      id: 'res-dora',
      workspaceId: 'ws-1',
      seatId: seatId,
      memberId: 'member-5',
      startsAt: upcomingStart,
      endsAt: upcomingStart.add(const Duration(hours: 2)),
      status: ReservationStatus.reserved,
    ),
    // Eve: only a booking 15 days out — beyond the 14-day window, so
    // her row shows no reservation chip (#237).
    Reservation(
      id: 'res-eve',
      workspaceId: 'ws-1',
      seatId: seatId,
      memberId: 'member-6',
      startsAt: now.add(const Duration(days: 15)),
      endsAt: now.add(const Duration(days: 15, hours: 2)),
      status: ReservationStatus.reserved,
    ),
  ]);

  final profile = FakeProfileRepository(
    profiles: [
      // My own lastSeenAt is stamped "now" by the presence heartbeat on app
      // start anyway (#223) — I render as Online.
      Profile(id: 'user-1', displayName: 'Flo', lastSeenAt: now),
      // Anna is online AND checked in: both chips coexist (#237).
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
      // user-6 (Eve) has no profile row at all: never seen.
    ],
  );

  return (
    workspace: workspace,
    reservations: reservations,
    floorPlan: floorPlan,
    profile: profile,
    upcomingStart: upcomingStart,
  );
}

/// Pumps the app signed in, opens settings and navigates into the
/// directory via its settings tile (kept as an every-member discovery
/// entry point; since #230 it switches to the Members shell tab).
Future<void> pumpDirectory(
  WidgetTester tester, {
  required FakeWorkspaceRepository workspace,
  FakeReservationRepository? reservations,
  FakeFloorPlanRepository? floorPlan,
  FakeProfileRepository? profile,
  LinkLauncher? linkLauncher,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          timeZoneMode: TimeZoneMode.device,
          workspace: workspace,
          reservations: reservations,
          floorPlan: floorPlan,
          profile: profile,
        ),
        if (linkLauncher != null)
          linkLauncherProvider.overrideWithValue(linkLauncher),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  // #1307 — the directory is the Members destination of the bottom bar;
  // Settings is no longer a second door to it.
  await tester.tap(find.text('Members'));
  await tester.pumpAndSettle();
}
