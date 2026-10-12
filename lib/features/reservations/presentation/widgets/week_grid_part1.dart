// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'week_grid.dart';

// #2386 — part 1 of _WeekGridState, split out of week_grid.dart so no
// file holds the whole class.
extension _WeekGridStatePart1 on _WeekGridState {

  /// Blocked for maintenance at some point during `[from, to)` — the
  /// timeline's day rule (#161 blocks are half-open ranges) applied to an
  /// arbitrary window: blocked when the window starts, or the block begins
  /// later within it.
  bool _blockedDuring(Seat seat, DateTime from, DateTime to) {
    if (seat.isBlockedAt(from)) return true;
    final blockedFrom = seat.blockedFrom;
    return blockedFrom != null &&
        !blockedFrom.isBefore(from) &&
        blockedFrom.isBefore(to);
  }

  Widget _singleLevelBody(BuildContext context, Level level) {
    final l10n = context.l10n;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    return switch (planAsync) {
      AsyncData(value: final plan) => _grid(context, [(null, plan)]),
      AsyncError() => _emptyHint(l10n),
      _ => const LoadingView(),
    };
  }

  /// All-levels mode loads WAIT-ALL like the timeline (#221): every
  /// level's plan is watched up front (they fetch in parallel) and nothing
  /// renders until each one resolved — a single consistent layout instead
  /// of rows reflowing as plans stream in. A level whose plan errored is
  /// skipped like an empty level.
  Widget _allLevelsBody(BuildContext context, List<Level> levels) {
    final entries = <(Level, AsyncValue<FloorPlan>)>[
      for (final l in levels) (l, ref.watch(floorPlanProvider(l.id))),
    ];
    final plans = <(Level?, FloorPlan)>[];
    for (final (level, planAsync) in entries) {
      switch (planAsync) {
        case AsyncData(value: final plan):
          plans.add((level, plan));
        case AsyncError():
          break; // Skipped, like a level with nothing to show.
        default:
          return const LoadingView();
      }
    }
    return _grid(context, plans);
  }

