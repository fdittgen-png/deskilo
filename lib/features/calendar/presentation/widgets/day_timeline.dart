// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/height_probe.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/widgets/level_chip_row.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/providers/browsed_level.dart';
import '../../../reservations/providers/reservation_providers.dart';

part 'day_timeline_part1.dart';
part 'day_timeline_part2.dart';

/// Geometry of the 24h timeline axis (#187). Pinned by test — treat these
/// as part of the visual contract, not free-floating magic numbers.
@visibleForTesting
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
      return _emptyHint(l10n, allLevels: false);
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

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

}
