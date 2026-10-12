// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'day_timeline.dart';

// #2386 — part 1 of _DayTimelineState, split out of day_timeline.dart so no
// file holds the whole class.
extension _DayTimelineStatePart1 on _DayTimelineState {

  /// Horizontal offset of [at] on the track, clamped to the day.
  ///
  /// #490 — anchored to the WORKSPACE wall clock, not the device's: a
  /// browser in another timezone otherwise paints every block shifted
  /// by the tz delta.
  double _offsetOf(DateTime at) {
    final minutes =
        WorkspaceTime.wall(at).difference(_dayStart).inMinutes;
    final raw = minutes / 60.0 * TimelineAxis.hourWidth;
    return raw.clamp(0.0, TimelineAxis.trackWidth).toDouble();
  }

  /// Blocked for maintenance at some point during the day (#161 blocks are
  /// half-open ranges): blocked when the day starts, or the block begins
  /// later within this day.
  bool _blockedDuring(Seat seat) {
    if (seat.isBlockedAt(_dayStartInstant)) return true;
    final from = seat.blockedFrom;
    return from != null &&
        !from.isBefore(_dayStartInstant) &&
        from.isBefore(_dayEndInstant);
  }

  void _onBlockTap(Reservation reservation) {
    if (reservation.memberId == widget.myMemberId) {
      widget.onReservationTap(reservation);
      return;
    }
    final l10n = context.l10n;
    final names = ref.read(memberNamesProvider).value ?? const {};
    final name = names[reservation.memberId] ?? '';
    final until =
        ref.watch(appFormatProvider).time(reservation.endsAt);
    final message = '${l10n.planOccupiedBy(name)} · '
        '${l10n.planUntil(until)}';
    AppSnack.info(context, message, replace: true);
  }

