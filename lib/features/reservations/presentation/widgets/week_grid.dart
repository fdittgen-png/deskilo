// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/time/date_text.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/widgets/level_chip_row.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/reservation.dart';
import '../../providers/browsed_level.dart';
import '../../providers/reservation_providers.dart';
import 'booking_range_text.dart';

part 'week_grid_part1.dart';

/// Geometry of the Reserve hub's Week grid (#236). Pinned by test — treat
/// these as part of the visual contract, not free-floating magic numbers.
@visibleForTesting
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
/// splits into a morning and an afternoon half-slot around the
/// configured half-day boundary (#446): a half is filled when ANY active
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
    this.isDayOpen,
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

  /// #814 — whether the workspace is open on a column's day. Closed
  /// columns draw muted, say so in their header and take no free-slot
  /// tap. Null = every day open (the pre-#814 behaviour).
  final bool Function(DateTime day)? isDayOpen;

  /// Key of a closed day's header marker.
  static Key closedHeaderKey(DateTime day) =>
      ValueKey('week-closed-${_dayStamp(day)}');

  /// WORKSPACE midnight of the Monday of [day]'s ISO week (#490 — the
  /// week is the workspace's, not the device's).
  static DateTime weekStartOf(DateTime day) {
    final local = WorkspaceTime.dateOf(day);
    return DateTime(local.year, local.month, local.day - (local.weekday - 1));
  }

  /// Public day stamp for cell/free-slot keys.
  static String dayStampOf(DateTime day) => _dayStamp(day);

  static String _dayStamp(DateTime day) => ymd(day);

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
  /// #1269 — the level choice lives in [BrowsedLevel] now, one value
  /// above every view of the hub. It used to be a `State` field here and
  /// one in each of the other two views, so switching the view snapped
  /// the hub back to the first floor.

  /// The seven local days of [WeekGrid.selectedDay]'s ISO week.
  List<DateTime> get _days {
    final monday = WeekGrid.weekStartOf(widget.selectedDay);
    return [
      for (var i = 0; i < WeekGridMetrics.daysPerWeek; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final levels = ref.watch(levelsProvider).value;
    if (levels == null) {
      return const LoadingView();
    }
    if (levels.isEmpty) {
      return _emptyHint(l10n);
    }
    // Default stays the FIRST real level; "All levels" is opt-in per view.
    final browsed = ref.watch(browsedLevelProvider);
    final allSelected = levels.length > 1 && browsed == BrowsedLevel.allLevels;
    final level = allSelected
        ? null
        : levels.where((l) => l.id == browsed).firstOrNull ?? levels.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Level chips like the day timeline (#187/#221) — throwaway
        // browsing state, never the persisted default.
        LevelChipRow(
          key: const ValueKey('week-grid-calendar-all-levels'),
          levels: levels,
          selectedLevelId: level?.id,
          onSelected: (id) =>
              ref.read(browsedLevelProvider.notifier).select(id),
          // Sentinel chip FIRST: stack every level in one grid.
          allLevelsLabel: l10n.calendarAllLevels,
          allLevelsSelected: allSelected,
          onAllLevelsSelected: () =>
              ref.read(browsedLevelProvider.notifier).selectAll(),
        ),
        Expanded(
          child: allSelected
              ? _allLevelsBody(context, levels)
              : _singleLevelBody(context, level!),
        ),
      ],
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
    // The cell IS the workspace-local CALENDAR day (midnight to
    // midnight — the display halves, #446), same clock as the
    // half-slot windows below, whatever zone the device is in. The
    // canonical fullDay window would hide bookings outside the
    // configured working hours.
    final dayStart = HalfDayWindows.displayMorning(day).start;
    final dayEnd = HalfDayWindows.displayAfternoon(day).end;
    final items = [
      for (final r in rowReservations)
        if (r.holdsRange(dayStart, dayEnd)) r,
    ];
    final selected = DateUtils.isSameDay(day, widget.selectedDay);
    return SizedBox(
      width: dayWidth,
      child: InkWell(
        key: ValueKey('week-grid-ink-well-${brightness.name}'),
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
    // Display halves, not booking windows (#446): a booking outside
    // the working hours still occupies the seat that half of the day.
    final half = morning
        ? HalfDayWindows.displayMorning(day)
        : HalfDayWindows.displayAfternoon(day);
    var occupied = false;
    var mine = false;
    for (final r in items) {
      if (!r.holdsRange(half.start, half.end)) continue;
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
          (r) => r.holdsRange(half.start, half.end),
        );
        final name = names[covering.memberId] ?? '';
        if (name.trim().isNotEmpty) {
          occupantInitial = name.trim().characters.first.toUpperCase();
        }
      }
    } else if (_blockedDuring(seat, half.start, half.end)) {
      fill = SeatStateColors.of(SeatState.blocked, brightness: brightness)
          .withValues(alpha: 0.3);
    } else if (!_dayOpen(day)) {
      // #814 — a closed day is not free: nothing to tap, nothing to book.
      fill = scheme.surfaceContainerHighest;
    }
    final free = fill == null;
    return DecoratedBox(
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
                    style: Theme.of(context).textTheme.labelSmall
                        ?.emphasised.copyWith(color: Colors.white),
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
    final l10n = context.l10n;
    final sorted = [...items]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final picked = await showAppSheet<Reservation>(
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
    AppLocalizations l10n,
  ) {
    final range = bookingRangeText(context, appFormatOf(context), l10n, r.startsAt, r.endsAt);
    if (!widget.everyone) return range;
    final name = names[r.memberId] ?? '';
    return name.isEmpty ? range : '$range · $name';
  }
}
