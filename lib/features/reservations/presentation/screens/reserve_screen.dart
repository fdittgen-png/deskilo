// SPDX-License-Identifier: 0BSD

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/motion.dart';
import '../../../../core/ui/view_toggle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calendar/presentation/widgets/day_timeline.dart';
import '../../../members/providers/directory_providers.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/seat_occupancy.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/member.dart';
import '../../domain/booking_error_text.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/default_booking_period.dart';
import '../../domain/reservation.dart';
import '../../domain/seat_state_logic.dart';
import '../../providers/default_period_controller.dart';
import '../../providers/reservation_providers.dart';
import '../../domain/space_code.dart';
import '../widgets/booking_controls.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/series_result_dialog.dart';
import '../widgets/space_scan.dart';
import '../widgets/reservation_detail_sheet.dart';
import '../widgets/month_grid.dart';
import '../widgets/week_grid.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';

/// Geometry and ranges of the Reserve hub (#208). Pinned by test — treat
/// these as part of the visual/behavioural contract, not free-floating
/// magic numbers.
abstract final class ReserveHubMetrics {
  /// Day pills on the date strip, starting today.
  static const int stripDayCount = 14;

  /// Height of the date-strip row (fits the two-line day pills). Trimmed
  /// from 76 (screenshot feedback 2026-07-20) — the compact chips fit the
  /// weekday + day-number stack in less vertical space.
  static const double stripHeight = 58;

  /// Furthest day (from today) reachable via the strip's calendar icon.
  static const int datePickerRangeDays = 365;

  /// Snapping of the from→to window chips (#184 pattern): 15-minute steps.
  static const int snapMinutes = 15;

  /// Default window length before capping (mirrors the plan's stay).
  static const Duration defaultStay = Duration(hours: 4);

  /// Latest selectable window end within a day (#184 pattern): 23:45.
  static const int lastSlotHour = 23;
  static const int lastSlotMinute = 45;
}

/// The three hub views under the date strip and window chips.
enum _ReserveView { plan, day, week, month }

/// Reserve hub (#208, epic #204): full-screen route pushed by the bottom
/// bar's raised centre button (#207). Top→bottom: a horizontal date-pill
/// strip (+ calendar icon for further dates) driving the selected day;
/// granularity-aware window chips (half-day Morning/Afternoon/Full day per
/// #201, else from→to clock chips per #184/#185); and a Plan · Day · Week
/// switch. Plan mirrors the live plan canvas for the selected window (free
/// seat tap books via the shared [BookingSheet], #206); Day shows the
/// everyone-mode [DayTimeline]; Week shows the selected day's whole ISO
/// week as a seat × day occupancy grid (#236) — tapping a day header
/// selects that day and jumps to its Day view.
///
/// Deliberately forward-looking reserve + visibility only: no walk-up
/// check-in, no check-out, no seat blocking and no series booking here —
/// those stay on the Plan tab and the existing flows.
class ReserveScreen extends ConsumerStatefulWidget {
  const ReserveScreen({super.key});


  @override
  ConsumerState<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends ConsumerState<ReserveScreen> {
  /// Local midnight of the day the hub opened on — the first pill of the
  /// date strip.
  late final DateTime _today;

  /// Local midnight of the browsed day (date strip / week-grid headers).
  late DateTime _selectedDay;

  /// Explicit window choice on [_selectedDay]; null until the user picks
  /// one — the effective window then falls back to a default (full day
  /// under half-day granularity, "now"-anchored default stay otherwise).
  DateTime? _windowStart;
  DateTime? _windowEnd;

  _ReserveView _view = _ReserveView.plan;

  /// Level chip choice of the Plan view — local browsing state, never the
  /// plan tab's persisted default (DayTimeline pattern, #187).
  String? _levelId;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    // #490 — "today" is the WORKSPACE's date, not the device's.
    _today = WorkspaceTime.dateOf(now);
    _selectedDay = _today;
  }

