// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#3314): the Demo's member statement keeps the server's rules
// (member_statement 0109/0208, 0237): a member reads their own statement and
// an admin or owner anyone's; the half-days are counted on the SPACE's clock,
// one per distinct day and half a reservation STARTS in, so a booking across
// noon counts its morning once; and half-days a credit covered are not billed
// as overage. Every expectation is stated by hand.
import 'package:deskilo/core/demo/data/credit_repository.dart';
import 'package:deskilo/core/demo/data/money/demo_member_statement.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

Reservation _booking(String id, DateTime startsUtc, DateTime endsUtc) => Reservation(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'member-2',
  startsAt: startsUtc,
  endsAt: endsUtc,
  status: ReservationStatus.reserved,
);

void main() {
  test('a member reads their own statement; another member\'s needs an admin '
      'or the owner', () async {
    final f = DemoFixture.build(now: DateTime(2026, 5, 13, 10));
    final members = [f.workspaces.myMember, ...f.workspaces.otherMembers];
    final plain = members.firstWhere((m) => !m.isAdmin && !m.isOwner);
    final other = members.firstWhere((m) => m.id != plain.id);
    final boss = members.firstWhere((m) => m.isAdmin || m.isOwner);

    f.actor.memberId = plain.id;
    expect(await f.money.fetchStatement(plain.id, '2026-05'), isNotNull);
    await expectLater(
      f.money.fetchStatement(other.id, '2026-05'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'not your statement')),
    );

    f.actor.memberId = boss.id;
    expect((await f.money.fetchStatement(plain.id, '2026-05')).period, '2026-05');
    expect((await f.money.fetchStatement(other.id, '2026-05')).period, '2026-05');
  });

  group('half-days on the space\'s clock, as member_statement counts them', () {
    // Auckland is UTC+13 in February (daylight time).
    final f = DemoFixture.build(now: DateTime(2027, 2, 15, 10));
    final i = f.workspaces.workspaces.indexWhere((w) => w.id == 'ws-1');
    f.workspaces.workspaces[i] =
        f.workspaces.workspaces[i].copyWith(timezone: 'Pacific/Auckland');
    final bookings = FakeReservationRepository()
      ..reservations.addAll([
        // 31 Jan 20:00 UTC = 1 Feb 09:00 in Auckland: February's morning,
        // though the device would call it January.
        _booking('across-zone', DateTime.utc(2027, 1, 31, 20), DateTime.utc(2027, 1, 31, 23)),
        // 1 Feb 10:00–15:00 Auckland (21:00–02:00 UTC): across noon, it
        // counts the morning it starts in — already counted above.
        _booking('across-noon', DateTime.utc(2027, 1, 31, 21), DateTime.utc(2027, 2, 1, 2)),
        // 1 Feb 13:00–17:00 Auckland: the afternoon.
        _booking('afternoon', DateTime.utc(2027, 2), DateTime.utc(2027, 2, 1, 4)),
      ]);
    final source = demoStatementSource(f.workspaces, bookings, 'ws-1', actor: () => 'member-1');

    test('February holds two half-days: the 1st\'s morning (twice booked, '
        'once counted) and its afternoon', () {
      expect(source.usedHalfDays('member-2', '2027-02'), 2);
    });

    test('January holds none, though every booking starts on 31 January in UTC', () {
      expect(source.usedHalfDays('member-2', '2027-01'), 0);
    });
  });

  test('half-days a credit covered are not billed as overage; a released use '
      'counts again', () {
    final f = DemoFixture.build(now: DateTime(2027, 2, 15, 10));
    final bookings = FakeReservationRepository()
      ..reservations.addAll([
        for (var d = 1; d <= 5; d++)
          _booking('b$d', DateTime.utc(2027, 2, d, 8), DateTime.utc(2027, 2, d, 10)),
      ]);
    final credits = FakeCreditRepository()
      ..uses.addAll([
        (reservationId: 'b1', halfDays: 1, releasedAt: null),
        (reservationId: 'b2', halfDays: 1, releasedAt: null),
        (reservationId: 'b3', halfDays: 1, releasedAt: DateTime(2027, 2, 3)),
      ]);
    final real = demoStatementSource(f.workspaces, bookings, 'ws-1',
        actor: () => 'member-1', credits: credits);
    expect(real.usedHalfDays('member-2', '2027-02'), 5);
    expect(real.creditHalfDays('member-2', '2027-02'), 2);

    // One open day at 100 %: two half-days included, 10.00 a half-day over.
    f.money.feeBands
      ..clear()
      ..add(const FeeBand(
        id: 'b', workspaceId: 'ws-1', fromPct: 0, toPct: 100,
        feeCents: 20000, overageFeeCents: 1000,
      ));
    final source = (
      member: real.member,
      caller: real.caller,
      openDays: (String _) => 1,
      usedHalfDays: real.usedHalfDays,
      creditHalfDays: real.creditHalfDays,
    );
    final member = f.workspaces.otherMembers.firstWhere((m) => m.id == 'member-2');
    final pct = member.subscriptionPct;
    final included = (2 * pct / 100).ceil();
    // 5 used − included − 2 covered by credits.
    final st = demoMemberStatement(f.money, source, 'member-2', '2027-02');
    expect(st.extraHalfDays, (5 - included - 2).clamp(0, 5));
    expect(st.overageCents, st.extraHalfDays * 1000);
    expect(st.extraHalfDays, lessThan(5 - included),
        reason: 'the two credit-covered half-days are not overage');
  });
}
