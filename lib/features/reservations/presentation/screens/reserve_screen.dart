// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../../core/theme/app_radius.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/motion.dart';
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
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/seat_state_logic.dart';
import '../../providers/reservation_providers.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/reservation_detail_sheet.dart';

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

  /// Pages of the Week view's pager — one local day per page, page 0 =
  /// today, matching the calendar icon's range.
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

  /// Week pager animation when a date pill drives the page.
  static const Duration pageAnimation = Duration(milliseconds: 250);
}

/// The three hub views under the date strip and window chips.
enum _ReserveView { plan, day, week }

/// Reserve hub (#208, epic #204): full-screen route pushed by the bottom
/// bar's raised centre button (#207). Top→bottom: a horizontal date-pill
/// strip (+ calendar icon for further dates) driving the selected day;
/// granularity-aware window chips (half-day Morning/Afternoon/Full day per
/// #201, else from→to clock chips per #184/#185); and a Plan · Day · Week
/// switch. Plan mirrors the live plan canvas for the selected window (free
/// seat tap books via the shared [BookingSheet], #206); Day shows the
/// everyone-mode [DayTimeline]; Week pages one timeline per day, synced
/// two-way with the date strip.
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

/// The router (#207) constructs this screen under its original placeholder
/// name; the alias keeps the route registration untouched by #208.
typedef ReservePlaceholderScreen = ReserveScreen;

class _ReserveScreenState extends ConsumerState<ReserveScreen> {
  /// Local midnight of the day the hub opened on — page 0 of the week
  /// pager and the first pill of the date strip.
  late final DateTime _today;

  /// Local midnight of the browsed day (date strip / week pager).
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

