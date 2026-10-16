// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Reserve hub's views (#2494): Plan and List (availability of the
// selected window on the live-plan canvas), Day, Week (#236) and Month (#7).
// Each is a widget reading the browsed day through [ReserveHubHost] and the
// reservations through its own providers.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/lexicon.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/availability_unavailable_banner.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/motion.dart';
import '../../../calendar/presentation/widgets/day_timeline.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/default_level_controller.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_availability.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/space_code.dart';
import '../../domain/week_tap_window.dart';
import '../../providers/browsed_level.dart';
import '../../providers/reservation_providers.dart';
import '../space_subjects.dart';
import '../widgets/booking_controls.dart';
import '../widgets/list_space_tap.dart';
import '../widgets/month_grid.dart';
import '../widgets/reserve_canvas.dart';
import '../widgets/reserve_view_menu.dart';
import '../widgets/seat_list_view.dart';
import '../widgets/space_scan.dart';
import '../widgets/week_grid.dart';
import 'reserve_hub_host.dart';
import 'reserve_hub_recorder.dart';

/// Plan view (map) or List view (the same plan as seats), per
/// [ReserveHubHost.view].
class ReservePlanView extends ConsumerWidget {
  const ReservePlanView({
    super.key,
    required this.host,
    required this.window,
    required this.dayOpen,
  });

  final ReserveHubHost host;
  final HalfDayWindow window;
  final bool dayOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
    final level = _browsedLevel(ref, levels);
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
    final seatList = host.view == ReserveView.list;
    // Floor switcher floats over the canvas (indoor-maps idiom, UX pass) —
    // hub-local browsing state (#187), never the plan tab's persisted
    // default (#159).
    final selector = _levelSelector(context, ref, levels, level);
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              if (seatList)
                Align(alignment: Alignment.topRight, child: selector),
              Expanded(
                // #209/#611 — map and list CROSS-FADE rather than swapping
                // hard. Outside any InteractiveViewer, so pan/zoom is
                // untouched by the transition.
                child: AnimatedSwitcher(
                  duration: AppMotion.viewSwitchOf(context),
                  child: _body(context, ref, planAsync, level, reservations,
                      seatList),
                ),
              ),
            ],
          ),
        ),
        if (!seatList)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: selector,
          ),
      ],
    );
  }

  /// #687 — the hub is the only map surface, so the floor it shows is the
  /// member's PERSISTED default (#159) when nothing has been browsed. The
  /// browsed choice still wins while set.
  ///
  /// #1269 — and when that choice is "All levels", this view RESOLVES it
  /// without WRITING over it. The plan cannot show two floors at once, so it
  /// falls back to the default and draws one — but the value stays what the
  /// member set, and the day view finds its chip exactly as it was left. A
  /// view that cannot honour a shared value must never destroy it.
  Level _browsedLevel(WidgetRef ref, List<Level> levels) {
    final browsed = ref.watch(browsedLevelProvider);
    final wanted = browsed == BrowsedLevel.allLevels ? null : browsed;
    return levels
            .where((l) =>
                l.id == (wanted ?? ref.watch(selectedLevelIdProvider).value))
            .firstOrNull ??
        levels.first;
  }

  Widget _levelSelector(
    BuildContext context,
    WidgetRef ref,
    List<Level> levels,
    Level level,
  ) {
    return LevelSelector(
      key: const ValueKey('reserve-layers'),
      keyPrefix: 'reserve',
      levels: levels,
      current: level,
      onSelected: (id) {
        // Changing floor answers the question the highlight was asking, so
        // the ring goes with it.
        host.clearFocus();
        ref.read(browsedLevelProvider.notifier).select(id);
        ReserveHubRecorder(ref).selectedLevel(); // #1881
        // #687/#159 — and it STICKS. Choosing a floor used to be browsing-
        // only here because the Plan tab owned the stored default; with
        // that tab gone, a member who works on the second floor would have
        // re-picked it on every launch forever.
        unawaited(ref.read(selectedLevelIdProvider.notifier).select(id));
      },
      // #466: the whole-level booking button, Plan-tab parity — the hub only
      // had the hidden double-tap path.
      trailing: _levelReserveVisible(ref, level)
          ? IconButton(
              key: const ValueKey('reserve-reserve-level'),
              tooltip: lexiconText(context,
                  key: 'levelReserveButton',
                  fallback: context.l10n.levelReserveButton),
              icon: const Icon(Icons.layers_outlined),
              onPressed: () => _reserveLevel(context, ref, level),
            )
          : null,
    );
  }

  void _reserveLevel(BuildContext context, WidgetRef ref, Level level) {
    final plan = ref.read(floorPlanProvider(level.id)).value;
    final window = host.bookingWindow;
    unawaited(showSpaceSheet(
      context,
      kind: SpaceKind.level,
      level: level,
      plan: plan,
      initialWindow: (start: window.start, end: window.end),
      // #687 — the level button is the OWNER's assignment path (#638). With
      // no roster it silently degraded to "book this floor for myself".
      members: spaceAssignmentCandidates(ref),
    ));
  }

  /// The map or the list, or why there is none.
  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<FloorPlan> planAsync,
    Level level,
    List<Reservation> reservations,
    bool seatList,
  ) {
    final l10n = context.l10n;
    final names = ref.watch(memberNamesProvider).value ?? const {};
    return switch (planAsync) {
      // #687 — the list answers "which seat can I take"; the map answers
      // "where is it". Same data, same tap handler, same closed-day gate.
      //
      // KeyedSubtree so the AnimatedSwitcher above sees a new child and
      // cross-fades (#209) instead of swapping hard.
      AsyncData(value: final plan) when seatList => KeyedSubtree(
          key: const ValueKey('reserve-list-view'),
          child: SeatListView(
            plan: plan,
            reservations: reservations,
            names: names,
            at: window.start,
            // Live judges at the instant, browsing across the window — the
            // same split the canvas and the tap handler use.
            windowEndOrNull: host.isLive ? null : window.end,
            dayOpen: dayOpen,
            onSeatTap: (seat) =>
                _seatTapped(ref, 'list', plan, seat, reservations),
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
          day: host.dayWindow(window.start),
          focus: host.focus,
          onSeatTap: (seat) =>
              _seatTapped(ref, 'plan', plan, seat, reservations),
        ),
      // #2011 — the floor plan could not be read: say so and offer Retry;
      // the level selector stays, so the level is kept.
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
    };
  }

  void _seatTapped(
    WidgetRef ref,
    String viewMode,
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
  ) {
    ReserveHubRecorder(ref).selectedSeat(viewMode, seat.name); // #1865
    unawaited(host.onSeatTap(plan, seat, reservations, window));
  }

  /// Whether [level] offers the whole-level booking affordance to ME — the
  /// plan tab's #466 rule: feature on, level bookable, and I hold the grant
  /// OR administer (the 0079 server rule).
  bool _levelReserveVisible(WidgetRef ref, Level level) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    if (!features.contains(WorkspaceFeature.levelBooking)) return false;
    if (!level.bookableAsWhole) return false;
    final me = ref.watch(myMemberProvider).value;
    if (me == null || me.status != MemberStatus.active) return false;
    return me.canReserveLevel || ref.watch(actsForReservationsProvider);
  }
}

