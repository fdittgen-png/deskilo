// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/height_probe.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/widgets/level_chip_row.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/providers/browsed_level.dart';
import '../../../workspace/providers/workspace_providers.dart';
import 'day_timeline_axis.dart';
import 'day_timeline_cells.dart';


/// Visual timeline of the selected calendar day (#187): one row per seat,
/// grouped under compact `office · desk` headers, blocks placed on a
/// horizontal 24h axis by reservation start–end.
///
/// The level choice is LOCAL state — deliberately not the plan tab's
/// `selectedLevelIdProvider`, which persists the member's default level.
///
/// Whole-office reservations render as a spanning block on EVERY seat of
/// that office: a whole-office booking occupies each seat, so each seat row
/// truthfully shows it as taken.
class DayTimeline extends ConsumerStatefulWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.reservations,
    required this.everyone,
    required this.myMemberId,
    required this.onReservationTap,
    this.showFreeSeats = false,
    this.onFreeSeatTap,
    this.onFreeSeatTapAt,
    this.dayOpen = true,
  });

  /// The selected local day (any instant within it).
  final DateTime day;

  /// Already filtered like the list: active + Mine/Everyone applied.
  /// May span the whole month; the timeline clips to [day] itself.
  final List<Reservation> reservations;

  /// Whether the Everyone filter is active — controls whether
  /// occupant names are drawn inside the blocks (parity with the list's
  /// subtitle).
  final bool everyone;

  /// The signed-in member — their blocks open [onReservationTap].
  final String? myMemberId;

  /// Tap on one of MY blocks (detail sheet, list parity). Blocks of other
  /// members show an occupant snackbar instead.
  final void Function(Reservation reservation) onReservationTap;

  /// Availability mode (the Reserve hub): every seat row renders even
  /// without reservations — a free row IS the availability — instead of
  /// collapsing to the empty hint.
  final bool showFreeSeats;

  /// Tap on a seat row's free area — the hub books the selected window
  /// on that seat. Null (the calendar) keeps rows passive.
  final void Function(Seat seat)? onFreeSeatTap;

  /// #2631 — the same tap with the INSTANT the finger landed on (the hour of
  /// a meeting room's track); wins over [onFreeSeatTap] where both are set.
  final void Function(Seat seat, DateTime at)? onFreeSeatTapAt;

  /// #814 — the workspace is closed on [day]: no free-area tap books
  /// anything, and every track reads muted like a blocked seat.
  final bool dayOpen;

  static Key blockKey(String reservationId) =>
      ValueKey('timeline-block-$reservationId');
  static Key trackKey(String seatId) => ValueKey('timeline-track-$seatId');
  static Key levelHeaderKey(String levelId) =>
      ValueKey('timeline-level-header-$levelId');
  static const Key nowLineKey = ValueKey('timeline-now-line');

  @override
  ConsumerState<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends ConsumerState<DayTimeline> {
  // The room the grid has, measured by [_HeightProbe]: seat rows grow into it.
  double _viewportHeight = 0;

  final ScrollController _axisController = ScrollController();

  /// #1269 — the level choice used to be a `State` field here, and one
  /// each in `WeekGrid` and `ReserveScreen`. Switching the view built a
  /// fresh widget whose field was null, so the hub snapped back to the
  /// first floor every time. It is [BrowsedLevel] now: one value above
  /// all four views, still browsing state and still never the plan's
  /// persisted default.
  ///
  /// Level ids collapsed in all-levels mode (#221 follow-up): tapping a
  /// level header hides its rows so a busy multi-floor day stays
  /// scannable. Session-only, and local because it means nothing to the
  /// other views.
  final Set<String> _collapsedLevels = {};

  /// Day the axis was last auto-scrolled for.
  DateTime? _autoScrolledDay;

  @override
  void dispose() {
    _axisController.dispose();
    super.dispose();
  }

  DateTime get _dayStart =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);

  /// The day as INSTANTS in the workspace's timezone (#490) — what
  /// reservation cover checks must compare against.
  DateTime get _dayStartInstant => WorkspaceTime.at(
      widget.day.year, widget.day.month, widget.day.day);

  DateTime get _dayEndInstant => WorkspaceTime.at(
      widget.day.year, widget.day.month, widget.day.day + 1);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final levels = ref.watch(levelsProvider).value;
    if (levels == null) {
      return const LoadingView();
    }
    if (levels.isEmpty) {
      return const TimelineEmptyHint(allLevels: false);
    }
    // Default stays the FIRST real level; "All levels" is opt-in.
    final browsed = ref.watch(browsedLevelProvider);
    final allSelected = levels.length > 1 && browsed == BrowsedLevel.allLevels;
    final level = allSelected
        ? null
        : levels.where((l) => l.id == browsed).firstOrNull ?? levels.first;
    final names = ref.watch(memberNamesProvider).value ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Level chips like the plan tab (#159 pattern) — but the selection
        // here is throwaway browsing state, never the persisted default.
        // Row height and tap target meet the 48dp Material minimum (#211).
        LevelChipRow(
          key: const ValueKey('day-timeline-calendar-all-levels'),
          levels: levels,
          selectedLevelId: level?.id,
          onSelected: (id) =>
              ref.read(browsedLevelProvider.notifier).select(id),
          // Sentinel chip FIRST: stack every level on one axis (#221).
          allLevelsLabel: l10n.calendarAllLevels,
          allLevelsSelected: allSelected,
          onAllLevelsSelected: () =>
              ref.read(browsedLevelProvider.notifier).selectAll(),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: HeightProbe(
                  onHeight: (h) {
                    if (h != _viewportHeight && mounted) {
                      setState(() => _viewportHeight = h);
                    }
                  },
                ),
              ),
              Positioned.fill(
                child: allSelected
                    ? _allLevelsBody(context, levels, names)
                    : _singleLevelBody(context, level!, names),
              ),
            ],
          ),
        ),
      ],
    );
  }

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

  /// The instant [dx] pixels along the track (the inverse of `_offsetOf`).
  DateTime _instantAt(double dx) {
    final minutes = (dx / TimelineAxis.hourWidth * 60).floor();
    return WorkspaceTime.at(_dayStart.year, _dayStart.month, _dayStart.day,
        minutes ~/ 60, minutes % 60);
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

  /// A level header's tap: collapse its rows, or open them again.
  void _toggleLevel(String levelId) => setState(() {
        if (!_collapsedLevels.remove(levelId)) {
          _collapsedLevels.add(levelId);
        }
      });

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
    final planAsync = ref.watch(floorPlanProvider(level.id));
    return switch (planAsync) {
      AsyncData(value: final plan) => _grid(context, [(null, plan)], names),
      AsyncError() => const TimelineEmptyHint(allLevels: false),
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

  /// Renders the given plans stacked on one shared axis. Single-level mode
  /// passes one `(null, plan)` entry (no level-header row); all-levels mode
  /// passes every level's plan in [levelsProvider]'s sortOrder.
  Widget _grid(
    BuildContext context,
    List<(Level?, FloorPlan)> plans,
    Map<String, String> names,
  ) {
    final allLevels = plans.any((e) => e.$1 != null);

    final dayReservations = widget.reservations
        .where((r) => r.holdsRange(_dayStartInstant, _dayEndInstant))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    // Built lazily: how tall a seat row is depends on how many there are.
    final rows = TimelineRows(
      ruler: TimelineRuler(
        format: ref.watch(appFormatProvider), // #1150
        dayStart: _dayStart,
      ),
    );
    final visibleReservations = <Reservation>[];
    for (final (level, plan) in plans) {
      visibleReservations.addAll(
          _addLevel(rows, level, plan, dayReservations, names));
    }

    // Free mode keeps rows even when nothing is booked — the hint only
    // fires when there are NO rows at all (no seats anywhere).
    if (visibleReservations.isEmpty &&
        (!widget.showFreeSeats || rows.tracks.length <= 1)) {
      return TimelineEmptyHint(allLevels: allLevels);
    }
    // Concatenating per-level lists loses the global start order the
    // auto-scroll relies on — restore it.
    visibleReservations.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (visibleReservations.isNotEmpty) {
      _scheduleAutoScroll(visibleReservations);
    }

    final now = ref.watch(clockProvider).now();
    final isToday = DateUtils.isSameDay(now, widget.day);
    final rowHeight = rows.rowHeightFor(_viewportHeight);

    return TimelineAxisView(
      controller: _axisController,
      leading: [for (final b in rows.leadingCells) b(rowHeight)],
      tracks: [for (final b in rows.tracks) b(rowHeight)],
      nowOffset: isToday ? _offsetOf(now) : null,
    );
  }

  /// One level's rows: its header in all-levels mode, then every desk's
  /// `office · desk` header and seat rows. Returns the level's
  /// reservations that day, or none when the level shows nothing.
  List<Reservation> _addLevel(
    TimelineRows rows,
    Level? level,
    FloorPlan plan,
    List<Reservation> dayReservations,
    Map<String, String> names,
  ) {
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
      return const [];
    }

    final collapsed = level != null && _collapsedLevels.contains(level.id);
    if (level != null) {
      rows.addHeader(
        TimelineLevelHeader(
          levelId: level.id,
          name: level.name,
          collapsed: collapsed,
          onToggle: () => _toggleLevel(level.id),
        ),
        TimelineAxis.levelHeaderRowHeight,
      );
    }
    // Collapsed: the header stays (a tap re-opens it) but its office /
    // desk / seat rows are skipped entirely.
    if (collapsed) return levelReservations;
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
        rows.addHeader(
          TimelineGroupHeader(label: header),
          TimelineAxis.headerRowHeight,
        );
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
          rows.addSeat(
            (h) => TimelineSeatCell(
              name: seat.name,
              blocked: _blockedDuring(seat),
              height: h,
            ),
            (h) => _track(seat, blocks, names, h),
          );
        }
      }
    }
    return levelReservations;
  }

  Widget _track(
    Seat seat,
    List<Reservation> blocks,
    Map<String, String> names,
    double rowHeight,
  ) {
    final onFreeSeatTap = widget.onFreeSeatTap;
    final onFreeSeatTapAt = widget.onFreeSeatTapAt;
    return TimelineTrack(
      seatId: seat.id,
      height: rowHeight,
      blocked: _blockedDuring(seat) || !widget.dayOpen,
      onFreeTap: onFreeSeatTap == null ? null : () => onFreeSeatTap(seat),
      onFreeTapAt: onFreeSeatTapAt == null
          ? null
          : (dx) => onFreeSeatTapAt(seat, _instantAt(dx)),
      blocks: [for (final r in blocks) _block(r, names)],
    );
  }

  Widget _block(Reservation reservation, Map<String, String> names) {
    final left = _offsetOf(reservation.startsAt);
    final right = _offsetOf(reservation.endsAt);
    final width = (right - left) < TimelineAxis.blockMinWidth
        ? TimelineAxis.blockMinWidth
        : right - left;
    return TimelineBlock(
      reservationId: reservation.id,
      left: left,
      width: width,
      own: reservation.memberId == widget.myMemberId,
      occupant: names[reservation.memberId] ?? '',
      showOccupant: widget.everyone && width > 40,
      onOpen: () => _onBlockTap(reservation),
    );
  }
}
