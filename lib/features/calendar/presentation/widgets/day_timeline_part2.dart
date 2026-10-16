// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'day_timeline.dart';

// #2386 — part 2 of _DayTimelineState, split out of day_timeline.dart so no
// file holds the whole class.
extension _DayTimelineStatePart2 on _DayTimelineState {

  Widget _seatCell(
    BuildContext context,
    Seat seat,
    Brightness brightness,
    double rowHeight,
  ) {
    final blocked = _blockedDuring(seat);
    return SizedBox(
      height: rowHeight,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                seat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            // Never state by color alone (spec §11): blocked seats get an
            // icon next to the muted track tint.
            if (blocked)
              Icon(
                Icons.block,
                size: 14,
                color: SeatStateColors.of(
                  SeatState.blocked,
                  brightness: brightness,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The instant [dx] pixels along the track (the inverse of `_offsetOf`).
  DateTime _instantAt(double dx) {
    final minutes = (dx / TimelineAxis.hourWidth * 60).floor();
    return WorkspaceTime.at(_dayStart.year, _dayStart.month, _dayStart.day,
        minutes ~/ 60, minutes % 60);
  }

  Widget _track(
    BuildContext context,
    Seat seat,
    List<Reservation> blocks,
    Map<String, String> names,
    Brightness brightness,
    double rowHeight,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = _blockedDuring(seat) || !widget.dayOpen;
    final blockedTint = SeatStateColors.of(
      SeatState.blocked,
      brightness: brightness,
    ).withValues(alpha: 0.15);
    return Container(
      key: DayTimeline.trackKey(seat.id),
      height: rowHeight,
      width: TimelineAxis.trackWidth,
      decoration: BoxDecoration(
        color: blocked ? blockedTint : null,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Stack(
        children: [
          // Free-area tap books this seat (hub); the blocks above keep
          // their own handlers and win hit-testing.
          if ((widget.onFreeSeatTap != null || widget.onFreeSeatTapAt != null) &&
              !blocked)
            Positioned.fill(
              child: InkWell(
                key: ValueKey('timeline-free-${seat.id}'),
                onTap: widget.onFreeSeatTapAt == null
                    ? () => widget.onFreeSeatTap!(seat)
                    : null,
                onTapUp: widget.onFreeSeatTapAt == null
                    ? null
                    : (d) => widget.onFreeSeatTapAt!(
                        seat, _instantAt(d.localPosition.dx)),
              ),
            ),
          for (final r in blocks) _block(context, r, names, brightness),
        ],
      ),
    );
  }

  Widget _block(
    BuildContext context,
    Reservation reservation,
    Map<String, String> names,
    Brightness brightness,
  ) {
    final own = reservation.memberId == widget.myMemberId;
    final base = SeatStateColors.of(
      own ? SeatState.mine : SeatState.reserved,
      brightness: brightness,
    );
    // MY bookings carry the full tone; everyone else's step back a
    // notch, so 'when did I reserve what' reads before any label does.
    final color = own ? base : base.withValues(alpha: 0.78);
    final onColor =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final left = _offsetOf(reservation.startsAt);
    final right = _offsetOf(reservation.endsAt);
    final width = (right - left) < TimelineAxis.blockMinWidth
        ? TimelineAxis.blockMinWidth
        : right - left;
    final occupant = names[reservation.memberId] ?? '';
    final initial = occupant.trim().isEmpty
        ? ''
        : occupant.trim().characters.first.toUpperCase();
    return Positioned(
      left: left,
      width: width,
      top: TimelineAxis.blockInset,
      bottom: TimelineAxis.blockInset,
      child: Material(
        color: color,
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: DayTimeline.blockKey(reservation.id),
          onTap: () => _onBlockTap(reservation),
          child: widget.everyone && width > 40
              ? Padding(
                  padding: AppSpacing.xsH,
                  child: Row(
                    children: [
                      if (initial.isNotEmpty) ...[
                        // The same avatar language as the plan's seat
                        // tiles and the week grid's cells.
                        Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: onColor.withValues(alpha: 0.22),
                          ),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: onColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          occupant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: onColor),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}
