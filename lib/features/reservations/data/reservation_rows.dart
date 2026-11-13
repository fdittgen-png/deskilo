// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/data/unreadable_rows.dart';
import '../domain/reservation.dart';

/// The reservations of [rows] this build can read, and how many it could
/// not (#3884). A row whose status it does not know is left out, recorded
/// under [reservationsArea] for the read [read] of [workspaceId] (replacing
/// that read's earlier record, and a read for another workspace replaces
/// the previous workspace's) and traced -- never read as a status it is not.
/// One such row no longer fails the whole list, and the caller is told how
/// many were left out.
ReadWithUnreadable<List<Reservation>> reservationsFromRows(
  Iterable<Object?> rows, {
  required String workspaceId,
  required String read,
}) {
  final left = <String, String>{};
  final kept = <Reservation>[];
  for (final raw in rows) {
    final row = Map<String, dynamic>.from(raw! as Map);
    final status = reservationStatusFromDb(row['status'] as String?);
    if (status == null) {
      left['${row['id']}'] = 'reservation status ${row['status']}';
    } else {
      kept.add(reservationFromRow(row, status));
    }
  }
  final unreadable = UnreadableRows.instance.record(
    reservationsArea,
    '$workspaceId|$read',
    left,
    scope: workspaceId,
  );
  return (rows: kept, unreadable: unreadable);
}

/// One reservation row whose [status] is already read.
Reservation reservationFromRow(
  Map<String, dynamic> row,
  ReservationStatus status,
) => Reservation(
  system: SystemColumns.fromRow(row),
  id: row['id'] as String,
  workspaceId: row['workspace_id'] as String,
  seatId: row['seat_id'] as String?,
  deskId: row['desk_id'] as String?,
  officeId: row['office_id'] as String?,
  levelId: row['level_id'] as String?,
  memberId: row['member_id'] as String,
  startsAt: DateTime.parse(row['starts_at'] as String),
  endsAt: DateTime.parse(row['ends_at'] as String),
  status: status,
  seriesId: row['series_id'] as String?,
  seriesPattern: row['series_pattern'] as String?,
  checkedInAt: row['checked_in_at'] == null
      ? null
      : DateTime.parse(row['checked_in_at'] as String),
  checkedOutAt: row['checked_out_at'] == null
      ? null
      : DateTime.parse(row['checked_out_at'] as String),
  spaceLabel: row['space_label'] as String?,
);
