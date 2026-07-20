// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/motion.dart';
import '../../../../core/ui/view_toggle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/domain/seat_context.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/presentation/widgets/reservation_detail_sheet.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../widgets/day_timeline.dart';

/// Reservations calendar (spec §6): month grid with markers + day list.
/// Workers see their own bookings; admins can switch to everyone's.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;
  late DateTime _selectedDay;
  bool _everyone = false;

  /// #187: selected-day area as timeline instead of list. Session-only —
  /// deliberately a plain State field, no persistence.
  bool _timeline = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Reservation> _visible(
    List<Reservation> reservations,
    String? myMemberId,
  ) {
    return reservations
        .where((r) => r.isActive)
        .where((r) => _everyone || r.memberId == myMemberId)
        .toList();
  }

  /// Detail sheet of one reservation (#182): where the seat is, its
  /// accessories, and a "Show on plan" jump. Popping with a [SeatContext]
  /// means "jump": signal the plan screen and switch tabs. Cancel actions
  /// stay in the row's trailing menu ([_cancelMenu]).
  Future<void> _detailSheet(Reservation reservation) async {
    final target = await showModalBottomSheet<SeatContext>(
      context: context,
      builder: (context) => ReservationDetailSheet(reservation: reservation),
    );
    if (target == null || !mounted) return;
    ref.read(planFocusControllerProvider.notifier).setFocus(
          PlanFocus(
            levelId: target.levelId,
            seatId: reservation.seatId,
            at: reservation.startsAt,
          ),
        );
    context.go('/plan');
  }

  Future<void> _cancelMenu(Reservation reservation) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: Text(
                reservation.seriesId == null
                    ? (l10n?.planCancelReservationButton ??
                        'Cancel reservation')
                    : (l10n?.calendarCancelOccurrence ??
                        'Cancel this occurrence'),
              ),
              onTap: () => Navigator.of(context).pop('single'),
            ),
            if (reservation.seriesId != null)
              ListTile(
                leading: const Icon(Icons.fast_forward_outlined),
                title: Text(
                  l10n?.calendarCancelFollowing ??
                      'Cancel this and following',
                ),
                onTap: () => Navigator.of(context).pop('following'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final repo = ref.read(reservationRepositoryProvider);
    try {
      if (choice == 'single') {
        await repo.cancel(reservation.id);
      } else {
        await repo.cancelSeries(
          reservation.seriesId!,
          from: reservation.startsAt,
        );
      }
    } catch (e, st) {
      debugPrint('cancel failed: $e\n$st');
      TraceLogger.instance.error('calendar', 'reservation cancel failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    invalidateBookingData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myMember = ref.watch(myMemberProvider).value;
    final reservations = ref
            .watch(reservationsForMonthProvider(monthKeyOf(_month)))
            .value ??
        const <Reservation>[];
    final visible = _visible(reservations, myMember?.id);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final targets = ref.watch(targetNamesProvider).value ?? const {};

    final dayReservations = visible
        .where((r) => _sameDay(r.startsAt.toLocal(), _selectedDay))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    // In landscape the month + controls move to a side panel so the day's
    // reservations fill the rest of the screen (and the month grid stops
    // being clipped to a couple of weeks under the header).
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: AppSpacing.smH,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n?.calendarPreviousMonth ?? 'Previous month',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n?.calendarNextMonth ?? 'Next month',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: AppSpacing.lgH,
          child: Row(
            children: [
              if (myMember?.canAdminister ?? false)
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(l10n?.calendarMineTab ?? 'Mine'),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n?.calendarEveryoneTab ?? 'Everyone'),
                      ),
                    ],
                    selected: {_everyone},
                    onSelectionChanged: (selection) =>
                        setState(() => _everyone = selection.first),
                  ),
                )
              else
                const Spacer(),
              // #187: list vs. timeline for the selected-day area — the
              // shared toggle idiom at full 48dp tap height (#211).
              ViewToggle<bool>(
                key: const ValueKey('calendar-view-switch'),
                options: [
                  ViewToggleOption(
                    value: false,
                    icon: Icons.view_list_outlined,
                    tooltip: l10n?.calendarListView ?? 'List view',
                  ),
                  ViewToggleOption(
                    value: true,
                    icon: Icons.view_timeline_outlined,
                    tooltip: l10n?.calendarTimelineView ?? 'Timeline view',
                  ),
                ],
                selected: _timeline,
                onChanged: (timeline) => setState(() => _timeline = timeline),
              ),
            ],
          ),
        ),
        // The month sits on a soft rounded card — a calmer, more modern
        // surface than a bare grid on the scaffold.
        Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.xs,
            AppSpacing.screenGutter,
            AppSpacing.sm,
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: AppRadius.xlAll,
            boxShadow: AppElevation.low(Theme.of(context).brightness),
          ),
          child: _MonthGrid(
            month: _month,
            selectedDay: _selectedDay,
            today: DateUtils.dateOnly(DateTime.now()),
            // Mine vs others' markers ('when did I reserve what' first): a
            // day with any of MY bookings carries a red dot, a day with
            // only other members' bookings a blue one.
            markedDays: {
              for (final r in visible)
                DateUtils.dateOnly(r.startsAt.toLocal()),
            },
            myDays: {
              for (final r in visible)
                if (r.memberId == myMember?.id)
                  DateUtils.dateOnly(r.startsAt.toLocal()),
            },
            onSelect: (day) => setState(() => _selectedDay = day),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
    final content = Expanded(
          child: RefreshIndicator(
            onRefresh: () async => invalidateBookingData(ref),
            // #209: cross-fade the list/timeline toggle. The two branches
            // carry distinct subtree keys so the switcher animates the
            // swap; empty vs. populated list share one key (no fade when
            // only the day's content changes).
            child: AnimatedSwitcher(
              duration: AppMotion.viewSwitch,
              child: _timeline
                ? KeyedSubtree(
                    key: const ValueKey('calendar-timeline-view'),
                    child: DayTimeline(
                      day: _selectedDay,
                      reservations: visible,
                      everyone: _everyone,
                      myMemberId: myMember?.id,
                      onReservationTap: _detailSheet,
                    ),
                  )
                : dayReservations.isEmpty
                ? KeyedSubtree(
                    key: const ValueKey('calendar-list-view'),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: EmptyState(
                            icon: Icons.event_available_outlined,
                            title: l10n?.calendarNoReservations ??
                                'No reservations on this day.',
                          ),
                        ),
                      ],
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('calendar-list-view'),
                    child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: dayReservations.length,
                    itemBuilder: (context, index) {
                      final r = dayReservations[index];
                      return _ReservationCard(
                        reservation: r,
                        seatLabel: targets[r.seatId ?? r.officeId] ?? '',
                        occupant: _everyone ? (names[r.memberId] ?? '') : '',
                        own: r.memberId == myMember?.id,
                        onTap: () => _detailSheet(r),
                        onActions: () => _cancelMenu(r),
                      );
                    },
                    ),
                  ),
            ),
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840 &&
            constraints.maxWidth > constraints.maxHeight) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: (constraints.maxWidth * 0.42).clamp(300.0, 520.0),
                child: SingleChildScrollView(child: header),
              ),
              const VerticalDivider(width: 1),
              content,
            ],
          );
        }
        return Column(children: [header, content]);
      },
    );
  }
}

