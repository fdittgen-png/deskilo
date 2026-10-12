// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'reserve_screen.dart';

// #2386 — part 1 of _ReserveScreenState, split out of reserve_screen.dart so no
// file holds the whole class.
extension _ReserveScreenStatePart1 on _ReserveScreenState {
  // The seat-action half of this screen lives in ReserveSeatActions —
  // the Plan tab's job, ported when that tab was deleted. These are what
  // it needs from the hub; the live/browsing distinction above all,
  // because it changes what a tap MEANS.
  bool get _isLiveImpl => _isLive;

  BookingGranularity get _granularityImpl => _granularity;

  HalfDayWindow get _bookingWindowImpl => _effectiveWindow(_granularity);

  bool _isWorkspaceOpenAtImpl(DateTime at) => _isWorkspaceOpenAt(at);

  // #1301 S4, widened by #1580: waiting on two of the five reads a
  // window is judged against let one be measured against invented hours.
  bool get _availabilityKnownImpl => !bookingDataPending(ref);

  DateTime _defaultEndForImpl(DateTime from) => _defaultEndFor(from);

  DateTime _lastSlotOfImpl(DateTime day) => _lastSlotOf(day);

  Future<void> _openReservationImpl(Reservation reservation) =>
      _detailSheet(reservation);

  /// The day's last selectable slot: 23:45 of [day], on the WORKSPACE
  /// clock (#490).
  DateTime _lastSlotOf(DateTime day) => WorkspaceTime.at(
        day.year,
        day.month,
        day.day,
        ReserveHubMetrics.lastSlotHour,
        ReserveHubMetrics.lastSlotMinute,
      );

  /// Snaps [t] down to the previous slot of the workspace's configured
  /// step (#184 pattern; 0032 makes the step owner-configurable).
  DateTime _snapToSlot(DateTime t) {
    final local = WorkspaceTime.wall(t);
    final snap = _granularity.stepMinutes ?? ReserveHubMetrics.snapMinutes;
    final m = (local.hour * 60 + local.minute) ~/ snap * snap;
    return WorkspaceTime.at(
        local.year, local.month, local.day, m ~/ 60, m % 60);
  }

