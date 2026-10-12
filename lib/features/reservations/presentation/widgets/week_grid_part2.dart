// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'week_grid.dart';

// #2386 — part 2 of _WeekGridState, split out of week_grid.dart so no
// file holds the whole class.
extension _WeekGridStatePart2 on _WeekGridState {

  Widget _dayCell(
    BuildContext context,
    Seat seat,
    List<Reservation> rowReservations,
    DateTime day,
    double dayWidth,
    Brightness brightness,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // The cell IS the workspace-local CALENDAR day (midnight to
    // midnight — the display halves, #446), same clock as the
    // half-slot windows below, whatever zone the device is in. The
    // canonical fullDay window would hide bookings outside the
    // configured working hours.
    final dayStart = HalfDayWindows.displayMorning(day).start;
    final dayEnd = HalfDayWindows.displayAfternoon(day).end;
    final items = [
      for (final r in rowReservations)
        if (r.holdsRange(dayStart, dayEnd)) r,
    ];
    final selected = DateUtils.isSameDay(day, widget.selectedDay);
    return SizedBox(
      width: dayWidth,
      child: InkWell(
        key: ValueKey('week-grid-ink-well-${brightness.name}'),
        onTap: items.isEmpty ? null : () => _cellSheet(seat, day, items),
        child: Container(
          // Subtle column tint under the highlighted header — never the
          // half-slots' own fill, which stays the occupancy signal.
          color: selected ? scheme.primary.withValues(alpha: 0.06) : null,
          padding: const EdgeInsets.all(WeekGridMetrics.cellInset),
          child: Row(
            children: [
              Expanded(
                child: _halfSlot(
                  context,
                  seat,
                  day,
                  items,
                  brightness,
                  morning: true,
                ),
              ),
              const SizedBox(width: WeekGridMetrics.halfSlotGap),
              Expanded(
                child: _halfSlot(
                  context,
                  seat,
                  day,
                  items,
                  brightness,
                  morning: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One half-slot: filled when ANY reservation of the cell overlaps the
  /// canonical half window (mine wins over others), muted when the seat is
  /// blocked during it, otherwise a subtle outline.
  Widget _halfSlot(
    BuildContext context,
    Seat seat,
    DateTime day,
    List<Reservation> items,
    Brightness brightness, {
    required bool morning,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // Display halves, not booking windows (#446): a booking outside
    // the working hours still occupies the seat that half of the day.
    final half = morning
        ? HalfDayWindows.displayMorning(day)
        : HalfDayWindows.displayAfternoon(day);
    var occupied = false;
    var mine = false;
    for (final r in items) {
      if (!r.holdsRange(half.start, half.end)) continue;
      occupied = true;
      if (r.memberId == widget.myMemberId) {
        mine = true;
        break;
      }
    }
    Color? fill;
    String? occupantInitial;
    if (occupied) {
      // The timeline's block tones (#187): mine vs reserved-by-others.
      fill = SeatStateColors.of(
        mine ? SeatState.mine : SeatState.reserved,
        brightness: brightness,
      );
      if (widget.everyone) {
        // WHO at a glance (needs analysis: availability + by whom): the
        // covering occupant's initial, mirroring the plan's seat avatars.
        final names = ref.watch(memberNamesProvider).value ?? const {};
        final covering = items.firstWhere(
          (r) => r.holdsRange(half.start, half.end),
        );
        final name = names[covering.memberId] ?? '';
        if (name.trim().isNotEmpty) {
          occupantInitial = name.trim().characters.first.toUpperCase();
        }
      }
    } else if (_blockedDuring(seat, half.start, half.end)) {
      fill = SeatStateColors.of(SeatState.blocked, brightness: brightness)
          .withValues(alpha: 0.3);
    } else if (!_dayOpen(day)) {
      // #814 — a closed day is not free: nothing to tap, nothing to book.
      fill = scheme.surfaceContainerHighest;
    }
    final free = fill == null;
    return DecoratedBox(
      key: WeekGrid.cellKey(seat.id, day, morning: morning),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadius.smAll,
        border: free
            ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6))
            : null,
      ),
      // A free half-slot is a booking affordance, not dead space.
      child: free && widget.onFreeSlotTap != null
          ? InkWell(
              key: ValueKey(
                'week-free-${seat.id}-${WeekGrid.dayStampOf(day)}-'
                '${morning ? 'am' : 'pm'}',
              ),
              borderRadius: AppRadius.smAll,
              onTap: () =>
                  widget.onFreeSlotTap!(seat, day, morning: morning),
            )
          : occupantInitial == null
              ? null
              : Center(
                  child: Text(
                    occupantInitial,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.emphasised.copyWith(color: Colors.white),
                  ),
                ),
    );
  }

  /// Small occupants sheet of one seat/day cell: "09:00 – 11:00 · Flo"
  /// per reservation (names only in Everyone mode), my own rows popping
  /// the tapped reservation for the hub's detail sheet.
  Future<void> _cellSheet(
    Seat seat,
    DateTime day,
    List<Reservation> items,
  ) async {
    final names = ref.read(memberNamesProvider).value ?? const {};
    final l10n = context.l10n;
    final sorted = [...items]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final picked = await showAppSheet<Reservation>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                child: Text(
                  '${seat.name} · ${DateFormat.MMMEd().format(day)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final r in sorted)
                ListTile(
                  key: WeekGrid.sheetItemKey(r.id),
                  leading: Icon(
                    r.memberId == widget.myMemberId
                        ? Icons.event_seat
                        : Icons.person_outline,
                  ),
                  title: Text(_occupantLine(r, names, l10n)),
                  trailing: r.memberId == widget.myMemberId
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: r.memberId == widget.myMemberId
                      ? () => Navigator.of(context).pop(r)
                      : null,
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    widget.onReservationTap(picked);
  }

  String _occupantLine(
    Reservation r,
    Map<String, String> names,
    AppLocalizations l10n,
  ) {
    final range = bookingRangeText(context, appFormatOf(context), l10n, r.startsAt, r.endsAt);
    if (!widget.everyone) return range;
    final name = names[r.memberId] ?? '';
    return name.isEmpty ? range : '$range · $name';
  }
}
