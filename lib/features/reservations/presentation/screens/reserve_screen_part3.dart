// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'reserve_screen.dart';

// #2386 — part 3 of _ReserveScreenState, split out of reserve_screen.dart so no
// file holds the whole class.
extension _ReserveScreenStatePart3 on _ReserveScreenState {

  /// Plan view: availability of the selected window on the live-plan
  /// canvas, hub-local level chips, free-seat tap books.
  Widget _planView(
    AppLocalizations l10n,
    HalfDayWindow window, {
    required bool dayOpen,
  }) {
    final levels = ref.watch(levelsProvider).value;
    if (levels == null) {
      return const LoadingView();
    }
    if (levels.isEmpty) {
      return EmptyState(
        icon: Icons.map_outlined,
        title: l10n.planNoLevels,
      );
    }
    // #687 — the hub is the only map surface, so the floor it shows is
    // the member's PERSISTED default (#159) when nothing has been
    // browsed. The browsed choice still wins while set.
    //
    // #1269 — and when that choice is "All levels", this view RESOLVES
    // it without WRITING over it. The plan cannot show two floors at
    // once, so it falls back to the default and draws one — but the
    // value stays what the member set, and the day view finds its chip
    // exactly as it was left. A view that cannot honour a shared value
    // must never destroy it.
    final browsed = ref.watch(browsedLevelProvider);
    final wanted = browsed == BrowsedLevel.allLevels ? null : browsed;
    final level = levels
            .where((l) =>
                l.id == (wanted ?? ref.watch(selectedLevelIdProvider).value))
            .firstOrNull ??
        levels.first;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    // The window may straddle TWO device-day keys (a workspace-clock full day
    // starts before the device midnight west of the workspace); reading only
    // dayKeyOf(start) misses those bookings — the reservation-shows-on-Plan-
    // not-on-Reserve bug. Fetch every key the window touches and merge by id.
    // #1848 — a window whose read failed is unavailable, never all free.
    if (reservationsUnavailableAcrossWindow(ref, window.start, window.end)) {
      return AvailabilityUnavailableBanner(
          onRetry: () =>
              retryReservationsAcrossWindow(ref, window.start, window.end));
    }
    final reservations =
        reservationsAcrossWindow(ref, window.start, window.end);
    final names = ref.watch(memberNamesProvider).value ?? const {};

    // Floor switcher floats over the canvas (indoor-maps idiom, UX
    // pass) — hub-local browsing state (#187), never the plan tab's
    // persisted default (#159).
    final selector = LevelSelector(
              key: const ValueKey('reserve-layers'),
              keyPrefix: 'reserve',
              levels: levels,
              current: level,
              onSelected: (id) {
                // Changing floor answers the question the highlight was
                // asking, so the ring goes with it.
                _clearFocus();
                ref.read(browsedLevelProvider.notifier).select(id);
                recordTaskStep(ref, RecorderActions.selectLevel); // #1881
                // #687/#159 — and it STICKS. Choosing a floor used to be
                // browsing-only here because the Plan tab owned the
                // stored default; with that tab gone, a member who works
                // on the second floor would have re-picked it on every
                // launch forever.
                unawaited(
                  ref.read(selectedLevelIdProvider.notifier).select(id),
                );
              },
              // #466: the whole-level booking button, Plan-tab parity —
              // the hub only had the hidden double-tap path.
              trailing: _levelReserveVisible(level)
                  ? IconButton(
                      key: const ValueKey('reserve-reserve-level'),
                      tooltip: lexiconText(context,
                          key: 'levelReserveButton',
                          fallback: context.l10n
                                  .levelReserveButton),
                      icon: const Icon(Icons.layers_outlined),
                      onPressed: () {
                        final plan =
                            ref.read(floorPlanProvider(level.id)).value;
                        final window = _effectiveWindow(_granularity);
                        unawaited(showSpaceSheet(
                          context,
                          kind: SpaceKind.level,
                          level: level,
                          plan: plan,
                          initialWindow:
                              (start: window.start, end: window.end),
                          // #687 — the level button is the OWNER's
                          // assignment path (#638). With no roster it
                          // silently degraded to "book this floor for
                          // myself".
                          members: spaceAssignmentCandidates(ref),
                        ));
                      },
                    )
                  : null,
            );
    return Stack(
      children: [
        Positioned.fill(child: Column(
      children: [
        if (_seatList) Align(alignment: Alignment.topRight, child: selector),
        Expanded(
          // #209/#611 — map and list CROSS-FADE rather than swapping
          // hard. Outside any InteractiveViewer, so pan/zoom is
          // untouched by the transition.
          child: AnimatedSwitcher(
            duration: AppMotion.viewSwitchOf(context),
            child: switch (planAsync) {
            // #687 — the list answers "which seat can I take"; the map
            // answers "where is it". Same data, same tap handler, same
            // closed-day gate.
            //
            // KeyedSubtree so the AnimatedSwitcher above sees a new
            // child and cross-fades (#209) instead of swapping hard.
            AsyncData(value: final plan) when _seatList => KeyedSubtree(
                key: const ValueKey('reserve-list-view'),
                child: SeatListView(
                plan: plan,
                reservations: reservations,
                names: names,
                at: window.start,
                // Live judges at the instant, browsing across the window
                // — the same split the canvas and the tap handler use.
                windowEndOrNull: _isLive ? null : window.end,
                dayOpen: dayOpen,
                  onSeatTap: (seat) {
                    recordTaskStep(ref, RecorderActions.selectResource, // #1865
                        payload: const {'view_mode': 'list', 'resource_kind': 'desk'},
                        values: resourceValues(seat.name));
                    unawaited(onSeatTap(plan, seat, reservations, window));
                  },
                  onSpaceTap: listSpaceTap(context, ref,
                      level: level, plan: plan, window: window),
                ),
              ),
            AsyncData(value: final plan) => ReserveCanvas(
                key: const ValueKey('reserve-canvas-view'),
                plan: plan,
                level: level,
                reservations: reservations,
                window: window,
                dayOpen: dayOpen,
                day: _dayWindow(window.start),
                focus: (
                  seatId: _focusSeatId,
                  deskId: _focusDeskId,
                  officeId: _focusOfficeId,
                  level: _focusLevel,
                ),
                onSeatTap: (seat) {
                  recordTaskStep(ref, RecorderActions.selectResource, // #1865
                      payload: const {'view_mode': 'plan', 'resource_kind': 'desk'},
                      values: resourceValues(seat.name));
                  unawaited(onSeatTap(plan, seat, reservations, window));
                },
              ),
            // #2011 — the floor plan could not be read: say so and offer
            // Retry; the level selector stays, so the level is kept.
            AsyncError() => Padding(
                padding: const EdgeInsets.all(16),
                child: InlineBanner(
                  key: const ValueKey('reserve-plan-unavailable'),
                  icon: Icons.cloud_off_outlined,
                  text: l10n.workspaceGenericError,
                  actionLabel: l10n.reserveStaleRetry,
                  onAction: () => ref.invalidate(floorPlanProvider(level.id)),
                ),
              ),
            _ => const LoadingView(),
            },
          ),
        ),
      ],
    )),
        if (!_seatList) Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: selector,
          ),
      ],
    );
  }

  /// Whether [level] offers the whole-level booking affordance to ME —
  /// the plan tab's #466 rule: feature on, level bookable, and I hold
  /// the grant OR administer (the 0079 server rule).
  bool _levelReserveVisible(Level level) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    if (!features.contains(WorkspaceFeature.levelBooking)) return false;
    if (!level.bookableAsWhole) return false;
    final me = ref.watch(myMemberProvider).value;
    if (me == null || me.status != MemberStatus.active) return false;
    return me.canReserveLevel || ref.watch(actsForReservationsProvider);
  }

  /// Day view: the selected day's per-seat timeline in everyone mode —
  /// see who else is booked; own blocks open the detail sheet.
  Widget _dayView() {
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final dayKey = dayKeyOf(_selectedDay);
    final dayRead = ref.watch(reservationsForDayProvider(dayKey));
    if (dayRead.hasError && !dayRead.hasValue) {
      return AvailabilityUnavailableBanner(
          onRetry: () => ref.invalidate(reservationsForDayProvider(dayKey)));
    }
    final reservations = dayRead.value ?? const <Reservation>[];
    final active = [for (final r in reservations) if (r.held) r];
    return DayTimeline(
      day: _selectedDay,
      reservations: active,
      everyone: true,
      myMemberId: myMemberId,
      onReservationTap: _detailSheet,
      // The hub's Day view is an AVAILABILITY surface: every seat row
      // renders, and tapping a row's free area books the selected
      // window on that seat (no more look-but-can't-book).
      showFreeSeats: true,
      dayOpen: _dayOpenOn(_selectedDay),
      onFreeSeatTap: (seat) => bookingSheet(
        seat,
        active,
        _effectiveWindow(_granularity),
      ),
    );
  }

  bool _dayOpenOn(DateTime day) => _isDayOpen?.call(day) ?? true;

  /// Week view (#236): the whole ISO week around the selected day as a
  /// seat × day grid. Reservations come from the month provider(s)
  /// covering the week — BOTH months when the week straddles a boundary —
  /// and the grid slices them per day itself (never seven per-day
  /// fetches). Tapping a day header selects the day and switches to the
  /// Day view.
  Widget _weekView() {
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final monday = WeekGrid.weekStartOf(_selectedDay);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final monthKeys = {monthKeyOf(monday), monthKeyOf(sunday)};
    // De-duplicated by id: a reservation crossing the month boundary is
    // returned by both month windows.
    final byId = <String, Reservation>{};
    var unavailable = false;
    for (final key in monthKeys) {
      final read = ref.watch(reservationsForMonthProvider(key));
      unavailable |= read.hasError && !read.hasValue;
      for (final r in read.value ?? const <Reservation>[]) {
        byId[r.id] = r;
      }
    }
    if (unavailable) {
      return AvailabilityUnavailableBanner(onRetry: () {
        for (final key in monthKeys) {
          ref.invalidate(reservationsForMonthProvider(key));
        }
      });
    }
    return WeekGrid(
      key: const ValueKey('reserve-week-grid'),
      selectedDay: _selectedDay,
      reservations: [
        for (final r in byId.values)
          if (r.held) r,
      ],
      everyone: true,
      myMemberId: myMemberId,
      onDaySelected: (day) {
        _selectDay(day);
        _update(() => _view = ReserveView.day);
      },
      onReservationTap: _detailSheet,
      isDayOpen: _isDayOpen,
      onFreeSlotTap: (seat, day, {required morning}) {
        final window = weekTapWindow(
          day: day,
          morning: morning,
          granularity: _granularity,
          current: _effectiveWindow(_granularity),
          defaultEndFor: _defaultEndFor,
        );
        unawaited(bookingSheet(seat, byId.values.toList(), window));
      },
    );
  }

  /// Month view (#7): the selected day's month as an availability
  /// calendar — free desks per day across ALL floors. Tapping a day
  /// selects it and drops into the Day view, where occupants are named.
  Widget _monthView() {
    final monthKey = monthKeyOf(_selectedDay);
    final read = ref.watch(reservationsForMonthProvider(monthKey));
    if (read.hasError && !read.hasValue) {
      return AvailabilityUnavailableBanner(
          onRetry: () => ref.invalidate(reservationsForMonthProvider(monthKey)));
    }
    final month = read.value ?? const <Reservation>[];
    return MonthGrid(
      key: const ValueKey('reserve-month-grid'),
      selectedDay: _selectedDay,
      reservations: [for (final r in month) if (r.held) r],
      isDayOpen: _isDayOpen,
      onDaySelected: (day) {
        _selectDay(day);
        _update(() => _view = ReserveView.day);
      },
    );
  }
}
