// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3964 (a) — the plan and booking features of the reference business, each
// as a seeded state read through the app's providers or an action a persona
// performs with its outcome asserted. Shared by the scenario checklist and
// the batch's own test.
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/plan/presentation/seat_occupancy.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/space_code.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';

import 'demo_assistant_journeys.dart';

/// Runs [checks] and says which of them failed, by name.
bool allHold(Map<String, bool> checks) {
  final failed = [
    for (final e in checks.entries)
      if (!e.value) e.key,
  ];
  if (failed.isNotEmpty) throw StateError('failed: $failed');
  return true;
}

/// The photo of Bruno, whom the wall tablet greets, is on his profile and in
/// the store the avatar is read from.
Future<bool> kioskPhotoState() => withOwnerSession((f, c) async {
  final profiles = await c.read(memberProfilesProvider.future);
  final userId = f.reservations.kioskUserId;
  return allHold({
    'a kiosk member': userId.isNotEmpty,
    'his profile has a photo': profiles[userId]?.hasAvatar ?? false,
    'the photo is stored': (f.profiles.avatarBytes[userId] ?? []).isNotEmpty,
  });
});

/// A seat of the plan is held by a member who has a photo, and the plan's own
/// occupancy read names that member for the seat.
Future<bool> planPhotoState() => withOwnerSession((f, c) async {
  final profiles = await c.read(memberProfilesProvider.future);
  final members = {
    for (final m in [f.workspaces.myMember, ...f.workspaces.otherMembers])
      m.id: m.userId,
  };
  var found = false;
  for (final level in await f.floorPlan.fetchLevels('ws-1')) {
    final plan = await f.floorPlan.fetchPlan(level.id);
    for (final r in f.reservations.reservations) {
      final seat = plan.seats.where((s) => s.id == r.seatId).firstOrNull;
      if (seat == null || r.status == ReservationStatus.cancelled) continue;
      final held = occupantOnSeat(
        plan: plan,
        seat: seat,
        reservations: f.reservations.reservations,
        from: r.startsAt,
        to: r.endsAt,
      );
      if (held != null &&
          (profiles[members[held.memberId]]?.hasAvatar ?? false)) {
        found = true;
      }
    }
  }
  return allHold({'a held seat with a photo on the plan': found});
});

/// The ground floor carries drawn decor: a couch and a table under its seats.
Future<bool> planDecorState() async {
  final f = DemoFixture.build();
  final plan = await f.floorPlan.fetchPlan('level-1');
  final kinds = {for (final i in plan.images) i.kind};
  return allHold({
    'decor on the level': plan.images.length >= 2,
    'a couch and a table': kinds.length >= 2 && !kinds.contains(null),
  });
}

/// Ada deletes a drawn object: it is gone from the plan, and the seats stay.
Future<bool> planDeleteAction() async {
  final f = DemoFixture.build();
  final before = await f.floorPlan.fetchPlan('level-1');
  final target = before.images.first;
  await f.floorPlan.deletePlanImage(target.id);
  final after = await f.floorPlan.fetchPlan('level-1');
  return allHold({
    'it was there': before.images.any((i) => i.id == target.id),
    'it is gone': !after.images.any((i) => i.id == target.id),
    'one fewer': after.images.length == before.images.length - 1,
    'the seats stay': after.seats.length == before.seats.length,
  });
}

/// A place's QR code, read back, brings the member to that place.
Future<bool> spaceQrAction() async {
  final f = DemoFixture.build();
  final checks = <String, bool>{};
  for (final level in await f.floorPlan.fetchLevels('ws-1')) {
    final plan = await f.floorPlan.fetchPlan(level.id);
    for (final seat in plan.seats.take(1)) {
      final payload = SpaceCodeCodec.encode(
        workspaceId: 'ws-1',
        kind: SpaceKind.seat,
        id: seat.id,
      );
      final code = SpaceCodeCodec.decode(payload);
      final context = code == null
          ? null
          : await f.floorPlan.fetchSeatContext(code.id);
      checks['${level.name}: decoded'] = code?.id == seat.id;
      checks['${level.name}: arrives on its level'] =
          context?.levelName == level.name;
    }
  }
  checks['a foreign code is not a place'] =
      SpaceCodeCodec.decode('https://x.test') == null;
  return allHold(checks);
}

/// The working day of the reference business is eight to six, an hour longer
/// than the product's, read as the workspace context reads it.
Future<bool> workingHoursState() async {
  final f = DemoFixture.build();
  final space = f.workspaces.workspaces.firstWhere((w) => w.id == 'ws-1');
  // The calendar the workspace context is made of, read as the app reads it.
  final hours = (await captureWorkspaceCalendar(
    f.workspaces,
    'ws-1',
    space.timezone,
  )).workHours;
  return allHold({
    'starts at eight': hours.startMinutes == 8 * 60,
    'ends at six': hours.endMinutes == 18 * 60,
    'longer than the product\'s day':
        hours.endMinutes > WorkHours.defaults.endMinutes,
    'valid': hours.isValid,
  });
}

/// The ground floor has one room only: members see it by the level's name.
Future<bool> singleRoomState() async {
  final f = DemoFixture.build();
  final plan = await f.floorPlan.fetchPlan('level-1');
  final level = (await f.floorPlan.fetchLevels('ws-1'))
      .firstWhere((l) => l.id == 'level-1');
  return allHold({
    'one room': plan.offices.length == 1,
    'the level is named': level.name.isNotEmpty,
    'the room has a name of its own': plan.offices.single.name.isNotEmpty,
  });
}

/// The workspace's booking rules, read through the provider.
Future<bool> bookingPoliciesState() => withOwnerSession((f, c) async {
  final p = await c.read(bookingPoliciesProvider.future);
  return allHold({
    'two places at once': p.simultaneousReservations == 2,
    'no booking longer than ten hours': p.maxDurationMinutes == 600,
    'outside hours: walk-up only':
        p.outsideHoursMode == OutsideHoursMode.walkupOnly,
  });
});

/// The same booking is found in the day, the week and the month of the
/// calendar.
Future<bool> calendarViewsAction() async {
  final f = DemoFixture.build();
  final day = DateTime.utc(f.seededAt.year, f.seededAt.month, f.seededAt.day);
  Future<Set<String>> ids(DateTime from, DateTime to) async => {
    for (final i in (await f.calendar.fetchItems(
      'ws-1',
      CalendarQuery(from: from, to: to, memberId: 'member-2'),
    )).items.where((i) => i.kind == CalendarKind.reservation))
      i.id,
  };
  final inDay = await ids(day, day.add(const Duration(days: 8)));
  final week = await ids(day, day.add(const Duration(days: 7)));
  final month = await ids(
    DateTime.utc(day.year, day.month),
    DateTime.utc(day.year, day.month + 1),
  );
  final one = week.isEmpty ? null : week.first;
  return allHold({
    'a booking this week': one != null,
    'in the wider window': one != null && inDay.contains(one),
    'in the month': one != null && month.contains(one),
  });
}

/// A member writes in a space thread, a screenshot of it is taken, and the
/// thread says so.
Future<bool> captureAction() async {
  final f = DemoFixture.build();
  await f.messenger.sendSpaceMessage('conv-capture', 'a note for the team');
  await f.messenger.recordScreenCapture(
    MessageContextKind.space,
    'conv-capture',
  );
  final thread = await f.messenger.spaceMessages('conv-capture');
  return allHold({
    'two entries': thread.length == 2,
    'the newest says a capture was taken':
        thread.first.notice?.kind == NoticeKind.captured,
    'it was recorded': f.messenger.captures.contains('conv-capture'),
  });
}
