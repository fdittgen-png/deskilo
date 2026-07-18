// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/reservation.dart';
import 'booking_range_text.dart';
import '../../providers/reservation_providers.dart';

/// Geometry of the Reserve hub's Week grid (#236). Pinned by test — treat
/// these as part of the visual contract, not free-floating magic numbers.
abstract final class WeekGridMetrics {
  /// Columns of the grid: the ISO week, Monday through Sunday.
  static const int daysPerWeek = 7;

  /// Fixed width of the leading seat-name column (timeline parity:
  /// `TimelineAxis.leadingWidth` is the same 112, kept as an own constant
  /// so the reservations feature never imports the calendar widget).
  static const double leadingWidth = 112;

  /// Height of the tappable day-header row ("Mon 13" pills).
  static const double headerHeight = 40;

  /// Height of one seat row of split day cells.
  static const double rowHeight = 36;

  /// Height of an `office · desk` group header row.
  static const double groupHeaderRowHeight = 28;

  /// Height of a level-name header row in all-levels mode.
  static const double levelHeaderRowHeight = 32;

  /// Narrowest day column; when seven of these don't fit next to the
  /// leading column, the day area scrolls horizontally instead.
  static const double minDayWidth = 44;

  /// Padding around the two half-slots inside a day cell.
  static const double cellInset = 3;

  /// Gap between the morning and afternoon half-slots of one cell.
  static const double halfSlotGap = 2;
}

/// Seat × day occupancy grid of one ISO week (#236): rows are seats
/// grouped under `office · desk` headers (level chips with the same
/// local-state "All levels" semantics as DayTimeline, #221/#187), columns
/// are Monday–Sunday of the week containing [selectedDay]. Each cell
/// splits into a morning and an afternoon half-slot around
/// [HalfDayWindows.pivotHour]: a half is filled when ANY active
/// reservation overlaps it (mine = the timeline's own tone, others = its
/// occupied tone, blocked seats muted), empty halves stay a subtle
/// outline.
///
/// Tapping a day header hands the day to [onDaySelected] (the hub selects
/// it and switches to the Day view); tapping an occupied cell opens a
/// small bottom sheet listing that seat/day's reservations, with
/// tap-through to [onReservationTap] for my own.
///
/// Whole-office reservations occupy every seat of that office, like the
/// day timeline: each seat row truthfully shows them as taken.
class WeekGrid extends ConsumerStatefulWidget {
  const WeekGrid({
    super.key,
    required this.selectedDay,
    required this.reservations,
    required this.everyone,
    required this.myMemberId,
    required this.onDaySelected,
    required this.onReservationTap,
    this.onFreeSlotTap,
  });

  /// The hub's selected local day (any instant within it) — the grid
  /// derives its Monday–Sunday columns from this day's ISO week and
  /// highlights its column.
  final DateTime selectedDay;

  /// Already filtered like the timeline's input: active + Mine/Everyone
  /// applied. May span the month(s) around the week; the grid clips each
  /// cell to its own day and half-slot.
  final List<Reservation> reservations;

  /// Whether occupant names are shown in the cell sheet (parity with the
  /// timeline's in-block names) — the Mine/Everyone visibility rule.
  final bool everyone;

  /// The signed-in member — their reservations render in the "mine" tone
  /// and tap through to [onReservationTap] from the cell sheet.
  final String? myMemberId;

  /// A day header was tapped (local midnight of that column's day).
  final void Function(DateTime day) onDaySelected;

  /// Tap-through on one of MY reservations in the cell sheet.
  final void Function(Reservation reservation) onReservationTap;

  /// Tap on a FREE half-slot — the hub books that seat for that day's
  /// half. Null keeps free cells passive.
  final void Function(Seat seat, DateTime day, {required bool morning})?
      onFreeSlotTap;

  /// Local midnight of the Monday of [day]'s ISO week.
  static DateTime weekStartOf(DateTime day) {
    final local = day.toLocal();
    return DateTime(local.year, local.month, local.day - (local.weekday - 1));
  }

  /// Public day stamp for cell/free-slot keys.
  static String dayStampOf(DateTime day) => _dayStamp(day);

