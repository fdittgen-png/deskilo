// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — all bookings of the period as a records table (K1): member,
// place, from, to, state. It reads the very list the grid draws, so the two
// show the same bookings. A row opens the booking beside the table.
import 'package:flutter/material.dart';

import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/ui/empty_state.dart';
import '../../core/ui/kit/records_table.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/presentation/widgets/my_reservations_layout.dart' show myReservationStatusWords;
import 'desk_booking_chip.dart';
import 'desk_calendar.dart';

/// The key of the records table of the desk calendar.
const Key _deskBookingsTableKey = ValueKey('desk-bookings-table');

class DeskBookingsTable extends StatelessWidget {
  const DeskBookingsTable({
    required this.bookings,
    required this.names,
    required this.placeNames,
    required this.onOpen,
    super.key,
  });

  final List<Reservation> bookings;
  final Map<String, String> names;
  final Map<String, String> placeNames;
  final ValueChanged<Reservation> onOpen;

  String _place(Reservation r) =>
      placeNames[bookingTargetId(r)] ?? r.spaceLabel ?? '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    return RecordsTable<Reservation>(
      key: _deskBookingsTableKey,
      tableId: 'desk-bookings',
      rows: bookings,
      keyOf: (r) => r.id,
      initialQuery: const RecordsQuery(sortColumn: 'from'),
      searchText: (r) => '${deskBookingWho(names, r)} ${_place(r)}',
      onOpen: onOpen,
      empty: EmptyState(
        icon: Icons.event_busy_outlined,
        title: l10n.calendarNothingHere,
      ),
      columns: [
        RecordColumn(
          id: 'member',
          label: l10n.calendarDeskColumnMember,
          flex: 3,
          hideable: false,
          sortKey: (r) => deskBookingWho(names, r).toLowerCase(),
          cell: (_, r) => Text(
            deskBookingWho(names, r),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        RecordColumn(
          id: 'place',
          label: l10n.calendarDeskColumnPlace,
          flex: 3,
          sortKey: (r) => _place(r).toLowerCase(),
          cell: (_, r) => Text(_place(r), overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'from',
          label: l10n.calendarDeskColumnFrom,
          flex: 3,
          sortKey: (r) => r.startsAt,
          cell: (_, r) => Text(format.dateTime(r.startsAt)),
        ),
        RecordColumn(
          id: 'to',
          label: l10n.calendarDeskColumnTo,
          flex: 3,
          sortKey: (r) => r.endsAt,
          cell: (_, r) => Text(format.dateTime(r.endsAt)),
        ),
        RecordColumn(
          id: 'state',
          label: l10n.calendarDeskColumnState,
          flex: 2,
          sortKey: (r) => r.status.index,
          cell: (_, r) => Text(myReservationStatusWords(l10n, r.status)),
        ),
      ],
      cardBuilder: (context, r) => Card(
        child: ListTile(
          title: Text(deskBookingWho(names, r)),
          subtitle: Text('${_place(r)} · ${deskBookingRange(context, r)}'),
          onTap: () => onOpen(r),
        ),
      ),
    );
  }
}
