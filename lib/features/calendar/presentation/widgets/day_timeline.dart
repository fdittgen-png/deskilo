// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/presentation/widgets/level_chip_row.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/providers/reservation_providers.dart';

/// Geometry of the 24h timeline axis (#187). Pinned by test — treat these
/// as part of the visual contract, not free-floating magic numbers.
abstract final class TimelineAxis {
  /// Horizontal pixels per hour on the track.
  static const double hourWidth = 48;

  /// Hours drawn on the axis (one local calendar day).
  static const int hoursPerDay = 24;

  /// Total scrollable track width.
  static const double trackWidth = hourWidth * hoursPerDay;

  /// An hour label (and grid line) every this many hours.
  static const int labelStepHours = 2;

  /// Height of one seat row / its track.
  static const double rowHeight = 36;

  /// Height of an `office · desk` group header row.
  static const double headerRowHeight = 28;

  /// Height of a level-name header row in all-levels mode (#221).
  static const double levelHeaderRowHeight = 32;

  /// Height of the hour ruler above the tracks.
  static const double rulerHeight = 24;

  /// Fixed width of the leading seat-name column.
  static const double leadingWidth = 112;

  /// Where the axis auto-scrolls to when the day has no reservation.
  static const int defaultStartHour = 8;

  /// Lead-in (hours) kept visible left of the auto-scroll target.
  static const double autoScrollLeadHours = 0.5;

  /// Vertical inset of a reservation block inside its row.
  static const double blockInset = 4;

  /// Minimum rendered block width so tiny bookings stay visible.
  static const double blockMinWidth = 2;

