// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/work_hours.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../providers/browsed_level.dart';
import '../../providers/default_period_controller.dart';
import '../../providers/reservation_providers.dart';
import '../booking_gate_scope.dart';
import '../reserve_seat_actions.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/reservation_detail_sheet.dart';
import '../widgets/reserve_canvas.dart';
import '../widgets/reserve_hub_layout.dart';
import '../widgets/reserve_view_menu.dart';
import 'reserve_hub_header.dart';
import 'reserve_hub_host.dart';
import 'reserve_hub_metrics.dart';
import 'reserve_hub_recorder.dart';
import 'reserve_hub_views.dart';
import 'reserve_window_rules.dart';


/// Reserve hub (#208, epic #204): full-screen route pushed by the bottom
/// bar's raised centre button (#207). Top→bottom: a horizontal date-pill
/// strip (+ calendar icon for further dates) driving the selected day;
/// granularity-aware window chips (half-day Morning/Afternoon/Full day per
/// #201, else from→to clock chips per #184/#185); and a Plan · Day · Week
/// switch. Plan mirrors the live plan canvas for the selected window (free
/// seat tap books via the shared [BookingSheet], #206); Day shows the
/// the everyone-mode day timeline; Week shows the selected day's whole ISO
/// week as a seat × day occupancy grid (#236) — tapping a day header
/// selects that day and jumps to its Day view.
///
/// Deliberately forward-looking reserve + visibility only: no walk-up
/// check-in, no check-out, no seat blocking and no series booking here —
/// those stay on the Plan tab and the existing flows.
///
/// The State keeps the browsed day, window, view and "Show on plan" focus
/// (#2494); the header and the views are widgets reading them through
/// [ReserveHubHost], the window arithmetic is [ReserveWindowRules].
class ReserveScreen extends ConsumerStatefulWidget {
  const ReserveScreen({super.key});

