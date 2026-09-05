// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/seat.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/seat_state_logic.dart';
import '../../../../core/time/workspace_time.dart';

/// The plan's SEAT LIST (#687), ported out of the deleted Plan tab.
///
/// Kept because the hub's Day view is a TIMELINE, not a list: it answers
/// "what is happening when", and this answers "which seat can I take".
/// Calling one a superset of the other cost a real feature — someone
/// scanning for a free desk does not want a time axis.
///
/// Its own file rather than another 160 lines in the hub, which is
/// already carrying two screens' worth of work.
class SeatListView extends ConsumerWidget {
  const SeatListView({
    super.key,
    required this.plan,
    required this.reservations,
    required this.names,
    required this.at,
    required this.dayOpen,
    required this.onSeatTap,
    this.windowEndOrNull,
  });

  final FloorPlan plan;
  final List<Reservation> reservations;
  final Map<String, String> names;

  /// The instant the rows describe — the window start while browsing,
  /// the live clock otherwise.
  final DateTime at;

  /// Null = live: occupancy is judged AT [at]. Set = browsing: judged
  /// across [at, windowEndOrNull), mirroring the canvas beside it.
  final DateTime? windowEndOrNull;

  /// Closed day (#186): every row muted, the state text says the DAY is
  /// shut rather than the seat being under maintenance.
  final bool dayOpen;

  final void Function(Seat seat) onSeatTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final timeFormat = DateFormat.Hm();
    final myMemberId = ref.watch(myMemberProvider).value?.id;

    if (plan.seats.isEmpty) {
      return EmptyState(
        icon: Icons.event_seat_outlined,
        title: l10n?.planNoSeats ?? 'This level has no seats yet.',
      );
    }

    String contextOf(Seat seat) {
      final desk =
          plan.desks.where((d) => d.id == seat.deskId).firstOrNull;
      final office = desk == null
          ? null
          : plan.offices.where((o) => o.id == desk.officeId).firstOrNull;
      return [office?.name, desk?.name]
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .join(' · ');
    }

    final seats = [...plan.seats]..sort((a, b) => a.name.compareTo(b.name));

    return ListView.builder(
      itemCount: seats.length,
      itemBuilder: (context, index) {
        final seat = seats[index];
        // Browsing (#184): the row mirrors the canvas — occupancy over the
        // whole window, instant-based in live mode. Closed day (#186):
        // every row muted like the canvas, tap gated in [_onSeatTap].
        final windowEnd = windowEndOrNull;
        final state = !dayOpen
            ? SeatState.blocked
            : windowEnd == null
                ? seatStateAt(
                    plan: plan,
                    seat: seat,
                    reservations: reservations,
                    myMemberId: myMemberId,
                    at: at,
                  )
                : seatStateInRange(
                    plan: plan,
                    seat: seat,
                    reservations: reservations,
                    myMemberId: myMemberId,
                    from: at,
                    to: windowEnd,
                  );
        final covering = windowEnd == null
            ? reservationOnSeatAt(
                plan: plan,
                seat: seat,
                reservations: reservations,
                at: at,
              )
            : reservationOnSeatInRange(
                plan: plan,
                seat: seat,
                reservations: reservations,
                from: at,
                to: windowEnd,
              );
        final until = covering == null
            ? null
            // #908 — on the space's clock, like the plan beside it.
            : timeFormat.format(WorkspaceTime.display(covering.endsAt));
        final who = covering == null
            ? ''
            : (names[covering.memberId] ?? '');
        // Closed day (#186): the muted state is the day's, not the
        // seat's — say so instead of the maintenance-block text.
        final stateText = !dayOpen
            ? (l10n?.planClosedDay ?? 'Closed on this day')
            : switch (state) {
                SeatState.free => l10n?.planStateFree ?? 'Free',
                SeatState.blocked => l10n?.planSeatBlocked ??
                    'This seat is blocked for maintenance.',
                SeatState.mine =>
                  '${l10n?.planStateYours ?? 'Yours'} · ${l10n?.planUntil(until ?? '') ?? 'until $until'}',
                SeatState.reserved =>
                  '${l10n?.planReservedBy(who) ?? 'Reserved by $who'} · ${l10n?.planUntil(until ?? '') ?? 'until $until'}',
                SeatState.occupied =>
                  '${l10n?.planOccupiedBy(who) ?? 'Occupied by $who'} · ${l10n?.planUntil(until ?? '') ?? 'until $until'}',
              };
        final accent = SeatStateColors.of(
          state,
          brightness: Theme.of(context).brightness,
        );
        // #575 — the same day-phase glance as the canvas ring: a dot
        // beside the seat icon (green = running, half green = still
        // ahead today, grey = already served).
        final phase = !dayOpen
            ? SeatDayPhase.none
            : seatDayPhaseAt(
                plan: plan,
                seat: seat,
                reservations: reservations,
                at: at,
              );
        final freeColor = SeatStateColors.of(
          SeatState.free,
          brightness: Theme.of(context).brightness,
        );
        final phaseColor = switch (phase) {
          SeatDayPhase.ongoing => freeColor,
          SeatDayPhase.upcoming => freeColor.withValues(alpha: 0.5),
          SeatDayPhase.past => SeatStateColors.of(
              SeatState.blocked,
              brightness: Theme.of(context).brightness,
            ),
          SeatDayPhase.none => null,
        };
        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                switch (state) {
                  SeatState.free => Icons.event_seat_outlined,
                  SeatState.blocked => Icons.block,
                  _ => Icons.event_seat,
                },
                color: accent,
              ),
              if (phaseColor != null)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    key: ValueKey('seat-day-phase-${seat.id}'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: phaseColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(seat.name.isEmpty ? contextOf(seat) : seat.name),
          subtitle: Text(
            [contextOf(seat), stateText]
                .where((s) => seat.name.isNotEmpty || s != contextOf(seat))
                .where((s) => s.isNotEmpty)
                .join('\n'),
          ),
          isThreeLine: seat.name.isNotEmpty && contextOf(seat).isNotEmpty,
          onTap: () => onSeatTap(seat),
        );
      },
    );
  }
}
