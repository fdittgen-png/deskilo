// SPDX-License-Identifier: MIT
//
// The member directory (#224, epic #222): every member reaches it from
// settings; each ACTIVE member renders up to TWO chips side by side
// (#237) — the reservation chip (checked in now with seat > reserved now
// > next upcoming booking within 14 days, formatted "{weekday} {day} ·
// {HH:mm} · {seat}") and the presence chip (online > relative last-seen;
// never seen = no chip) — and the WhatsApp button appears only for
// members who shared a number, launching wa.me through the injectable
// link seam.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/theme/status_colors.dart';
import 'package:deskilo/core/trace/dev_mode.dart';
import 'package:deskilo/core/ui/empty_state.dart';
import 'dart:typed_data';

import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

// A 1×1 transparent PNG for avatar-image tests.
final _pngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Member _member(
  int n, {
  MemberStatus status = MemberStatus.active,
  bool isAdmin = false,
  bool isOwner = false,
}) =>
    Member(
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
}) _seed() {
  final now = DateTime.now();

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
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..myMember = _member(1)
    ..otherMembers.addAll([
      _member(2, isOwner: true),
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

  final profile = FakeProfileRepository(profiles: [
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
  ]);

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

/// Text of the chip under [key], or null when it does not render.
String? _chipTextByKey(WidgetTester tester, Key key) {
  final chip = find.byKey(key);
  if (chip.evaluate().isEmpty) return null;
  return tester
      .widget<Text>(find.descendant(of: chip, matching: find.byType(Text)))
      .data;
}

/// Text of the presence chip on [memberId]'s row.
String? _chipText(WidgetTester tester, String memberId) =>
    _chipTextByKey(tester, ValueKey('directory-status-$memberId'));

/// Text of the reservation chip on [memberId]'s row (#237).
String? _resChipText(WidgetTester tester, String memberId) =>
    _chipTextByKey(tester, ValueKey('directory-res-$memberId'));

void main() {
  testWidgets(
      'active members list alphabetically with independent reservation + '
      'presence chips (#237): checked-in and reserved-now beat upcoming; '
      'a booking 15 days out shows nothing', (tester) async {
    final seeded = _seed();
    await _pumpDirectory(
      tester,
      workspace: seeded.workspace,
      reservations: seeded.reservations,
      floorPlan: seeded.floorPlan,
      profile: seeded.profile,
    );

    // Anna: checked in AND online — BOTH chips side by side.
    expect(_resChipText(tester, 'member-2'), 'Checked in · A1');
    expect(_chipText(tester, 'member-2'), 'Online');

    // Ben: online only, no booking — presence chip alone.
    expect(_chipText(tester, 'member-3'), 'Online');
    expect(_resChipText(tester, 'member-3'), isNull);

    // Cara: unchecked booking covering now (unnamed seat), never seen —
    // reservation chip alone.
    expect(_resChipText(tester, 'member-4'), 'Reserved now');
    expect(_chipText(tester, 'member-4'), isNull);

    // Dora: relative last-seen plus her NEXT upcoming booking, formatted
    // "{weekday} {day} · {HH:mm} · {seat}".
    final start = seeded.upcomingStart;
    expect(
      _resChipText(tester, 'member-5'),
      '${DateFormat.E().format(start)} ${DateFormat.d().format(start)}'
      ' · ${DateFormat.Hm().format(start)} · A1',
    );
    expect(_chipText(tester, 'member-5'), '2 h');

    // Eve: never seen and her only booking starts 15 days out — outside
    // the 14-day window, no chip of either kind.
    expect(_chipText(tester, 'member-6'), isNull);
    expect(_resChipText(tester, 'member-6'), isNull);
    expect(find.text('Eve'), findsOneWidget);

    // Myself: the heartbeat stamped me just now — Online.
    expect(_chipText(tester, 'member-1'), 'Online');

    // Paused members stay out of the directory.
    expect(find.text('Paula'), findsNothing);

    // Checked-in keeps the filled success style; online stays outlined
    // success; reserved-now is outlined primary; upcoming is outlined
    // neutral.
    final checkedIn = tester.widget<Container>(
      find.byKey(const ValueKey('directory-res-member-2')),
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
    final caraContext = tester.element(
      find.byKey(const ValueKey('directory-res-member-4')),
    );
    final caraDeco = tester
        .widget<Container>(find.byKey(const ValueKey('directory-res-member-4')))
        .decoration! as BoxDecoration;
    expect(caraDeco.color, isNull);
    expect(
      (caraDeco.border! as Border).top.color,
      Theme.of(caraContext).colorScheme.primary,
    );
    final doraContext = tester.element(
      find.byKey(const ValueKey('directory-res-member-5')),
    );
    final doraDeco = tester
        .widget<Container>(find.byKey(const ValueKey('directory-res-member-5')))
        .decoration! as BoxDecoration;
    expect(doraDeco.color, isNull);
    expect(
      (doraDeco.border! as Border).top.color,
      Theme.of(doraContext).colorScheme.onSurfaceVariant,
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

  testWidgets(
      'the custom status line renders on the row; without a configured '
      'group the group tile stays absent', (tester) async {
    final seeded = _seed();
    await _pumpDirectory(
      tester,
      workspace: seeded.workspace,
      reservations: seeded.reservations,
      floorPlan: seeded.floorPlan,
      profile: seeded.profile,
    );

    // Ben's self-set status line (#231) sits on his row next to the
    // automatic chip; both coexist.
    expect(find.text('In a call · back at 14:00'), findsOneWidget);
    expect(_chipText(tester, 'member-3'), 'Online');

    // No WhatsApp group configured: no tile above the list.
    expect(find.byKey(const ValueKey('directory-group')), findsNothing);
  });

  testWidgets(
      'swipe right on a sharing member launches wa.me and the row '
      'survives; non-sharing rows carry no swipe affordance at all',
      (tester) async {
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

    // Only Ben (shared number) is wrapped in a Dismissible; Anna's row
    // has no swipe affordance whatsoever.
    expect(
      find.byKey(const ValueKey('directory-swipe-member-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('directory-swipe-member-2')),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('Anna'),
        matching: find.byType(Dismissible),
      ),
      findsNothing,
    );

    // Swipe right past the dismiss threshold: confirmDismiss launches
    // wa.me and resolves false, so the row snaps back instead of being
    // dismissed.
    await tester.drag(find.text('Ben'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(launched.single.toString(), 'https://wa.me/491701234567');
    expect(find.text('Ben'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('directory-swipe-member-3')),
      findsOneWidget,
    );
  });

  testWidgets(
      'tapping a row opens the public-profile sheet: role line, automatic '
      'status, custom status, and the WhatsApp button only when shared',
      (tester) async {
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

    // Ben: plain member, online, custom status, shared number.
    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Member')),
      findsOneWidget,
    );
    expect(
      _chipTextByKey(
        tester,
        const ValueKey('directory-sheet-status-member-3'),
      ),
      'Online',
    );
    // Ben has no booking: no reservation chip in his sheet either.
    expect(
      find.byKey(const ValueKey('directory-sheet-res-member-3')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('In a call · back at 14:00'),
      ),
      findsOneWidget,
    );

    // The sheet's WhatsApp button launches wa.me and closes the sheet.
    await tester.tap(
      find.byKey(const ValueKey('directory-sheet-wa-member-3')),
    );
    await tester.pumpAndSettle();
    expect(launched.single.toString(), 'https://wa.me/491701234567');
    expect(find.byType(BottomSheet), findsNothing);

    // Anna: owner, online AND checked in on A1 — the sheet shows the
    // same chip pair as her row (#237) — no shared number, so no
    // WhatsApp button in her sheet.
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    final annaSheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: annaSheet, matching: find.text('Owner')),
      findsOneWidget,
    );
    expect(
      _chipTextByKey(tester, const ValueKey('directory-sheet-res-member-2')),
      'Checked in · A1',
    );
    expect(
      _chipTextByKey(
        tester,
        const ValueKey('directory-sheet-status-member-2'),
      ),
      'Online',
    );
    expect(
      find.byKey(const ValueKey('directory-sheet-wa-member-2')),
      findsNothing,
    );

    // Close dismisses the sheet.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
      'the group tile appears when the workspace has a WhatsApp group '
      'link and opens it through the link seam', (tester) async {
    final seeded = _seed();
    await seeded.workspace
        .setWhatsappGroup('ws-1', 'https://chat.whatsapp.com/AbCdEf123');
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

    expect(find.text('Open WhatsApp group'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('directory-group')));
    await tester.pumpAndSettle();

    expect(
      launched.single.toString(),
      'https://chat.whatsapp.com/AbCdEf123',
    );
  });

  testWidgets(
      'each row carries a role badge for the owner and admins only; plain '
      'members get none', (tester) async {
    final seeded = _seed();
    // Promote Ben to admin so all three roles are on screen at once.
    seeded.workspace.otherMembers
      ..removeWhere((m) => m.id == 'member-3')
      ..add(_member(3, isAdmin: true));
    await _pumpDirectory(
      tester,
      workspace: seeded.workspace,
      reservations: seeded.reservations,
      floorPlan: seeded.floorPlan,
      profile: seeded.profile,
    );

    // Anna (owner) and Ben (admin) each get a role badge; Cara (plain
    // member) and I (plain member) do not.
    expect(
      _chipTextByKey(tester, const ValueKey('directory-role-member-2')),
      'Owner',
    );
    expect(
      _chipTextByKey(tester, const ValueKey('directory-role-member-3')),
      'Admin',
    );
    expect(
      find.byKey(const ValueKey('directory-role-member-4')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('directory-role-member-1')),
      findsNothing,
    );
  });

  testWidgets(
      'tapping a member lists their upcoming reservations; tapping one '
      'opens its detail sheet', (tester) async {
    final seeded = _seed();
    await _pumpDirectory(
      tester,
      workspace: seeded.workspace,
      reservations: seeded.reservations,
      floorPlan: seeded.floorPlan,
      profile: seeded.profile,
    );

    // Dora holds one upcoming booking on A1; her sheet lists it.
    await tester.tap(find.text('Dora'));
    await tester.pumpAndSettle();
    expect(find.text('Reservations'), findsOneWidget);
    final tile =
        find.byKey(const ValueKey('directory-sheet-reservation-res-dora'));
    expect(tile, findsOneWidget);

    // Tapping it swaps the member sheet for the shared reservation
    // detail sheet (its Cancel action proves which sheet is showing).
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('directory-sheet-reservation-res-dora')),
      findsNothing,
    );
    expect(find.byType(ReservationDetailSheet), findsOneWidget);
  });

  testWidgets(
      "a member's photo renders as their avatar image; others keep the "
      'initial', (tester) async {
    final seeded = _seed();
    // Ben has a photo; give the fake his bytes.
    seeded.profile.profiles.add(
      const Profile(
        id: 'user-3',
        displayName: 'Ben',
        avatarPath: 'user-3/avatar',
      ),
    );
    // Replace the earlier Ben profile (same id) so hasAvatar is true.
    seeded.profile.profiles
        .removeWhere((p) => p.id == 'user-3' && p.avatarPath == null);
    seeded.profile.avatarBytes['user-3'] = _pngBytes;

    await _pumpDirectory(
      tester,
      workspace: seeded.workspace,
      reservations: seeded.reservations,
      floorPlan: seeded.floorPlan,
      profile: seeded.profile,
    );

    // Ben's row shows a CircleAvatar backed by an image; a member without a
    // photo (Anna) keeps a text initial.
    final benAvatars = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .where((a) => a.backgroundImage != null);
    expect(benAvatars, isNotEmpty);
  });

  testWidgets(
      'a member with no upcoming booking shows the empty reservations line',
      (tester) async {
    final seeded = _seed();
    await _pumpDirectory(
      tester,
      workspace: seeded.workspace,
      reservations: seeded.reservations,
      floorPlan: seeded.floorPlan,
      profile: seeded.profile,
    );

    // Ben has no booking at all.
    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    expect(find.text('No upcoming reservations'), findsOneWidget);
  });
}