  // ── window derivation (mirrors plan_screen's #184/#201 mechanics) ──

  /// Booking granularity of the active workspace (#200/#201). Loading or
  /// unknown reads as flexible, like the plan header.
  BookingGranularity get _granularity =>
      ref.read(bookingGranularityProvider).value ??
      BookingGranularity.flexible;

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

  /// One configured slot — the minimal booking extension.
  Duration get _slotStep => Duration(
        minutes: _granularity.stepMinutes ?? ReserveHubMetrics.snapMinutes,
      );

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

  /// The canonical builder whose window on [day] the current window
  /// matches — null when none does (#201 pattern).
  HalfDayWindow Function(DateTime day)? _matchingHalfDayBuilder(
    DateTime day,
    HalfDayWindow window,
  ) {
    const builders = [
      HalfDayWindows.morning,
      HalfDayWindows.afternoon,
      HalfDayWindows.fullDay,
    ];
    for (final builder in builders) {
      final candidate = builder(day);
      if (window.start == candidate.start && window.end == candidate.end) {
        return builder;
      }
    }
    return null;
  }

  // ── day selection (strip · calendar icon · week-grid headers) ──


  /// Central day switch: re-maps the window onto the new day (canonical
  /// half re-derived under half-day granularity, times of day kept under
  /// flexible — plan's date-button behaviour, #184/#201). The week grid
  /// needs no syncing: it re-derives its week from [_selectedDay].
  void _selectDay(DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (DateUtils.isSameDay(dayOnly, _selectedDay)) return;
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
    setState(() {
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
    setState(() {
      _windowStart = from;
      _windowEnd = end;
    });
  }

  Future<void> _pickTo() async {
    final window = _effectiveWindow(_granularity);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(WorkspaceTime.wall(window.end)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
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
        l10n?.planEndBeforeStart ?? 'End must be after start.',
        replace: true,
      );
      return;
    }
    setState(() {
      _windowStart = from;
      _windowEnd = end;
    });
  }

  // ── availability + error mapping (plan parity, #186/#201) ──

  /// Whether the workspace is open on the local day of [at] (#186).
  /// Unknown (providers still loading or errored) counts as open — the
  /// server guard stays the authority.
  bool _isWorkspaceOpenAt(DateTime at) {
    final openWeekdays = ref.read(openWeekdaysProvider).value;
    final closures = ref.read(closureDaysProvider).value;
    if (openWeekdays == null || closures == null) return true;
    return isWorkspaceOpenOn(WorkspaceTime.dateOf(at), openWeekdays, closures);
  }

  /// Forward to the shared mapper with this screen's slot size
  /// (maintainability audit: the 42-line switch was pasted per screen).
  String _errorText(AppLocalizations? l10n, Object error, String fallback) =>
      bookingErrorText(l10n, error, fallback,
          stepMinutes: _granularity.stepMinutes);


  // ── Plan view: seat tap → shared booking sheet (#206) ──

  Future<void> _onSeatTap(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    HalfDayWindow window,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Closed day (#186): no sheet at all — the server would reject any
    // booking touching it (`assert_workspace_open`, migration 0013).
    if (!_isWorkspaceOpenAt(window.start)) {
      AppSnack.info(
        context,
        l10n?.planClosedDay ?? 'Closed on this day',
        replace: true,
      );
      return;
    }
    final myMemberId = ref.read(myMemberProvider).value?.id;
    final state = seatStateInRange(
      plan: plan,
      seat: seat,
      reservations: reservations,
      myMemberId: myMemberId,
      from: window.start,
      to: window.end,
    );
    switch (state) {
      case SeatState.blocked:
        // No blocking management here — that stays on the Plan tab (#161).
        AppSnack.info(
          context,
          l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.',
          replace: true,
        );
      case SeatState.free:
        await _bookingSheet(seat, reservations, window, plan: plan);
      case SeatState.mine:
        final mine = reservationOnSeatInRange(
          plan: plan,
          seat: seat,
          reservations: reservations,
          from: window.start,
          to: window.end,
        );
        // Visibility, not management: the detail sheet (#206) shows where
        // the seat is; cancelling stays in the existing calendar/plan
        // flows.
        if (mine != null) await _detailSheet(mine);
      case SeatState.reserved:
      case SeatState.occupied:
        final other = reservationOnSeatInRange(
          plan: plan,
          seat: seat,
          reservations: reservations,
          from: window.start,
          to: window.end,
        );
        if (other == null) return;
        final names = ref.read(memberNamesProvider).value ?? const {};
        final name = names[other.memberId] ?? '';
        final template = state == SeatState.occupied
            ? (l10n?.planOccupiedBy(name) ?? 'Occupied by $name')
            : (l10n?.planReservedBy(name) ?? 'Reserved by $name');
        final until =
            DateFormat.Hm().format(WorkspaceTime.wall(other.endsAt));
        AppSnack.info(
          context,
          '$template · ${l10n?.planUntil(until) ?? 'until $until'}',
          replace: true,
        );
    }
  }

  /// Punctual reservation over the browsed window via the shared
  /// [BookingSheet] (#206) — never a walk-up, never a series, never a
  /// maintenance block (those stay on the Plan tab).
  /// The plan containing [seatId] — the Day/Week hub surfaces span all
  /// levels, so a tapped seat's plan is resolved from the loaded plans
  /// (#452: the next-reservation cap needs it for whole-space rows).
  FloorPlan? _planContaining(String seatId) {
    final levels = ref.read(levelsProvider).value ?? const [];
    for (final level in levels) {
      final plan = ref.read(floorPlanProvider(level.id)).value;
      if (plan != null && plan.seats.any((s) => s.id == seatId)) return plan;
    }
    return null;
  }

  Future<void> _bookingSheet(
    Seat seat,
    List<Reservation> reservations,
    HalfDayWindow window, {
    FloorPlan? plan,
  }) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    // Defense in depth (#161): the tap handler never routes blocked seats
    // here, but a stale plan could — the RPCs reject them anyway.
    if (seat.isBlockedAt(window.start)) {
      AppSnack.info(
        context,
        l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.',
        replace: true,
      );
      return;
    }
    final myMemberId = ref.read(myMemberProvider).value?.id;
    final dayBased = _granularity.isDayBased;
    // Cap by the next reservation on the seat (plan parity): a
    // range-filtered free seat cannot be capped below the window, but a
    // stale plan could.
    // Whole-space rows need the seat's plan; without one the cap is
    // skipped — the server re-checks every booking anyway.
    final seatPlan = plan ?? _planContaining(seat.id);
    final next = seatPlan == null
        ? null
        : nextReservationOnSeat(
            plan: seatPlan,
            seat: seat,
            reservations: reservations,
            at: window.start,
          );
    var end = window.end;
    var capped = false;
    if (next != null && next.startsAt.isBefore(end)) {
      end = next.startsAt;
      capped = true;
    }

    final choice = await showModalBottomSheet<BookingChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => BookingSheet(
        seatId: seat.id,
        seatName: seat.name,
        start: window.start,
        initialEnd: end,
        cap: next?.startsAt,
        capped: capped,
        granularity: _granularity,
        walkUp: false,
        fixedEnd: dayBased,
        members: const [],
        myMemberId: myMemberId,
        // Series is available from the hub too now (was Plan-only): the
        // repeat picker shows when the workspace enables it.
        allowSeries: ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.seriesBooking),
        allowBlocking: false,
      ),
    );
    if (choice == null || !mounted) return;

