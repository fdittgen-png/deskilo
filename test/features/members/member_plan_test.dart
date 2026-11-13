// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — what the members' desk says about a plan comes from what is
// stored: the fee band's fee, "unavailable" where no band covers the share
// (never a guess), the statement's own parts for the estimate, and the last
// booking the member came to.
import 'package:deskilo/features/members/domain/member_plan.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

const _bands = [
  FeeBand(
    id: 'b1',
    workspaceId: 'ws',
    fromPct: 0,
    toPct: 50,
    feeCents: 9000,
    overageFeeCents: 1500,
  ),
  FeeBand(
    id: 'b2',
    workspaceId: 'ws',
    fromPct: 50,
    toPct: 80,
    feeCents: 15000,
    overageFeeCents: 1200,
  ),
];

Reservation _r(String id, String member, DateTime at, ReservationStatus s) =>
    Reservation(
      id: id,
      workspaceId: 'ws',
      memberId: member,
      seatId: 'seat',
      startsAt: at,
      endsAt: at.add(const Duration(hours: 4)),
      status: s,
    );

void main() {
  test('the plan fee is the covering band, else unavailable, none at 0', () {
    expect((planFeeOf(_bands, 50) as BandFee).cents, 9000);
    expect((planFeeOf(_bands, 51) as BandFee).cents, 15000);
    // 90 % lies above every band: no fee is made up for it.
    expect(planFeeOf(_bands, 90), isA<FeeUnavailable>());
    expect(planFeeOf(const [], 50), isA<FeeUnavailable>());
    expect(planFeeOf(_bands, 0), isA<NoPlan>());
  });

  test('a member is on the band covering their share, a kiosk on none', () {
    const m = Member(
      id: 'm',
      workspaceId: 'ws',
      userId: 'u',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.paused,
      subscriptionPct: 75,
    );
    expect(onBand(m, _bands[1]), isTrue);
    expect(onBand(m, _bands[0]), isFalse);
    expect(onBand(m.copyWith(isKiosk: true), _bands[1]), isFalse);
    expect(onBand(m.copyWith(status: MemberStatus.exited), _bands[1]), isFalse);
  });

  test('the last visit is the latest booking come to, not one ahead', () {
    final now = DateTime(2026, 11, 12, 12);
    final rows = [
      _r('1', 'a', DateTime(2026, 11, 3, 9), ReservationStatus.completed),
      _r('2', 'a', DateTime(2026, 11, 10, 9), ReservationStatus.checkedIn),
      _r('3', 'a', DateTime(2026, 11, 11, 9), ReservationStatus.cancelled),
      _r('4', 'a', DateTime(2026, 11, 20, 9), ReservationStatus.reserved),
      _r('5', 'b', DateTime(2026, 11, 11, 9), ReservationStatus.completed),
    ];
    expect(lastVisitOf('a', rows, now), DateTime(2026, 11, 10, 9));
    expect(lastVisitOf('c', rows, now), isNull);
  });

  test('the estimate is the statement\'s own parts and balance', () {
    const s = Statement(
      period: '2026-11',
      subscriptionPct: 50,
      feeCents: 9000,
      includedHalfDays: 10,
      openDays: 20,
      usedHalfDays: 12,
      extraHalfDays: 2,
      overageCents: 3000,
      creditsCents: 1000,
      balanceCents: -11500,
      accessorySupplementCents: 300,
      deskSupplementCents: 200,
    );
    final e = estimateOf(s);
    expect(e.period, '2026-11');
    expect(e.supplementCents, 500);
    // The parts add up to the balance the server gave.
    expect(
      e.feeCents + e.overageCents + e.supplementCents - e.creditsCents,
      11500,
    );
    expect(e.owedCents, 11500);
    expect(estimateOf(s.copyWith(balanceCents: 400)).owedCents, 0);
  });
}
