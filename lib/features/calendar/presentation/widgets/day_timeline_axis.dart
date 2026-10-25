// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the day timeline's axis: its geometry, the rows stacked on it,
// the scrolling body that shows them and the hint for an empty day.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/empty_state.dart';
import 'day_timeline.dart';

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

  /// A seat row grows to use a tall viewport (a few seats must not leave
  /// the lower part of the screen empty), but never beyond this.
  static const double maxRowHeight = 96;

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

/// The rows of one timeline, built lazily: how tall a seat row is depends
/// on how many seat rows there are.
class TimelineRows {
  TimelineRows({required Widget ruler})
    : leadingCells = [(_) => const SizedBox(height: TimelineAxis.rulerHeight)],
      tracks = [(_) => ruler];

  final List<Widget Function(double rowHeight)> leadingCells;
  final List<Widget Function(double rowHeight)> tracks;
  int _seatRows = 0;
  double _fixedHeight = TimelineAxis.rulerHeight;

  /// A header row of [height] in the leading column, with an empty track.
  void addHeader(Widget cell, double height) {
    leadingCells.add((_) => cell);
    tracks.add((_) => SizedBox(height: height, width: TimelineAxis.trackWidth));
    _fixedHeight += height;
  }

  void addSeat(
    Widget Function(double rowHeight) cell,
    Widget Function(double rowHeight) track,
  ) {
    _seatRows++;
    leadingCells.add(cell);
    tracks.add(track);
  }

  /// A few seats must not leave the lower part of the screen empty: the
  /// rows share the room the viewport has beyond their natural height,
  /// up to a readable maximum. A long list keeps the compact rows and
  /// scrolls as before.
  double rowHeightFor(double viewportHeight) {
    var rowHeight = TimelineAxis.rowHeight;
    if (_seatRows > 0) {
      final natural = _fixedHeight + _seatRows * TimelineAxis.rowHeight;
      if (viewportHeight > natural) {
        rowHeight =
            (TimelineAxis.rowHeight + (viewportHeight - natural) / _seatRows)
                .clamp(TimelineAxis.rowHeight, TimelineAxis.maxRowHeight);
      }
    }
    return rowHeight;
  }
}

/// The scrolling body: the leading name column beside the horizontally
/// scrolling tracks, the hour grid lines and, today, the now line.
class TimelineAxisView extends StatelessWidget {
  const TimelineAxisView({
    super.key,
    required this.controller,
    required this.leading,
    required this.tracks,
    required this.nowOffset,
  });

  /// The horizontal axis — [DayTimeline] auto-scrolls it.
  final ScrollController controller;
  final List<Widget> leading;
  final List<Widget> tracks;

  /// Where the now line sits; null when the day is not today.
  final double? nowOffset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = nowOffset;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: TimelineAxis.leadingWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: leading,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: TimelineAxis.trackWidth,
                child: Stack(
                  children: [
                    for (
                      var h = 0;
                      h < TimelineAxis.hoursPerDay;
                      h += TimelineAxis.labelStepHours
                    )
                      Positioned(
                        left: h * TimelineAxis.hourWidth,
                        top: TimelineAxis.rulerHeight,
                        bottom: 0,
                        width: 1,
                        child: ColoredBox(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: tracks,
                    ),
                    if (now != null)
                      Positioned(
                        key: DayTimeline.nowLineKey,
                        left: now,
                        top: 0,
                        bottom: 0,
                        width: TimelineAxis.nowLineWidth,
                        // IgnorePointer: ColoredBox is hit-test OPAQUE, so
                        // without it the line steals the tap from any block
                        // whose centre the wall clock is currently crossing
                        // (a running booking became untappable for a few
                        // minutes — caught as CI run #416's master flake).
                        child: IgnorePointer(
                          child: ColoredBox(color: scheme.error),
                        ),
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
}

/// The day has nothing to show. Stays a scrollable so an enclosing
/// RefreshIndicator keeps working.
class TimelineEmptyHint extends StatelessWidget {
  const TimelineEmptyHint({super.key, required this.allLevels});

  /// Every level came up empty, not just the one chosen.
  final bool allLevels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hint = allLevels
        ? (l10n.calendarTimelineAllEmpty)
        : (l10n.calendarTimelineEmpty);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: EmptyState(icon: Icons.view_timeline_outlined, title: hint),
        ),
      ],
    );
  }
}
