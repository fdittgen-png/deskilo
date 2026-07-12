// SPDX-License-Identifier: MIT
//
// The member directory (#224, epic #222): every member reaches it from
// settings; each ACTIVE member renders exactly one status chip resolved in
// priority order (checked in > online > reserved today > offline with a
// relative last-seen; never seen = no chip), and the WhatsApp button
// appears only for members who shared a number, launching wa.me through
// the injectable link seam.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/theme/status_colors.dart';
import 'package:deskilo/core/trace/dev_mode.dart';
import 'package:deskilo/core/ui/empty_state.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

/// In-memory [DevModeStore]; settings watches it, keep it off the channels.
class _InMemoryDevModeStore implements DevModeStore {
  bool enabled = false;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool enabled) async => this.enabled = enabled;
}

Member _member(
  int n, {
  MemberStatus status = MemberStatus.active,
}) =>
    Member(
      id: 'member-$n',
      workspaceId: 'ws-1',
      userId: 'user-$n',
      isAdmin: false,
      isOwner: false,
      status: status,
    );

/// Seeds the canonical directory workspace: I am a PLAIN member (no owner
/// or admin role — the directory and its settings entry are open to
/// everyone). Anna is checked in on seat A1, Ben is online and shares
/// WhatsApp, Cara has a reservation later today, Dora was last seen ~2 h
/// ago, Eve was never seen, Paula is paused (hidden).
({
  FakeWorkspaceRepository workspace,
  FakeReservationRepository reservations,
  FakeFloorPlanRepository floorPlan,
  FakeProfileRepository profile,
}) _seed() {
  final now = DateTime.now();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..myMember = _member(1)
    ..otherMembers.addAll([
      _member(2),
      _member(3),
      _member(4),
      _member(5),
      _member(6),
      _member(7, status: MemberStatus.paused),
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
    // Cara: active reservation still running today, not checked in.
    Reservation(
      id: 'res-cara',
      workspaceId: 'ws-1',
      seatId: 'seat-other',
      memberId: 'member-4',
      startsAt: now.subtract(const Duration(minutes: 5)),
      endsAt: now.add(const Duration(minutes: 30)),
      status: ReservationStatus.reserved,
    ),
  ]);

  final profile = FakeProfileRepository(profiles: [
    // My own lastSeenAt is stamped "now" by the presence heartbeat on app
    // start anyway (#223) — I render as Online.
    Profile(id: 'user-1', displayName: 'Flo', lastSeenAt: now),
    const Profile(id: 'user-2', displayName: 'Anna'),
    Profile(
      id: 'user-3',
      displayName: 'Ben',
      whatsapp: '+491701234567',
      lastSeenAt: now.subtract(const Duration(minutes: 1)),
    ),
    const Profile(id: 'user-4', displayName: 'Cara'),
    Profile(
      id: 'user-5',
      displayName: 'Dora',
      lastSeenAt: now.subtract(const Duration(hours: 2, minutes: 5)),
    ),
    // user-6 (Eve) has no profile row at all: never seen.
  ]);

  return (
    workspace: workspace,
    reservations: reservations,
    floorPlan: floorPlan,
    profile: profile,
  );
}

/// Pumps the app signed in, opens settings and navigates into the
/// directory via its settings tile (kept as an every-member discovery
/// entry point; since #230 it switches to the Members shell tab).
Future<void> _pumpDirectory(
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
          workspace: workspace,
          reservations: reservations,
          floorPlan: floorPlan,
          profile: profile,
        ),
        devModeStoreProvider.overrideWithValue(_InMemoryDevModeStore()),
        if (linkLauncher != null)
          linkLauncherProvider.overrideWithValue(linkLauncher),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();

  // The entry is in the personal section and needs no role: the plain
  // member sees it while the owner-only management entry is absent.
  expect(find.text('Members'), findsOneWidget);
  expect(find.text('Members & plans'), findsNothing);

  await tester.tap(find.text('Members'));
  await tester.pumpAndSettle();
}

/// Text of the status chip on [memberId]'s row.
String? _chipText(WidgetTester tester, String memberId) {
  final chip = find.byKey(ValueKey('directory-status-$memberId'));
  if (chip.evaluate().isEmpty) return null;
  return tester
      .widget<Text>(find.descendant(of: chip, matching: find.byType(Text)))
      .data;
}

void main() {
  testWidgets(
      'active members list alphabetically with one status chip each, '
      'in checked-in > online > reserved-today > offline priority',
      (tester) async {
    final seeded = _seed();
    await _pumpDirectory(
      tester,
      workspace: seeded.workspace,
      reservations: seeded.reservations,
      floorPlan: seeded.floorPlan,
      profile: seeded.profile,
    );

    // One chip per member, resolved by priority.
    expect(_chipText(tester, 'member-2'), 'Checked in · A1');
    expect(_chipText(tester, 'member-3'), 'Online');
    expect(_chipText(tester, 'member-4'), 'Reserved today');
    expect(_chipText(tester, 'member-5'), '2 h');
    // Never seen: no chip at all.
    expect(_chipText(tester, 'member-6'), isNull);
    expect(find.text('Eve'), findsOneWidget);
    // Myself: the heartbeat stamped me just now — Online.
    expect(_chipText(tester, 'member-1'), 'Online');

    // Paused members stay out of the directory.
    expect(find.text('Paula'), findsNothing);

    // Checked-in is the filled success chip; online is outlined success.
    final checkedIn = tester.widget<Container>(
      find.byKey(const ValueKey('directory-status-member-2')),
    );
    final checkedInDeco = checkedIn.decoration! as BoxDecoration;
    expect(checkedInDeco.color, AppStatusColors.success);
    final online = tester.widget<Container>(
      find.byKey(const ValueKey('directory-status-member-3')),
    );
    final onlineDeco = online.decoration! as BoxDecoration;
    expect(onlineDeco.color, isNull);
    expect(
      (onlineDeco.border! as Border).top.color,
      AppStatusColors.success,
    );

    // Alphabetical by display name.
    final order = ['Anna', 'Ben', 'Cara', 'Dora', 'Eve', 'Flo'];
    final ys = [for (final name in order) tester.getTopLeft(find.text(name)).dy];
    expect(ys, List.of(ys)..sort());
  });

  testWidgets(
      'the WhatsApp button appears only for the sharing member and opens '
      'wa.me through the link seam', (tester) async {
    final seeded = _seed();
    final launched = <Uri>[];
    await _pumpDirectory(
      tester,
      workspace: seeded.workspace,
      reservations: seeded.reservations,
      floorPlan: seeded.floorPlan,
      profile: seeded.profile,
      linkLauncher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    // Only Ben shared a number.
    expect(find.byTooltip('Chat on WhatsApp'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('directory-wa-member-3')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('directory-wa-member-3')));
    await tester.pumpAndSettle();

    expect(launched.single.toString(), 'https://wa.me/491701234567');
  });

  testWidgets('no active members renders the EmptyState', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..myMember = _member(1, status: MemberStatus.paused)
      ..memberNames = {'member-1': 'Flo'};
    await _pumpDirectory(tester, workspace: workspace);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No members yet.'), findsOneWidget);
  });
}