  /// Default window end for a start at [from]: the default stay, clamped
  /// to the day's last slot — and never at/before [from].
  DateTime _defaultEndFor(DateTime from) {
    var end = from.add(ReserveHubMetrics.defaultStay);
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) end = from.add(_slotStep);
    return end;
  }

  /// The window the hub currently browses/books, always on [_selectedDay].
  /// Explicit choice wins; otherwise half-day granularity defaults to
  /// the member's preferred period (#586, full day when none is set)
  /// and flexible to "now"-anchored times of day.
  HalfDayWindow _effectiveWindow(BookingGranularity granularity) {
    final start = _windowStart;
    final end = _windowEnd;
    if (start != null && end != null) return (start: start, end: end);
    if (granularity.isDayBased) {
      return defaultWindowFor(
        ref.read(defaultPeriodProvider).value,
        _selectedDay,
      );
    }
    final now = _snapToSlot(ref.read(clockProvider).now());
    final from = WorkspaceTime.at(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      now.hour,
      now.minute,
    );
    return (start: from, end: _defaultEndFor(from));
  }

  // ── day selection (strip · calendar icon · week-grid headers) ──


  /// Central day switch: re-maps the window onto the new day (canonical
  /// half re-derived under half-day granularity, times of day kept under
  /// flexible — plan's date-button behaviour, #184/#201). The week grid
  /// needs no syncing: it re-derives its week from [_selectedDay].
  void _selectDay(DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (DateUtils.isSameDay(dayOnly, _selectedDay)) return;
    recordTaskStep(ref, RecorderActions.selectDate, // #1865
        payload: {'date_relation': dateRelation(dayOnly, _today)},
        values: dayValues(dayOnly));
    final granularity = _granularity;
    final window = _effectiveWindow(granularity);
    DateTime? from;
    DateTime? to;
    if (_windowStart != null && _windowEnd != null) {
      if (granularity.isDayBased) {
        final builder =
            _matchingHalfDayBuilder(_selectedDay, window) ??
                HalfDayWindows.fullDay;
        final moved = builder(dayOnly);
        from = moved.start;
        to = moved.end;
      } else {
        from = WorkspaceTime.at(
          dayOnly.year,
          dayOnly.month,
          dayOnly.day,
          window.start.hour,
          window.start.minute,
        );
        var kept = WorkspaceTime.at(
          dayOnly.year,
          dayOnly.month,
          dayOnly.day,
          window.end.hour,
          window.end.minute,
        );
        if (!kept.isAfter(from)) kept = _defaultEndFor(from);
        to = kept;
      }
    }
    _update(() {
      _selectedDay = dayOnly;
      _windowStart = from;
      _windowEnd = to;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: _today,
      lastDate: _today.add(
        const Duration(days: ReserveHubMetrics.datePickerRangeDays),
      ),
    );
    if (picked == null) return;
    if (!mounted) return;
    _selectDay(picked);
  }

  // ── window chips (plan header patterns #184/#201) ──

  Future<void> _pickFrom() async {
    final window = _effectiveWindow(_granularity);
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(WorkspaceTime.wall(window.start)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final duration = window.end.difference(window.start);
    final from = _snapToSlot(WorkspaceTime.at(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      picked.hour,
      picked.minute,
    ));
    var end = from.add(duration);
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) end = from.add(_slotStep);
    _update(() {
      _windowStart = from;
      _windowEnd = end;
    });
    recordTaskStep(ref, RecorderActions.selectPeriod, // #1865
        payload: const {'period': 'custom'}, values: periodValues(from, end));
  }

  Future<void> _pickTo() async {
    final window = _effectiveWindow(_granularity);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(WorkspaceTime.wall(window.end)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final l10n = context.l10n;
    final from = window.start;
    final fromWall = WorkspaceTime.wall(from);
    final end = _snapToSlot(WorkspaceTime.at(
      fromWall.year,
      fromWall.month,
      fromWall.day,
      picked.hour,
      picked.minute,
    ));
    if (!end.isAfter(from)) {
      AppSnack.error(
        context,
        l10n.planEndBeforeStart,
        replace: true,
      );
      return;
    }
    _update(() {
      _windowStart = from;
      _windowEnd = end;
    });
  }

  /// #772 — whether the BROWSED window contains this very moment (in
  /// workspace wall time): choosing the Morning chip during the morning
  /// still means "I could be sitting here now", so the booking sheet
  /// offers to check in right away — without turning the tap into a
  /// walk-up (a hand-picked window must stay bookable as picked).
  bool get _windowIsNowImpl {
    if (!_selectedDay.isAtSameMomentAs(_today)) return false;
    // #1082 — compare INSTANTS. This used to take `raw.hour`/`.minute`
    // — the DEVICE's wall clock — and hand them to WorkspaceTime.at as
    // if they were the space's, so at 09:00 in New York (15:00 in Paris)
    // the Morning chip read as live and offered "check in right away"
    // for a half-day that ended three hours ago, while the Afternoon
    // chip the member was actually sitting in was refused.
    //
    // The window bounds are already workspace-anchored absolute
    // instants, and `now` is an absolute instant, so no wall-clock
    // reconstruction is needed at all: comparing them directly is right
    // in every timezone, which is why there is no WorkspaceTime call
    // left here.
    final now = ref.read(clockProvider).now();
    final window = _effectiveWindow(_granularity);
    return !now.isBefore(window.start) && now.isBefore(window.end);
  }

  /// Applies a pending "Show on plan" jump (#182/#576).
  ///
  /// It lands HERE now that the hub is the only map surface. PlanCanvas
  /// has always taken the highlight parameters; the hub simply never
  /// passed them, because the Plan tab owned the jump.
  void _applyFocus(PlanFocus focus) {
    // A "show on plan" jump names a floor, and the other views should
    // follow it: the member asked to be taken somewhere.
    ref.read(browsedLevelProvider.notifier).select(focus.levelId);
    _update(() {
      _view = ReserveView.plan;
      _focusSeatId = focus.seatId;
      _focusDeskId = focus.deskId;
      _focusOfficeId = focus.officeId;
      _focusLevel = focus.wholeLevel;
    });
    final at = focus.at;
    // Only a FUTURE instant moves the browsed day: jumping to a booking
    // that already ended should show WHERE it was, not send the hub back
    // in time to a day nobody asked for.
    if (at != null && at.isAfter(ref.read(clockProvider).now())) {
      _update(() {
        _selectedDay = WorkspaceTime.dateOf(at);
        // Provisional (#184): the reservation's own end is not on the
        // focus, so the window opens at its start with the default stay
        // and is refined below once the day's bookings resolve.
        _windowStart = at;
        _windowEnd = _defaultEndFor(at);
      });
      unawaited(_resolveFocusWindow(focus, at));
    }
    // Cleared after the frame: mutating the provider inside its own
    // change notification re-enters the listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(planFocusControllerProvider.notifier).clear();
    });
  }

  /// #184 — widens the focus window to the jumped-to reservation's own
  /// `[startsAt, endsAt)` once the day's bookings arrive.
  ///
  /// Ported with the Plan tab's job: without it the hub browses a
  /// default-length window at the right start, so a two-hour booking
  /// shows as one and the plan disagrees with the sheet that sent you.
  ///
  /// Whole-space jumps carry no seat and keep the default window —
  /// there is no single reservation whose hours to adopt.
  Future<void> _resolveFocusWindow(PlanFocus focus, DateTime from) async {
    final seatId = focus.seatId;
    if (seatId == null) return;
    final List<Reservation> reservations;
    try {
      reservations =
          await ref.read(reservationsForDayProvider(dayKeyOf(from)).future);
    } on Object catch (e, st) {
      debugPrint('focus window resolution failed: $e\n$st');
      TraceLogger.instance.error(
        'reservations',
        'focus window resolution failed',
        error: e,
        stackTrace: st,
      );
      return;
    }
    // They may have moved on while the day was loading.
    if (!mounted || _windowStart != from) return;
    final covering = reservations
        .where((r) => r.seatId == seatId && r.coversInstant(from))
        .firstOrNull;
    if (covering == null) return;
    var end = covering.endsAt;
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) return;
    _update(() => _windowEnd = end);
  }

  /// Drops the jump highlight. Any interaction that changes what is being
  /// looked at means the question "where is it" has been answered.
  void _clearFocus() {
    if (_focusSeatId == null &&
        _focusDeskId == null &&
        _focusOfficeId == null &&
        !_focusLevel) {
      return;
    }
    _update(() {
      _focusSeatId = null;
      _focusDeskId = null;
      _focusOfficeId = null;
      _focusLevel = false;
    });
  }

  bool _isWorkspaceOpenAt(DateTime at) {
    final openWeekdays = ref.read(openWeekdaysProvider).value;
    final closures = ref.read(closureDaysProvider).value;
    if (openWeekdays == null || closures == null) return false;
    return isWorkspaceOpenOn(WorkspaceTime.dateOf(at), openWeekdays, closures);
  }

  /// Forward to the shared mapper with this screen's slot size
  /// (maintainability audit: the 42-line switch was pasted per screen).


  // ── Plan view: seat tap → shared booking sheet (#206) ──


  /// Detail sheet + "Show on plan" jump — via the shared helper that
  /// owns the popped-target handling (#182/#206/#422).
  Future<void> _detailSheet(Reservation reservation) =>
      showReservationDetail(context, ref, reservation);
}
