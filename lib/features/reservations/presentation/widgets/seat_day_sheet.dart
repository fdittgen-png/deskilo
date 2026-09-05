// SPDX-License-Identifier: 0BSD
//
// #903 — the day on ONE seat. When a seat carries more than one booking
// the plan cannot say who has it when: this sheet lays the open day out
// row by row — every booking with its hours, its occupant and whether it
// is done, running or still ahead, and every free stretch as something
// you can take. Tapping a free row hands its window back to the caller,
// which opens the ordinary booking sheet on it.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/time/workspace_time.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/seat.dart';
import '../../domain/seat_state_logic.dart';

/// A free stretch of the day, between (or around) the bookings.
class SeatDayGap {
  const SeatDayGap(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// The day's free stretches around [segments], each at least [minMinutes].
List<SeatDayGap> seatDayGaps({
  required List<SeatDaySegment> segments,
  required DateTime dayStart,
  required DateTime dayEnd,
  int minMinutes = 15,
}) {
  final gaps = <SeatDayGap>[];
  var cursor = dayStart;
  for (final segment in segments) {
    if (segment.start.isAfter(cursor) &&
        segment.start.difference(cursor).inMinutes >= minMinutes) {
      gaps.add(SeatDayGap(cursor, segment.start));
    }
    if (segment.end.isAfter(cursor)) cursor = segment.end;
  }
  if (dayEnd.isAfter(cursor) &&
      dayEnd.difference(cursor).inMinutes >= minMinutes) {
    gaps.add(SeatDayGap(cursor, dayEnd));
  }
  return gaps;
}

/// Shows the day of [seat]. Returns the free window the person picked, or
/// null when they only looked.
Future<SeatDayGap?> showSeatDaySheet(
  BuildContext context, {
  required Seat seat,
  required List<SeatDaySegment> segments,
  required Map<String, String> names,
  required DateTime dayStart,
  required DateTime dayEnd,
  required DateTime now,
}) =>
    showModalBottomSheet<SeatDayGap>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SeatDaySheet(
        seat: seat,
        segments: segments,
        names: names,
        dayStart: dayStart,
        dayEnd: dayEnd,
        now: now,
      ),
    );

class _SeatDaySheet extends StatelessWidget {
  const _SeatDaySheet({
    required this.seat,
    required this.segments,
    required this.names,
    required this.dayStart,
    required this.dayEnd,
    required this.now,
  });

  final Seat seat;
  final List<SeatDaySegment> segments;
  final Map<String, String> names;
  final DateTime dayStart;
  final DateTime dayEnd;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final hm = DateFormat.Hm(locale);
    final gaps = seatDayGaps(
      segments: segments,
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
    // One list in clock order: what is taken and what is not.
    final rows = <({DateTime start, DateTime end, SeatDaySegment? booking})>[
      for (final s in segments) (start: s.start, end: s.end, booking: s),
      for (final g in gaps) (start: g.start, end: g.end, booking: null),
    ]..sort((a, b) => a.start.compareTo(b.start));

    // #908 — a segment carries the raw instant; every reservation
    // surface prints it through WorkspaceTime.display, which reads the
    // space's clock unless the member asked for their own. Formatting
    // the instant itself printed UTC — a Paris morning showed 06:00.
    String when(DateTime start, DateTime end) =>
        '${hm.format(WorkspaceTime.display(start))} – '
        '${hm.format(WorkspaceTime.display(end))}';
    String phaseOf(DateTime start, DateTime end) => end.isBefore(now)
        ? (l10n?.seatDayPast ?? 'Done')
        : start.isAfter(now)
            ? (l10n?.seatDayAhead ?? 'Ahead')
            : (l10n?.seatDayNow ?? 'Now');

    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.seatDayTitle(seat.name) ?? 'Seat ${seat.name} today',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              l10n?.seatDaySubtitle ??
                  'Who has this seat, and when. Tap a free stretch to take it.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final row in rows)
              if (row.booking case final booking?)
                ListTile(
                  key: ValueKey('seat-day-booking-${booking.reservationId}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    booking.isMine ? Icons.person : Icons.event_seat_outlined,
                    color: SeatStateColors.of(booking.state,
                        brightness: theme.brightness),
                  ),
                  title: Text(when(booking.start, booking.end)),
                  subtitle: Text(booking.isMine
                      ? (l10n?.seatDayMine ?? 'You')
                      : (names[booking.memberId] ??
                          (l10n?.seatDaySomeone ?? 'A member'))),
                  trailing: Text(phaseOf(booking.start, booking.end),
                      style: theme.textTheme.labelSmall),
                )
              else
                ListTile(
                  key: ValueKey(
                      'seat-day-free-${row.start.millisecondsSinceEpoch}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.add_circle_outline,
                      color: SeatStateColors.of(SeatState.free,
                          brightness: theme.brightness)),
                  title: Text(when(row.start, row.end)),
                  subtitle: Text(l10n?.seatDayFree ?? 'Free — book it'),
                  onTap: () => Navigator.of(context)
                      .pop(SeatDayGap(row.start, row.end)),
                ),
          ],
        ),
      ),
    );
  }
}