  PageController? _weekController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedDay = _today;
  }

  @override
  void dispose() {
    _weekController?.dispose();
    super.dispose();
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

  /// Snaps [t] down to the previous 15-minute slot (#184 pattern).
  DateTime _snapToSlot(DateTime t) {
    final local = t.toLocal();
    const snap = ReserveHubMetrics.snapMinutes;
    final m = (local.hour * 60 + local.minute) ~/ snap * snap;
    return DateTime(local.year, local.month, local.day, m ~/ 60, m % 60);
  }

  /// Default window end for a start at [from]: the default stay, clamped
  /// to the day's last slot — and never at/before [from].
  DateTime _defaultEndFor(DateTime from) {
    var end = from.add(ReserveHubMetrics.defaultStay);
    final last = _lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) {
      end = from.add(const Duration(minutes: ReserveHubMetrics.snapMinutes));
    }
    return end;
  }

  /// The window the hub currently browses/books, always on [_selectedDay].
  /// Explicit choice wins; otherwise half-day granularity defaults to the
  /// full-day window and flexible to "now"-anchored times of day.
  HalfDayWindow _effectiveWindow(BookingGranularity granularity) {
    final start = _windowStart;
    final end = _windowEnd;
    if (start != null && end != null) return (start: start, end: end);
    if (granularity == BookingGranularity.halfDay) {
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

  // ── day selection (strip · calendar icon · week pager) ──

  int _pageOf(DateTime day) =>
      (day.difference(_today).inHours / Duration.hoursPerDay).round();

  DateTime _dayOfPage(int index) =>
      DateTime(_today.year, _today.month, _today.day + index);

  /// Central day switch: re-maps the window onto the new day (canonical
  /// half re-derived under half-day granularity, times of day kept under
  /// flexible — plan's date-button behaviour, #184/#201) and keeps the
  /// week pager in sync unless the pager itself drove the change.
  void _selectDay(DateTime day, {bool fromPager = false}) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (!DateUtils.isSameDay(dayOnly, _selectedDay)) {
      final granularity = _granularity;
      final window = _effectiveWindow(granularity);
      DateTime? from;
      DateTime? to;
      if (_windowStart != null && _windowEnd != null) {
        if (granularity == BookingGranularity.halfDay) {
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
    if (fromPager) return;
    final controller = _weekController;
    if (_view == _ReserveView.week &&
        controller != null &&
        controller.hasClients) {
      final target = _pageOf(dayOnly);
      if (controller.page?.round() != target) {
        controller.animateToPage(
          target,
          duration: ReserveHubMetrics.pageAnimation,
          curve: Curves.easeInOut,
        );
      }
    }
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
    if (!end.isAfter(from)) {
      end = from.add(const Duration(minutes: ReserveHubMetrics.snapMinutes));
    }
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
    if (error is PostgrestException &&
        error.message.contains(BookingGranularityError.serverSubstring)) {
      return l10n?.planHalfDayError ?? 'Bookings here are per half day.';
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
    final halfDay = _granularity == BookingGranularity.halfDay;
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
        walkUp: false,
        fixedEnd: halfDay,
        members: const [],
        myMemberId: myMemberId,
        allowSeries: false,
        allowBlocking: false,
      ),
    );
    if (choice == null || !mounted) return;

    try {
      await ref.read(reservationRepositoryProvider).create(
            workspaceId: workspace.id,
            seatId: seat.id,
            startsAt: window.start,
            endsAt: choice.end,
            checkIn: false,
          );
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.shellReserveButton ?? 'Reserve')),
      body: Column(
        children: [
          _dateStrip(l10n),
          _windowChips(l10n, granularity, window),
          if (!dayOpen) _closedDayBanner(l10n),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<_ReserveView>(
              key: const ValueKey('reserve-view-switch'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _ReserveView.plan,
                  label: Text(l10n?.tabPlan ?? 'Plan'),
                ),
                ButtonSegment(
                  value: _ReserveView.day,
                  label: Text(l10n?.reserveDayView ?? 'Day'),
                ),
                ButtonSegment(
                  value: _ReserveView.week,
                  label: Text(l10n?.reserveWeekView ?? 'Week'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) {
                setState(() => _view = selection.first);
                // Re-entering Week with a day picked elsewhere: bring the
                // pager (which kept its old page) back under the strip.
                if (_view != _ReserveView.week) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final controller = _weekController;
                  if (controller == null || !controller.hasClients) return;
                  final target = _pageOf(_selectedDay);
                  if (controller.page?.round() != target) {
                    controller.jumpToPage(target);
                  }
                });
              },
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: ReserveHubMetrics.stripDayCount,
              itemBuilder: (context, index) {
                final day = _dayOfPage(index);
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
                    visualDensity: VisualDensity.compact,
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
    if (granularity == BookingGranularity.halfDay) {
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
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setState(() {
              final chosen = windowOf(_selectedDay);
              _windowStart = chosen.start;
              _windowEnd = chosen.end;
            }),
          ),
        );
      }

      // scaleDown keeps the three chips on one row on narrow screens.
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            chip(
              'reserve-day-chip',
              l10n?.reserveFullDayChip ?? 'Full day',
              HalfDayWindows.fullDay,
            ),
          ],
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
  /// selected day, so nothing below is bookable.
  Widget _closedDayBanner(AppLocalizations? l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('reserve-closed-banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_busy,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n?.planClosedDay ?? 'Closed on this day',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
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
        // (#187), never the plan tab's persisted default (#159).
        if (levels.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final Level l in levels)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(l.name),
                      selected: l.id == level.id,
                      visualDensity: VisualDensity.compact,
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
    return DayTimeline(
      day: _selectedDay,
      reservations: [for (final r in reservations) if (r.isActive) r],
      everyone: true,
      myMemberId: myMemberId,
      onReservationTap: _detailSheet,
    );
  }

  /// Week view: one day timeline per page, two-way synced with the date
  /// strip (a swipe moves the selected pill, a pill tap moves the page).
  Widget _weekView() {
    final controller =
        _weekController ??= PageController(initialPage: _pageOf(_selectedDay));
    return PageView.builder(
      key: const ValueKey('reserve-week-pager'),
      controller: controller,
      itemCount: ReserveHubMetrics.weekPageCount,
      onPageChanged: (index) {
        final day = _dayOfPage(index);
        if (!DateUtils.isSameDay(day, _selectedDay)) {
          _selectDay(day, fromPager: true);
        }
      },
      itemBuilder: (context, index) =>
          _WeekDayPage(day: _dayOfPage(index), onReservationTap: _detailSheet),
    );
  }
}

/// One page of the Week view: the day's timeline, self-loading via the
/// per-day provider so month boundaries never need a double fetch.
class _WeekDayPage extends ConsumerWidget {
  const _WeekDayPage({required this.day, required this.onReservationTap});

  final DateTime day;
  final void Function(Reservation reservation) onReservationTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final reservations =
        ref.watch(reservationsForDayProvider(dayKeyOf(day))).value ??
            const <Reservation>[];
    return DayTimeline(
      day: day,
      reservations: [for (final r in reservations) if (r.isActive) r],
      everyone: true,
      myMemberId: myMemberId,
      onReservationTap: onReservationTap,
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
  });

  final FloorPlan plan;
  final Map<String, SeatState> seatStates;
  final Map<String, String> seatLabels;
  final ValueChanged<Seat> onSeatTap;

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
            seatStates: seatStates,
            seatLabels: seatLabels,
          ),
        ),
      ),
    );
  }
}
