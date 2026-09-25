// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1643 — one owned reservation as an RFC 5545 calendar file.
//
// A member wants their booking in the calendar they already keep. The
// file that does that is one `VCALENDAR` holding one `VEVENT`, and this
// is the whole serializer: no parser, no sync, no subscription feed. No
// pinned package either — `pub.dev` offers iCalendar libraries, but every
// one of them is a general parser-and-model with a licence and a
// dependency tree to review for the sake of the twelve properties below.
// Writing them is fifty lines; the RFC rules that bite (CRLF, folding at
// 75 octets without cutting a UTF-8 sequence, text escaping) are each a
// test here, against an independent unfolding parser, so the choice can
// be revisited on evidence.
//
// ## What the file never carries
//
// No amount, no attendee, no e-mail address, no member name, no note, no
// bearer link, no validation detail, and no `METHOD:REQUEST` — a request
// would make every importer offer to send an invitation, and there is
// nobody to invite. The UID identifies the reservation without naming
// it: a digest of the installation and the reservation id, so a reimport
// lands on the same event and a stranger holding the file learns
// neither the backend nor the row. `STATUS` says what the booking IS —
// a cancelled reservation exports as `CANCELLED`, never as a live one.
//
// ## Instants, not wall clocks
//
// Every stamp is written in UTC from the reservation's own timestamps.
// The screen's "09:00" is a rendering in the workspace zone; the booking
// is an instant, and an instant survives a DST change in the reader's
// calendar where a floating time would not. The end is exclusive, as
// the reservation's is (`coversInstant`) and as `DTEND` is in the RFC.
//
// Pure Dart: the CLI and the tests import it without Flutter.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'reservation.dart';

/// The two statuses a booking can export as. There is no `TENTATIVE`:
/// a reservation the server holds is confirmed, and one it released is
/// cancelled — the app has no "maybe".
enum CalendarEventStatus { confirmed, cancelled }

/// Everything the file will say, decided before a byte is written.
///
/// The preview shows exactly these fields, and `save` rebuilds the file
/// from a fresh reading to compare against them, so a booking that moved
/// between preview and save is refused rather than exported stale.
final class CalendarSnapshot {
  const CalendarSnapshot({
    required this.uid,
    required this.stampUtc,
    required this.startUtc,
    required this.endUtc,
    required this.summary,
    required this.location,
    required this.status,
  });

  final String uid;
  final DateTime stampUtc;
  final DateTime startUtc;
  final DateTime endUtc;

  /// The booked resource — a seat, a desk, an office, a floor.
  final String summary;

  /// The venue — the workspace's name.
  final String location;
  final CalendarEventStatus status;

  /// What a retime or a cancellation changes: the fields a reimport must
  /// see. The stamp is deliberately NOT part of it — two snapshots of the
  /// same unchanged booking taken a minute apart are the same booking.
  bool sameBookingAs(CalendarSnapshot other) =>
      uid == other.uid &&
      startUtc == other.startUtc &&
      endUtc == other.endUtc &&
      summary == other.summary &&
      location == other.location &&
      status == other.status;
}

/// The UID of a reservation's event, stable across exports and across
/// retimes: `sha256(installation ␟ reservationId)` in hex, at the domain
/// that says which product wrote it.
///
/// [installation] scopes it — the same reservation id on two backends
/// must not collide in a calendar that imported both — and a digest
/// keeps both the backend host and the row id out of the file.
String calendarUidFor({
  required String installation,
  required String reservationId,
}) {
  final digest = sha256.convert(utf8.encode('$installation␟$reservationId'));
  return '$digest@deskilo.app';
}