  static String _dayStamp(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}$m$d';
  }

  /// Key of one half-slot: `week-cell-<seatId>-<yyyymmdd>-<am|pm>`.
  static Key cellKey(String seatId, DateTime day, {required bool morning}) =>
      ValueKey('week-cell-$seatId-${_dayStamp(day)}-${morning ? 'am' : 'pm'}');

  /// Key of one tappable day header.
  static Key dayHeaderKey(DateTime day) =>
      ValueKey('week-day-header-${_dayStamp(day)}');

  /// Key of a level-name header row in all-levels mode.
  static Key levelHeaderKey(String levelId) =>
      ValueKey('week-level-header-$levelId');

  /// Key of one reservation row inside the occupied-cell sheet.
  static Key sheetItemKey(String reservationId) =>
      ValueKey('week-sheet-item-$reservationId');

  @override
  ConsumerState<WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends ConsumerState<WeekGrid> {
  /// Sentinel value of [_levelId] for the "All levels" chip — never a real
  /// level id. Deliberately a local copy of DayTimeline's selector (#221):
  /// the two widgets share the chip semantics but none of the row
  /// rendering, so a shared extraction would couple more than it saves.
  static const String _allLevelsId = '__all-levels__';

  /// Level chip choice — local browsing state, never the plan tab's
  /// persisted default (DayTimeline pattern, #187).
  String? _levelId;

  /// The seven local days of [WeekGrid.selectedDay]'s ISO week.
  List<DateTime> get _days {
    final monday = WeekGrid.weekStartOf(widget.selectedDay);
    return [
      for (var i = 0; i < WeekGridMetrics.daysPerWeek; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
  }

  /// Blocked for maintenance at some point during `[from, to)` — the
  /// timeline's day rule (#161 blocks are half-open ranges) applied to an
  /// arbitrary window: blocked when the window starts, or the block begins
  /// later within it.
  bool _blockedDuring(Seat seat, DateTime from, DateTime to) {
    if (seat.isBlockedAt(from)) return true;
    final blockedFrom = seat.blockedFrom;
    return blockedFrom != null &&
        !blockedFrom.isBefore(from) &&
        blockedFrom.isBefore(to);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levels = ref.watch(levelsProvider).value;
    if (levels == null) {
      return const LoadingView();
    }
    if (levels.isEmpty) {
      return _emptyHint(l10n);
    }
    // Default stays the FIRST real level; "All levels" is opt-in per view.
    final allSelected = levels.length > 1 && _levelId == _allLevelsId;
    final level = allSelected
        ? null
        : levels.where((l) => l.id == _levelId).firstOrNull ?? levels.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Level chips like the day timeline (#187/#221) — throwaway
        // browsing state, never the persisted default. Row height and tap
        // target meet the 48dp Material minimum (#211).
        if (levels.length > 1)
          SizedBox(
            height: kMinInteractiveDimension,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.mdH,
              children: [
                // Sentinel chip FIRST: stack every level in one grid.
                Padding(
                  padding: AppSpacing.xsH,
                  child: ChoiceChip(
                    label: Text(l10n?.calendarAllLevels ?? 'All levels'),
                    selected: allSelected,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) =>
                        setState(() => _levelId = _allLevelsId),
                  ),
                ),
                for (final Level l in levels)
                  Padding(
                    padding: AppSpacing.xsH,
                    child: ChoiceChip(
                      label: Text(l.name),
                      selected: !allSelected && l.id == level?.id,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => setState(() => _levelId = l.id),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: allSelected
              ? _allLevelsBody(context, levels)
              : _singleLevelBody(context, level!),
        ),
      ],
    );
  }

  Widget _singleLevelBody(BuildContext context, Level level) {
    final l10n = AppLocalizations.of(context);
    final planAsync = ref.watch(floorPlanProvider(level.id));
    return switch (planAsync) {
      AsyncData(value: final plan) => _grid(context, [(null, plan)]),
      AsyncError() => _emptyHint(l10n),
      _ => const LoadingView(),
    };
  }

  /// All-levels mode loads WAIT-ALL like the timeline (#221): every
  /// level's plan is watched up front (they fetch in parallel) and nothing
  /// renders until each one resolved — a single consistent layout instead
  /// of rows reflowing as plans stream in. A level whose plan errored is
  /// skipped like an empty level.
  Widget _allLevelsBody(BuildContext context, List<Level> levels) {
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
    return _grid(context, plans);
  }

  /// Unlike the timeline there is no per-day empty case — the grid shows
  /// EVERY seat so free weeks read as free — so the only empty state is a
  /// workspace without a drawn plan.
  Widget _emptyHint(AppLocalizations? l10n) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: Icons.view_week_outlined,
            title:
                l10n?.planNoLevels ?? 'The workspace has no floor plan yet.',
          ),
        ),
      ],
    );
  }

  /// Renders the given plans stacked in one grid. Single-level mode passes
  /// one `(null, plan)` entry (no level-header row); all-levels mode
  /// passes every level's plan in [levelsProvider]'s sortOrder.
  Widget _grid(BuildContext context, List<(Level?, FloorPlan)> plans) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    if (!plans.any((e) => e.$2.seats.isNotEmpty)) {
      return _emptyHint(l10n);
    }
    final days = _days;
    final weekStart = days.first;
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + WeekGridMetrics.daysPerWeek,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Seven equal columns fitted to the phone width; below the minimum
        // the day area keeps the minimum and scrolls horizontally.
        final available =
            constraints.maxWidth - WeekGridMetrics.leadingWidth;
        final fitted = available / WeekGridMetrics.daysPerWeek;
        final dayWidth = fitted < WeekGridMetrics.minDayWidth
            ? WeekGridMetrics.minDayWidth
            : fitted;
        final gridWidth = dayWidth * WeekGridMetrics.daysPerWeek;

        final leadingCells = <Widget>[
          const SizedBox(height: WeekGridMetrics.headerHeight),
        ];
        final gridRows = <Widget>[_headerRow(context, days, dayWidth)];
        for (final (level, plan) in plans) {
          if (plan.seats.isEmpty) continue;
          if (level != null) {
            leadingCells.add(_levelHeaderCell(context, level));
            gridRows.add(const SizedBox(
              height: WeekGridMetrics.levelHeaderRowHeight,
            ));
          }
          for (final office in plan.offices) {
            final officeReservations = widget.reservations
                .where((r) => r.officeId == office.id)
                .toList();
            for (final desk in plan.desksOf(office.id)) {
              final seats = plan.seatsOf(desk.id);
              if (seats.isEmpty) continue;
              leadingCells.add(
                _groupHeaderCell(context, '${office.name} · ${desk.name}'),
              );
              gridRows.add(const SizedBox(
                height: WeekGridMetrics.groupHeaderRowHeight,
              ));
              for (final Seat seat in seats) {
                final rowReservations = <Reservation>[
                  ...officeReservations,
                  ...widget.reservations.where((r) => r.seatId == seat.id),
                ];
                leadingCells.add(_seatCell(
                  context,
                  seat,
                  brightness,
                  blockedDuringWeek: _blockedDuring(seat, weekStart, weekEnd),
                ));
                gridRows.add(_seatRow(
                  context,
                  seat,
                  rowReservations,
                  days,
                  dayWidth,
                  brightness,
                ));
              }
            }
          }
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: WeekGridMetrics.leadingWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: leadingCells,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: gridWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: gridRows,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Tappable "Mon 13" day headers; the selected day's pill highlighted.
  Widget _headerRow(
    BuildContext context,
    List<DateTime> days,
    double dayWidth,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final weekdayFormat = DateFormat.E();
    final dayFormat = DateFormat.d();
    final style = Theme.of(context).textTheme.labelMedium;
    return SizedBox(
      height: WeekGridMetrics.headerHeight,
      child: Row(
        children: [
          for (final day in days)
            SizedBox(
              width: dayWidth,
              child: Padding(
                padding: const EdgeInsets.all(WeekGridMetrics.cellInset),
                child: Material(
                  color: DateUtils.isSameDay(day, widget.selectedDay)
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: AppRadius.mdAll,
                  child: InkWell(
                    key: WeekGrid.dayHeaderKey(day),
                    borderRadius: AppRadius.mdAll,
                    onTap: () => widget.onDaySelected(day),
                    child: Center(
                      child: Text(
                        '${weekdayFormat.format(day)} '
                        '${dayFormat.format(day)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DateUtils.isSameDay(day, widget.selectedDay)
                            ? style?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              )
                            : style?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Level-name header in all-levels mode — like the timeline's,
  /// deliberately distinct from the muted group headers.
  Widget _levelHeaderCell(BuildContext context, Level level) {
    return SizedBox(
      key: WeekGrid.levelHeaderKey(level.id),
      height: WeekGridMetrics.levelHeaderRowHeight,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          top: AppSpacing.md,
        ),
        child: Text(
          level.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }

  Widget _groupHeaderCell(BuildContext context, String label) {
    return SizedBox(
      height: WeekGridMetrics.groupHeaderRowHeight,
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

  Widget _seatCell(
    BuildContext context,
    Seat seat,
    Brightness brightness, {
    required bool blockedDuringWeek,
  }) {
    return SizedBox(
      height: WeekGridMetrics.rowHeight,
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
            // Never state by color alone (spec §11): seats blocked at some
            // point of the week get an icon next to the muted half-slots.
            if (blockedDuringWeek)
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

  /// One seat's seven split day cells.
  Widget _seatRow(
    BuildContext context,
    Seat seat,
    List<Reservation> rowReservations,
    List<DateTime> days,
    double dayWidth,
    Brightness brightness,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: WeekGridMetrics.rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in days)
            _dayCell(
              context,
              seat,
              rowReservations,
              day,
              dayWidth,
              brightness,
            ),
        ],
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    Seat seat,
    List<Reservation> rowReservations,
    DateTime day,
    double dayWidth,
    Brightness brightness,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // The cell IS the workspace-local day — same clock as the half-slot
    // windows below, whatever zone the device is in.
    final dayWindow = HalfDayWindows.fullDay(day);
    final items = [
      for (final r in rowReservations)
        if (r.coversRange(dayWindow.start, dayWindow.end)) r,
    ];
    final selected = DateUtils.isSameDay(day, widget.selectedDay);
    return SizedBox(
      width: dayWidth,
      child: InkWell(
        onTap: items.isEmpty ? null : () => _cellSheet(seat, day, items),
        child: Container(
          // Subtle column tint under the highlighted header — never the
          // half-slots' own fill, which stays the occupancy signal.
          color: selected ? scheme.primary.withValues(alpha: 0.06) : null,
          padding: const EdgeInsets.all(WeekGridMetrics.cellInset),
          child: Row(
            children: [
              Expanded(
                child: _halfSlot(
                  context,
                  seat,
                  day,
                  items,
                  brightness,
                  morning: true,
                ),
              ),
              const SizedBox(width: WeekGridMetrics.halfSlotGap),
              Expanded(
                child: _halfSlot(
                  context,
                  seat,
                  day,
                  items,
                  brightness,
                  morning: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One half-slot: filled when ANY reservation of the cell overlaps the
  /// canonical half window (mine wins over others), muted when the seat is
  /// blocked during it, otherwise a subtle outline.
  Widget _halfSlot(
    BuildContext context,
    Seat seat,
    DateTime day,
    List<Reservation> items,
    Brightness brightness, {
    required bool morning,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final half = morning
        ? HalfDayWindows.morning(day)
        : HalfDayWindows.afternoon(day);
    var occupied = false;
    var mine = false;
    for (final r in items) {
      if (!r.coversRange(half.start, half.end)) continue;
      occupied = true;
      if (r.memberId == widget.myMemberId) {
        mine = true;
        break;
      }
    }
    Color? fill;
    String? occupantInitial;
    if (occupied) {
      // The timeline's block tones (#187): mine vs reserved-by-others.
      fill = SeatStateColors.of(
        mine ? SeatState.mine : SeatState.reserved,
        brightness: brightness,
      );
      if (widget.everyone) {
        // WHO at a glance (needs analysis: availability + by whom): the
        // covering occupant's initial, mirroring the plan's seat avatars.
        final names = ref.watch(memberNamesProvider).value ?? const {};
        final covering = items.firstWhere(
          (r) => r.coversRange(half.start, half.end),
        );
        final name = names[covering.memberId] ?? '';
        if (name.trim().isNotEmpty) {
          occupantInitial = name.trim().characters.first.toUpperCase();
        }
      }
    } else if (_blockedDuring(seat, half.start, half.end)) {
      fill = SeatStateColors.of(SeatState.blocked, brightness: brightness)
          .withValues(alpha: 0.3);
    }
    final free = fill == null;
    return Container(
      key: WeekGrid.cellKey(seat.id, day, morning: morning),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadius.smAll,
        border: free
            ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6))
            : null,
      ),
      // A free half-slot is a booking affordance, not dead space.
      child: free && widget.onFreeSlotTap != null
          ? InkWell(
              key: ValueKey(
                'week-free-${seat.id}-${WeekGrid.dayStampOf(day)}-'
                '${morning ? 'am' : 'pm'}',
              ),
              borderRadius: AppRadius.smAll,
              onTap: () =>
                  widget.onFreeSlotTap!(seat, day, morning: morning),
            )
          : occupantInitial == null
              ? null
              : Center(
                  child: Text(
                    occupantInitial,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
    );
  }

  /// Small occupants sheet of one seat/day cell: "09:00 – 11:00 · Flo"
  /// per reservation (names only in Everyone mode), my own rows popping
  /// the tapped reservation for the hub's detail sheet.
  Future<void> _cellSheet(
    Seat seat,
    DateTime day,
    List<Reservation> items,
  ) async {
    final names = ref.read(memberNamesProvider).value ?? const {};
    final l10n = AppLocalizations.of(context);
    final sorted = [...items]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final picked = await showModalBottomSheet<Reservation>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                child: Text(
                  '${seat.name} · ${DateFormat.MMMEd().format(day)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final r in sorted)
                ListTile(
                  key: WeekGrid.sheetItemKey(r.id),
                  leading: Icon(
                    r.memberId == widget.myMemberId
                        ? Icons.event_seat
                        : Icons.person_outline,
                  ),
                  title: Text(_occupantLine(r, names, l10n)),
                  trailing: r.memberId == widget.myMemberId
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: r.memberId == widget.myMemberId
                      ? () => Navigator.of(context).pop(r)
                      : null,
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    widget.onReservationTap(picked);
  }

  String _occupantLine(
    Reservation r,
    Map<String, String> names,
    AppLocalizations? l10n,
  ) {
    final range = bookingRangeText(l10n, r.startsAt, r.endsAt);
    if (!widget.everyone) return range;
    final name = names[r.memberId] ?? '';
    return name.isEmpty ? range : '$range · $name';
  }
}
