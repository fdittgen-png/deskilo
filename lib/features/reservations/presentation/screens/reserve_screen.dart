// SPDX-License-Identifier: MIT
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

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
import '../../../events/providers/event_providers.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/domain/seat_context.dart';
import '../../../plan/presentation/widgets/floor_plan_painter.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../../money/domain/quota_rules.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/seat_state_logic.dart';
import '../../providers/reservation_providers.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/series_result_dialog.dart';
import '../widgets/reservation_detail_sheet.dart';
import '../widgets/month_grid.dart';
import '../widgets/week_grid.dart';

/// Geometry and ranges of the Reserve hub (#208). Pinned by test — treat
/// these as part of the visual/behavioural contract, not free-floating
/// magic numbers.
abstract final class ReserveHubMetrics {
  /// Day pills on the date strip, starting today.
  static const int stripDayCount = 14;

  /// Height of the date-strip row (fits the two-line day pills).
  static const double stripHeight = 76;

  /// Furthest day (from today) reachable via the strip's calendar icon.
  static const int datePickerRangeDays = 365;

  /// Historical page count of the Week view's former day pager. #236
  /// replaced the pager with the seat × day [WeekGrid]; the constant stays
  /// pinned so the metrics contract only ever grows.
  static const int weekPageCount = 365;

  /// Cell size of the hub's plan canvas (matches the live plan's).
  static const double canvasCellSize = 14;

  /// Grid cells per canvas side (matches the live plan's canvas).
  static const int canvasCells = 120;

  /// Zoom limits and pan margin of the canvas host (live-plan parity).
  static const double canvasMinScale = 0.4;
  static const double canvasMaxScale = 3;
  static const double canvasBoundaryMargin = 200;

  /// Snapping of the from→to window chips (#184 pattern): 15-minute steps.
  static const int snapMinutes = 15;

  /// Default window length before capping (mirrors the plan's stay).
  static const Duration defaultStay = Duration(hours: 4);

  /// Latest selectable window end within a day (#184 pattern): 23:45.
  static const int lastSlotHour = 23;
  static const int lastSlotMinute = 45;

  /// Historical Week-pager animation (see [weekPageCount]) — pinned, no
  /// longer driving anything since the grid replaced the pager (#236).
  static const Duration pageAnimation = Duration(milliseconds: 250);
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