    try {
      if (choice.pattern == null) {
        await ref.read(reservationRepositoryProvider).create(
              workspaceId: workspace.id,
              seatId: seat.id,
              startsAt: choice.start,
              endsAt: choice.end,
              checkIn: false,
            );
      } else {
        final result =
            await ref.read(reservationRepositoryProvider).createSeries(
                  workspaceId: workspace.id,
                  seatId: seat.id,
                  firstStart: choice.start,
                  firstEnd: choice.end,
                  pattern: choice.pattern!,
                  until: choice.until!,
                );
        if (mounted) await showSeriesResultDialog(context, result);
      }
    } catch (e, st) {
      debugPrint('reserve hub booking failed: $e\n$st');
      TraceLogger.instance
          .error('reserve', 'booking failed', error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        _errorText(
          l10n,
          e,
          l10n?.reserveBookingFailed ??
              'Could not reserve — the seat may have just been taken.',
        ),
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    invalidateBookingData(ref);
  }

  /// Detail sheet + "Show on plan" jump — via the shared helper that
  /// owns the popped-target handling (#182/#206/#422).
  Future<void> _detailSheet(Reservation reservation) =>
      showReservationDetail(context, ref, reservation);

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watched so the chips swap once the rule resolves (#201) — flexible
    // is also the rule's default, so nothing flashes.
    final granularity = ref.watch(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
    final window = _effectiveWindow(granularity);

    // Closed day (#186): banner + gated booking. Watched (not the
    // read-based [_isWorkspaceOpenAt]) so the hub reacts to availability
    // edits; unknown while loading counts as open.
    final openWeekdays = ref.watch(openWeekdaysProvider).value;
    final closures = ref.watch(closureDaysProvider).value;
    final dayOpen = openWeekdays == null ||
        closures == null ||
        isWorkspaceOpenOn(_selectedDay, openWeekdays, closures);

    // No own AppBar: the hub lives inside the shell (bottom bar always
    // visible); the shell's app bar carries the 'Reserve' title.
    // In landscape the controls move to a side panel so the view (level,
    // week grid, month) fills the rest of the screen.
    // Space refactor: ONE control row under the date strip — view
    // toggle, window controls and level picker share it (all shared
    // widgets, booking_controls.dart), horizontally scrollable so every
    // segment keeps its 48dp target (#284 idiom). Two header rows total
    // instead of four; the view below gets the difference.
    Widget header() {
      final controls = <Widget>[
              ViewToggle<_ReserveView>(
              key: const ValueKey('reserve-view-switch'),
              options: [
                ViewToggleOption(
                  value: _ReserveView.plan,
                  icon: Icons.map_outlined,
                  tooltip: l10n?.tabPlan ?? 'Plan',
                ),
                ViewToggleOption(
                  value: _ReserveView.day,
                  icon: Icons.view_timeline_outlined,
                  tooltip: l10n?.reserveDayView ?? 'Day',
                ),
                ViewToggleOption(
                  value: _ReserveView.week,
                  icon: Icons.view_week_outlined,
                  tooltip: l10n?.reserveWeekView ?? 'Week',
                ),
                ViewToggleOption(
                  value: _ReserveView.month,
                  icon: Icons.calendar_month_outlined,
                  tooltip: l10n?.reserveMonthView ?? 'Month',
                ),
              ],
              selected: _view,
              // No re-entry syncing needed since #236: the week grid
              // derives its week from the selected day on every build.
              onChanged: (view) => setState(() => _view = view),
            ),
            // One date affordance (UX pass): the 7-day pill strip was
            // redundant with the calendar picker — a chip naming the
            // selected day opens it.
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: TextButton(
                key: const ValueKey('reserve-date-button'),
                onPressed: _pickDate,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_month_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(DateFormat.MMMd().format(_selectedDay)),
                ]),
              ),
            ),
            // Space QR scan (field request): a desk/office/level card
            // opens that space's permitted actions. Feature-gated since
            // the hierarchy pass.
            if (ref
                .watch(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.spaceQrCodes))
            IconButton(
              key: const ValueKey('reserve-scan-button'),
              tooltip: l10n?.spaceScanTitle ?? 'Scan a space code',
              icon: const Icon(Icons.qr_code_scanner_outlined),
              onPressed: () => scanSpace(context, ref),
            ),
            // Honest controls: the window chips act on Plan (state
            // filter + booking window) and Day (the window a free-row
            // tap books). Week books per tapped half, Month is an
            // overview — no chips.
            if (_view == _ReserveView.plan || _view == _ReserveView.day)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: WindowControls(
                  keyPrefix: 'reserve',
                  granularity: granularity,
                  day: _selectedDay,
                  isSelected: (w) =>
                      window.start == w.start && window.end == w.end,
                  onPickWindow: (w) => setState(() {
                    _windowStart = w.start;
                    _windowEnd = w.end;
                  }),
                  from: window.start,
                  to: window.end,
                  onPickFrom: _pickFrom,
                  onPickTo: _pickTo,
                ),
              ),
      ];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // #606 — the hub's contextual how-to; gated inside the widget.
          // #611 — MotionReveal eases it (and the closed-day banner
          // below) in/out instead of popping; call-site wrap only.
          const MotionReveal(child: HelpHint(HelpHintId.reserve)),
          MotionReveal(
            child: dayOpen
                ? const SizedBox.shrink(
                    key: ValueKey('reserve-open-day'))
                : _closedDayBanner(l10n),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.xs,
            ),
            // A Wrap, never a scroll: every control stays visible at
            // any width; narrow phones flow onto a second line.
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: controls,
            ),
          ),
        ],
      );
    }
    final content = Expanded(
            // #209: cross-fade the Plan/Day/Week toggle. Distinct subtree
            // keys make the switcher animate the swap; the fade stays
            // OUTSIDE the canvas's InteractiveViewer transform.
            // #611 — fade-through style: the incoming view also scales
            // 0.97→1, per the M3 top-level-switch pattern.
            child: AnimatedSwitcher(
              duration: AppMotion.viewSwitchOf(context),
              switchInCurve: MotionTokens.enter,
              switchOutCurve: MotionTokens.ease,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: switch (_view) {
                _ReserveView.plan => KeyedSubtree(
                    key: const ValueKey('reserve-plan-view'),
                    child: _planView(l10n, window, dayOpen: dayOpen),
                  ),
                _ReserveView.day => KeyedSubtree(
                    key: const ValueKey('reserve-day-view'),
                    child: _dayView(),
                  ),
                _ReserveView.week => KeyedSubtree(
                    key: const ValueKey('reserve-week-view'),
                    child: _weekView(),
                  ),
                _ReserveView.month => KeyedSubtree(
                    key: const ValueKey('reserve-month-view'),
                    child: _monthView(),
                  ),
              },
            ),
          );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > constraints.maxHeight) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  // #478 phone-landscape audit: 40% sidebar left the
                  // canvas cramped while the panel sat mostly empty.
                  width:
                      (constraints.maxWidth * 0.3).clamp(260.0, 380.0),
                  child: SingleChildScrollView(child: header()),
                ),
                const VerticalDivider(width: 1),
                content,
              ],
            );
          }
          return Column(children: [header(), content]);
        },
      ),
    );
  }



  /// Closed-day banner (#186 style): the workspace is not open on the
  /// selected day, so nothing below is bookable. Shared [InlineBanner]
  /// since #210.
  Widget _closedDayBanner(AppLocalizations? l10n) {
    return InlineBanner(
      key: const ValueKey('reserve-closed-banner'),
      icon: Icons.event_busy,
      text: l10n?.planClosedDay ?? 'Closed on this day',
    );
  }

  /// Plan view: availability of the selected window on the live-plan
  /// canvas, hub-local level chips, free-seat tap books.
  Widget _planView(
    AppLocalizations? l10n,
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
        title: l10n?.planNoLevels ?? 'The workspace has no floor plan yet.',
      );
    }
    final level =
        levels.where((l) => l.id == _levelId).firstOrNull ?? levels.first;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    // The window may straddle TWO device-day keys (a workspace-clock full day
    // starts before the device midnight west of the workspace); reading only
    // dayKeyOf(start) misses those bookings — the reservation-shows-on-Plan-
    // not-on-Reserve bug. Fetch every key the window touches and merge by id.
    final reservations =
        reservationsAcrossWindow(ref, window.start, window.end);
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final names = ref.watch(memberNamesProvider).value ?? const {};

    // Floor switcher floats over the canvas (indoor-maps idiom, UX
    // pass) — hub-local browsing state (#187), never the plan tab's
    // persisted default (#159).
    return Stack(
      children: [
        Positioned.fill(child: Column(
      children: [
        Expanded(
          child: switch (planAsync) {
            AsyncData(value: final plan) => PlanCanvas(
                paintKey: const ValueKey('reserve-plan-canvas'),
                plan: plan,
                // Double tap = whole-space reserve / check-in (field
                // request); only registered while the feature is on.
                onSpaceDoubleTap: ref
                        .watch(enabledFeaturesSyncProvider)
                        .contains(WorkspaceFeature.levelBooking)
                    ? (desk, office) => showSpaceSheet(
                          context,
                          kind: desk != null
                              ? SpaceKind.desk
                              : office != null
                                  ? SpaceKind.office
                                  : SpaceKind.level,
                          level: level,
                          office: office ??
                              plan.offices
                                  .where((o) => o.id == desk?.officeId)
                                  .firstOrNull,
                          desk: desk,
                          plan: plan,
                          // Seed the reserve picker with the hub's
                          // selected day + period (0065).
                          initialWindow:
                              (start: window.start, end: window.end),
                        )
                    : null,
                // Presence dots: same rule as the directory and Plan tab.
                onlineSeatIds: onlineSeatIdsFor(
                  plan: plan,
                  reservations: reservations,
                  members:
                      ref.watch(workspaceMembersProvider).value ?? const [],
                  profiles:
                      ref.watch(memberProfilesProvider).value ?? const {},
                  from: window.start,
                  to: window.end,
                  now: ref.watch(clockProvider).now(),
                ),
                deskOpacity: (ref
                            .watch(currentWorkspaceProvider)
                            .value
                            ?.deskOpacity ??
                        100) /
                    100,
                background:
                    ref.watch(levelBackgroundProvider(level.id)).value,
                images: {
                  for (final image in plan.images)
                    // Single watch per image (perf audit): the double watch
                        // subscribed twice per image on every rebuild.
                        image.id: ?ref.watch(planImageProvider(image.id)).value,
                },
                seatStates: seatStatesFor(
                  plan: plan,
                  reservations: reservations,
                  myMemberId: myMemberId,
                  from: window.start,
                  to: window.end,
                  dayOpen: dayOpen,
                ),
                // #575 — the day-phase rings on the hub's plan too.
                seatDayPhases: seatDayPhasesFor(
                  plan: plan,
                  reservations: reservations,
                  at: window.start,
                  dayOpen: dayOpen,
                ),
                seatLabels: {
                  for (final seat in plan.seats)
                    seat.id: occupantLabelFor(
                      plan: plan,
                      seat: seat,
                      reservations: reservations,
                      names: names,
                      from: window.start,
                      to: window.end,
                    ),
                },
                // #462: the room/table itself reads reserved, with the
                // occupant's name — for every user.
                spaceOverlays: spaceOverlaysFor(
                  plan: plan,
                  reservations: reservations,
                  names: names,
                  myMemberId: myMemberId,
                  from: window.start,
                  to: window.end,
                ),
                onSeatTap: (seat) =>
                    _onSeatTap(plan, seat, reservations, window),
              ),
            AsyncError() => Center(
                child: Text(
                  l10n?.workspaceGenericError ??
                      'Something went wrong. Please try again.',
                ),
              ),
            _ => const LoadingView(),
          },
        ),
      ],
    )),
        if (levels.length > 1 || _levelReserveVisible(level))
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: LevelSelector(
              keyPrefix: 'reserve',
              levels: levels,
              current: level,
              onSelected: (id) => setState(() => _levelId = id),
              // #466: the whole-level booking button, Plan-tab parity —
              // the hub only had the hidden double-tap path.
              trailing: _levelReserveVisible(level)
                  ? IconButton(
                      key: const ValueKey('reserve-reserve-level'),
                      tooltip: AppLocalizations.of(context)
                              ?.levelReserveButton ??
                          'Reserve level',
                      icon: const Icon(Icons.layers_outlined),
                      onPressed: () {
                        final plan =
                            ref.read(floorPlanProvider(level.id)).value;
                        final window = _effectiveWindow(_granularity);
                        showSpaceSheet(
                          context,
                          kind: SpaceKind.level,
                          level: level,
                          plan: plan,
                          initialWindow:
                              (start: window.start, end: window.end),
                        );
                      },
                    )
                  : null,
            ),
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
    return me.canReserveLevel || me.canAdminister;
  }

  /// Day view: the selected day's per-seat timeline in everyone mode —
  /// see who else is booked; own blocks open the detail sheet.
  Widget _dayView() {
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final reservations = ref
            .watch(reservationsForDayProvider(dayKeyOf(_selectedDay)))
            .value ??
        const <Reservation>[];
    final active = [for (final r in reservations) if (r.isActive) r];
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
      onFreeSeatTap: (seat) => _bookingSheet(
        seat,
        active,
        _effectiveWindow(_granularity),
      ),
    );
  }

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
    for (final key in monthKeys) {
      final month = ref.watch(reservationsForMonthProvider(key)).value ??
          const <Reservation>[];
      for (final r in month) {
        byId[r.id] = r;
      }
    }
    return WeekGrid(
      key: const ValueKey('reserve-week-grid'),
      selectedDay: _selectedDay,
      reservations: [
        for (final r in byId.values)
          if (r.isActive) r,
      ],
      everyone: true,
      myMemberId: myMemberId,
      onDaySelected: (day) {
        _selectDay(day);
        setState(() => _view = _ReserveView.day);
      },
      onReservationTap: _detailSheet,
      onFreeSlotTap: (seat, day, {required morning}) {
        final window = _tapWindowOn(day, morning: morning);
        _bookingSheet(seat, byId.values.toList(), window);
      },
    );
  }

  /// The window a Week-cell tap books on [day]: the tapped half under
  /// half-day granularity, the whole day under full-day, and the hub's
  /// current from→to times mapped onto [day] otherwise.
  HalfDayWindow _tapWindowOn(DateTime day, {required bool morning}) {
    final granularity = _granularity;
    if (granularity == BookingGranularity.halfDay) {
      return morning
          ? HalfDayWindows.morning(day)
          : HalfDayWindows.afternoon(day);
    }
    if (granularity == BookingGranularity.fullDay) {
      return HalfDayWindows.fullDay(day);
    }
    final window = _effectiveWindow(granularity);
    final startWall = WorkspaceTime.wall(window.start);
    final endWall = WorkspaceTime.wall(window.end);
    final from = WorkspaceTime.at(
      day.year,
      day.month,
      day.day,
      startWall.hour,
      startWall.minute,
    );
    var to = WorkspaceTime.at(
      day.year,
      day.month,
      day.day,
      endWall.hour,
      endWall.minute,
    );
    if (!to.isAfter(from)) to = _defaultEndFor(from);
    return (start: from, end: to);
  }

  /// Month view (#7): the selected day's month as an availability
  /// calendar — free desks per day across ALL floors. Tapping a day
  /// selects it and drops into the Day view, where occupants are named.
  Widget _monthView() {
    final month = ref.watch(reservationsForMonthProvider(
          monthKeyOf(_selectedDay),
        )).value ??
        const <Reservation>[];
    return MonthGrid(
      key: const ValueKey('reserve-month-grid'),
      selectedDay: _selectedDay,
      reservations: [for (final r in month) if (r.isActive) r],
      onDaySelected: (day) {
        _selectDay(day);
        setState(() => _view = _ReserveView.day);
      },
    );
  }
}

