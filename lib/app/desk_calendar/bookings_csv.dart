// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the bookings of the period as a CSV file: one row per
// booking under the table's own columns, in the reader's language. The hours
// are ISO instants with the business's offset, so a spreadsheet reads the same
// moment the table shows. Text cells go through the shared cell writer, which
// quotes and keeps a spreadsheet from running a cell that starts with =, +, -
// or @. UTF-8 with a byte order mark and CRLF line ends, as the other table
// exports are written.
import 'dart:convert';
import 'dart:typed_data';

import '../../core/files/file_names.dart';
import '../../core/text/csv.dart';
import '../../features/reservations/domain/reservation.dart';

/// The header words, in the reader's language.
typedef BookingsCsvHeader = ({
  String member,
  String place,
  String from,
  String to,
  String state,
});

/// [bookings] as the table's CSV; [who], [place], [at] and [state] give a
/// row's words as the table shows them.
Uint8List bookingsCsv(
  List<Reservation> bookings, {
  required BookingsCsvHeader header,
  required String Function(Reservation r) who,
  required String Function(Reservation r) place,
  required String Function(DateTime instant) at,
  required String Function(ReservationStatus status) state,
}) {
  final lines = <String>[
    [
      header.member,
      header.place,
      header.from,
      header.to,
      header.state,
    ].map(csvCell).join(','),
    for (final r in bookings)
      [
        csvCell(who(r)),
        csvCell(place(r)),
        csvCell(at(r.startsAt)),
        csvCell(at(r.endsAt)),
        csvCell(state(r.status)),
      ].join(','),
  ];
  return Uint8List.fromList([
    0xEF, 0xBB, 0xBF, // UTF-8 byte order mark, as the other table exports.
    ...utf8.encode('${lines.join('\r\n')}\r\n'),
  ]);
}

/// The file's name: the workspace and the days the period spans.
String bookingsCsvName(String workspaceName, String from, String to) =>
    'deskilo-bookings-${safeFileSlug(workspaceName)}-$from-$to.csv';
