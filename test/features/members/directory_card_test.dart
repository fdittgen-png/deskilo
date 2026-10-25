// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what a directory row and the profile sheet show, as a table on
// DirectoryCard's facts: role label, presence and reservation chips,
// the avatar dot, the on-site card, WhatsApp, and when a subtitle exists.
import 'package:deskilo/features/members/application/directory_card.dart';
import 'package:deskilo/features/members/domain/directory_status.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 10, 10, 30);

Member _member({bool owner = false, bool admin = false}) => Member(
      id: 'm1',
      workspaceId: 'ws-1',
      userId: 'u1',
      isAdmin: admin,
      isOwner: owner,
      status: MemberStatus.active,
    );

final _reservation = Reservation(
  id: 'r1',
  workspaceId: 'ws-1',
  seatId: 'seat-1',
  memberId: 'm1',
  startsAt: _now.subtract(const Duration(hours: 1)),
  endsAt: _now.add(const Duration(hours: 1)),
  status: ReservationStatus.checkedIn,
);

DirectoryCard _card({
  Member? member,
  String email = '',
  bool isSelf = false,
  Profile? profile,
  DateTime? lastSeenAt,
  ReservationInfo? info,
}) =>
    DirectoryCard(
      member: member ?? _member(),
      name: 'Ada',
      email: email,
      isSelf: isSelf,
      profile: profile,
      presence: resolveDirectoryPresence(
        lastSeenAt: lastSeenAt,
        now: _now,
        isSelf: isSelf,
      ),
      reservationInfo: info,
      memberReservations: const [],
      targetNames: const {'seat-1': 'A1'},
      now: _now,
    );

void main() {
  test('role: owner outranks admin, everyone else is a member', () {
    final cases = <(Member, DirectoryRole)>[
      (_member(owner: true, admin: true), DirectoryRole.owner),
      (_member(owner: true), DirectoryRole.owner),
      (_member(admin: true), DirectoryRole.admin),
      (_member(), DirectoryRole.member),
    ];
    for (final (member, role) in cases) {
      expect(_card(member: member).role, role, reason: '$member');
    }
  });

  test('chips, dot, on-site card and subtitle per facts', () {
    final cases = <({
      String name,
      DirectoryCard card,
      bool presence,
      bool reservation,
      bool online,
      bool onSite,
      bool subtitle,
    })>[
      (
        name: 'never seen, nothing else',
        card: _card(),
        presence: false,
        reservation: false,
        online: false,
        onSite: false,
        subtitle: false,
      ),
      (
        name: 'self is online',
        card: _card(isSelf: true),
        presence: true,
        reservation: false,
        online: true,
        onSite: false,
        subtitle: true,
      ),
      (
        name: 'seen an hour ago',
        card: _card(lastSeenAt: _now.subtract(const Duration(hours: 1))),
        presence: true,
        reservation: false,
        online: false,
        onSite: false,
        subtitle: true,
      ),
      (
        name: 'checked in',
        card: _card(info: CheckedInNow(_reservation)),
        presence: false,
        reservation: true,
        online: false,
        onSite: true,
        subtitle: true,
      ),
      (
        name: 'reserved, not checked in',
        card: _card(info: ReservedNow(_reservation)),
        presence: false,
        reservation: true,
        online: false,
        onSite: false,
        subtitle: true,
      ),
      (
        name: 'only an email',
        card: _card(email: 'ada@example.org'),
        presence: false,
        reservation: false,
        online: false,
        onSite: false,
        subtitle: true,
      ),
      (
        name: 'only a status line',
        card: _card(profile: const Profile(id: 'u1', statusText: 'Back at 2')),
        presence: false,
        reservation: false,
        online: false,
        onSite: false,
        subtitle: true,
      ),
    ];
    for (final c in cases) {
      expect(c.card.showsPresence, c.presence, reason: c.name);
      expect(c.card.showsReservation, c.reservation, reason: c.name);
      expect(c.card.online, c.online, reason: c.name);
      expect(c.card.onSite, c.onSite, reason: c.name);
      expect(c.card.hasSubtitle, c.subtitle, reason: c.name);
    }
  });

  test('WhatsApp, status and seat name come from the facts', () {
    expect(_card().whatsappUri, isNull);
    expect(_card().statusText, '');
    expect(_card().seatName, '');
    final shared =
        _card(profile: const Profile(id: 'u1', whatsapp: '+33612345678'));
    expect(shared.whatsappUri, Uri.https('wa.me', '/33612345678'));
    expect(_card(info: CheckedInNow(_reservation)).seatName, 'A1');
  });
}
