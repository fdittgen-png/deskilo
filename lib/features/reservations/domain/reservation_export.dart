// SPDX-License-Identifier: 0BSD
/// The developer reservation dump (#677): every booking the workspace
/// holds — past, present and future — as one CSV, for analysis and
/// debugging.
///
/// This is NOT the workspace export (`excel_export.dart`). That one is
/// for an owner and is shaped for reading: names, formatted dates, one
/// sheet per topic. This is for whoever is looking at a bug report,
/// which means the opposite priorities:
///
///  * **raw ids, not names.** A name cannot be pasted into a `where id =`
///    and does not survive a member renaming themselves between the bug
///    and the report.
///  * **UTC ISO-8601, always.** A local-time dump of a booking that
///    straddles a DST change is unreadable exactly when the DST change
///    is the bug. Every stamp carries `Z` and every column name says
///    `_utc`, so a reader converting to the workspace's zone knows what
///    they are converting FROM — which a bare local timestamp never
///    tells them.
///  * **every state, including the ones the UI hides.** Cancelled and
///    released bookings are usually noise; in a "why can nobody book
///    this seat" report they are the answer.
///  * **the derived columns a reader would otherwise compute wrong.**
///    Which of seat/desk/office/level is set decides what KIND of
///    booking this is, and that rule lives in one place rather than in
///    every spreadsheet someone builds on top of this file.
///
/// Nothing here is filtered, and that is deliberate: a diagnostic export
/// that hid rows would send someone hunting for a booking the file
/// silently dropped.
library;

import 'reservation.dart';

/// What a reservation actually booked. The model allows exactly one of
/// seat/desk/office/level to be set; `unknown` exists because a dump
/// that quietly mislabels a malformed row is worse than one that admits
/// it found something it did not expect — and a malformed row is
/// precisely what a bug report is about.
enum ReservationScope { seat, desk, office, level, unknown }

ReservationScope reservationScopeOf(Reservation r) {
  if (r.seatId != null) return ReservationScope.seat;
  if (r.deskId != null) return ReservationScope.desk;
  if (r.officeId != null) return ReservationScope.office;
  if (r.levelId != null) return ReservationScope.level;
  return ReservationScope.unknown;
}

const _columns = [
  'id',
  'workspace_id',
  'member_id',
  'scope',
  'seat_id',
  'desk_id',
  'office_id',
  'level_id',
  'space_label',
  'status',
  'starts_at_utc',
  'ends_at_utc',
  'checked_in_at_utc',
  'checked_out_at_utc',
  'duration_minutes',
  'checked_in_late_minutes',
  'checked_out_early_minutes',
  'series_id',
  'series_pattern',
];

/// The dump. [generatedAt] and [rowCount] go in a header comment so the
/// file says what it is when it arrives detached from the message that
/// carried it.
String buildReservationExportCsv({
  required List<Reservation> reservations,
  required DateTime generatedAt,
  String? workspaceId,
}) {
  final buffer = StringBuffer()
    // A leading `#` line: spreadsheet importers skip it as a comment and
    // a human reading the raw file learns what they are holding.
    ..writeln('# DesKilo reservation export — all states, all time')
    ..writeln('# generated ${_utc(generatedAt)}'
        '${workspaceId == null ? '' : ' · workspace $workspaceId'}')
    ..writeln('# ${reservations.length} row(s); times are UTC')
    ..writeln(_columns.join(','));

  for (final r in reservations) {
    buffer.writeln([
      _q(r.id),
      _q(r.workspaceId),
      _q(r.memberId),
      reservationScopeOf(r).name,
      _q(r.seatId),
      _q(r.deskId),
      _q(r.officeId),
      _q(r.levelId),
      // #587: the substitution snapshot is the ONLY trace of what a
      // deleted plan object was, so a dump without it loses the answer
      // to "what was this booking for".
      _q(r.spaceLabel),
      reservationStatusToDb(r.status),
      _utc(r.startsAt),
      _utc(r.endsAt),
      _utcOrEmpty(r.checkedInAt),
      _utcOrEmpty(r.checkedOutAt),
      r.endsAt.difference(r.startsAt).inMinutes.toString(),
      // Signed on purpose. A NEGATIVE late-minutes is an early check-in
      // inside the leeway, which is legal; suppressing the sign would
      // hide the difference between "arrived early" and "arrived on the
      // dot".
      _minutesBetween(r.startsAt, r.checkedInAt),
      _minutesBetween(r.checkedOutAt, r.endsAt),
      _q(r.seriesId),
      _q(r.seriesPattern),
    ].join(','));
  }
  return buffer.toString();
}

/// ISO-8601 in UTC with the `Z`, so nothing has to guess an offset.
String _utc(DateTime value) => value.toUtc().toIso8601String();

String _utcOrEmpty(DateTime? value) => value == null ? '' : _utc(value);

/// Minutes from [from] to [to], or empty when either is missing — a
/// booking nobody checked into has no lateness, and writing `0` there
/// would claim it was punctual.
String _minutesBetween(DateTime? from, DateTime? to) =>
    (from == null || to == null)
        ? ''
        : to.difference(from).inMinutes.toString();

/// CSV quoting. Ids and patterns should never contain a comma or a
/// quote, but `space_label` is a member-visible name and absolutely can
/// — one unquoted comma there shifts every following column, and the
/// reader would silently misread the whole file rather than fail.
String _q(String? value) {
  if (value == null || value.isEmpty) return '';
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
