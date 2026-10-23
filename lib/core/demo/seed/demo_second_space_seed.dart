// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's second space: a small coworking in Leipzig that started the
// way a new space starts — core features only, no VAT, no accounting book,
// no purchases. Ada (the owner at home) opened it with Jonas and holds it
// as co-owner, so the demo's owner persona can walk its setup; Bruno is an
// ordinary member here. That is what Me is for: one person, several spaces,
// one place to see them all — the spaces, what each one waits for, and
// what is owed in each.
//
// Ada and Bruno keep the member ids they have at home. On a server every
// membership row has its own id; the in-memory repositories key the person
// a session acts as by that id, so one id per person keeps a booking or a
// request made in Leipzig attributed to the same persona without a second
// actor. Nothing in the demo compares member ids across spaces.
import '../../../features/plan/domain/desk.dart';
import '../../../features/plan/domain/grid_geometry.dart';
import '../../../features/plan/domain/level.dart';
import '../../../features/plan/domain/office.dart';
import '../../../features/plan/domain/seat.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../../../features/workspace/domain/closure_day.dart';
import '../../../features/workspace/domain/conversation.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/member_note.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_document.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/floor_plan_repository.dart';
import '../data/reservation_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_clock.dart';
import '../demo_dataset.dart';
import 'demo_flags.dart';

const demoSecondSpaceId = 'ws-2';
const demoSecondSpaceName = 'Kontorhaus Plagwitz';
const demoSecondSpaceAddress = 'Am Kanal 7\n04229 Leipzig';

/// Ids the bookings, the tests and the guides tell stories about.
abstract final class _Leipzig {
  static const ground = 'de-level-ground';
  static const gallery = 'de-level-gallery';
  static const hall = 'de-office-hall';
  static const galleryRoom = 'de-office-gallery';
  static const longTable = 'de-desk-long';
  static const window = 'de-desk-window';
  static const hallSeats = [
    'de-seat-b1',
    'de-seat-b2',
    'de-seat-b3',
    'de-seat-b4',
  ];
  static const gallerySeats = ['de-seat-g1', 'de-seat-g2'];
}

/// The people of the Leipzig space: its owner, two locals, and the two
/// people of the demo's main space who also work here.
const demoSecondCast = <DemoPerson>[
  DemoPerson(
    memberId: 'de-member-jonas',
    userId: 'user-de-jonas',
    name: 'Jonas Becker',
    subscriptionPct: 100,
    isAdmin: true,
    isOwner: true,
    email: 'jonas.becker@example.test',
  ),
  DemoPerson(
    memberId: 'de-member-lena',
    userId: 'user-de-lena',
    name: 'Lena Hoffmann',
    subscriptionPct: 100,
    email: 'lena.hoffmann@example.test',
  ),
  DemoPerson(
    memberId: 'de-member-mehmet',
    userId: 'user-de-mehmet',
    name: 'Mehmet Kaya',
    subscriptionPct: 50,
    email: 'mehmet.kaya@example.test',
  ),
  // Ada works from Leipzig on a half-time membership.
  DemoPerson(
    memberId: 'member-1',
    userId: 'user-1',
    name: 'Ada Lindqvist',
    subscriptionPct: 50,
    email: 'ada.lindqvist@example.test',
  ),
  // Bruno comes by now and then and pays per use.
  DemoPerson(
    memberId: 'member-2',
    userId: 'user-2',
    name: 'Bruno Kessler',
    subscriptionPct: 0,
    email: 'bruno.kessler@example.test',
  ),
];

/// The Leipzig space as its owner set it up: German, in euros, small
/// business exempt from VAT, with the features a new space starts with.
Workspace demoSecondSpace() => Workspace(
  id: demoSecondSpaceId,
  rolePermissions: everydayMatrix(),
  name: demoSecondSpaceName,
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'KONTOR2026',
  featureFlags: demoSecondSpaceFeatureFlags,
  environment: 'prod',
  address: demoSecondSpaceAddress,
  street: 'Am Kanal 7',
  postalCode: '04229',
  city: 'Leipzig',
  vatRegime: 'exempt',
  taxExemptionReason: 'Kleinunternehmer gemäß § 19 UStG',
  legalId: 'HRB 40217',
  branding: const {
    'seed_color': '#B45309',
    'pattern': 'dots',
    'symbol_text': 'KP',
    'symbol_color': '#B45309',
  },
);

