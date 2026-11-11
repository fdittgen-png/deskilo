// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3305 — a member's statement in the Demo, per member and period, as the
// server's `member_statement` (0109, its scans rewritten by 0208) computes it
// from that member's own records: the band fee of their subscription
// percentage, the half-days their reservations used against the entitlement
// the month's open days give, the overage beyond it, and the period's ledger —
// their credits not consumed by an invoice match, less their charges. The
// Demo prices no supplements, so those stay 0. A month fully before the
// membership owes nothing.
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../credit_repository.dart';
import '../money_repository.dart';
import '../reservation_repository.dart';
import '../workspace_repository.dart';

/// Where a space's statement reads what is not money: its members, who is
/// asking, the open days of a month, the half-days a member's reservations
/// used and the half-days their credits covered.
typedef DemoStatementSource = ({
  Member? Function(String memberId) member,
  Member? Function() caller,
  int Function(String period) openDays,
  int Function(String memberId, String period) usedHalfDays,
  int Function(String memberId, String period) creditHalfDays,
});

/// The half-day boundary the server falls back to (`half_boundary_minutes`,
/// 0109 #446): the Demo's spaces set no other.
const _halfBoundaryMinutes = 12 * 60;

bool _tzReady = false;

/// The source of the space [workspaceId] in [workspaces], [reservations] and
/// [credits]; [actor] is the member the session acts as.
DemoStatementSource demoStatementSource(
  FakeWorkspaceRepository workspaces,
  FakeReservationRepository reservations,
  String workspaceId, {
  required String Function() actor,
  FakeCreditRepository? credits,
}) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  final zone = tz.getLocation(
    workspaces.workspaces.firstWhere((w) => w.id == workspaceId).timezone,
  );
  Member? memberOf(String id) => [
    workspaces.myMember,
    ...workspaces.otherMembers,
  ].where((m) => m.id == id).firstOrNull;
  // The reservations that count, with their start on the space's clock, as
  // member_statement scans them: held, of the member, started in the month.
  Iterable<(Reservation, tz.TZDateTime)> held(String memberId, String period) sync* {
    for (final r in reservations.reservations) {
      if (r.memberId != memberId ||
          !const {
            ReservationStatus.reserved,
            ReservationStatus.checkedIn,
            ReservationStatus.completed,
          }.contains(r.status)) {
        continue;
      }
      final start = tz.TZDateTime.from(r.startsAt, zone);
      if (yearMonth(start.year, start.month) == period) yield (r, start);
    }
  }

  return (
    member: memberOf,
    caller: () => memberOf(actor()),
    openDays: (period) {
      final first = DateTime.parse('$period-01');
      final open = workspaces.openWeekdays[workspaceId] ?? const [1, 2, 3, 4, 5];
      final closed = {
        for (final c in workspaces.closureDays)
          if (c.workspaceId == workspaceId)
            DateTime(c.day.year, c.day.month, c.day.day),
      };
      var days = 0;
      for (var d = first; d.month == first.month; d = DateTime(d.year, d.month, d.day + 1)) {
        if (open.contains(d.weekday) && !closed.contains(d)) days++;
      }
      return days;
    },
    // One half-day per distinct (day, half) a reservation STARTS in, on the
    // space's clock (0109/0208): a booking across noon counts its morning.
    usedHalfDays: (memberId, period) => {
      for (final (_, start) in held(memberId, period))
        (start.year, start.month, start.day,
            start.hour * 60 + start.minute < _halfBoundaryMinutes ? 0 : 1),
    }.length,
    // The month's live credit uses (0237 member_credit_uses_in_period).
    creditHalfDays: (memberId, period) {
      final ids = {for (final (r, _) in held(memberId, period)) r.id};
      return (credits?.uses ?? const [])
          .where((u) => u.releasedAt == null && ids.contains(u.reservationId))
          .fold(0, (n, u) => n + u.halfDays);
    },
  );
}

/// [memberId]'s statement of [period] over [m]'s money and [source].
Statement demoMemberStatement(
  FakeMoneyRepository m,
  DemoStatementSource source,
  String memberId,
  String period,
) {
  final member = source.member(memberId);
  final pct = member?.subscriptionPct ?? 100;
  final policy = member?.overagePolicy ?? m.statement.overagePolicy;
  final joined = member?.joinedAt;
  if (joined != null &&
      period.compareTo(yearMonth(joined.year, joined.month)) < 0) {
    return Statement(
      period: period,
      subscriptionPct: pct,
      feeCents: 0,
      includedHalfDays: 0,
      openDays: 0,
      usedHalfDays: 0,
      extraHalfDays: 0,
      overageCents: 0,
      creditsCents: 0,
      balanceCents: 0,
      overagePolicy: policy,
    );
  }
  final band = m.feeBands
      .where((b) => b.fromPct < pct && pct <= b.toPct)
      .firstOrNull;
  final fee = band?.feeCents ?? 0;
  final rate = band?.overageFeeCents ?? 0;
  final openDays = source.openDays(period);
  final included = (openDays * 2 * pct / 100).ceil();
  final used = source.usedHalfDays(memberId, period);
  // Credit-covered half-days are not billed as overage (0237).
  final covered = source.creditHalfDays(memberId, period);
  final extra = used - included - covered > 0 ? used - included - covered : 0;
  // What an invoice match used of a credit settled that invoice: it does
  // not improve the month a second time (#3671: only what is left counts). Charges always count.
  final credits = m.ledger
      .where((e) =>
          e.memberId == memberId &&
          e.period == period &&
          // #3601 — the subscription is charged once: by the fee band above.
          // Its ledger line is what the invoicing wizard bills, not a second
          // charge of the same month.
          e.category != LedgerCategory.subscription &&
          (e.kind != LedgerKind.credit || m.remainingOf(e) > 0))
      .fold(0, (int n, e) =>
          n + (e.kind == LedgerKind.credit ? m.remainingOf(e) : -e.amountCents));
  return Statement(
    period: period,
    subscriptionPct: pct,
    feeCents: fee,
    includedHalfDays: included,
    openDays: openDays,
    usedHalfDays: used,
    extraHalfDays: extra,
    overageCents: extra * rate,
    creditsCents: credits,
    balanceCents: credits - fee - extra * rate,
    overagePolicy: policy,
    overageRateCents: rate,
    remainingHalfDays: used > included ? 0 : included - used,
  );
}
