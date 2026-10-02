// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/seat_state_logic.dart';
import 'list_space_tap.dart';
import '../../../../core/i18n/format_controller.dart';

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
    this.onSpaceTap,
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

  /// #1825 — whole-space reservation from a desk or office header; null
  /// when this member may not reserve a space as a whole (feature off, no
  /// grant, no roster). Only a header whose space is bookable as a whole
  /// becomes actionable. Called with neither id, it reserves the level.
  final void Function(String? deskId, String? officeId)? onSpaceTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final level = ref
        .watch(levelsProvider)
        .value
        ?.where((l) => l.id == plan.levelId)
        .firstOrNull;
    final wholeLevel = onSpaceTap != null && levelReservable(ref, level);
    if (plan.seats.isEmpty &&
        !wholeLevel &&
        !plan.desks.any((d) => d.bookableAsWhole) &&
        !plan.offices.any((o) => o.bookableAsWhole)) {
      return EmptyState(
        icon: Icons.event_seat_outlined,
        title: l10n?.planNoSeats ?? 'This level has no seats yet.',
      );
    }

    // #1273 — a level's only room is named by the level.
    final byLevel = namesSingleRoomsByLevel(ref);
    final levelName = levelNameOf(ref, plan.levelId);
    String contextOf(Seat seat) {
      final desk =
          plan.desks.where((d) => d.id == seat.deskId).firstOrNull;
      final office = desk == null
          ? null
          : plan.offices.where((o) => o.id == desk.officeId).firstOrNull;
      return [
        if (office != null)
          plan.officeContextName(office, levelName: levelName, byLevel: byLevel),
        desk?.name,
      ]
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .join(' · ');
    }

    // #1825 — the structure the member reserves in: each office, its
    // desks, each desk's seats; seats with no desk last. A desk or office
    // with no seat still shows when it can be reserved as a whole.
    int byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
    final rows = <Widget>[];
    Widget header(String key, IconData icon, String name, double indent,
        {VoidCallback? onTap}) =>
        ListTile(
          key: ValueKey(key),
          contentPadding: EdgeInsetsDirectional.only(start: 16 + indent, end: 16),
          leading: Icon(icon),
          title: Text(name, style: Theme.of(context).textTheme.titleSmall),
          trailing: onTap == null
              ? null
              : Icon(Icons.add_circle_outline,
                  semanticLabel: l10n?.planReserveButton ?? 'Reserve'),
          onTap: onTap,
        );
    VoidCallback? spaceTap({String? deskId, String? officeId, required bool whole}) {
      final tap = onSpaceTap;
      return tap == null || !whole || !dayOpen ? null : () => tap(deskId, officeId);
    }

    // #1825 — the whole level, at the top, only where the level rail
    // offers it (its stricter rule); structure otherwise stays the rail's.
    if (wholeLevel) {
      rows.add(header('list-level-${plan.levelId}', Icons.layers_outlined,
          level!.name, 0, onTap: spaceTap(whole: true)));
    }
    final placed = <String>{};
    final offices = [...plan.offices]..sort((a, b) => byName(a.name, b.name));
    for (final office in offices) {
      final desks = [
        for (final d in plan.desks)
          if (d.officeId == office.id) d,
      ]..sort((a, b) => byName(a.name, b.name));
      final seatsOf = {
        for (final d in desks)
          d.id: [
            for (final s in plan.seats)
              if (s.deskId == d.id) s,
          ]..sort((a, b) => byName(a.name, b.name)),
      };
      final shown = desks
          .where((d) => d.bookableAsWhole || seatsOf[d.id]!.isNotEmpty)
          .toList();
      if (shown.isEmpty && !office.bookableAsWhole) continue;
      rows.add(header(
        'list-office-${office.id}',
        Icons.meeting_room_outlined,
        plan.officeContextName(office, levelName: levelName, byLevel: byLevel),
        0,
        onTap: spaceTap(officeId: office.id, whole: office.bookableAsWhole),
      ));
      for (final desk in shown) {
        rows.add(header('list-desk-${desk.id}', Icons.table_restaurant_outlined,
            desk.name, 16, onTap: spaceTap(deskId: desk.id, whole: desk.bookableAsWhole)));
        for (final seat in seatsOf[desk.id]!) {
          placed.add(seat.id);
          rows.add(_seatRow(context, ref, seat, 32, ''));
        }
      }
    }
    final unplaced = [
      for (final s in plan.seats)
        if (!placed.contains(s.id)) s,
    ]..sort((a, b) => byName(a.name, b.name));
    for (final seat in unplaced) {
      rows.add(_seatRow(context, ref, seat, 0, contextOf(seat)));
    }

    return ListView(children: rows);
  }

  Widget _seatRow(
    BuildContext context,
    WidgetRef ref,
    Seat seat,
    double indent,
    String place,
  ) {
    final l10n = AppLocalizations.of(context);
    final timeFormat = ref.watch(appFormatProvider); // #1150
    final myMemberId = ref.watch(myMemberProvider).value?.id;
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
            : timeFormat.time(covering.endsAt);
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
          key: ValueKey('list-seat-${seat.id}'),
          contentPadding:
              EdgeInsetsDirectional.only(start: 16 + indent, end: 16),
          title: Text(seat.name.isEmpty ? place : seat.name),
          subtitle: Text(
            [place, stateText]
                .where((s) => seat.name.isNotEmpty || s != place)
                .where((s) => s.isNotEmpty)
                .join('\n'),
          ),
          isThreeLine: seat.name.isNotEmpty && place.isNotEmpty,
          onTap: () => onSeatTap(seat),
        );
  }
}
