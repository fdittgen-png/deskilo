// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the Week grid's cells: the day headers, the level and group
// headers, a seat's name cell, its row of day cells, one half-slot, the
// scrolling body and a cell's occupants sheet. They draw what they are
// given; which rows exist and what a half-slot shows stays with [WeekGrid].
// [WeekGridMetrics] is their geometry.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/ui/empty_state.dart';
import '../../domain/reservation.dart';
import 'week_grid.dart';

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

/// Tappable "Mon 13" day headers; the selected day's pill highlighted.
class WeekGridDayHeaders extends StatelessWidget {
  const WeekGridDayHeaders({
    super.key,
    required this.days,
    required this.dayWidth,
    required this.selectedDay,
    required this.dayOpen,
    required this.onDaySelected,
  });

  final List<DateTime> days;
  final double dayWidth;
  final DateTime selectedDay;

  /// #814 — a closed day carries the closed icon under its label.
  final bool Function(DateTime day) dayOpen;
  final void Function(DateTime day) onDaySelected;

  @override
  Widget build(BuildContext context) {
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
                  color: DateUtils.isSameDay(day, selectedDay)
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: AppRadius.mdAll,
                  child: InkWell(
                    key: WeekGrid.dayHeaderKey(day),
                    borderRadius: AppRadius.mdAll,
                    onTap: () => onDaySelected(day),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${weekdayFormat.format(day)} '
                            '${dayFormat.format(day)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DateUtils.isSameDay(day, selectedDay)
                                ? style?.strong.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  )
                                : style?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                          ),
                          if (!dayOpen(day))
                            Icon(
                              Icons.event_busy_outlined,
                              key: WeekGrid.closedHeaderKey(day),
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                        ],
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
}

/// Level-name header in all-levels mode — like the timeline's,
/// deliberately distinct from the muted group headers.
class WeekGridLevelHeader extends StatelessWidget {
  const WeekGridLevelHeader({
    super.key,
    required this.levelId,
    required this.name,
  });

  final String levelId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: WeekGrid.levelHeaderKey(levelId),
      height: WeekGridMetrics.levelHeaderRowHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.md),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

/// The muted `office · desk` header above a desk's seat rows.
class WeekGridGroupHeader extends StatelessWidget {
  const WeekGridGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
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
}

/// A seat's name in the leading column, with the blocked icon.
class WeekGridSeatCell extends StatelessWidget {
  const WeekGridSeatCell({
    super.key,
    required this.name,
    required this.blockedDuringWeek,
  });

  final String name;
  final bool blockedDuringWeek;

  @override
  Widget build(BuildContext context) {
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
                name,
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
                  brightness: Theme.of(context).brightness,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One seat's row of day [cells], underlined like a timeline track.
class WeekGridSeatRow extends StatelessWidget {
  const WeekGridSeatRow({super.key, required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
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
        children: cells,
      ),
    );
  }
}

/// One half-slot: [fill] when it is taken, blocked or closed; a subtle
/// outline — and, with [onFreeTap], a booking affordance — when free.
class WeekGridHalfSlot extends StatelessWidget {
  const WeekGridHalfSlot({
    super.key,
    required this.seatId,
    required this.day,
    required this.morning,
    required this.fill,
    required this.occupantInitial,
    this.onFreeTap,
  });

  final String seatId;
  final DateTime day;
  final bool morning;

  /// Null for a free half.
  final Color? fill;

  /// The covering occupant's initial in Everyone mode.
  final String? occupantInitial;

  /// Books the free half; null keeps it passive.
  final VoidCallback? onFreeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final free = fill == null;
    final initial = occupantInitial;
    return DecoratedBox(
      key: WeekGrid.cellKey(seatId, day, morning: morning),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadius.smAll,
        border: free
            ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6))
            : null,
      ),
      // A free half-slot is a booking affordance, not dead space.
      child: free && onFreeTap != null
          ? InkWell(
              key: ValueKey(
                'week-free-$seatId-${WeekGrid.dayStampOf(day)}-'
                '${morning ? 'am' : 'pm'}',
              ),
              borderRadius: AppRadius.smAll,
              onTap: onFreeTap,
            )
          : initial == null
          ? null
          : Center(
              child: Text(
                initial,
                style: Theme.of(context).textTheme.labelSmall?.emphasised
                    .copyWith(color: Colors.white),
              ),
            ),
    );
  }
}

/// The scrolling body: the leading name column beside the day area, which
/// scrolls horizontally when seven columns do not fit.
class WeekGridBody extends StatelessWidget {
  const WeekGridBody({
    super.key,
    required this.leading,
    required this.rows,
    required this.gridWidth,
  });

  final List<Widget> leading;
  final List<Widget> rows;
  final double gridWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: WeekGridMetrics.leadingWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: leading,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Unlike the timeline there is no per-day empty case — the grid shows
/// EVERY seat so free weeks read as free — so the only empty state is a
/// workspace without a drawn plan.
class WeekGridEmptyHint extends StatelessWidget {
  const WeekGridEmptyHint({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: Icons.view_week_outlined,
            title: context.l10n.planNoLevels,
          ),
        ),
      ],
    );
  }
}

/// Small occupants sheet of one seat/day cell: one line per reservation,
/// my own rows popping the tapped reservation for the hub's detail sheet.
class WeekGridCellSheet extends StatelessWidget {
  const WeekGridCellSheet({
    super.key,
    required this.title,
    required this.items,
    required this.myMemberId,
    required this.lineOf,
  });

  final String title;

  /// Sorted by start.
  final List<Reservation> items;
  final String? myMemberId;

  /// "09:00 – 11:00 · Flo" (names only in Everyone mode).
  final String Function(Reservation reservation) lineOf;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final r in items)
              ListTile(
                key: WeekGrid.sheetItemKey(r.id),
                leading: Icon(
                  r.memberId == myMemberId
                      ? Icons.event_seat
                      : Icons.person_outline,
                ),
                title: Text(lineOf(r)),
                trailing: r.memberId == myMemberId
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: r.memberId == myMemberId
                    ? () => Navigator.of(context).pop(r)
                    : null,
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