  /// Key of one date-strip pill (tests): the pill of [day]'s local date.
  static Key dayPillKey(DateTime day) =>
      ValueKey('reserve-day-pill-${dayKeyOf(day)}');

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
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedDay = _today;
  }

  // ── window derivation (mirrors plan_screen's #184/#201 mechanics) ──

  /// Booking granularity of the active workspace (#200/#201). Loading or
  /// unknown reads as flexible, like the plan header.
  BookingGranularity get _granularity =>
      ref.read(bookingGranularityProvider).value ??
      BookingGranularity.flexible;

  /// The day's last selectable slot: 23:45 local of [day].
  DateTime _lastSlotOf(DateTime day) => DateTime(
        day.year,
        day.month,
        day.day,
        ReserveHubMetrics.lastSlotHour,
        ReserveHubMetrics.lastSlotMinute,
      );

  /// Snaps [t] down to the previous slot of the workspace's configured
  /// step (#184 pattern; 0032 makes the step owner-configurable).
  DateTime _snapToSlot(DateTime t) {
    final local = t.toLocal();
    final snap = _granularity.stepMinutes ?? ReserveHubMetrics.snapMinutes;
    final m = (local.hour * 60 + local.minute) ~/ snap * snap;
    return DateTime(local.year, local.month, local.day, m ~/ 60, m % 60);
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
  /// Explicit choice wins; otherwise half-day granularity defaults to the
  /// full-day window and flexible to "now"-anchored times of day.
  HalfDayWindow _effectiveWindow(BookingGranularity granularity) {
    final start = _windowStart;
    final end = _windowEnd;
    if (start != null && end != null) return (start: start, end: end);
    if (granularity.isDayBased) {
      return HalfDayWindows.fullDay(_selectedDay);
    }
    final now = _snapToSlot(DateTime.now());
    final from = DateTime(
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

  DateTime _stripDay(int index) =>
      DateTime(_today.year, _today.month, _today.day + index);

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
        from = DateTime(
          dayOnly.year,
          dayOnly.month,
          dayOnly.day,
          window.start.hour,
          window.start.minute,
        );
        var kept = DateTime(
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
      initialTime: TimeOfDay.fromDateTime(window.start),
    );
    if (picked == null) return;
    if (!mounted) return;
    final duration = window.end.difference(window.start);
    final from = _snapToSlot(DateTime(
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
      initialTime: TimeOfDay.fromDateTime(window.end),
    );
    if (picked == null) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final from = window.start;
    final end = _snapToSlot(DateTime(
      from.year,
      from.month,
      from.day,
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
    return isWorkspaceOpenOn(at.toLocal(), openWeekdays, closures);
  }

  /// Booking failure snackbar text: closed-day (#186) and half-day (#201)
  /// server refusals get their dedicated explanations instead of the
  /// misleading generic [fallback] — same mapping as the plan screen.
  String _bookingErrorText(
    AppLocalizations? l10n,
    Object error,
    String fallback,
  ) {
    if (error is PostgrestException &&
        error.message.contains(WorkspaceClosedError.serverSubstring)) {
      return l10n?.planClosedDayError ??
          'The workspace is closed on that day.';
    }
    // Quota before granularity: 'half-day quota' also contains the
    // granularity substring 'half-day'.
    if (error is PostgrestException &&
        error.message.contains(QuotaExceededError.serverSubstring)) {
      return l10n?.quotaExceededError ??
          'Monthly half-day quota reached — request extra half-days '
              'from the Money tab.';
    }
    if (error is PostgrestException &&
        error.message.contains(BookingGranularityError.serverSubstring)) {
      return l10n?.planHalfDayError ?? 'Bookings here are per half day.';
    }
    if (error is PostgrestException &&
        error.message
            .contains(BookingGranularityError.fullDayServerSubstring)) {
      return l10n?.planFullDayError ??
          'Bookings here cover the full day.';
    }
    if (error is PostgrestException &&
        error.message
            .contains(BookingGranularityError.slotServerSubstring)) {
      final step = _granularity.stepMinutes ?? 15;
      return l10n?.planSlotError(step) ??
          'Bookings must start and end on the $step-minute grid.';
    }
    return fallback;
  }

  // ── Plan view: seat tap → shared booking sheet (#206) ──

  String _firstName(String name) => name.split(' ').firstOrNull ?? name;

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
        await _bookingSheet(seat, reservations, window);
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
        final until = DateFormat.Hm().format(other.endsAt.toLocal());
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
  Future<void> _bookingSheet(
    Seat seat,
    List<Reservation> reservations,
    HalfDayWindow window,
  ) async {
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
    final next = nextReservationOnSeat(
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
        _bookingErrorText(
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

  /// Detail sheet of one reservation (#182/#206): where the seat is and a
  /// "Show on plan" jump — popping with a [SeatContext] signals the plan
  /// screen and leaves the hub for the Plan tab (calendar parity).
  Future<void> _detailSheet(Reservation reservation) async {
    final target = await showModalBottomSheet<SeatContext>(
      context: context,
      builder: (context) => ReservationDetailSheet(reservation: reservation),
    );
    if (target == null || !mounted) return;
    ref.read(planFocusControllerProvider.notifier).setFocus(
          PlanFocus(
            levelId: target.levelId,
            seatId: reservation.seatId,
            at: reservation.startsAt,
          ),
        );
    context.go('/plan');
  }

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
    return Scaffold(
      body: Column(
        children: [
          _dateStrip(l10n),
          // Honest controls: the window chips act on Plan (state filter +
          // booking window) and Day (the window a free-row tap books).
          // Week books per tapped half, Month is an overview — no chips.
          if (_view == _ReserveView.plan || _view == _ReserveView.day)
            _windowChips(l10n, granularity, window),
          if (!dayOpen) _closedDayBanner(l10n),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            // #211: the shared toggle idiom — same key, same labels and
            // behaviour as the original SegmentedButton, plus the shared
            // icon set (map/timeline/week).
            child: ViewToggle<_ReserveView>(
              key: const ValueKey('reserve-view-switch'),
              options: [
                ViewToggleOption(
                  value: _ReserveView.plan,
                  icon: Icons.map_outlined,
                  label: l10n?.tabPlan ?? 'Plan',
                ),
                ViewToggleOption(
                  value: _ReserveView.day,
                  icon: Icons.view_timeline_outlined,
                  label: l10n?.reserveDayView ?? 'Day',
                ),
                ViewToggleOption(
                  value: _ReserveView.week,
                  icon: Icons.view_week_outlined,
                  label: l10n?.reserveWeekView ?? 'Week',
                ),
                ViewToggleOption(
                  value: _ReserveView.month,
                  icon: Icons.calendar_month_outlined,
                  label: l10n?.reserveMonthView ?? 'Month',
                ),
              ],
              selected: _view,
              // No re-entry syncing needed since #236: the week grid
              // derives its week from the selected day on every build.
              onChanged: (view) => setState(() => _view = view),
            ),
          ),
          Expanded(
            // #209: cross-fade the Plan/Day/Week toggle. Distinct subtree
            // keys make the switcher animate the swap; the fade stays
            // OUTSIDE the canvas's InteractiveViewer transform.
            child: AnimatedSwitcher(
              duration: AppMotion.viewSwitch,
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
          ),
        ],
      ),
    );
  }

  /// Horizontal date-pill strip: [ReserveHubMetrics.stripDayCount] days
  /// from today, plus a calendar icon for anything further out.
  Widget _dateStrip(AppLocalizations? l10n) {
    final weekdayFormat = DateFormat.E();
    final dayFormat = DateFormat.d();
    return SizedBox(
      height: ReserveHubMetrics.stripHeight,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.smH,
              itemCount: ReserveHubMetrics.stripDayCount,
              itemBuilder: (context, index) {
                final day = _stripDay(index);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 8,
                  ),
                  child: ChoiceChip(
                    key: ReserveScreen.dayPillKey(day),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdayFormat.format(day),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(dayFormat.format(day)),
                      ],
                    ),
                    selected: DateUtils.isSameDay(day, _selectedDay),
                    // 48dp Material tap minimum (#211): the padded target
                    // keeps the pill's hit area honest inside the strip.
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => _selectDay(day),
                  ),
                );
              },
            ),
          ),
          IconButton(
            key: const ValueKey('reserve-date-button'),
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: l10n?.reservePickDateTooltip ?? 'Choose a date',
            onPressed: _pickDate,
          ),
        ],
      ),
    );
  }

  /// Granularity-aware window chips: Morning/Afternoon/Full day under
  /// half-day granularity (#201 pattern), from→to clock chips otherwise
  /// (#184/#185 pattern).
  Widget _windowChips(
    AppLocalizations? l10n,
    BookingGranularity granularity,
    HalfDayWindow window,
  ) {
    if (granularity.isDayBased) {
      final selectedBuilder = _matchingHalfDayBuilder(_selectedDay, window);
      Widget chip(
        String key,
        String label,
        HalfDayWindow Function(DateTime day) windowOf,
      ) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ChoiceChip(
            key: ValueKey(key),
            label: Text(label),
            selected: selectedBuilder == windowOf,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => setState(() {
              final chosen = windowOf(_selectedDay);
              _windowStart = chosen.start;
              _windowEnd = chosen.end;
            }),
          ),
        );
      }

      // scaleDown keeps the three chips on one row on narrow screens. The
      // 48dp-tall box centers the chips and preserves their padded tap
      // targets (#211).
      return SizedBox(
        height: kMinInteractiveDimension,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Full-day granularity (0032) books whole days only — the
              // half chips exist under half-day granularity alone.
              if (granularity == BookingGranularity.halfDay) ...[
                chip(
                  'reserve-am-chip',
                  l10n?.planMorningChip ?? 'Morning',
                  HalfDayWindows.morning,
                ),
                chip(
                  'reserve-pm-chip',
                  l10n?.planAfternoonChip ?? 'Afternoon',
                  HalfDayWindows.afternoon,
                ),
              ],
              chip(
                'reserve-day-chip',
                l10n?.reserveFullDayChip ?? 'Full day',
                HalfDayWindows.fullDay,
              ),
            ],
          ),
        ),
      );
    }

    final timeFormat = DateFormat.Hm();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Tooltip(
          message: l10n?.planFromLabel ?? 'From',
          child: TextButton(
            key: const ValueKey('reserve-from-chip'),
            onPressed: _pickFrom,
            child: Text(timeFormat.format(window.start)),
          ),
        ),
        Icon(
          Icons.arrow_right_alt,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        Tooltip(
          message: l10n?.planToLabel ?? 'To',
          child: TextButton(
            key: const ValueKey('reserve-to-chip'),
            onPressed: _pickTo,
            child: Text(timeFormat.format(window.end)),
          ),
        ),
      ],
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
    final reservations = ref
            .watch(reservationsForDayProvider(dayKeyOf(window.start)))
            .value ??
        const <Reservation>[];
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final names = ref.watch(memberNamesProvider).value ?? const {};

    String labelFor(FloorPlan plan, Seat seat) {
      final r = reservationOnSeatInRange(
        plan: plan,
        seat: seat,
        reservations: reservations,
        from: window.start,
        to: window.end,
      );
      if (r == null) return '';
      return _firstName(names[r.memberId] ?? '');
    }

    return Column(
      children: [
        // One tap per level — hub-local chips like the day timeline
        // (#187), never the plan tab's persisted default (#159). Row
        // height and tap target meet the 48dp Material minimum (#211).
        if (levels.length > 1)
          SizedBox(
            height: kMinInteractiveDimension,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.mdH,
              children: [
                for (final Level l in levels)
                  Padding(
                    padding: AppSpacing.xsH,
                    child: ChoiceChip(
                      label: Text(l.name),
                      selected: l.id == level.id,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => setState(() => _levelId = l.id),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: switch (planAsync) {
            AsyncData(value: final plan) => _ReservePlanCanvas(
                plan: plan,
                background:
                    ref.watch(levelBackgroundProvider(level.id)).value,
                seatStates: {
                  for (final seat in plan.seats)
                    // Closed day (#186): every seat renders muted —
                    // nothing looks bookable.
                    seat.id: !dayOpen
                        ? SeatState.blocked
                        : seatStateInRange(
                            plan: plan,
                            seat: seat,
                            reservations: reservations,
                            myMemberId: myMemberId,
                            from: window.start,
                            to: window.end,
                          ),
                },
                seatLabels: {
                  for (final seat in plan.seats) seat.id: labelFor(plan, seat),
                },
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
    );
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
    final from = DateTime(
      day.year,
      day.month,
      day.day,
      window.start.hour,
      window.start.minute,
    );
    var to = DateTime(
      day.year,
      day.month,
      day.day,
      window.end.hour,
      window.end.minute,
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

/// Minimal live-plan canvas host, mirrored from the plan screen's private
/// `_LivePlanCanvas` (#208 keeps plan_screen untouched — smallest diff):
/// [FloorPlanPainter] inside an InteractiveViewer with a tap handler
/// resolving cell → seat via [FloorPlan.seatAtCell]. No jump highlight
/// here — that affordance belongs to the Plan tab (#182).
class _ReservePlanCanvas extends StatelessWidget {
  const _ReservePlanCanvas({
    required this.plan,
    required this.seatStates,
    required this.seatLabels,
    required this.onSeatTap,
    this.background,
  });

  final FloorPlan plan;
  final Map<String, SeatState> seatStates;
  final Map<String, String> seatLabels;
  final ValueChanged<Seat> onSeatTap;
  final ui.Image? background;

  @override
  Widget build(BuildContext context) {
    const size = Size(
      ReserveHubMetrics.canvasCells * ReserveHubMetrics.canvasCellSize,
      ReserveHubMetrics.canvasCells * ReserveHubMetrics.canvasCellSize,
    );
    return InteractiveViewer(
      constrained: false,
      minScale: ReserveHubMetrics.canvasMinScale,
      maxScale: ReserveHubMetrics.canvasMaxScale,
      boundaryMargin:
          const EdgeInsets.all(ReserveHubMetrics.canvasBoundaryMargin),
      child: GestureDetector(
        onTapUp: (details) {
          const cell = ReserveHubMetrics.canvasCellSize;
          final x = (details.localPosition.dx / cell).floor();
          final y = (details.localPosition.dy / cell).floor();
          final seat = plan.seatAtCell(x, y);
          if (seat != null) onSeatTap(seat);
        },
        child: CustomPaint(
          key: const ValueKey('reserve-plan-canvas'),
          size: size,
          painter: FloorPlanPainter(
            plan: plan,
            cellSize: ReserveHubMetrics.canvasCellSize,
            colorScheme: Theme.of(context).colorScheme,
            brightness: Theme.of(context).brightness,
            background: background,
            seatStates: seatStates,
            seatLabels: seatLabels,
          ),
        ),
      ),
    );
  }
}