  /// Unlike the timeline there is no per-day empty case — the grid shows
  /// EVERY seat so free weeks read as free — so the only empty state is a
  /// workspace without a drawn plan.
  Widget _emptyHint(AppLocalizations l10n) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: Icons.view_week_outlined,
            title:
                l10n.planNoLevels,
          ),
        ),
      ],
    );
  }

  /// Renders the given plans stacked in one grid. Single-level mode passes
  /// one `(null, plan)` entry (no level-header row); all-levels mode
  /// passes every level's plan in [levelsProvider]'s sortOrder.
  Widget _grid(BuildContext context, List<(Level?, FloorPlan)> plans) {
    final l10n = context.l10n;
    final brightness = Theme.of(context).brightness;
    if (!plans.any((e) => e.$2.seats.isNotEmpty)) {
      return _emptyHint(l10n);
    }
    final days = _days;
    final weekStart = days.first;
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + WeekGridMetrics.daysPerWeek,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Seven equal columns fitted to the phone width; below the minimum
        // the day area keeps the minimum and scrolls horizontally.
        final available =
            constraints.maxWidth - WeekGridMetrics.leadingWidth;
        final fitted = available / WeekGridMetrics.daysPerWeek;
        final dayWidth = fitted < WeekGridMetrics.minDayWidth
            ? WeekGridMetrics.minDayWidth
            : fitted;
        final gridWidth = dayWidth * WeekGridMetrics.daysPerWeek;

        final leadingCells = <Widget>[
          const SizedBox(height: WeekGridMetrics.headerHeight),
        ];
        final gridRows = <Widget>[_headerRow(context, days, dayWidth)];
        for (final (level, plan) in plans) {
          if (plan.seats.isEmpty) continue;
          // Whole-level reservations (#452) occupy every seat row of
          // the level, like whole-office and whole-desk ones below.
          final levelReservations = widget.reservations
              .where((r) => r.levelId == plan.levelId)
              .toList();
          if (level != null) {
            leadingCells.add(_levelHeaderCell(context, level));
            gridRows.add(const SizedBox(
              height: WeekGridMetrics.levelHeaderRowHeight,
            ));
          }
          // #1273 — a level's only room is named by the level.
          final byLevel = namesSingleRoomsByLevel(ref);
          final levelName = level?.name ?? levelNameOf(ref, plan.levelId);
          for (final office in plan.offices) {
            final officeReservations = widget.reservations
                .where((r) => r.officeId == office.id)
                .toList();
            for (final desk in plan.desksOf(office.id)) {
              final seats = plan.seatsOf(desk.id);
              if (seats.isEmpty) continue;
              // Whole-desk reservations (0059) occupy every seat row of
              // the desk, like whole-office ones.
              final deskReservations = widget.reservations
                  .where((r) => r.deskId == desk.id)
                  .toList();
              leadingCells.add(
                _groupHeaderCell(
                  context,
                  '${plan.officeContextName(office, levelName: levelName, byLevel: byLevel)} · ${desk.name}',
                ),
              );
              gridRows.add(const SizedBox(
                height: WeekGridMetrics.groupHeaderRowHeight,
              ));
              for (final Seat seat in seats) {
                final rowReservations = <Reservation>[
                  ...levelReservations,
                  ...officeReservations,
                  ...deskReservations,
                  ...widget.reservations.where((r) => r.seatId == seat.id),
                ];
                leadingCells.add(_seatCell(
                  context,
                  seat,
                  brightness,
                  blockedDuringWeek: _blockedDuring(seat, weekStart, weekEnd),
                ));
                gridRows.add(_seatRow(
                  context,
                  seat,
                  rowReservations,
                  days,
                  dayWidth,
                  brightness,
                ));
              }
            }
          }
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: WeekGridMetrics.leadingWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: leadingCells,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: gridWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: gridRows,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _dayOpen(DateTime day) => widget.isDayOpen?.call(day) ?? true;

  /// Tappable "Mon 13" day headers; the selected day's pill highlighted.
  Widget _headerRow(
    BuildContext context,
    List<DateTime> days,
    double dayWidth,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final weekdayFormat = DateFormat.E();
    final dayFormat = DateFormat.d();
    final style = Theme.of(context).textTheme.labelMedium;
    return SizedBox(
      height: WeekGridMetrics.headerHeight,
      child: Row(
        children: [
          for (final day in days)
            SizedBox(
              width: dayWidth,
              child: Padding(
                padding: const EdgeInsets.all(WeekGridMetrics.cellInset),
                child: Material(
                  color: DateUtils.isSameDay(day, widget.selectedDay)
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: AppRadius.mdAll,
                  child: InkWell(
                    key: WeekGrid.dayHeaderKey(day),
                    borderRadius: AppRadius.mdAll,
                    onTap: () => widget.onDaySelected(day),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${weekdayFormat.format(day)} '
                            '${dayFormat.format(day)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DateUtils.isSameDay(day, widget.selectedDay)
                                ? style?.strong.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  )
                                : style?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                          ),
                          if (!_dayOpen(day))
                            Icon(
                              Icons.event_busy_outlined,
                              key: WeekGrid.closedHeaderKey(day),
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Level-name header in all-levels mode — like the timeline's,
  /// deliberately distinct from the muted group headers.
  Widget _levelHeaderCell(BuildContext context, Level level) {
    return SizedBox(
      key: WeekGrid.levelHeaderKey(level.id),
      height: WeekGridMetrics.levelHeaderRowHeight,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          top: AppSpacing.md,
        ),
        child: Text(
          level.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }

  Widget _groupHeaderCell(BuildContext context, String label) {
    return SizedBox(
      height: WeekGridMetrics.groupHeaderRowHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.sm),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }

  Widget _seatCell(
    BuildContext context,
    Seat seat,
    Brightness brightness, {
    required bool blockedDuringWeek,
  }) {
    return SizedBox(
      height: WeekGridMetrics.rowHeight,
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
            // Never state by color alone (spec §11): seats blocked at some
            // point of the week get an icon next to the muted half-slots.
            if (blockedDuringWeek)
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

  /// One seat's seven split day cells.
  Widget _seatRow(
    BuildContext context,
    Seat seat,
    List<Reservation> rowReservations,
    List<DateTime> days,
    double dayWidth,
    Brightness brightness,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: WeekGridMetrics.rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in days)
            _dayCell(
              context,
              seat,
              rowReservations,
              day,
              dayWidth,
              brightness,
            ),
        ],
      ),
    );
  }
}
