// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — what the members' desk says about a member's plan, from what is
// stored (the decision on #3618): the plan fee is the fee band covering the
// share, and where none covers it the fee is unavailable, never a guess; the
// estimated next invoice is the statement's own figures for its period,
// never a sum the table makes; the last visit is the latest booking the
// member came to among the bookings read.
import '../../features/money/domain/fee_band.dart';
import '../../features/money/domain/statement.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/workspace/domain/member.dart';

/// A member's plan fee, as the fee bands give it.
sealed class PlanFee {
  const PlanFee();
}

/// No subscription (share 0): no plan fee.
final class NoPlan extends PlanFee {
  const NoPlan();
}

/// The fee of the [band] covering the share, in the business's currency.
final class BandFee extends PlanFee {
  const BandFee(this.band);
  final FeeBand band;
  int get cents => band.feeCents;
}

/// No band covers the share: the fee cannot be said.
final class FeeUnavailable extends PlanFee {
  const FeeUnavailable();
}

/// The plan fee of a member at [pct] under [bands].
PlanFee planFeeOf(List<FeeBand> bands, int pct) {
  if (pct == 0) return const NoPlan();
  final band = feeBandFor(bands, pct);
  return band == null ? const FeeUnavailable() : BandFee(band);
}

/// Whether [member] is on [band]: a paying member (not a kiosk, not gone)
/// whose share it covers.
bool onBand(Member member, FeeBand band) =>
    !member.isKiosk &&
    member.status != MemberStatus.exited &&
    band.fromPct < member.subscriptionPct &&
    member.subscriptionPct <= band.toPct;

/// The latest start of a booking [memberId] came to (checked in or
/// completed) at or before [now], among [reservations]; null when none.
DateTime? lastVisitOf(
  String memberId,
  Iterable<Reservation> reservations,
  DateTime now,
) {
  DateTime? last;
  for (final r in reservations) {
    if (r.memberId != memberId || r.startsAt.isAfter(now)) continue;
    if (r.status != ReservationStatus.checkedIn &&
        r.status != ReservationStatus.completed) {
      continue;
    }
    if (last == null || r.startsAt.isAfter(last)) last = r.startsAt;
  }
  return last;
}

/// What the statement of a period says the member's invoice for it will
/// carry so far: its parts and their result, all the server's figures.
typedef NextInvoiceEstimate = ({
  String period,
  int feeCents,
  int overageCents,
  int supplementCents,
  int creditsCents,

  /// What the member would owe for the period: the statement's balance,
  /// as an amount owed (never below zero).
  int owedCents,
});

/// The estimate of [statement]: its own parts, nothing recomputed.
NextInvoiceEstimate estimateOf(Statement statement) => (
  period: statement.period,
  feeCents: statement.feeCents,
  overageCents: statement.overageCents,
  supplementCents:
      statement.accessorySupplementCents +
      statement.levelSupplementCents +
      statement.officeSupplementCents +
      statement.deskSupplementCents,
  creditsCents: statement.creditsCents,
  owedCents: statement.balanceCents < 0 ? -statement.balanceCents : 0,
);
