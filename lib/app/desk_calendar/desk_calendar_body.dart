// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — what the desk calendar shows of a period: the filter row,
// then the grid (or the records table) with the open booking beside it (K2).
// One read and one filtered list feed the grid and the table, so they cannot
// disagree; a click on a booking puts it in the address, a click on a free
// cell opens New booking as a side panel.
import 'dart:async';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/files/file_delivery.dart';
import '../../core/files/file_delivery_notice.dart';
import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/i18n/week_start.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/shortcuts/app_shortcuts.dart';
import '../../core/shortcuts/shortcut_scope.dart';
import '../../core/storage/pane_width_store.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/time/clock.dart';
import '../../core/time/day_axis.dart';
import '../../core/time/work_hours.dart';
import '../../core/time/workspace_calendar.dart';
import '../../core/ui/availability_unavailable_banner.dart';
import '../../core/ui/kit/list_detail_scaffold.dart';
import '../../core/ui/loading_view.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/presentation/widgets/my_reservations_layout.dart' show myReservationStatusWords;
import '../../features/workspace/providers/workspace_providers.dart';
import 'bookings_csv.dart';
import 'desk_booking_chip.dart';
import 'desk_booking_pane.dart';
import 'desk_bookings_table.dart';
import 'desk_calendar.dart';
import 'desk_calendar_providers.dart';
import 'desk_day_grid.dart';
import 'desk_filter_row.dart';
import 'desk_grid_rows.dart';
import 'desk_metrics.dart';
import 'desk_month_grid.dart';
import 'desk_new_booking.dart';
import 'desk_week_grid.dart';

/// The key of the zoom-in button of the day grid.
const Key _deskZoomInKey = ValueKey('desk-zoom-in');

/// The key of the zoom-out button of the day grid.
const Key _deskZoomOutKey = ValueKey('desk-zoom-out');

class DeskCalendarBody extends ConsumerStatefulWidget {
  const DeskCalendarBody({
    required this.address,
    required this.calendar,
    super.key,
  });

  final DeskCalendarAddress address;
  final WorkspaceCalendar calendar;

  @override
  ConsumerState<DeskCalendarBody> createState() => _DeskCalendarBodyState();
}

class _DeskCalendarBodyState extends ConsumerState<DeskCalendarBody> {
  DeskFilter _filter = const DeskFilter();
  double _zoom = 1;
  bool _exporting = false;

  DeskCalendarAddress get _address => widget.address;
  WorkspaceCalendar get _calendar => widget.calendar;

  void _go(DeskCalendarAddress next) => context.go(next.location);

  void _open(Reservation r) => _go(_address.copyWith(reservationId: r.id));

  DateTime _at(DateTime day) => _calendar.at(day.year, day.month, day.day);

  void _zoomBy(double factor) => setState(
    () => _zoom = (_zoom * factor).clamp(1, DeskCalendarMetrics.zoomMax),
  );

  /// When the next booking of [place] at or after [from] begins.
  DateTime? _capOf(List<Reservation> bookings, DeskPlace place, DateTime from) {
    final next =
        bookingsOfPlace(place, bookings)
            .where((r) => r.isActive && !r.startsAt.isBefore(from))
            .map((r) => r.startsAt)
            .toList()
          ..sort();
    return next.firstOrNull;
  }

  Future<void> _newBooking(
    List<DeskPlace> seats,
    List<Reservation> bookings,
    DeskPlace place,
    DateTime day, {
    DateTime? at,
  }) => showDeskNewBooking(context, ref, (
    seats: seats,
    place: place,
    day: day,
    at: at,
    capOf: (p, from) => _capOf(bookings, p, from),
  ));

