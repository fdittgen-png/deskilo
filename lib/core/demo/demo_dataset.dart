// SPDX-License-Identifier: 0BSD
//
// #1374 — the people, rooms, bookings and bills a visitor explores.
//
// One cast, consistent across every screen: the person whose booking is
// on the plan is the person on the invoice and the person whose request
// is waiting for a decision. Small on purpose — five people and a
// handful of records tell a story; two hundred tell none — and every
// value is obviously fictional, so a screenshot is safe to publish.
//
// Everything is placed relative to [DemoFixture.seededAt], never to a
// literal date, so a demo opened next year still shows a booking for
// today (ADR 0028).
import '../../features/plan/domain/seat.dart';
import '../../features/events/domain/workspace_event.dart';
import '../../features/money/domain/invoice.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/workspace/domain/member.dart';
import 'data/event_repository.dart';
import 'data/floor_plan_repository.dart';
import 'data/money_repository.dart';
import 'data/reservation_repository.dart';
import 'data/workspace_repository.dart';

/// The cast. Ids are stable so a story can be told about them in tests
/// and in the guides.
class DemoPerson {
  const DemoPerson({
    required this.memberId,
    required this.userId,
    required this.name,
    required this.subscriptionPct,
    this.status = MemberStatus.active,
    this.isAdmin = false,
    this.isOwner = false,
  });

  final String memberId;
  final String userId;
  final String name;
  final int subscriptionPct;
  final MemberStatus status;
  final bool isAdmin;
  final bool isOwner;
}

/// Five people, each with a reason to exist on screen.
const demoCast = <DemoPerson>[
  // The visitor: an owner, so every administrative surface has something
  // to show. Her own booking is today's.
  DemoPerson(
    memberId: 'member-1',
    userId: 'user-1',
    name: 'Ada Lindqvist',
    subscriptionPct: 100,
    isAdmin: true,
    isOwner: true,
  ),
  // A half-time member with an unpaid bill: the money screens need
  // somebody who owes something, and the dunning rules need a target.
  DemoPerson(
    memberId: 'member-2',
    userId: 'user-2',
    name: 'Bruno Kessler',
    subscriptionPct: 50,
  ),
  // Checked in right now, so the plan shows an occupied seat — and an
  // administrator, which is the Admin persona of #1376: somebody who
  // runs the day without owning the space.
  DemoPerson(
    memberId: 'member-3',
    userId: 'user-3',
    name: 'Chiara Rossi',
    subscriptionPct: 100,
    isAdmin: true,
  ),
  // Waiting to be admitted: the decision surfaces need a decision.
  DemoPerson(
    memberId: 'member-4',
    userId: 'user-4',
    name: 'Dov Meir',
    subscriptionPct: 50,
    status: MemberStatus.pending,
  ),
  // Paused: a status that is neither active nor gone, which the members
  // screen must render honestly.
  DemoPerson(
    memberId: 'member-5',
    userId: 'user-5',
    name: 'Elise Fontaine',
    subscriptionPct: 100,
    status: MemberStatus.paused,
  ),
];

/// Seeds [workspaces] with the cast.
void seedDemoPeople(FakeWorkspaceRepository workspaces) =>
    seedDemoPeopleAs(workspaces, demoCast.first);

/// Seeds the cast with [me] as the signed-in member (#1376).
///
/// The visitor is one of the cast rather than a sixth invisible person,
/// so a persona has real bookings, real bills and a place on the plan.
/// Everybody else is in `otherMembers`, which is what the directory,
/// the plan and the money screens read.
void seedDemoPeopleAs(FakeWorkspaceRepository workspaces, DemoPerson me) {
  Member memberOf(DemoPerson person) => Member(
        id: person.memberId,
        workspaceId: 'ws-1',
        userId: person.userId,
        isAdmin: person.isAdmin,
        isOwner: person.isOwner,
        status: person.status,
        subscriptionPct: person.subscriptionPct,
      );

  workspaces.myMember = memberOf(me);
  workspaces.otherMembers
    ..clear()
    ..addAll([
      for (final person in demoCast)
        if (person.memberId != me.memberId) memberOf(person),
    ]);
}

/// Seeds bookings around [now]: one finished yesterday, one happening
/// today, one next week — the three states the Reserve screens show.
/// #1378 — a demonstration plan a visitor can book on.
///
/// `seedSmallPlan` gives one seat, and the dataset books it, so the first
/// journey the issue asks for — choose a seat and reserve it — had no
/// free seat to choose. The demo desk therefore seats four: enough that
/// the plan reads as a room in use, and enough that there is somewhere
/// to sit.
void seedDemoPlan(FakeFloorPlanRepository plan) {
  plan.seedSmallPlan();
  final first = plan.seats.single;
  for (var i = 1; i < 4; i++) {
    plan.seats.add(
      Seat(
        id: 'demo-seat-\$i',
        workspaceId: first.workspaceId,
        deskId: first.deskId,
        name: 'A\${i + 1}',
        x: first.x + i * 3,
        y: first.y,
        orientation: first.orientation,
        chair: first.chair,
        amenities: first.amenities,
      ),
    );
  }
}

