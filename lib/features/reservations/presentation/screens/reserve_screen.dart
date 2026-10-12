// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/help/help_blocker.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/lexicon.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/work_hours.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/availability_unavailable_banner.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calendar/presentation/widgets/day_timeline.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/providers/default_level_controller.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../../task_recorder/application/booking_observation.dart'
    show dateRelation, dayValues, periodOf, periodValues, resourceValues;
import '../../../task_recorder/domain/action_registry.dart'
    show RecorderActions;
import '../../../task_recorder/presentation/recorder_seam.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/booking_policies.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/next_open_day.dart';
import '../../../workspace/domain/workspace.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/getting_started_hint.dart';
import '../../domain/default_booking_period.dart';
import '../../domain/reservation.dart';
import '../../domain/space_code.dart';
import '../../domain/week_tap_window.dart';
import '../../providers/browsed_level.dart';
import '../../providers/default_period_controller.dart';
import '../../providers/reservation_providers.dart';
import '../booking_gate_scope.dart';
import '../getting_started_facts.dart';
import '../reserve_seat_actions.dart';
import '../space_subjects.dart';
import '../widgets/booking_controls.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/booking_window_summary.dart';
import '../widgets/getting_started_card.dart';
import '../widgets/list_space_tap.dart';
import '../widgets/month_grid.dart';
import '../widgets/pending_booking_banner.dart';
import '../widgets/reservation_detail_sheet.dart';
import '../widgets/reserve_canvas.dart';
import '../widgets/reserve_hub_layout.dart';
import '../widgets/reserve_view_menu.dart';
import '../widgets/seat_legend.dart';
import '../widgets/seat_list_view.dart';
import '../widgets/space_scan.dart';
import '../widgets/stale_availability_banner.dart';
import '../widgets/week_grid.dart';

part 'reserve_screen_part1.dart';
part 'reserve_screen_part2.dart';
part 'reserve_screen_part3.dart';

part 'reserve_screen_part4.dart';


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
      if (mounted) recordTaskStep(ref, RecorderActions.openReserve);
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

  /// #903 — the OPEN day around [at]: what the divided seat fill and the
  /// seat-day timeline measure themselves against.
  // #908 — anchored on the workspace clock: "08:00–17:00" describes the
  // space, not the device reading it.
  ({DateTime start, DateTime end}) _dayWindow(DateTime at) =>
      workDayWindow(at, hours: bookingGateOf(ref)?.hours);

  // #1269 — the browsed level lives in [BrowsedLevel] now, shared with
  // the day and week views. It used to be a `State` field here and one
  // in each of those, so switching the view built a fresh widget whose
  // field was null and the hub snapped back to the first floor.

  /// The seat LIST and the MAP are the same view with two
  /// presentations, so both render the plan surface below.
  bool get _seatList => _view == ReserveView.list;

  // ── window derivation (mirrors plan_screen's #184/#201 mechanics) ──

  /// Booking granularity of the active workspace (#200/#201). Loading or
  /// unknown reads as flexible, like the plan header.
  BookingGranularity get _granularity =>
      ref.read(bookingGranularityProvider).value ??
      BookingGranularity.flexible;

  /// One configured slot — the minimal booking extension.
  Duration get _slotStep => Duration(
        minutes: _granularity.stepMinutes ?? ReserveHubMetrics.snapMinutes,
      );

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
  ///
  bool get _isLive =>
      _selectedDay.isAtSameMomentAs(_today) && _windowStart == null;

  /// #814 — whether the workspace is open on [day], for the Day, Week
  /// and Month views (the plan already reads `dayOpen`). Null while the
  /// feature is off: the views then draw every day as bookable, as they
  /// always did.
  bool Function(DateTime day)? get _isDayOpen {
    if (!ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.bookingGate)) {
      return null;
    }
    final openWeekdays = ref.watch(openWeekdaysProvider).value;
    final closures = ref.watch(closureDaysProvider).value;
    // #1301 S4 — not loaded yet: no day reads as bookable.
    if (openWeekdays == null || closures == null) return (_) => false;
    return (day) => isWorkspaceOpenOn(day, openWeekdays, closures);
  }

  // #2386 — the operations; each body is in a part file.
  @override bool get isLive => _isLiveImpl;
  @override BookingGranularity get granularity => _granularityImpl;
  @override HalfDayWindow get bookingWindow => _bookingWindowImpl;
  @override bool isWorkspaceOpenAt(DateTime at) => _isWorkspaceOpenAtImpl(at);
  @override bool get availabilityKnown => _availabilityKnownImpl;
  @override DateTime defaultEndFor(DateTime from) => _defaultEndForImpl(from);
  @override DateTime lastSlotOf(DateTime day) => _lastSlotOfImpl(day);
  @override Future<void> openReservation(Reservation reservation) => _openReservationImpl(reservation);
  @override bool get windowIsNow => _windowIsNowImpl;
  @override Widget build(BuildContext context) => _buildImpl(context);

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

}
