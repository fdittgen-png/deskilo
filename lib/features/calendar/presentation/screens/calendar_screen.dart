// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/trace/trace_logger.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
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
    final timeFormat = DateFormat.Hm();

    final dayReservations = visible
        .where((r) => _sameDay(r.startsAt.toLocal(), _selectedDay))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
              // #187: list vs. timeline for the selected-day area.
              IconButton(
                icon: const Icon(Icons.view_list_outlined),
                isSelected: !_timeline,
                visualDensity: VisualDensity.compact,
                tooltip: l10n?.calendarListView ?? 'List view',
                onPressed: () => setState(() => _timeline = false),
              ),
              IconButton(
                icon: const Icon(Icons.view_timeline_outlined),
                isSelected: _timeline,
                visualDensity: VisualDensity.compact,
                tooltip: l10n?.calendarTimelineView ?? 'Timeline view',
                onPressed: () => setState(() => _timeline = true),
              ),
            ],
          ),
        ),
        _MonthGrid(
          month: _month,
          selectedDay: _selectedDay,
          markedDays: {
            for (final r in visible) DateUtils.dateOnly(r.startsAt.toLocal()),
          },
          onSelect: (day) => setState(() => _selectedDay = day),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => invalidateBookingData(ref),
            child: _timeline
                ? DayTimeline(
                    day: _selectedDay,
                    reservations: visible,
                    everyone: _everyone,
                    myMemberId: myMember?.id,
                    onReservationTap: _detailSheet,
                  )
                : dayReservations.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            l10n?.calendarNoReservations ??
                                'No reservations on this day.',
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: dayReservations.length,
                    itemBuilder: (context, index) {
                      final r = dayReservations[index];
                      final own = r.memberId == myMember?.id;
                      return ListTile(
                        leading: Icon(
                          r.seriesId != null
                              ? Icons.repeat
                              : (r.status == ReservationStatus.checkedIn
                                  ? Icons.event_seat
                                  : Icons.schedule),
                        ),
                        title: Text(
                          '${timeFormat.format(r.startsAt.toLocal())} – '
                          '${timeFormat.format(r.endsAt.toLocal())} · '
                          '${targets[r.seatId ?? r.officeId] ?? ''}',
                        ),
                        subtitle:
                            _everyone ? Text(names[r.memberId] ?? '') : null,
                        trailing: own
                            ? IconButton(
                                icon: const Icon(Icons.more_vert),
                                tooltip: l10n?.calendarReservationActions ??
                                    'Reservation actions',
                                onPressed: () => _cancelMenu(r),
                              )
                            : null,
                        // #182: where is this seat? Detail sheet with the
                        // location chain and a "Show on plan" jump.
                        onTap: () => _detailSheet(r),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.markedDays,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Set<DateTime> markedDays;
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        final marked = markedDays.contains(day);
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
                                  decoration: selected
                                      ? BoxDecoration(
                                          color: scheme.primary,
                                          shape: BoxShape.circle,
                                        )
                                      : null,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: selected
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 6,
                                  child: marked
                                      ? Icon(
                                          Icons.circle,
                                          size: 5,
                                          color: scheme.primary,
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
