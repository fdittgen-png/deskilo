// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the day timeline's cells: the hour ruler, the level and group
// headers, a seat's name cell, its track, a reservation block and the
// scrolling axis that holds them. They draw what they are given; which rows
// exist and what a tap does stays with [DayTimeline].
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/seat_state_colors.dart';
import 'day_timeline.dart';
import 'day_timeline_axis.dart';

/// The hour labels above the tracks, every [TimelineAxis.labelStepHours].
class TimelineRuler extends StatelessWidget {
  const TimelineRuler({
    super.key,
    required this.format,
    required this.dayStart,
  });

  /// #1150 — the member's clock (12 h / 24 h).
  final AppFormat format;

  /// Local midnight of the day shown.
  final DateTime dayStart;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: TimelineAxis.rulerHeight,
      width: TimelineAxis.trackWidth,
      child: Stack(
        children: [
          for (
            var h = 0;
            h < TimelineAxis.hoursPerDay;
            h += TimelineAxis.labelStepHours
          )
            Positioned(
              left: h * TimelineAxis.hourWidth + 3,
              bottom: 2,
              child: Text(
                format.wallTime(dayStart.add(Duration(hours: h))),
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

/// Level-name header in all-levels mode — deliberately distinct from the
/// muted `office · desk` group headers: titleSmall in the primary color.
/// Tapping it collapses or expands that level's rows; the chevron shows
/// which way the tap goes.
class TimelineLevelHeader extends StatelessWidget {
  const TimelineLevelHeader({
    super.key,
    required this.levelId,
    required this.name,
    required this.collapsed,
    required this.onToggle,
  });

  final String levelId;
  final String name;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return SizedBox(
      key: DayTimeline.levelHeaderKey(levelId),
      height: TimelineAxis.levelHeaderRowHeight,
      child: InkWell(
        key: const ValueKey('day-timeline-calendar-level-collapsed'),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            top: AppSpacing.sm,
          ),
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: collapsed
                      ? (l10n.calendarLevelCollapsed(name))
                      : (l10n.calendarLevelExpanded(name)),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The muted `office · desk` header above a desk's seat rows.
class TimelineGroupHeader extends StatelessWidget {
  const TimelineGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
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
}

/// A seat's name in the leading column, with the blocked icon.
class TimelineSeatCell extends StatelessWidget {
  const TimelineSeatCell({
    super.key,
    required this.name,
    required this.blocked,
    required this.height,
  });

  final String name;

  /// Blocked for maintenance at some point during the day.
  final bool blocked;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
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
            // Never state by color alone (spec §11): blocked seats get an
            // icon next to the muted track tint.
            if (blocked)
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

/// One seat's track on the 24 h axis: the muted tint when it cannot be
/// booked, the free-area tap, and the reservation [blocks] above it.
class TimelineTrack extends StatelessWidget {
  const TimelineTrack({
    super.key,
    required this.seatId,
    required this.height,
    required this.blocked,
    required this.blocks,
    this.onFreeTap,
    this.onFreeTapAt,
  });

  final String seatId;
  final double height;

  /// Blocked during the day, or the workspace is closed (#814).
  final bool blocked;

  /// The [TimelineBlock]s on this track.
  final List<Widget> blocks;

  /// Tap on the free area — the hub books the selected window on it.
  final VoidCallback? onFreeTap;

  /// #2631 — the same tap with how far along the track the finger landed;
  /// wins over [onFreeTap] where both are set.
  final void Function(double dx)? onFreeTapAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blockedTint = SeatStateColors.of(
      SeatState.blocked,
      brightness: Theme.of(context).brightness,
    ).withValues(alpha: 0.15);
    final freeTapAt = onFreeTapAt;
    return Container(
      key: DayTimeline.trackKey(seatId),
      height: height,
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
        children: [
          // Free-area tap books this seat (hub); the blocks above keep
          // their own handlers and win hit-testing.
          if ((onFreeTap != null || freeTapAt != null) && !blocked)
            Positioned.fill(
              child: InkWell(
                key: ValueKey('timeline-free-$seatId'),
                onTap: freeTapAt == null ? onFreeTap : null,
                onTapUp: freeTapAt == null
                    ? null
                    : (d) => freeTapAt(d.localPosition.dx),
              ),
            ),
          ...blocks,
        ],
      ),
    );
  }
}

/// One reservation on a track, placed by [left] and [width].
class TimelineBlock extends StatelessWidget {
  const TimelineBlock({
    super.key,
    required this.reservationId,
    required this.left,
    required this.width,
    required this.own,
    required this.occupant,
    required this.showOccupant,
    required this.onOpen,
  });

  final String reservationId;
  final double left;
  final double width;

  /// The signed-in member's own booking.
  final bool own;

  /// The occupant's name, '' when unknown.
  final String occupant;

  /// Everyone's bookings are shown and the block is wide enough for a name.
  final bool showOccupant;

  /// Opens the booking (mine) or names its occupant (someone else's).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final base = SeatStateColors.of(
      own ? SeatState.mine : SeatState.reserved,
      brightness: Theme.of(context).brightness,
    );
    // MY bookings carry the full tone; everyone else's step back a
    // notch, so 'when did I reserve what' reads before any label does.
    final color = own ? base : base.withValues(alpha: 0.78);
    final onColor =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark
        ? Colors.white
        : Colors.black87;
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
          key: DayTimeline.blockKey(reservationId),
          onTap: onOpen,
          child: showOccupant
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
                          style: Theme.of(context).textTheme.labelSmall
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
