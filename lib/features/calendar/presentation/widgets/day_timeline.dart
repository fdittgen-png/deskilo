// SPDX-License-Identifier: MIT
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

  static Key blockKey(String reservationId) =>
      ValueKey('timeline-block-$reservationId');
  static Key trackKey(String seatId) => ValueKey('timeline-track-$seatId');
  static const Key nowLineKey = ValueKey('timeline-now-line');

  @override
  ConsumerState<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends ConsumerState<DayTimeline> {
  final ScrollController _axisController = ScrollController();

  /// Level chip choice — local, never the plan's persisted default.
  String? _levelId;

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
      return _emptyHint(l10n);
    }
    final level =
        levels.where((l) => l.id == _levelId).firstOrNull ?? levels.first;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    final names = ref.watch(memberNamesProvider).value ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Level chips like the plan tab (#159 pattern) — but the selection
        // here is throwaway browsing state, never the persisted default.
        if (levels.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.mdH,
              children: [
                for (final Level l in levels)
                  Padding(
                    padding: AppSpacing.xsH,
                    child: ChoiceChip(
                      label: Text(l.name),
                      selected: l.id == level.id,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _levelId = l.id),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: switch (planAsync) {
            AsyncData(value: final plan) => _grid(context, plan, names),
            AsyncError() => _emptyHint(l10n),
            _ => const LoadingView(),
          },
        ),
      ],
    );
  }

  Widget _emptyHint(AppLocalizations? l10n) {
    final hint = l10n?.calendarTimelineEmpty ??
        'No reservations on this level for this day.';
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

  Widget _grid(
    BuildContext context,
    FloorPlan plan,
    Map<String, String> names,
  ) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    final dayReservations = widget.reservations
        .where((r) => r.coversRange(_dayStart, _dayEnd))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    // Only what lives on this level.
    final seatIds = {for (final s in plan.seats) s.id};
    final officeIds = {for (final o in plan.offices) o.id};
    final levelReservations = dayReservations
        .where((r) =>
            (r.seatId != null && seatIds.contains(r.seatId)) ||
            (r.officeId != null && officeIds.contains(r.officeId)))
        .toList();

    if (plan.seats.isEmpty || levelReservations.isEmpty) {
      return _emptyHint(l10n);
    }
    _scheduleAutoScroll(levelReservations);

    final leadingCells = <Widget>[
      const SizedBox(height: TimelineAxis.rulerHeight),
    ];
    final tracks = <Widget>[_ruler(context)];
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
    final color = SeatStateColors.of(
      own ? SeatState.mine : SeatState.reserved,
      brightness: brightness,
    );
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final left = _offsetOf(reservation.startsAt);
    final right = _offsetOf(reservation.endsAt);
    final width = (right - left) < TimelineAxis.blockMinWidth
        ? TimelineAxis.blockMinWidth
        : right - left;
    final occupant = names[reservation.memberId] ?? '';
    return Positioned(
      left: left,
      width: width,
      top: TimelineAxis.blockInset,
      bottom: TimelineAxis.blockInset,
      child: Material(
        color: color,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          key: DayTimeline.blockKey(reservation.id),
          borderRadius: AppRadius.smAll,
          onTap: () => _onBlockTap(reservation),
          child: widget.everyone
              ? Padding(
                  padding: AppSpacing.xsH,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
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
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}