/// One reservation in the day list, as a modern rounded card: a colored
/// round leading badge (its icon reads series / checked-in / reserved),
/// the time range in prominent type, the seat/room and — in Everyone mode
/// — the occupant beneath. Tapping opens the detail sheet; own bookings
/// carry the actions menu. The badge tint is a stable per-target color so
/// the same seat reads the same hue across days.
class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.seatLabel,
    required this.occupant,
    required this.own,
    required this.onTap,
    required this.onActions,
  });

  final Reservation reservation;
  final String seatLabel;
  final String occupant;
  final bool own;
  final VoidCallback onTap;
  final VoidCallback onActions;

  /// A calm, on-brand palette; the target id picks a stable index so a
  /// given seat keeps its hue day to day.
  static const _palette = <Color>[
    Color(0xFFE07A5F), // terracotta (brand)
    Color(0xFF3D8A7D), // teal
    Color(0xFF5B7DB1), // slate blue
    Color(0xFFE0A458), // amber
    Color(0xFF9B6A9E), // mauve
    Color(0xFF6E9B5B), // sage
  ];

  Color get _badgeColor {
    final key = reservation.seatId ?? reservation.officeId ?? reservation.id;
    return _palette[key.hashCode.abs() % _palette.length];
  }

  IconData get _icon => reservation.seriesId != null
      ? Icons.repeat
      : reservation.status == ReservationStatus.checkedIn
          ? Icons.event_seat
          : Icons.schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final timeFormat = DateFormat.Hm();
    final badge = _badgeColor;
    final start = timeFormat.format(reservation.startsAt.toLocal());
    final end = timeFormat.format(reservation.endsAt.toLocal());
    final timeRange = '$start – $end';
    final location =
        occupant.isEmpty ? seatLabel : '$seatLabel · $occupant';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: AppElevation.low(theme.brightness),
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: badge.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 20, color: badge),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeRange,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (own)
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: l10n?.calendarReservationActions ??
                        'Reservation actions',
                    onPressed: onActions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.markedDays,
    required this.myDays,
    required this.onSelect,
  });

  /// Reservation-marker dot colours: red for a day carrying MY bookings,
  /// blue for a day with only other members'. Fixed hues (not scheme
  /// colours) so "mine vs. theirs" reads the same in light and dark.
  static const Color _mineDot = Color(0xFFEF5350); // red 400
  static const Color _otherDot = Color(0xFF42A5F5); // blue 400

  final DateTime month;
  final DateTime selectedDay;

  /// Local today — gets a ring so it stays findable when another day is
  /// selected.
  final DateTime today;
  final Set<DateTime> markedDays;

  /// Days with at least one of MY bookings — the red dot; other marked
  /// days get the blue one.
  final Set<DateTime> myDays;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    final weekdayFormat = DateFormat.E();

    return Padding(
      padding: AppSpacing.smH,
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayFormat
                          .format(DateTime(2026, 6, 1 + i)) // a Monday
                          .substring(0, 1),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final index = row * 7 + col - leading;
                        if (index < 0 || index >= daysInMonth) {
                          return const SizedBox(height: 40);
                        }
                        final day =
                            DateTime(month.year, month.month, index + 1);
                        final selected =
                            DateUtils.isSameDay(day, selectedDay);
                        final isToday = DateUtils.isSameDay(day, today);
                        final marked = markedDays.contains(day);
                        // Selected wins the filled disc; an unselected today
                        // keeps a ring so it stays findable.
                        final decoration = selected
                            ? BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              )
                            : isToday
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: scheme.primary,
                                      width: 1.5,
                                    ),
                                  )
                                : null;
                        return InkWell(
                          onTap: () => onSelect(day),
                          borderRadius: AppRadius.mdAll,
                          child: SizedBox(
                            height: 40,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: decoration,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: selected
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
                                      fontWeight: isToday || selected
                                          ? FontWeight.w700
                                          : null,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 6,
                                  child: marked
                                      ? Icon(
                                          Icons.circle,
                                          size: 5,
                                          color: myDays.contains(day)
                                              ? _mineDot
                                              : _otherDot,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