  Future<void> _export(List<Reservation> shown, DeskCalendarData data) async {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final names = ref.read(memberNamesProvider).value ?? const {}; // empty-ok: a missing name is blank in the file, not invented
    final bytes = bookingsCsv(
      shown,
      header: (
        member: l10n.calendarDeskColumnMember,
        place: l10n.calendarDeskColumnPlace,
        from: l10n.calendarDeskColumnFrom,
        to: l10n.calendarDeskColumnTo,
        state: l10n.calendarDeskColumnState,
      ),
      who: (r) => deskBookingWho(names, r),
      place: (r) => data.names[bookingTargetId(r)] ?? r.spaceLabel ?? '',
      at: (instant) => instant.toUtc().toIso8601String(),
      state: (s) => myReservationStatusWords(l10n, s),
    );
    final span = deskSpanOf(
      _address.view,
      _address.day,
      weekStartOf(format),
    );
    final name = bookingsCsvName(
      ref.read(currentWorkspaceProvider).value?.name ?? '',
      isoDay(span.from),
      isoDay(DateTime(span.to.year, span.to.month, span.to.day - 1)),
    );
    setState(() => _exporting = true);
    try {
      final delivery = await deliverFile(context, ref, bytes: bytes, fileName: name);
      if (!mounted) return;
      announceFileDelivery(context, delivery, retry: () => _export(shown, data));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// The opening hours of [day], widened to hold every booking of the day, so
  /// a booking outside the hours is drawn rather than dropped.
  DayAxis _axisOf(DateTime day, WorkHours hours, List<Reservation> bookings) {
    var start = hours.startMinutes;
    var end = hours.endMinutes;
    for (final r in bookings) {
      final from = _calendar.wall(r.startsAt);
      final to = _calendar.wall(r.endsAt);
      final fromMinutes = _calendar.dateOf(r.startsAt) == day
          ? from.hour * Duration.minutesPerHour
          : 0;
      final toMinutes = _calendar.dateOf(r.endsAt) == day
          ? (to.hour + (to.minute > 0 ? 1 : 0)) * Duration.minutesPerHour
          : Duration.minutesPerDay;
      if (fromMinutes < start) start = fromMinutes;
      if (toMinutes > end) end = toMinutes;
    }
    return buildDayAxis(
      _calendar.location,
      day,
      startMinutes: start,
      endMinutes: end > Duration.minutesPerDay ? Duration.minutesPerDay : end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = ref.watch(appFormatProvider);
    final span = deskSpanOf(_address.view, _address.day, weekStartOf(format));
    final read = ref.watch(deskCalendarDataProvider(span));
    return switch (read) {
      AsyncData(:final value) => _loaded(context, span, value),
      AsyncError() => AvailabilityUnavailableBanner(
        onRetry: () => ref.invalidate(deskCalendarDataProvider(span)),
      ),
      _ => const LoadingView(),
    };
  }

  Widget _loaded(BuildContext context, DeskSpan span, DeskCalendarData data) {
    final names = ref.watch(memberNamesProvider).value ?? const {}; // empty-ok: a missing name is blank, not invented
    final bookings = deskBookingsIn(
      data.reservations,
      _filter,
      from: _at(span.from),
      to: _at(span.to),
      facts: data.facts,
    );
    final rows = deskPlaceRows(
      plans: data.plans,
      filter: _filter,
      bookings: bookings,
      names: data.names,
      levelOf: data.levelOf,
    );
    final seats = [
      for (final r in rows)
        if (r.seat != null) r,
    ];
    final selected = _address.reservationId;
    final known = data.reservations.where((r) => r.id == selected).firstOrNull;
    final grid = _address.mode == DeskMode.table
        ? DeskBookingsTable(
            bookings: bookings,
            names: names,
            placeNames: data.names,
            onOpen: _open,
          )
        : _grid(context, data, bookings, rows, seats, names);
    return ShortcutScope(
      handlers: {
        AppShortcutId.newRecord: () {
          if (seats.isEmpty) return;
          unawaited(
            _newBooking(seats, bookings, seats.first, _address.day),
          );
        },
      },
      child: Column(
        children: [
          DeskFilterRow(
            filter: _filter,
            levels: data.levels,
            members: names,
            onChanged: (f) => setState(() => _filter = f),
            onNew: seats.isEmpty
                ? null
                : () => unawaited(
                    _newBooking(seats, bookings, seats.first, _address.day),
                  ),
            onExport: _exporting || bookings.isEmpty
                ? null
                : () => unawaited(_export(bookings, data)),
          ),
          Expanded(
            child: ListDetailScaffold(
              id: 'calendar',
              paneStore: ref.watch(paneWidthStoreProvider),
              // Tab walks the grid row by row in the order it is built, not
              // by where a cell sits on screen: a sideways scroll to reach a
              // cell must not reorder the walk.
              list: FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: grid,
              ),
              selected: selected,
              onClose: () => _go(_address.copyWith(closeReservation: true)),
              detail: (context, id) => DeskBookingPane(
                key: ValueKey('desk-pane-$id'),
                bookingId: id,
                known: known,
                names: names,
                placeNames: data.names,
                onClose: () => _go(_address.copyWith(closeReservation: true)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    DeskCalendarData data,
    List<Reservation> bookings,
    List<DeskPlace> rows,
    List<DeskPlace> seats,
    Map<String, String> names,
  ) {
    final levelNames = {for (final l in data.levels) l.id: l.name};
    final entries = deskGridEntries(rows, levelNames);
    final selected = _address.reservationId;
    final today = _calendar.dateOf(ref.watch(clockProvider).now());
    final first = weekStartOf(ref.watch(appFormatProvider));
    switch (_address.view) {
      case DeskView.day:
        return _dayGrid(context, data, bookings, entries, seats, names);
      case DeskView.week:
        final start = startOfWeek(_address.day, first);
        return DeskWeekGrid(
          days: [
            for (var i = 0; i < 7; i++)
              DateTime(start.year, start.month, start.day + i),
          ],
          entries: entries,
          bookings: bookings,
          names: names,
          selectedId: selected,
          today: today,
          isOpen: _calendar.isOpenOn,
          dayStart: _at,
          onOpen: _open,
          onFree: (place, day) =>
              unawaited(_newBooking(seats, bookings, place, day)),
        );
      case DeskView.month:
        return DeskMonthGrid(
          month: _address.day,
          weeks: deskMonthWeeks(_address.day, first),
          bookings: bookings,
          names: names,
          placeNames: data.names,
          selectedId: selected,
          today: today,
          isOpen: _calendar.isOpenOn,
          dayStart: _at,
          onOpen: _open,
          onDay: (day) =>
              _go(_address.copyWith(view: DeskView.day, day: day)),
          onMore: (day, hidden) => unawaited(
            _showHidden(context, day, hidden, names, data.names),
          ),
        );
    }
  }

  Widget _dayGrid(
    BuildContext context,
    DeskCalendarData data,
    List<Reservation> bookings,
    List<DeskGridEntry> entries,
    List<DeskPlace> seats,
    Map<String, String> names,
  ) {
    final hours = ref.watch(workHoursProvider).value;
    if (hours == null) return const LoadingView();
    final day = _address.day;
    final open = _calendar.isOpenOn(day);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              if (!open)
                Expanded(child: Text(context.l10n.calendarClosedDay))
              else
                const Spacer(),
              IconButton(
                key: _deskZoomOutKey,
                tooltip: context.l10n.calendarDeskZoomOut,
                icon: const Icon(Icons.zoom_out),
                onPressed: _zoom > 1 ? () => _zoomBy(1 / DeskCalendarMetrics.zoomStep) : null,
              ),
              IconButton(
                key: _deskZoomInKey,
                tooltip: context.l10n.calendarDeskZoomIn,
                icon: const Icon(Icons.zoom_in),
                onPressed: _zoom < DeskCalendarMetrics.zoomMax
                    ? () => _zoomBy(DeskCalendarMetrics.zoomStep)
                    : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: DeskDayGrid(
            axis: _axisOf(day, hours, bookings),
            entries: entries,
            bookings: bookings,
            names: names,
            selectedId: _address.reservationId,
            zoom: _zoom,
            open: open,
            onOpen: _open,
            onFree: (place, instant) => unawaited(
              _newBooking(seats, bookings, place, day, at: instant),
            ),
          ),
        ),
      ],
    );
  }

  /// The bookings a month cell left out, each opening beside the grid.
  Future<void> _showHidden(
    BuildContext context,
    DateTime day,
    List<Reservation> hidden,
    Map<String, String> names,
    Map<String, String> placeNames,
  ) {
    final format = appFormatOf(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('desk-month-hidden'),
        scrollable: true,
        title: Text(format.dates(DateShape.weekdayMonthDay).format(day)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in hidden)
              ListTile(
                key: ValueKey('desk-month-hidden-${r.id}'),
                title: Text(deskBookingWho(names, r)),
                subtitle: Text(
                  '${placeNames[bookingTargetId(r)] ?? ''} · '
                  '${deskBookingRange(dialogContext, r)}',
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _open(r);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(dialogContext).closeButtonLabel),
          ),
        ],
      ),
    );
  }
}