void seedDemoReservations(
  FakeReservationRepository reservations,
  FakeFloorPlanRepository plan,
  DateTime now,
) {
  // The LAST seat, so the first one stays free: a visitor must be able to
  // book something on the plan they land on (#1378).
  final seatId = plan.seats.isEmpty ? 'seat-1' : plan.seats.last.id;
  final morning = DateTime(now.year, now.month, now.day, 9);
  reservations.reservations
    ..clear()
    ..addAll([
      Reservation(
        id: 'demo-past',
        workspaceId: 'ws-1',
        seatId: seatId,
        memberId: 'member-2',
        startsAt: morning.subtract(const Duration(days: 1)),
        endsAt: morning.subtract(const Duration(days: 1)).add(const Duration(hours: 8)),
        status: ReservationStatus.completed,
      ),
      Reservation(
        id: 'demo-today',
        workspaceId: 'ws-1',
        seatId: seatId,
        memberId: 'member-3',
        startsAt: morning,
        endsAt: morning.add(const Duration(hours: 8)),
        status: ReservationStatus.checkedIn,
      ),
      Reservation(
        id: 'demo-next-week',
        workspaceId: 'ws-1',
        seatId: seatId,
        memberId: 'member-1',
        startsAt: morning.add(const Duration(days: 7)),
        endsAt: morning.add(const Duration(days: 7, hours: 8)),
        status: ReservationStatus.reserved,
      ),
    ]);
}

/// Seeds last month's bills: Ada's settled, Bruno's still open. Two
/// invoices are enough for the archive, the statement and the reminder
/// rules to have something true to say.
/// #1378 — a decision waiting to be made.
///
/// The Events tab of an empty demo says "nothing to decide", which is the
/// one thing a demonstration of a validation workflow must not say. Dov
/// is the cast's pending member (#1374), so his own request to join is
/// the decision that is already there when a visitor arrives.
void seedDemoEvents(FakeEventRepository events, DateTime now) {
  events.events
    ..clear()
    ..add(
      WorkspaceEvent(
        id: 'demo-join-request',
        workspaceId: 'ws-1',
        type: EventType.memberJoin,
        action: EventAction.submitted,
        actorMemberId: 'member-4',
        subjectMemberId: 'member-4',
        payload: const {'reason': 'demo'},
        status: EventStatus.pending,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    );
}

void seedDemoMoney(FakeMoneyRepository money, DateTime now) {
  final lastMonth = DateTime(now.year, now.month - 1, 28);
  final period =
      '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';
  money.invoices
    ..clear()
    ..addAll([
      _demoInvoice(
        id: 'demo-invoice-ada',
        memberId: 'member-1',
        memberName: 'Ada Lindqvist',
        number: 'F-2026-0007',
        issuedAt: lastMonth,
        period: period,
        totalCents: 18000,
      ),
      _demoInvoice(
        id: 'demo-invoice-bruno',
        memberId: 'member-2',
        memberName: 'Bruno Kessler',
        number: 'F-2026-0008',
        issuedAt: lastMonth,
        period: period,
        totalCents: 9000,
      ),
    ]);
}

Invoice _demoInvoice({
  required String id,
  required String memberId,
  required String memberName,
  required String number,
  required DateTime issuedAt,
  required String period,
  required int totalCents,
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: memberId,
      number: number,
      issuedAt: issuedAt,
      period: period,
      title: period,
      // The line's label is the period itself: this file is pure Dart
      // and has no localizations, and an English sentence would read as
      // English in a French demo. A line a visitor can read in any
      // language is the honest choice here; prose belongs to the
      // journeys (#1378), which have a BuildContext.
      lines: [InvoiceLine(label: period, amountCents: totalCents)],
      totalCents: totalCents,
      currency: 'EUR',
      memberName: memberName,
      memberAddress: '',
      workspaceName: 'Test Space',
      workspaceAddress: '',
      issuerName: 'Ada Lindqvist',
      signature: 'demo',
    );

/// What is wrong with a seeded session, or nothing.
///
/// A fixture that points at a member or a seat that does not exist looks
/// fine until a screen opens it, so the session says so at build time
/// rather than on a visitor's screen (#1374).
List<String> validateDemoFixture({
  required FakeWorkspaceRepository workspaces,
  required FakeFloorPlanRepository plan,
  required FakeReservationRepository reservations,
  required FakeMoneyRepository money,
}) {
  final problems = <String>[];
  final memberIds = {
    workspaces.myMember.id,
    for (final m in workspaces.otherMembers) m.id,
  };
  final seatIds = {for (final s in plan.seats) s.id};

  for (final reservation in reservations.reservations) {
    if (!memberIds.contains(reservation.memberId)) {
      problems.add('reservation ${reservation.id}: no member '
          '${reservation.memberId}');
    }
    if (reservation.seatId != null && !seatIds.contains(reservation.seatId)) {
      problems.add('reservation ${reservation.id}: no seat '
          '${reservation.seatId}');
    }
    if (!reservation.endsAt.isAfter(reservation.startsAt)) {
      problems.add('reservation ${reservation.id}: ends before it starts');
    }
  }
  for (final invoice in money.invoices) {
    if (!memberIds.contains(invoice.memberId)) {
      problems.add('invoice ${invoice.number}: no member ${invoice.memberId}');
    }
    if (invoice.totalCents <= 0) {
      problems.add('invoice ${invoice.number}: nothing to pay');
    }
  }
  if (plan.seats.isEmpty) problems.add('the plan has no seat to book');
  if (memberIds.length < 2) problems.add('a space of one is not a space');
  return problems;
}