Member _rowOf(DemoPerson person) => Member(
  id: person.memberId,
  workspaceId: demoSecondSpaceId,
  userId: person.userId,
  isAdmin: person.isAdmin,
  isOwner: person.isOwner,
  status: person.status,
  subscriptionPct: person.subscriptionPct,
);

/// The memberships, names and e-mails of the Leipzig space, seen by
/// Ada; a persona switch moves the "mine" pointer (`DemoSecondSpaceData`).
void seedLeipzigPeople(FakeWorkspaceRepository space) {
  final rows = [
    for (final p in demoSecondCast)
      if (p.memberId == 'member-1')
        _rowOf(p).copyWith(coOwner: CoOwnerStatus.active)
      else
        _rowOf(p),
  ];
  space
    ..myMember = rows.firstWhere((m) => m.id == 'member-1')
    ..memberNames = {for (final p in demoSecondCast) p.memberId: p.name}
    ..memberEmails = {for (final p in demoSecondCast) p.memberId: p.email}
    ..otherMembers.addAll(rows.where((m) => m.id != 'member-1'));
}

/// Two floors: the hall with its long table, and a gallery by the window.
void seedLeipzigPlan(FakeFloorPlanRepository plan) {
  const ws = demoSecondSpaceId;
  plan.levels.addAll(const [
    Level(
      id: _Leipzig.ground,
      workspaceId: ws,
      name: 'Erdgeschoss',
      sortOrder: 0,
    ),
    Level(
      id: _Leipzig.gallery,
      workspaceId: ws,
      name: 'Galerie',
      sortOrder: 1,
    ),
  ]);
  plan.offices.addAll(const [
    Office(
      id: _Leipzig.hall,
      workspaceId: ws,
      levelId: _Leipzig.ground,
      name: 'Werkhalle',
      color: 3,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 30, h: 20),
    ),
    Office(
      id: _Leipzig.galleryRoom,
      workspaceId: ws,
      levelId: _Leipzig.gallery,
      name: 'Fensterplätze',
      color: 5,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 20, h: 12),
    ),
  ]);
  plan.desks.addAll(const [
    Desk(
      id: _Leipzig.longTable,
      workspaceId: ws,
      officeId: _Leipzig.hall,
      name: 'Langer Tisch',
      rect: GridRect(x: 2, y: 2, w: 4 * SeatFootprint.length, h: 4),
    ),
    Desk(
      id: _Leipzig.window,
      workspaceId: ws,
      officeId: _Leipzig.galleryRoom,
      name: 'Fenstertisch',
      rect: GridRect(x: 2, y: 2, w: 2 * SeatFootprint.length, h: 4),
    ),
  ]);
  void seats(String desk, List<String> ids, String prefix) {
    for (final (i, id) in ids.indexed) {
      plan.seats.add(
        Seat(
          id: id,
          workspaceId: ws,
          deskId: desk,
          name: '$prefix${i + 1}',
          x: 2 + i * SeatFootprint.length,
          y: 2,
          orientation: SeatOrientation.n,
          chair: 'standard',
          amenities: const ['monitor'],
        ),
      );
    }
  }

  seats(_Leipzig.longTable, _Leipzig.hallSeats, 'B');
  seats(_Leipzig.window, _Leipzig.gallerySeats, 'G');
}