  /// Width of the "now" indicator line.
  static const double nowLineWidth = 2;
}

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
  });

  /// The selected local day (any instant within it).
  final DateTime day;

  /// Already filtered like the list: active + Mine/Everyone applied.
  /// May span the whole month; the timeline clips to [day] itself.
  final List<Reservation> reservations;

  /// Whether the admin-gated Everyone filter is active — controls whether
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
  /// Sentinel value of [_levelId] for the "All levels" chip (#221) — never
  /// a real level id (real ids are UUIDs / seeded `level-N` ids).
  static const String _allLevelsId = '__all-levels__';

  final ScrollController _axisController = ScrollController();

  /// Level chip choice — local, never the plan's persisted default.
  /// [_allLevelsId] stacks every level on one shared axis.
  String? _levelId;

  /// Level ids collapsed in all-levels mode (#221 follow-up): tapping a
  /// level header hides its rows so a busy multi-floor day stays scannable.
  /// Session-only browsing state, like [_levelId].
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

  DateTime get _dayEnd =>
      DateTime(widget.day.year, widget.day.month, widget.day.day + 1);

  /// Horizontal offset of [at] on the track, clamped to the day.
  double _offsetOf(DateTime at) {
    final minutes = at.toLocal().difference(_dayStart).inMinutes;
    final raw = minutes / 60.0 * TimelineAxis.hourWidth;
    return raw.clamp(0.0, TimelineAxis.trackWidth).toDouble();
  }

  /// Blocked for maintenance at some point during the day (#161 blocks are
  /// half-open ranges): blocked when the day starts, or the block begins
  /// later within this day.
  bool _blockedDuring(Seat seat) {
    if (seat.isBlockedAt(_dayStart)) return true;
    final from = seat.blockedFrom;
    return from != null && !from.isBefore(_dayStart) && from.isBefore(_dayEnd);
  }

  void _onBlockTap(Reservation reservation) {
    if (reservation.memberId == widget.myMemberId) {
      widget.onReservationTap(reservation);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final names = ref.read(memberNamesProvider).value ?? const {};
    final name = names[reservation.memberId] ?? '';
    final until = DateFormat.Hm().format(reservation.endsAt.toLocal());
    final message = '${l10n?.planOccupiedBy(name) ?? 'Occupied by $name'} · '
        '${l10n?.planUntil(until) ?? 'until $until'}';
    AppSnack.info(context, message, replace: true);
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levels = ref.watch(levelsProvider).value;
    if (levels == null) {
      return const LoadingView();
    }
    if (levels.isEmpty) {
      return _emptyHint(l10n, allLevels: false);
    }
    // Default stays the FIRST real level; "All levels" is opt-in per view.
    final allSelected = levels.length > 1 && _levelId == _allLevelsId;
    final level = allSelected
        ? null
        : levels.where((l) => l.id == _levelId).firstOrNull ?? levels.first;
    final names = ref.watch(memberNamesProvider).value ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Level chips like the plan tab (#159 pattern) — but the selection
        // here is throwaway browsing state, never the persisted default.
        // Row height and tap target meet the 48dp Material minimum (#211).
        LevelChipRow(
          levels: levels,
          selectedLevelId: level?.id,
          onSelected: (id) => setState(() => _levelId = id),
          // Sentinel chip FIRST: stack every level on one axis (#221).
          allLevelsLabel: l10n?.calendarAllLevels ?? 'All levels',
          allLevelsSelected: allSelected,
          onAllLevelsSelected: () =>
              setState(() => _levelId = _allLevelsId),
        ),
        Expanded(
          child: allSelected
              ? _allLevelsBody(context, levels, names)
              : _singleLevelBody(context, level!, names),
        ),
      ],
    );
  }

  Widget _singleLevelBody(
    BuildContext context,
    Level level,
    Map<String, String> names,
  ) {
    final l10n = AppLocalizations.of(context);
    final planAsync = ref.watch(floorPlanProvider(level.id));
    return switch (planAsync) {
      AsyncData(value: final plan) => _grid(context, [(null, plan)], names),
      AsyncError() => _emptyHint(l10n, allLevels: false),
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

  Widget _emptyHint(AppLocalizations? l10n, {required bool allLevels}) {
    final hint = allLevels
        ? (l10n?.calendarTimelineAllEmpty ??
            'No reservations on any level for this day.')
        : (l10n?.calendarTimelineEmpty ??
            'No reservations on this level for this day.');
    // Stays a scrollable so an enclosing RefreshIndicator keeps working.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: Icons.view_timeline_outlined,
            title: hint,
          ),
        ),
      ],
    );
  }

  /// Renders the given plans stacked on one shared axis. Single-level mode
  /// passes one `(null, plan)` entry (no level-header row); all-levels mode
  /// passes every level's plan in [levelsProvider]'s sortOrder.
  Widget _grid(
    BuildContext context,
    List<(Level?, FloorPlan)> plans,
    Map<String, String> names,
  ) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final allLevels = plans.any((e) => e.$1 != null);

    final dayReservations = widget.reservations
        .where((r) => r.coversRange(_dayStart, _dayEnd))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final leadingCells = <Widget>[
      const SizedBox(height: TimelineAxis.rulerHeight),
    ];
    final tracks = <Widget>[_ruler(context)];
    final visibleReservations = <Reservation>[];
    for (final (level, plan) in plans) {
      // Only what lives on this level.
      final seatIds = {for (final s in plan.seats) s.id};
      final officeIds = {for (final o in plan.offices) o.id};
      final levelReservations = dayReservations
          .where((r) =>
              (r.seatId != null && seatIds.contains(r.seatId)) ||
              (r.officeId != null && officeIds.contains(r.officeId)))
          .toList();

      // Same per-level rule as single-level mode: nothing to show without
      // seats or without a visible reservation that day. In all-levels
      // mode such a level is skipped entirely (#221); the overall empty
      // hint below fires only when EVERY level came up empty.
      if (plan.seats.isEmpty ||
          (!widget.showFreeSeats && levelReservations.isEmpty)) {
        continue;
      }
      visibleReservations.addAll(levelReservations);

      final collapsed = level != null && _collapsedLevels.contains(level.id);
      if (level != null) {
        leadingCells
            .add(_levelHeaderCell(context, level: level, collapsed: collapsed));
        tracks.add(const SizedBox(
          height: TimelineAxis.levelHeaderRowHeight,
          width: TimelineAxis.trackWidth,
        ));
      }
      // Collapsed: the header stays (a tap re-opens it) but its office /
      // desk / seat rows are skipped entirely.
      if (collapsed) continue;
      for (final office in plan.offices) {
        final officeReservations = levelReservations
            .where((r) => r.officeId == office.id)
            .toList();
        for (final desk in plan.desksOf(office.id)) {
          final seats = plan.seatsOf(desk.id);
          if (seats.isEmpty) continue;
          final header = '${office.name} · ${desk.name}';
          leadingCells.add(_headerCell(context, header));
          tracks.add(const SizedBox(
            height: TimelineAxis.headerRowHeight,
            width: TimelineAxis.trackWidth,
          ));
          for (final Seat seat in seats) {
            final blocks = <Reservation>[
              ...officeReservations,
              ...levelReservations.where((r) => r.seatId == seat.id),
            ];
            leadingCells.add(_seatCell(context, seat, brightness));
            tracks.add(_track(context, seat, blocks, names, brightness));
          }
        }
      }
    }

    // Free mode keeps rows even when nothing is booked — the hint only
    // fires when there are NO rows at all (no seats anywhere).
    if (visibleReservations.isEmpty &&
        (!widget.showFreeSeats || tracks.length <= 1)) {
      return _emptyHint(l10n, allLevels: allLevels);
    }
    // Concatenating per-level lists loses the global start order the
    // auto-scroll relies on — restore it.
    visibleReservations.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (visibleReservations.isNotEmpty) {
      _scheduleAutoScroll(visibleReservations);
    }

    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(now, widget.day);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: TimelineAxis.leadingWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: leadingCells,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _axisController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: TimelineAxis.trackWidth,
                child: Stack(
                  children: [
                    for (var h = 0;
                        h < TimelineAxis.hoursPerDay;
                        h += TimelineAxis.labelStepHours)
                      Positioned(
                        left: h * TimelineAxis.hourWidth,
                        top: TimelineAxis.rulerHeight,
                        bottom: 0,
                        width: 1,
                        child: ColoredBox(
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: tracks,
                    ),
                    if (isToday)
                      Positioned(
                        key: DayTimeline.nowLineKey,
                        left: _offsetOf(now),
                        top: 0,
                        bottom: 0,
                        width: TimelineAxis.nowLineWidth,
                        child: ColoredBox(color: scheme.error),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruler(BuildContext context) {
    final timeFormat = DateFormat.Hm();
    final style = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: TimelineAxis.rulerHeight,
      width: TimelineAxis.trackWidth,
      child: Stack(
        children: [
          for (var h = 0;
              h < TimelineAxis.hoursPerDay;
              h += TimelineAxis.labelStepHours)
            Positioned(
              left: h * TimelineAxis.hourWidth + 3,
              bottom: 2,
              child: Text(
                timeFormat.format(_dayStart.add(Duration(hours: h))),
                style: style,
              ),
            ),
        ],
      ),
    );
  }

  /// Level-name header in all-levels mode — deliberately distinct from the
  /// muted `office · desk` group headers: titleSmall in the primary color.
  /// Tapping it collapses or expands that level's rows; the chevron shows
  /// which way the tap goes.
  Widget _levelHeaderCell(
    BuildContext context, {
    required Level level,
    required bool collapsed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      key: DayTimeline.levelHeaderKey(level.id),
      height: TimelineAxis.levelHeaderRowHeight,
      child: InkWell(
        onTap: () => setState(() {
          if (!_collapsedLevels.remove(level.id)) {
            _collapsedLevels.add(level.id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                collapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: collapsed
                      ? (l10n?.calendarLevelCollapsed(level.name) ??
                          '${level.name}, collapsed')
                      : (l10n?.calendarLevelExpanded(level.name) ??
                          '${level.name}, expanded'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(BuildContext context, String label) {
    return SizedBox(
      height: TimelineAxis.headerRowHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.sm),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }

  Widget _seatCell(BuildContext context, Seat seat, Brightness brightness) {
    final blocked = _blockedDuring(seat);
    return SizedBox(
      height: TimelineAxis.rowHeight,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                seat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            // Never state by color alone (spec §11): blocked seats get an
            // icon next to the muted track tint.
            if (blocked)
              Icon(
                Icons.block,
                size: 14,
                color: SeatStateColors.of(
                  SeatState.blocked,
                  brightness: brightness,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _track(
    BuildContext context,
    Seat seat,
    List<Reservation> blocks,
    Map<String, String> names,
    Brightness brightness,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = _blockedDuring(seat);
    final blockedTint = SeatStateColors.of(
      SeatState.blocked,
      brightness: brightness,
    ).withValues(alpha: 0.15);
    return Container(
      key: DayTimeline.trackKey(seat.id),
      height: TimelineAxis.rowHeight,
      width: TimelineAxis.trackWidth,
      decoration: BoxDecoration(
        color: blocked ? blockedTint : null,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Free-area tap books this seat (hub); the blocks above keep
          // their own handlers and win hit-testing.
          if (widget.onFreeSeatTap != null && !blocked)
            Positioned.fill(
              child: InkWell(
                key: ValueKey('timeline-free-${seat.id}'),
                onTap: () => widget.onFreeSeatTap!(seat),
              ),
            ),
          for (final r in blocks) _block(context, r, names, brightness),
        ],
      ),
    );
  }

  Widget _block(
    BuildContext context,
    Reservation reservation,
    Map<String, String> names,
    Brightness brightness,
  ) {
    final own = reservation.memberId == widget.myMemberId;
    final base = SeatStateColors.of(
      own ? SeatState.mine : SeatState.reserved,
      brightness: brightness,
    );
    // MY bookings carry the full tone; everyone else's step back a
    // notch, so 'when did I reserve what' reads before any label does.
    final color = own ? base : base.withValues(alpha: 0.78);
    final onColor =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final left = _offsetOf(reservation.startsAt);
    final right = _offsetOf(reservation.endsAt);
    final width = (right - left) < TimelineAxis.blockMinWidth
        ? TimelineAxis.blockMinWidth
        : right - left;
    final occupant = names[reservation.memberId] ?? '';
    final initial = occupant.trim().isEmpty
        ? ''
        : occupant.trim().characters.first.toUpperCase();
    return Positioned(
      left: left,
      width: width,
      top: TimelineAxis.blockInset,
      bottom: TimelineAxis.blockInset,
      child: Material(
        color: color,
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: DayTimeline.blockKey(reservation.id),
          onTap: () => _onBlockTap(reservation),
          child: widget.everyone && width > 40
              ? Padding(
                  padding: AppSpacing.xsH,
                  child: Row(
                    children: [
                      if (initial.isNotEmpty) ...[
                        // The same avatar language as the plan's seat
                        // tiles and the week grid's cells.
                        Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: onColor.withValues(alpha: 0.22),
                          ),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: onColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          occupant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: onColor),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}