/// Maps a reservation onto the fields the file may carry.
///
/// [spaceName] is the resolved name of the booked target (or the
/// audit substitution when it was deleted), [workspaceName] the venue,
/// [now] the clock — [CalendarSnapshot.stampUtc] is never read from the
/// wall clock so the file is deterministic under test.
CalendarSnapshot calendarSnapshotOf(
  Reservation reservation, {
  required String installation,
  required String spaceName,
  required String workspaceName,
  required DateTime now,
}) {
  final resource = spaceName.trim();
  return CalendarSnapshot(
    uid: calendarUidFor(
      installation: installation,
      reservationId: reservation.id,
    ),
    stampUtc: now.toUtc(),
    startUtc: reservation.startsAt.toUtc(),
    endUtc: reservation.endsAt.toUtc(),
    summary: resource.isEmpty ? workspaceName.trim() : resource,
    location: workspaceName.trim(),
    status: switch (reservation.status) {
      ReservationStatus.reserved ||
      ReservationStatus.checkedIn ||
      ReservationStatus.completed =>
        CalendarEventStatus.confirmed,
      ReservationStatus.cancelled ||
      ReservationStatus.released =>
        CalendarEventStatus.cancelled,
    },
  );
}

/// The product identifier every file carries (RFC 5545 §3.7.3).
const calendarProdId = '-//DesKilo//Reservation//EN';

/// The file: one `VCALENDAR`, one `VEVENT`, CRLF line endings, every
/// content line folded at 75 octets. The text is returned as a `String`
/// whose UTF-8 encoding is the file's bytes.
String serializeCalendarFile(CalendarSnapshot snapshot) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:$calendarProdId',
    'BEGIN:VEVENT',
    'UID:${snapshot.uid}',
    'DTSTAMP:${formatCalendarInstant(snapshot.stampUtc)}',
    'DTSTART:${formatCalendarInstant(snapshot.startUtc)}',
    'DTEND:${formatCalendarInstant(snapshot.endUtc)}',
    'SUMMARY:${escapeCalendarText(snapshot.summary)}',
    if (snapshot.location.isNotEmpty)
      'LOCATION:${escapeCalendarText(snapshot.location)}',
    'STATUS:${switch (snapshot.status) {
      CalendarEventStatus.confirmed => 'CONFIRMED',
      CalendarEventStatus.cancelled => 'CANCELLED',
    }}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  final buffer = StringBuffer();
  for (final line in lines) {
    for (final piece in foldCalendarLine(line)) {
      buffer
        ..write(piece)
        ..write('\r\n');
    }
  }
  return buffer.toString();
}

/// `DATE-TIME` in UTC form (§3.3.5): `20260329T003000Z`. The argument is
/// converted, so a caller passing a local instant still gets `Z`.
String formatCalendarInstant(DateTime instant) {
  final utc = instant.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
      'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

/// `TEXT` escaping (§3.3.11): backslash, semicolon and comma are
/// escaped, any line break becomes `\n`, and the remaining control
/// characters — which no importer needs and which would otherwise
/// smuggle a second content line into the file — are dropped.
String escapeCalendarText(String value) {
  final out = StringBuffer();
  final runes = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').runes;
  for (final rune in runes) {
    switch (rune) {
      case 0x5C: // backslash
        out.write(r'\\');
      case 0x3B: // ;
        out.write(r'\;');
      case 0x2C: // ,
        out.write(r'\,');
      case 0x0A:
        out.write(r'\n');
      default:
        if (rune < 0x20 || rune == 0x7F) continue;
        out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Maximum octets of a content line before its CRLF (§3.1).
const calendarLineOctets = 75;

/// Folds one logical line into physical lines of at most 75 octets,
/// each continuation starting with a single space that counts towards
/// its 75. The cut is measured in UTF-8 BYTES and never falls inside a
/// multi-byte sequence: a continuation byte (`10xxxxxx`) is pushed to
/// the next line with its lead byte, so «é» or an emoji in a seat name
/// arrives whole.
List<String> foldCalendarLine(String line) {
  final bytes = utf8.encode(line);
  if (bytes.length <= calendarLineOctets) return [line];
  final pieces = <String>[];
  var start = 0;
  var first = true;
  while (start < bytes.length) {
    final room = first ? calendarLineOctets : calendarLineOctets - 1;
    var end = start + room;
    if (end >= bytes.length) {
      end = bytes.length;
    } else {
      // Back up to the start of the character that would be cut.
      while (end > start && (bytes[end] & 0xC0) == 0x80) {
        end--;
      }
    }
    final piece = utf8.decode(bytes.sublist(start, end));
    pieces.add(first ? piece : ' $piece');
    first = false;
    start = end;
  }
  return pieces;
}