  /// One initial jump per selected day: to just before the first
  /// reservation, or to the working-day start when the day is empty.
  void _scheduleAutoScroll(List<Reservation> dayReservations) {
    if (_autoScrolledDay != null &&
        DateUtils.isSameDay(_autoScrolledDay, widget.day)) {
      return;
    }
    final day = widget.day;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_axisController.hasClients) return;
      if (!DateUtils.isSameDay(day, widget.day)) return;
      _autoScrolledDay = day;
      // [dayReservations] is sorted by start, so the first one is the
      // earliest; a start before midnight clamps to hour 0.
      final startHour = dayReservations.isEmpty
          ? TimelineAxis.defaultStartHour.toDouble()
          : _offsetOf(dayReservations.first.startsAt) /
              TimelineAxis.hourWidth;
      final target = ((startHour - TimelineAxis.autoScrollLeadHours) *
              TimelineAxis.hourWidth)
          .clamp(0.0, _axisController.position.maxScrollExtent)
          .toDouble();
      _axisController.jumpTo(target);
    });
  }

  Widget _singleLevelBody(
    BuildContext context,
    Level level,
    Map<String, String> names,
  ) {
    final l10n = context.l10n;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    return switch (planAsync) {
      AsyncData(value: final plan) => _grid(context, [(null, plan)], names),
      AsyncError() => _emptyHint(l10n, allLevels: false),
      _ => const LoadingView(),
    };
  }

  /// All-levels mode loads WAIT-ALL: every level's plan is watched up
  /// front (they fetch in parallel) and nothing renders until each one
  /// resolved — a single consistent layout instead of rows reflowing as
  /// plans stream in. A level whose plan errored is skipped like an empty
  /// level.
  Widget _allLevelsBody(
    BuildContext context,
    List<Level> levels,
    Map<String, String> names,
  ) {
    // levelsProvider returns the levels sorted by sortOrder — the stacking
    // order below is that same order.
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
    return _grid(context, plans, names);
  }

  Widget _emptyHint(AppLocalizations l10n, {required bool allLevels}) {
    final hint = allLevels
        ? (l10n.calendarTimelineAllEmpty)
        : (l10n.calendarTimelineEmpty);
    // Stays a scrollable so an enclosing RefreshIndicator keeps working.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: Icons.view_timeline_outlined,
            title: hint,
          ),
        ),
      ],
    );
  }

  /// Renders the given plans stacked on one shared axis. Single-level mode
  /// passes one `(null, plan)` entry (no level-header row); all-levels mode
  /// passes every level's plan in [levelsProvider]'s sortOrder.
  Widget _grid(
    BuildContext context,
    List<(Level?, FloorPlan)> plans,
    Map<String, String> names,
  ) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final allLevels = plans.any((e) => e.$1 != null);

    final dayReservations = widget.reservations
        .where((r) => r.holdsRange(_dayStartInstant, _dayEndInstant))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    // Built lazily: how tall a seat row is depends on how many there are.
    final leadingCells = <Widget Function(double)>[
      (_) => const SizedBox(height: TimelineAxis.rulerHeight),
    ];
    final tracks = <Widget Function(double)>[(_) => _ruler(context)];
    var seatRows = 0;
    var fixedHeight = TimelineAxis.rulerHeight;
    final visibleReservations = <Reservation>[];
    for (final (level, plan) in plans) {
      // Only what lives on this level — incl. whole-desk and
      // whole-level rows (#452), which were silently dropped before.
      final seatIds = {for (final s in plan.seats) s.id};
      final deskIds = {for (final d in plan.desks) d.id};
      final officeIds = {for (final o in plan.offices) o.id};
      final levelReservations = dayReservations
          .where((r) =>
              (r.seatId != null && seatIds.contains(r.seatId)) ||
              (r.deskId != null && deskIds.contains(r.deskId)) ||
              (r.officeId != null && officeIds.contains(r.officeId)) ||
              (r.levelId != null && r.levelId == plan.levelId))
          .toList();

      // Same per-level rule as single-level mode: nothing to show without
      // seats or without a visible reservation that day. In all-levels
      // mode such a level is skipped entirely (#221); the overall empty
      // hint below fires only when EVERY level came up empty.
      if (plan.seats.isEmpty ||
          (!widget.showFreeSeats && levelReservations.isEmpty)) {
        continue;
      }
      visibleReservations.addAll(levelReservations);

      final collapsed = level != null && _collapsedLevels.contains(level.id);
      if (level != null) {
        leadingCells.add(
          (_) => _levelHeaderCell(context, level: level, collapsed: collapsed),
        );
        tracks.add((_) => const SizedBox(
              height: TimelineAxis.levelHeaderRowHeight,
              width: TimelineAxis.trackWidth,
            ));
        fixedHeight += TimelineAxis.levelHeaderRowHeight;
      }
      // Collapsed: the header stays (a tap re-opens it) but its office /
      // desk / seat rows are skipped entirely.
      if (collapsed) continue;
      // Whole-level rows lane onto every seat of the level (#452).
      final wholeLevelReservations = levelReservations
          .where((r) => r.levelId == plan.levelId)
          .toList();
      // #1273 — a level's only room is named by the level.
      final byLevel = namesSingleRoomsByLevel(ref);
      final levelName = level?.name ?? levelNameOf(ref, plan.levelId);
      for (final office in plan.offices) {
        final officeReservations = levelReservations
            .where((r) => r.officeId == office.id)
            .toList();
        for (final desk in plan.desksOf(office.id)) {
          final seats = plan.seatsOf(desk.id);
          if (seats.isEmpty) continue;
          final header =
              '${plan.officeContextName(office, levelName: levelName, byLevel: byLevel)} · ${desk.name}';
          leadingCells.add((_) => _headerCell(context, header));
          tracks.add((_) => const SizedBox(
                height: TimelineAxis.headerRowHeight,
                width: TimelineAxis.trackWidth,
              ));
          fixedHeight += TimelineAxis.headerRowHeight;
          // Whole-desk rows lane onto this desk's seats (#452).
          final deskReservations = levelReservations
              .where((r) => r.deskId == desk.id)
              .toList();
          for (final Seat seat in seats) {
            final blocks = <Reservation>[
              ...wholeLevelReservations,
              ...officeReservations,
              ...deskReservations,
              ...levelReservations.where((r) => r.seatId == seat.id),
            ];
            seatRows++;
            leadingCells.add((h) => _seatCell(context, seat, brightness, h));
            tracks.add((h) => _track(context, seat, blocks, names, brightness, h));
          }
        }
      }
    }

    // Free mode keeps rows even when nothing is booked — the hint only
    // fires when there are NO rows at all (no seats anywhere).
    if (visibleReservations.isEmpty &&
        (!widget.showFreeSeats || tracks.length <= 1)) {
      return _emptyHint(l10n, allLevels: allLevels);
    }
    // Concatenating per-level lists loses the global start order the
    // auto-scroll relies on — restore it.
    visibleReservations.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (visibleReservations.isNotEmpty) {
      _scheduleAutoScroll(visibleReservations);
    }

    final now = ref.watch(clockProvider).now();
    final isToday = DateUtils.isSameDay(now, widget.day);

    // A few seats must not leave the lower part of the screen empty: the
    // rows share the room the viewport has beyond their natural height,
    // up to a readable maximum. A long list keeps the compact rows and
    // scrolls as before.
    var rowHeight = TimelineAxis.rowHeight;
    if (seatRows > 0) {
      final natural = fixedHeight + seatRows * TimelineAxis.rowHeight;
      if (_viewportHeight > natural) {
        rowHeight = (TimelineAxis.rowHeight +
                (_viewportHeight - natural) / seatRows)
            .clamp(TimelineAxis.rowHeight, TimelineAxis.maxRowHeight);
      }
    }
    final leadingBuilt = [for (final b in leadingCells) b(rowHeight)];
    final tracksBuilt = [for (final b in tracks) b(rowHeight)];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: TimelineAxis.leadingWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: leadingBuilt,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _axisController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: TimelineAxis.trackWidth,
                child: Stack(
                  children: [
                    for (var h = 0;
                        h < TimelineAxis.hoursPerDay;
                        h += TimelineAxis.labelStepHours)
                      Positioned(
                        left: h * TimelineAxis.hourWidth,
                        top: TimelineAxis.rulerHeight,
                        bottom: 0,
                        width: 1,
                        child: ColoredBox(
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: tracksBuilt,
                    ),
                    if (isToday)
                      Positioned(
                        key: DayTimeline.nowLineKey,
                        left: _offsetOf(now),
                        top: 0,
                        bottom: 0,
                        width: TimelineAxis.nowLineWidth,
                        // IgnorePointer: ColoredBox is hit-test OPAQUE, so
                        // without it the line steals the tap from any block
                        // whose centre the wall clock is currently crossing
                        // (a running booking became untappable for a few
                        // minutes — caught as CI run #416's master flake).
                        child: IgnorePointer(
                          child: ColoredBox(color: scheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruler(BuildContext context) {
    final timeFormat = ref.watch(appFormatProvider); // #1150
    final style = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: TimelineAxis.rulerHeight,
      width: TimelineAxis.trackWidth,
      child: Stack(
        children: [
          for (var h = 0;
              h < TimelineAxis.hoursPerDay;
              h += TimelineAxis.labelStepHours)
            Positioned(
              left: h * TimelineAxis.hourWidth + 3,
              bottom: 2,
              child: Text(
                timeFormat.wallTime(_dayStart.add(Duration(hours: h))),
                style: style,
              ),
            ),
        ],
      ),
    );
  }

  /// Level-name header in all-levels mode — deliberately distinct from the
  /// muted `office · desk` group headers: titleSmall in the primary color.
  /// Tapping it collapses or expands that level's rows; the chevron shows
  /// which way the tap goes.
  Widget _levelHeaderCell(
    BuildContext context, {
    required Level level,
    required bool collapsed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return SizedBox(
      key: DayTimeline.levelHeaderKey(level.id),
      height: TimelineAxis.levelHeaderRowHeight,
      child: InkWell(
        key: const ValueKey('day-timeline-calendar-level-collapsed'),
        onTap: () => _update(() {
          if (!_collapsedLevels.remove(level.id)) {
            _collapsedLevels.add(level.id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                collapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: collapsed
                      ? (l10n.calendarLevelCollapsed(level.name))
                      : (l10n.calendarLevelExpanded(level.name)),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(BuildContext context, String label) {
    return SizedBox(
      height: TimelineAxis.headerRowHeight,
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
}