/// Bookings around [now]: Ada's desk today (to check in at), Lena already
/// in, Bruno on Friday, Ada next week, and two finished ones.
void seedLeipzigBookings(FakeReservationRepository reservations, DateTime now) {
  final day = demoDateOf(now);
  DateTime at(int offset, int hour) =>
      demoAt(day.year, day.month, day.day + offset, hour);
  Reservation booking(
    String id,
    String member,
    String seat,
    int offset,
    int from,
    int to, {
    ReservationStatus status = ReservationStatus.reserved,
  }) {
    final starts = at(offset, from);
    final ends = at(offset, to);
    final done = status == ReservationStatus.completed;
    return Reservation(
      id: id,
      workspaceId: demoSecondSpaceId,
      seatId: seat,
      memberId: member,
      startsAt: starts,
      endsAt: ends,
      status: status,
      checkedInAt: status == ReservationStatus.checkedIn || done
          ? starts
          : null,
      checkedOutAt: done ? ends : null,
    );
  }

  const hall = _Leipzig.hallSeats;
  reservations.reservations
    ..clear()
    ..addAll([
      booking('de-ada-today', 'member-1', hall[0], 0, 10, 17),
      booking(
        'de-lena-today',
        'de-member-lena',
        hall[3],
        0,
        9,
        18,
        status: ReservationStatus.checkedIn,
      ),
      booking('de-bruno-friday', 'member-2', hall[1], 2, 9, 13),
      booking(
        'de-ada-next-week',
        'member-1',
        _Leipzig.gallerySeats[0],
        8,
        9,
        17,
      ),
      booking(
        'de-mehmet-yesterday',
        'de-member-mehmet',
        hall[2],
        -1,
        9,
        17,
        status: ReservationStatus.completed,
      ),
      booking(
        'de-ada-last-week',
        'member-1',
        hall[0],
        -7,
        9,
        17,
        status: ReservationStatus.completed,
      ),
    ]);
}

/// Saxony's fixed public holidays, last year to next, the house rules,
/// and the welcome thread Jonas wrote to Ada.
void seedLeipzigSpaceLife(FakeWorkspaceRepository space, DateTime now) {
  const fixed = [(1, 1), (5, 1), (10, 3), (10, 31), (12, 25), (12, 26)];
  for (var y = now.year - 1; y <= now.year + 1; y++) {
    for (final (m, d) in fixed) {
      space.closureDays.add(
        ClosureDay(
          id: 'de-holiday-$y-$m-$d',
          workspaceId: demoSecondSpaceId,
          day: DateTime(y, m, d),
          reason: 'Feiertag',
        ),
      );
    }
  }
  space.documents.addAll(const [
    WorkspaceDocument(
      id: 'de-doc-hausordnung',
      workspaceId: demoSecondSpaceId,
      title: 'Hausordnung',
      category: 'statutes',
      url: 'https://example.test/kontorhaus/hausordnung.pdf',
    ),
    WorkspaceDocument(
      id: 'de-doc-wlan',
      workspaceId: demoSecondSpaceId,
      title: 'WLAN und Drucker',
      category: 'guides',
      url: 'https://example.test/kontorhaus/wlan.pdf',
    ),
  ]);
  _seedWelcomeThread(space, now);
}

void _seedWelcomeThread(FakeWorkspaceRepository space, DateTime now) {
  MemberNote note(
    String id,
    String from,
    String to,
    String body,
    int hoursAgo, {
    bool read = true,
  }) => MemberNote(
    id: id,
    workspaceId: demoSecondSpaceId,
    fromMemberId: from,
    toMemberId: to,
    body: body,
    createdAt: now.subtract(Duration(hours: hoursAgo)),
    readAt: read ? now.subtract(Duration(hours: hoursAgo - 1)) : null,
    conversationId: 'de-conv-jonas',
  );
  final thread = [
    note(
      'de-msg-1',
      'member-1',
      'de-member-jonas',
      'Hallo Jonas, ich bin heute ab zehn Uhr am langen Tisch.',
      20,
    ),
    note(
      'de-msg-2',
      'de-member-jonas',
      'member-1',
      'Willkommen zurück! Dein Schlüssel liegt am Empfang.',
      1,
      read: false,
    ),
  ];
  space.conversations.add(
    Conversation(
      id: 'de-conv-jonas',
      kind: ConversationKind.direct,
      lastAt: thread.last.createdAt,
      otherMemberId: 'de-member-jonas',
      lastBody: thread.last.body,
      lastFromMemberId: 'de-member-jonas',
      unread: 1,
      participantCount: 2,
    ),
  );
  space.conversationMessages['de-conv-jonas'] = thread;
  space.memberNotes.addAll(thread);
}