/// #814 — whether the workspace is open on a day, for the Day, Week and
/// Month views (the plan already reads `dayOpen`). Null while the feature is
/// off: the views then draw every day as bookable, as they always did.
bool Function(DateTime day)? _dayOpenPredicate(WidgetRef ref) {
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

/// Day view: the selected day's per-seat timeline in everyone mode — see who
/// else is booked; own blocks open the detail sheet.
class ReserveDayView extends ConsumerWidget {
  const ReserveDayView({super.key, required this.host});

  final ReserveHubHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = host.selectedDay;
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final dayKey = dayKeyOf(selectedDay);
    final dayRead = ref.watch(reservationsForDayProvider(dayKey));
    if (dayRead.hasError && !dayRead.hasValue) {
      return AvailabilityUnavailableBanner(
          onRetry: () => ref.invalidate(reservationsForDayProvider(dayKey)));
    }
    final reservations = dayRead.value ?? const <Reservation>[];
    final active = [for (final r in reservations) if (r.held) r];
    return DayTimeline(
      day: selectedDay,
      reservations: active,
      everyone: true,
      myMemberId: myMemberId,
      onReservationTap: host.openReservation,
      // The hub's Day view is an AVAILABILITY surface: every seat row
      // renders, and tapping a row's free area books the selected window on
      // that seat (no more look-but-can't-book).
      showFreeSeats: true,
      dayOpen: _dayOpenPredicate(ref)?.call(selectedDay) ?? true,
      onFreeSeatTap: (seat) => host.bookingSheet(
        seat,
        active,
        host.bookingWindow,
      ),
      // #2631 — a room is booked at the hour that was tapped.
      onFreeSeatTapAt: (seat, at) => host.bookingSheet(
        seat,
        active,
        seat.slotMinutes == null
            ? host.bookingWindow
            : (start: at, end: at.add(const Duration(minutes: 1))),
      ),
    );
  }
}

/// Week view (#236): the whole ISO week around the selected day as a seat ×
/// day grid. Reservations come from the month provider(s) covering the week —
/// BOTH months when the week straddles a boundary — and the grid slices them
/// per day itself (never seven per-day fetches). Tapping a day header selects
/// the day and switches to the Day view.
class ReserveWeekView extends ConsumerWidget {
  const ReserveWeekView({super.key, required this.host});

  final ReserveHubHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = host.selectedDay;
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final monday = WeekGrid.weekStartOf(selectedDay);
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
      selectedDay: selectedDay,
      reservations: [
        for (final r in byId.values)
          if (r.held) r,
      ],
      everyone: true,
      myMemberId: myMemberId,
      onDaySelected: (day) {
        host
          ..selectDay(day)
          ..showView(ReserveView.day);
      },
      onReservationTap: host.openReservation,
      isDayOpen: _dayOpenPredicate(ref),
      onFreeSlotTap: (seat, day, {required morning}) {
        final window = weekTapWindow(
          day: day,
          morning: morning,
          granularity: host.granularity,
          current: host.bookingWindow,
          defaultEndFor: host.defaultEndFor,
        );
        unawaited(host.bookingSheet(seat, byId.values.toList(), window));
      },
    );
  }
}

/// Month view (#7): the selected day's month as an availability calendar —
/// free desks per day across ALL floors. Tapping a day selects it and drops
/// into the Day view, where occupants are named.
class ReserveMonthView extends ConsumerWidget {
  const ReserveMonthView({super.key, required this.host});

  final ReserveHubHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = host.selectedDay;
    final monthKey = monthKeyOf(selectedDay);
    final read = ref.watch(reservationsForMonthProvider(monthKey));
    if (read.hasError && !read.hasValue) {
      return AvailabilityUnavailableBanner(
          onRetry: () =>
              ref.invalidate(reservationsForMonthProvider(monthKey)));
    }
    final month = read.value ?? const <Reservation>[];
    return MonthGrid(
      key: const ValueKey('reserve-month-grid'),
      selectedDay: selectedDay,
      reservations: [for (final r in month) if (r.held) r],
      isDayOpen: _dayOpenPredicate(ref),
      onDaySelected: (day) {
        host
          ..selectDay(day)
          ..showView(ReserveView.day);
      },
    );
  }
}