  @override
  ConsumerState<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends ConsumerState<ReserveScreen>
    with ReserveSeatActions<ReserveScreen>
    implements ReserveHubHost {
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

  ReserveView _view = ReserveView.plan;

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
    // #1865 — the task recorder notes that the form was entered.
    unawaited(Future.microtask(() {
      if (mounted) ReserveHubRecorder(ref).openedReserve();
    }));
    // A focus request may already be pending when this screen is first
    // built — the ref.listen in build only catches later ones. Post-frame
    // so applying it never mutates a provider during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(planFocusControllerProvider);
      if (pending != null) _applyFocus(pending);
    });
  }

  // ── what the views and the seat actions ask of the hub ──

  @override
  DateTime get selectedDay => _selectedDay;

  @override
  DateTime get today => _today;

  @override
  ReserveView get view => _view;

  @override
  void showView(ReserveView view) => setState(() => _view = view);

  /// LIVE mode: today, with no hand-picked window (#687).
  ///
  /// The same condition the "Now" button offers to restore, and the hub's
  /// equivalent of the Plan tab's `_browse == null`. It decides whether a
  /// free-seat tap is a WALK-UP — "I am standing here now" — or a
  /// reservation for a browsed window. Getting it wrong either checks
  /// someone in for a slot they are not in yet, or refuses to check in
  /// someone who is standing at the desk.
  @override
  bool get isLive =>
      _selectedDay.isAtSameMomentAs(_today) && _windowStart == null;

  /// Booking granularity of the active workspace (#200/#201). Loading or
  /// unknown reads as flexible, like the plan header.
  @override
  BookingGranularity get granularity =>
      ref.read(bookingGranularityProvider).value ??
      BookingGranularity.flexible;

  ReserveWindowRules get _rules => ReserveWindowRules(granularity);

  /// The window the hub currently browses/books, always on [_selectedDay].
  HalfDayWindow _effectiveWindow(BookingGranularity granularity) =>
      ReserveWindowRules(granularity).effectiveWindow(
        selectedDay: _selectedDay,
        now: ref.read(clockProvider).now(),
        preferredPeriod: granularity.isDayBased
            ? ref.read(defaultPeriodProvider).value
            : null,
        start: _windowStart,
        end: _windowEnd,
      );

  @override
  HalfDayWindow get bookingWindow => _effectiveWindow(granularity);

  @override
  ReserveFocus get focus => (
        seatId: _focusSeatId,
        deskId: _focusDeskId,
        officeId: _focusOfficeId,
        level: _focusLevel,
      );

  /// #903 — the OPEN day around [at]: what the divided seat fill and the
  /// seat-day timeline measure themselves against.
  // #908 — anchored on the workspace clock: "08:00–17:00" describes the
  // space, not the device reading it.
  @override
  ({DateTime start, DateTime end}) dayWindow(DateTime at) =>
      workDayWindow(at, hours: bookingGateOf(ref)?.hours);

  @override
  DateTime defaultEndFor(DateTime from) => _rules.defaultEndFor(from);

  @override
  DateTime lastSlotOf(DateTime day) => _rules.lastSlotOf(day);

  @override
  bool isWorkspaceOpenAt(DateTime at) {
    final openWeekdays = ref.read(openWeekdaysProvider).value;
    final closures = ref.read(closureDaysProvider).value;
    if (openWeekdays == null || closures == null) return false;
    return isWorkspaceOpenOn(WorkspaceTime.dateOf(at), openWeekdays, closures);
  }

  // #1301 S4, widened by #1580: waiting on two of the five reads a window is
  // judged against let one be measured against invented hours.
  @override
  bool get availabilityKnown => !bookingDataPending(ref);

  /// Detail sheet + "Show on plan" jump — via the shared helper that owns
  /// the popped-target handling (#182/#206/#422).
  @override
  Future<void> openReservation(Reservation reservation) =>
      showReservationDetail(context, ref, reservation);

  /// #772 — whether the BROWSED window contains this very moment (in
  /// workspace wall time): choosing the Morning chip during the morning
  /// still means "I could be sitting here now", so the booking sheet offers
  /// to check in right away — without turning the tap into a walk-up (a
  /// hand-picked window must stay bookable as picked).
  @override
  bool get windowIsNow {
    if (!_selectedDay.isAtSameMomentAs(_today)) return false;
    // #1082 — compare INSTANTS. The window bounds are already workspace-
    // anchored absolute instants, and `now` is an absolute instant, so no
    // wall-clock reconstruction is needed at all: comparing them directly is
    // right in every timezone (at 09:00 in New York, 15:00 in Paris, the
    // Morning chip must not read as live for a half-day that ended hours
    // ago).
    final now = ref.read(clockProvider).now();
    final window = bookingWindow;
    return !now.isBefore(window.start) && now.isBefore(window.end);
  }

  // ── day selection (strip · calendar icon · week-grid headers) ──

  /// Central day switch: re-maps the window onto the new day (canonical half
  /// re-derived under half-day granularity, times of day kept under
  /// flexible — plan's date-button behaviour, #184/#201). The week grid
  /// needs no syncing: it re-derives its week from [_selectedDay].
  @override
  void selectDay(DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (DateUtils.isSameDay(dayOnly, _selectedDay)) return;
    ReserveHubRecorder(ref).selectedDate(dayOnly, _today); // #1865
    HalfDayWindow? moved;
    if (_windowStart != null && _windowEnd != null) {
      moved = _rules.remapWindow(bookingWindow,
          fromDay: _selectedDay, toDay: dayOnly);
    }
    setState(() {
      _selectedDay = dayOnly;
      _windowStart = moved?.start;
      _windowEnd = moved?.end;
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
    selectDay(picked);
  }

  // ── window chips (plan header patterns #184/#201) ──

  Future<void> _pickFrom() async {
    final window = bookingWindow;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(WorkspaceTime.wall(window.start)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final rules = _rules;
    final from = rules.snapToSlot(WorkspaceTime.at(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      picked.hour,
      picked.minute,
    ));
    final end = rules.endAfter(from, window.end.difference(window.start));
    setState(() {
      _windowStart = from;
      _windowEnd = end;
    });
    ReserveHubRecorder(ref).selectedCustomPeriod(from, end); // #1865
  }

  Future<void> _pickTo() async {
    final window = bookingWindow;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(WorkspaceTime.wall(window.end)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final l10n = context.l10n;
    final from = window.start;
    final fromWall = WorkspaceTime.wall(from);
    final end = _rules.snapToSlot(WorkspaceTime.at(
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
    setState(() {
      _windowStart = from;
      _windowEnd = end;
    });
  }

  // ── "Show on plan" (#182/#576) ──

  /// Applies a pending "Show on plan" jump (#182/#576).
  ///
  /// It lands HERE now that the hub is the only map surface. PlanCanvas has
  /// always taken the highlight parameters; the hub simply never passed
  /// them, because the Plan tab owned the jump.
  void _applyFocus(PlanFocus focus) {
    // A "show on plan" jump names a floor, and the other views should
    // follow it: the member asked to be taken somewhere.
    ref.read(browsedLevelProvider.notifier).select(focus.levelId);
    setState(() {
      _view = ReserveView.plan;
      _focusSeatId = focus.seatId;
      _focusDeskId = focus.deskId;
      _focusOfficeId = focus.officeId;
      _focusLevel = focus.wholeLevel;
    });
    final at = focus.at;
    // Only a FUTURE instant moves the browsed day: jumping to a booking that
    // already ended should show WHERE it was, not send the hub back in time
    // to a day nobody asked for.
    if (at != null && at.isAfter(ref.read(clockProvider).now())) {
      setState(() {
        _selectedDay = WorkspaceTime.dateOf(at);
        // Provisional (#184): the reservation's own end is not on the
        // focus, so the window opens at its start with the default stay and
        // is refined below once the day's bookings resolve.
        _windowStart = at;
        _windowEnd = defaultEndFor(at);
      });
      unawaited(_resolveFocusWindow(focus, at));
    }
    // Cleared after the frame: mutating the provider inside its own change
    // notification re-enters the listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(planFocusControllerProvider.notifier).clear();
    });
  }

  /// #184 — widens the focus window to the jumped-to reservation's own
  /// `[startsAt, endsAt)` once the day's bookings arrive.
  ///
  /// Ported with the Plan tab's job: without it the hub browses a
  /// default-length window at the right start, so a two-hour booking shows
  /// as one and the plan disagrees with the sheet that sent you.
  ///
  /// Whole-space jumps carry no seat and keep the default window — there is
  /// no single reservation whose hours to adopt.
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
    final last = lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) return;
    setState(() => _windowEnd = end);
  }

  /// Drops the jump highlight. Any interaction that changes what is being
  /// looked at means the question "where is it" has been answered.
  @override
  void clearFocus() {
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

  // ── build ──

  /// #2016 — 'Back to now': today AND the live window (a hand-picked window
  /// left on today reads as live while past). Only while browsing; on the
  /// view row so #699's two rows hold.
  Widget? _backToNow(AppLocalizations l10n) {
    if (!_selectedDay.isAtSameMomentAs(_today) ||
        _windowStart != null) {
      // A word, not a clock (that read as a time editor); the full action is
      // the tooltip and the screen-reader label.
      return Tooltip(
        message: l10n.reserveBackToNow,
        child: TextButton(
          key: const ValueKey('reserve-now-button'),
          onPressed: () => setState(() {
            _selectedDay = _today;
            _windowStart = null;
            _windowEnd = null;
          }),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            minimumSize: const Size(0, kMinInteractiveDimension),
          ),
          child: Text(
            l10n.planNowButton,
            semanticsLabel: l10n.reserveBackToNow,
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // #182 — the hub stays alive in the shell's indexed stack, so this
    // listener survives tab switches.
    ref.listen(planFocusControllerProvider, (_, focus) {
      if (focus != null) _applyFocus(focus);
    });
    final l10n = context.l10n;
    // Watched so the chips swap once the rule resolves (#201) — flexible is
    // also the rule's default, so nothing flashes.
    final watchedGranularity = ref.watch(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
    final window = _effectiveWindow(watchedGranularity);
    final dayOpen = reserveDayAvailability(ref, _selectedDay).open;
    // No own AppBar: the hub lives inside the shell (bottom bar always
    // visible); the shell's app bar carries the 'Reserve' title.
    // ReserveHubLayout owns the adaptive controls panel and view transitions.
    final header = ReserveHubHeader(
      host: this,
      window: window,
      backToNow: _backToNow(l10n),
      actions: ReserveHeaderActions(
        pickDate: _pickDate,
        pickFrom: _pickFrom,
        pickTo: _pickTo,
        pickWindow: (w) => setState(() {
          _windowStart = w.start;
          _windowEnd = w.end;
        }),
      ),
    );
    return ReserveHubLayout(
      header: header,
      view: _view,
      buildView: (view) => switch (view) {
        ReserveView.plan || ReserveView.list =>
          ReservePlanView(host: this, window: window, dayOpen: dayOpen),
        ReserveView.day => ReserveDayView(host: this),
        ReserveView.week => ReserveWeekView(host: this),
        ReserveView.month => ReserveMonthView(host: this),
      },
    );
  }
}
