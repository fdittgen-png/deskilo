// SPDX-License-Identifier: 0BSD
import 'dart:async';

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
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/presentation/seat_occupancy.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../reserve_seat_actions.dart';
import '../space_subjects.dart';
import '../widgets/seat_list_view.dart';
import '../../../plan/providers/default_level_controller.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../../plan/presentation/widgets/seat_photos.dart';
import '../../../profile/domain/profile.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/member.dart';
import '../../domain/week_tap_window.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/default_booking_period.dart';
import '../../domain/reservation.dart';
import '../../providers/default_period_controller.dart';
import '../../providers/reservation_providers.dart';
import '../../domain/space_code.dart';
import '../widgets/booking_controls.dart';
import '../widgets/booking_sheet.dart';
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
/// #687 — `list` is the plan's SEAT LIST, ported from the deleted Plan
/// tab. It sits in the main toggle rather than in a second one nested
/// inside the plan view: two toggles meant two map icons in one toolbar,
/// which is confusing to look at and ambiguous to tap.
enum _ReserveView { plan, list, day, week, month }

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

class _ReserveScreenState extends ConsumerState<ReserveScreen>
    with ReserveSeatActions<ReserveScreen> {
  // The seat-action half of this screen lives in ReserveSeatActions —
  // the Plan tab's job, ported when that tab was deleted. These are what
  // it needs from the hub; the live/browsing distinction above all,
  // because it changes what a tap MEANS.
  @override
  bool get isLive => _isLive;

  @override
  BookingGranularity get granularity => _granularity;

  @override
  HalfDayWindow get bookingWindow => _effectiveWindow(_granularity);

  @override
  bool isWorkspaceOpenAt(DateTime at) => _isWorkspaceOpenAt(at);

  @override
  DateTime defaultEndFor(DateTime from) => _defaultEndFor(from);

  @override
  DateTime lastSlotOf(DateTime day) => _lastSlotOf(day);

  @override
  Future<void> openReservation(Reservation reservation) =>
      _detailSheet(reservation);

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

  /// The seat LIST and the MAP are the same view with two
  /// presentations, so both render the plan surface below.
  bool get _seatList => _view == _ReserveView.list;

  // #687 — "Show on plan" (#182/#576) lands HERE now that the hub is the
  // only map surface. PlanCanvas has always taken these; the hub simply
  // never passed them, because the Plan tab owned the jump.
  String? _focusSeatId;
  String? _focusDeskId;
  String? _focusOfficeId;
  bool _focusLevel = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    // #490 — "today" is the WORKSPACE's date, not the device's.
    _today = WorkspaceTime.dateOf(now);
    _selectedDay = _today;
    // A focus request may already be pending when this screen is first
    // built — the ref.listen in build only catches later ones. Post-frame
    // so applying it never mutates a provider during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(planFocusControllerProvider);
      if (pending != null) _applyFocus(pending);
    });
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
  /// LIVE mode: today, with no hand-picked window (#687).
  ///
  /// The same condition the "Now" button offers to restore, and the
  /// hub's equivalent of the Plan tab's `_browse == null`. It decides
  /// whether a free-seat tap is a WALK-UP — "I am standing here now" —
  /// or a reservation for a browsed window. Getting it wrong either
  /// checks someone in for a slot they are not in yet, or refuses to
  /// check in someone who is standing at the desk.
  bool get _isLive =>
      _selectedDay.isAtSameMomentAs(_today) && _windowStart == null;

  /// Applies a pending "Show on plan" jump (#182/#576).
  ///
  /// It lands HERE now that the hub is the only map surface. PlanCanvas
  /// has always taken the highlight parameters; the hub simply never
  /// passed them, because the Plan tab owned the jump.
  void _applyFocus(PlanFocus focus) {
    setState(() {
      _view = _ReserveView.plan;
      _levelId = focus.levelId;
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
      setState(() {
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
    } catch (e, st) {
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
    setState(() => _windowEnd = end);
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
    setState(() {
      _focusSeatId = null;
      _focusDeskId = null;
      _focusOfficeId = null;
      _focusLevel = false;
    });
  }

  bool _isWorkspaceOpenAt(DateTime at) {
    final openWeekdays = ref.read(openWeekdaysProvider).value;
    final closures = ref.read(closureDaysProvider).value;
    if (openWeekdays == null || closures == null) return true;
    return isWorkspaceOpenOn(WorkspaceTime.dateOf(at), openWeekdays, closures);
  }

  /// Forward to the shared mapper with this screen's slot size
  /// (maintainability audit: the 42-line switch was pasted per screen).


  // ── Plan view: seat tap → shared booking sheet (#206) ──


  /// Detail sheet + "Show on plan" jump — via the shared helper that
  /// owns the popped-target handling (#182/#206/#422).
  Future<void> _detailSheet(Reservation reservation) =>
      showReservationDetail(context, ref, reservation);

  // ── build ──

  @override
  Widget build(BuildContext context) {
    // #182 — the hub stays alive in the shell's indexed stack, so this
    // listener survives tab switches.
    ref.listen(planFocusControllerProvider, (_, focus) {
      if (focus != null) _applyFocus(focus);
    });
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
                  // The Plan TAB's own former icon, now free and already
                  // meaning "the plan" to anyone who used it.
                  //
                  // Not a map icon (the map/list button beside this row
                  // owns that metaphor) and not a seat icon (the raised
                  // Reserve button owns THAT). Three collisions in a row
                  // is a sign the toolbar is icon-dense; each one was a
                  // real ambiguity a user would meet, not just a finder
                  // the tests tripped over.
                  icon: Icons.grid_view_outlined,
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
            // Map <-> list, as ONE button showing the icon of what you
            // would switch TO.
            //
            // It was a fifth segment in the toggle above until the
            // tap-target guard caught it: five icon segments squeeze to
            // 45.6dp at phone width, under the 48dp floor. And it never
            // belonged there anyway — Day/Week/Month are TIME views,
            // while map and list are two presentations of the same one.
            // A second two-segment toggle would have shown two map icons
            // in one row; this shows one, and never the one you are
            // already looking at.
            if (_view == _ReserveView.plan || _view == _ReserveView.list)
              IconButton(
                key: const ValueKey('reserve-seat-view-switch'),
                tooltip: _seatList
                    ? (l10n?.planMapViewTooltip ?? 'Plan view')
                    : (l10n?.planListViewTooltip ?? 'List view'),
                icon: Icon(
                  _seatList ? Icons.map_outlined : Icons.view_list_outlined,
                ),
                onPressed: () => setState(() => _view = _seatList
                    ? _ReserveView.plan
                    : _ReserveView.list),
              ),
            // 'Now' returns to today AND to the live window — parity
            // with the Plan tab, which has had it since #184.
            //
            // Shown only while browsing, like Plan's: an always-visible
            // disabled button is header noise. Without it, getting back
            // from a browsed date meant opening the picker and hunting
            // for today, on the surface people book from most.
            //
            // It clears the WINDOW too, not just the day. Leaving a
            // hand-picked window on today reads as live while showing a
            // slot that may already be past.
            if (!_selectedDay.isAtSameMomentAs(_today) ||
                _windowStart != null)
              IconButton(
                key: const ValueKey('reserve-now-button'),
                tooltip: l10n?.planNowButton ?? 'Now',
                icon: const Icon(Icons.schedule_outlined),
                onPressed: () => setState(() {
                  _selectedDay = _today;
                  _windowStart = null;
                  _windowEnd = null;
                }),
              ),
            // Honest controls: the window chips act on Plan (state
            // filter + booking window) and Day (the window a free-row
            // tap books). Week books per tapped half, Month is an
            // overview — no chips.
            if (_view != _ReserveView.week && _view != _ReserveView.month)
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
                // Map and list are the same VIEW with two
                // presentations; _planView picks between them and keys
                // its own child, so the cross-fade (#209) happens
                // inside rather than swapping the whole surface.
                _ReserveView.plan || _ReserveView.list => KeyedSubtree(
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
        // #687 — the hub is the only map surface, so the floor it shows
        // is the member's PERSISTED default (#159), not just this
        // session's browsing state. `_levelId` still wins while set, so
        // a "show on plan" jump (#182) stays transient and never
        // overwrites a floor someone chose deliberately.
        levels
                .where((l) =>
                    l.id ==
                    (_levelId ?? ref.watch(selectedLevelIdProvider).value))
                .firstOrNull ??
            levels.first;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    // The window may straddle TWO device-day keys (a workspace-clock full day
    // starts before the device midnight west of the workspace); reading only
    // dayKeyOf(start) misses those bookings — the reservation-shows-on-Plan-
    // not-on-Reserve bug. Fetch every key the window touches and merge by id.
    final reservations =
        reservationsAcrossWindow(ref, window.start, window.end);
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final names = ref.watch(memberNamesProvider).value ?? const {};
    // #620 — occupant profile photos on every map, kiosk or not.
    final photosOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.planMemberPhotos);
    final memberUserIds = {
      for (final m in ref.watch(workspaceMembersProvider).value ?? <Member>[])
        m.id: m.userId,
    };
    final memberProfiles =
        ref.watch(memberProfilesProvider).value ?? const <String, Profile>{};

    // Floor switcher floats over the canvas (indoor-maps idiom, UX
    // pass) — hub-local browsing state (#187), never the plan tab's
    // persisted default (#159).
    return Stack(
      children: [
        Positioned.fill(child: Column(
      children: [
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
                  onSeatTap: (seat) =>
                      onSeatTap(plan, seat, reservations, window),
                ),
              ),
            AsyncData(value: final plan) => SeatPhotoLoader(
                key: const ValueKey('reserve-canvas-view'),
                seatUserIds: !photosOn
                    ? const {}
                    : {
                        for (final seat in plan.seats)
                          if (occupantOnSeat(
                                plan: plan,
                                seat: seat,
                                reservations: reservations,
                                from: window.start,
                                to: window.end,
                              )?.memberId
                              case final occupantMemberId?)
                            if (memberUserIds[occupantMemberId] case final userId?)
                              if (memberProfiles[userId]?.hasAvatar ?? false)
                                seat.id: userId,
                      },
                builder: (context, seatPhotos) => PlanCanvas(
                seatPhotos: seatPhotos,
                paintKey: const ValueKey('reserve-plan-canvas'),
                plan: plan,
                highlightedSeatId: _focusSeatId,
                highlightedDeskId: _focusDeskId,
                highlightedOfficeId: _focusOfficeId,
                highlightLevel: _focusLevel,
                // Double tap = whole-space reserve / check-in (field
                // request); only registered while the feature is on.
                onSpaceDoubleTap: ref
                        .watch(enabledFeaturesSyncProvider)
                        .contains(WorkspaceFeature.levelBooking)
                    ? (desk, office) => showSpaceSheet(
                          context,
                          // #687 — without this the double-tap sheet
                          // offered no subject picker at all, so a whole
                          // room or table could only ever be booked for
                          // yourself.
                          members: spaceAssignmentCandidates(ref),
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
                    onSeatTap(plan, seat, reservations, window),
              ),
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
              onSelected: (id) {
                // Changing floor answers the question the highlight was
                // asking, so the ring goes with it.
                _clearFocus();
                setState(() => _levelId = id);
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
                          // #687 — the level button is the OWNER's
                          // assignment path (#638). With no roster it
                          // silently degraded to "book this floor for
                          // myself".
                          members: spaceAssignmentCandidates(ref),
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
      onFreeSeatTap: (seat) => bookingSheet(
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
        final window = weekTapWindow(
          day: day,
          morning: morning,
          granularity: _granularity,
          current: _effectiveWindow(_granularity),
          defaultEndFor: _defaultEndFor,
        );
        bookingSheet(seat, byId.values.toList(), window);
      },
    );
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

