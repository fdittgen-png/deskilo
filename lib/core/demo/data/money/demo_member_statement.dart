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
import 'package:deskilo/core/time/date_text.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';

import '../money_repository.dart';
import '../reservation_repository.dart';
import '../workspace_repository.dart';

/// Where a space's statement reads what is not money: its members, the open
/// days of a month and the half-days a member's reservations used.
typedef DemoStatementSource = ({
  Member? Function(String memberId) member,
  int Function(String period) openDays,
  int Function(String memberId, String period) usedHalfDays,
});

/// The source of the space [workspaceId] in [workspaces] and [reservations].
DemoStatementSource demoStatementSource(
  FakeWorkspaceRepository workspaces,
  FakeReservationRepository reservations,
  String workspaceId,
) => (
  member: (id) => [
    workspaces.myMember,
    ...workspaces.otherMembers,
  ].where((m) => m.id == id).firstOrNull,
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
  usedHalfDays: (memberId, period) {
    // Distinct (day, half) the member held, the boundary at noon.
    final halves = <(DateTime, int)>{};
    for (final r in reservations.reservations) {
      if (r.memberId != memberId ||
          !const {
            ReservationStatus.reserved,
            ReservationStatus.checkedIn,
            ReservationStatus.completed,
          }.contains(r.status)) {
        continue;
      }
      final start = r.startsAt.toLocal();
      if (yearMonth(start.year, start.month) != period) continue;
      final day = DateTime(start.year, start.month, start.day);
      final noon = day.add(const Duration(hours: 12));
      if (start.isBefore(noon)) halves.add((day, 0));
      if (r.endsAt.toLocal().isAfter(noon)) halves.add((day, 1));
    }
    return halves.length;
  },
);

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
  final extra = used > included ? used - included : 0;
  // A credit an invoice match consumed settled that invoice: it does not
  // improve the month a second time. Charges always count.
  final consumed = {
    ...m.consumedPaymentIds,
    for (final x in m.invoiceMatchesStore.values) ?x.paymentLedgerId,
  };
  final credits = m.ledger
      .where((e) =>
          e.memberId == memberId &&
          e.period == period &&
          (e.kind != LedgerKind.credit || !consumed.contains(e.id)))
      .fold(0, (int n, e) =>
          n + (e.kind == LedgerKind.credit ? e.amountCents : -e.amountCents));
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
