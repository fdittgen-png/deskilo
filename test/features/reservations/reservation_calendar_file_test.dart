// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1643 — one owned reservation as an RFC 5545 file, held to the RFC by
// an independent reader.
//
// The serializer is fifty lines; the rules that bite are CRLF, folding
// at 75 octets without cutting a UTF-8 sequence, and text escaping, and
// each of those is checked here by a small unfolding parser written
// AGAINST the RFC rather than against the serializer — plus two golden
// files, byte for byte, so a change to the output is a change somebody
// has to look at.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_calendar_file.dart';
import 'package:flutter_test/flutter_test.dart';

/// The independent reader: unfolds (CRLF followed by one space or tab),
/// splits content lines at the first `:` after the name and its
/// parameters, and un-escapes TEXT. Refuses a bare LF, because a file
/// with one is not an iCalendar file.
Map<String, String> parseIcs(String text) {
  expect(text.contains(RegExp(r'(?<!\r)\n')), isFalse,
      reason: 'a bare LF is not an iCalendar line ending');
  expect(text.endsWith('\r\n'), isTrue);
  final unfolded = text.replaceAll(RegExp(r'\r\n[ \t]'), '');
  final props = <String, String>{};
  for (final line in unfolded.split('\r\n')) {
    if (line.isEmpty) continue;
    final colon = line.indexOf(':');
    expect(colon, greaterThan(0), reason: 'malformed content line: $line');
    final name = line.substring(0, colon).split(';').first;
    final value = line.substring(colon + 1);
    // Every property appears once in this file; BEGIN/END repeat.
    if (name != 'BEGIN' && name != 'END') {
      expect(props.containsKey(name), isFalse, reason: 'duplicate $name');
    }
    props[name] = value;
  }
  return props;
}

String unescapeText(String value) {
  final out = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final c = value[i];
    if (c != r'\') {
      out.write(c);
      continue;
    }
    i++;
    final next = value[i];
    out.write(switch (next) {
      'n' || 'N' => '\n',
      _ => next, // `\\`, `\;`, `\,`
    });
  }
  return out.toString();
}

/// Every PHYSICAL line of [text] as bytes, without its CRLF.
List<List<int>> physicalLines(String text) => text
    .split('\r\n')
    .where((l) => l.isNotEmpty)
    .map((l) => utf8.encode(l))
    .toList();

final _now = DateTime.utc(2026, 5, 13, 10);

Reservation _reservation({
  String id = 'res-1',
  ReservationStatus status = ReservationStatus.reserved,
  DateTime? start,
  DateTime? end,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: 'member-secret-8f2c',
      // 29 March 2026, the night Europe springs forward: 01:30 Berlin is
      // 00:30Z, and 03:30 Berlin — two wall hours later — is 01:30Z.
      startsAt: start ?? WorkspaceTime.at(2026, 3, 29, 1, 30),
      endsAt: end ?? WorkspaceTime.at(2026, 3, 29, 3, 30),
      status: status,
    );

CalendarSnapshot _snapshot(
  Reservation r, {
  String installation = 'example.test',
  String spaceName = 'A1',
  String workspaceName = 'Test Space',
}) =>
    calendarSnapshotOf(
      r,
      installation: installation,
      spaceName: spaceName,
      workspaceName: workspaceName,
      now: _now,
    );

String _golden(String name) =>
    File('test/features/reservations/goldens/$name').readAsStringSync();

void main() {
  setUpAll(() => WorkspaceTime.install('Europe/Berlin'));
  tearDownAll(WorkspaceTime.reset);

  test('the plain file is byte-identical to its golden', () {
    final text = serializeCalendarFile(_snapshot(_reservation()));
    expect(text, _golden('reservation_calendar_file.ics'));
  });

  test('the escaped and folded file is byte-identical to its golden', () {
    final text = serializeCalendarFile(_snapshot(
      _reservation(status: ReservationStatus.cancelled),
      spaceName: 'Salle «Été»; bureau 12, côté fenêtre\\ étage 2\r\n'
          'rangée B — éééééééééééééééééééé fin',
      workspaceName: 'Espace « Pézenas »',
    ));
    expect(text, _golden('reservation_calendar_file_folded.ics'));
  });

  test('the required properties, read back by an independent parser', () {
    final props = parseIcs(serializeCalendarFile(_snapshot(_reservation())));
    expect(props['VERSION'], '2.0');
    expect(props['PRODID'], calendarProdId);
    expect(props['UID'], endsWith('@deskilo.app'));
    expect(props['DTSTAMP'], '20260513T100000Z');
    expect(props['DTSTART'], '20260329T003000Z');
    expect(props['DTEND'], '20260329T013000Z');
    expect(props['SUMMARY'], 'A1');
    expect(props['LOCATION'], 'Test Space');
    expect(props['STATUS'], 'CONFIRMED');
    expect(props.containsKey('METHOD'), isFalse,
        reason: 'METHOD:REQUEST would make every importer offer an '
            'invitation, and there is nobody to invite');
    expect(props.containsKey('ATTENDEE'), isFalse);
    expect(props.containsKey('ORGANIZER'), isFalse);
    expect(props.containsKey('DESCRIPTION'), isFalse);
    expect(props.containsKey('URL'), isFalse);
  });

  test('every line ends in CRLF and the file is one VCALENDAR / one VEVENT',
      () {
    final text = serializeCalendarFile(_snapshot(_reservation()));
    final lines = text.split('\r\n');
    expect(lines.last, isEmpty, reason: 'the file ends with CRLF');
    expect(lines.first, 'BEGIN:VCALENDAR');
    expect(lines[lines.length - 2], 'END:VCALENDAR');
    expect(lines.where((l) => l == 'BEGIN:VEVENT').length, 1);
    expect(lines.where((l) => l == 'END:VEVENT').length, 1);
  });

  test('instants: a DST-crossing booking exports its UTC instants, not the '
      'wall clock, and the end is the exclusive end', () {
    // The screen says 01:30–03:30 (two wall hours); the instant is one.
    final props = parseIcs(serializeCalendarFile(_snapshot(_reservation())));
    expect(props['DTSTART'], '20260329T003000Z');
    expect(props['DTEND'], '20260329T013000Z');
    // Autumn: 25 October 2026, 02:30 Berlin after the fall-back is 01:30Z.
    final autumn = _reservation(
      start: WorkspaceTime.at(2026, 10, 25, 1, 30),
      end: WorkspaceTime.at(2026, 10, 25, 3, 30),
    );
    final p2 = parseIcs(serializeCalendarFile(_snapshot(autumn)));
    expect(p2['DTSTART'], '20261024T233000Z');
    expect(p2['DTEND'], '20261025T023000Z');
    // A booking given as a LOCAL DateTime still exports with `Z`.
    expect(formatCalendarInstant(DateTime(2026, 7, 1, 12)),
        formatCalendarInstant(DateTime(2026, 7, 1, 12).toUtc()));
    expect(formatCalendarInstant(DateTime.utc(2026, 7, 1, 12, 5, 9)),
        '20260701T120509Z');
  });

  test('the stamp comes from the clock the caller passes, so two exports at '
      'different instants differ only there', () {
    final a = serializeCalendarFile(_snapshot(_reservation()));
    final later = calendarSnapshotOf(
      _reservation(),
      installation: 'example.test',
      spaceName: 'A1',
      workspaceName: 'Test Space',
      now: _now.add(const Duration(minutes: 1)),
    );
    final b = serializeCalendarFile(later);
    expect(a, isNot(b));
    expect(parseIcs(b)['DTSTAMP'], '20260513T100100Z');
    expect(a.replaceAll('20260513T100000Z', 'X'),
        b.replaceAll('20260513T100100Z', 'X'));
  });

  group('UID', () {
    test('is stable for the same installation and reservation, across '
        'retimes and status changes', () {
      final a = _snapshot(_reservation()).uid;
      final moved = _snapshot(_reservation(
        start: WorkspaceTime.at(2026, 4, 2, 9),
        end: WorkspaceTime.at(2026, 4, 2, 13),
        status: ReservationStatus.cancelled,
      )).uid;
      expect(moved, a);
    });

    test('differs across installations and across reservations', () {
      final a = _snapshot(_reservation()).uid;
      expect(_snapshot(_reservation(), installation: 'other.test').uid,
          isNot(a));
      expect(_snapshot(_reservation(id: 'res-2')).uid, isNot(a));
      // And the two halves cannot be shuffled into a collision: the
      // separator is a character that appears in neither.
      expect(
        calendarUidFor(installation: 'ab', reservationId: 'c'),
        isNot(calendarUidFor(installation: 'a', reservationId: 'bc')),
      );
    });

    test('names neither the backend nor the row', () {
      final text = serializeCalendarFile(_snapshot(_reservation()));
      expect(text, isNot(contains('example.test')));
      expect(text, isNot(contains('res-1')));
      expect(parseIcs(text)['UID'],
          matches(RegExp(r'^[0-9a-f]{64}@deskilo\.app$')));
    });
  });

  test('status: reserved, checked-in and completed are CONFIRMED; cancelled '
      'and released are CANCELLED — never a live event for a dead booking',
      () {
    String statusOf(ReservationStatus s) =>
        parseIcs(serializeCalendarFile(_snapshot(_reservation(status: s))))[
            'STATUS']!;
    expect(statusOf(ReservationStatus.reserved), 'CONFIRMED');
    expect(statusOf(ReservationStatus.checkedIn), 'CONFIRMED');
    expect(statusOf(ReservationStatus.completed), 'CONFIRMED');
    expect(statusOf(ReservationStatus.cancelled), 'CANCELLED');
    expect(statusOf(ReservationStatus.released), 'CANCELLED');
  });

  group('text escaping', () {
    test('backslash, semicolon, comma and line breaks survive a round trip',
        () {
      const summary = 'A\\B; C, D\r\nE\nF\rG';
      final props = parseIcs(
          serializeCalendarFile(_snapshot(_reservation(), spaceName: summary)));
      expect(props['SUMMARY'], r'A\\B\; C\, D\nE\nF\nG');
      expect(unescapeText(props['SUMMARY']!), 'A\\B; C, D\nE\nF\nG');
    });

    test('a CRLF in a name cannot inject a second content line', () {
      const hostile = 'A1\r\nATTENDEE:mailto:x@example.test\r\nSUMMARY:pwned';
      final text =
          serializeCalendarFile(_snapshot(_reservation(), spaceName: hostile));
      final props = parseIcs(text);
      expect(props.containsKey('ATTENDEE'), isFalse);
      expect(props['SUMMARY'], r'A1\nATTENDEE:mailto:x@example.test\nSUMMARY:pwned');
      expect(text.split('\r\n').where((l) => l.startsWith('SUMMARY:')).length,
          1);
    });

    test('other control characters are dropped, not written', () {
      expect(escapeCalendarText('A BCD\tE'), 'ABCDE');
    });

    test('empty summary falls back to the venue; empty venue omits LOCATION',
        () {
      final props = parseIcs(serializeCalendarFile(
          _snapshot(_reservation(), spaceName: '  ', workspaceName: 'Venue')));
      expect(props['SUMMARY'], 'Venue');
      final p2 = parseIcs(serializeCalendarFile(
          _snapshot(_reservation(), spaceName: 'A1', workspaceName: '')));
      expect(p2.containsKey('LOCATION'), isFalse);
    });
  });

  group('folding', () {
    test('no physical line exceeds 75 octets and unfolding restores the '
        'value', () {
      final long = List.filled(30, 'Salle été').join(' · ');
      final text =
          serializeCalendarFile(_snapshot(_reservation(), spaceName: long));
      for (final line in physicalLines(text)) {
        expect(line.length, lessThanOrEqualTo(calendarLineOctets),
            reason: 'line of ${line.length} octets');
        // Strict decode: a line that started mid-sequence would throw.
        utf8.decode(line, allowMalformed: false);
      }
      expect(parseIcs(text)['SUMMARY'], long);
    });

    test('a cut that would land inside a UTF-8 sequence moves back to the '
        'character boundary', () {
      // 8 octets of name + 40 × 2-octet é = 88: the 75th octet is the
      // second byte of the 34th é, so the first line stops at 74.
      final pieces = foldCalendarLine('SUMMARY:${'é' * 40}');
      expect(pieces.length, 2);
      expect(utf8.encode(pieces.first).length, 74);
      expect(pieces.first, 'SUMMARY:${'é' * 33}');
      expect(pieces.last, ' ${'é' * 7}');
      // A four-octet character (emoji) at the boundary, likewise.
      final emoji = foldCalendarLine('SUMMARY:${'🪑' * 20}');
      for (final p in emoji) {
        expect(utf8.encode(p).length, lessThanOrEqualTo(75));
        utf8.decode(utf8.encode(p), allowMalformed: false);
      }
      expect(emoji.join().replaceAll('\r\n ', ''),
          isNot('SUMMARY:${'🪑' * 20}'),
          reason: 'joined pieces still carry the fold spaces');
      expect(emoji.map((p) => p.startsWith(' ') ? p.substring(1) : p).join(),
          'SUMMARY:${'🪑' * 20}');
    });

    test('a line of exactly 75 octets is not folded', () {
      final line = 'SUMMARY:${'x' * 67}';
      expect(utf8.encode(line).length, 75);
      expect(foldCalendarLine(line), [line]);
    });
  });

  test('canaries: nothing private reaches the file', () {
    final text = serializeCalendarFile(_snapshot(_reservation()));
    for (final canary in [
      'member-secret-8f2c', // the member id
      'res-1', // the row
      'example.test', // the backend
      'ws-1', // the workspace id
      '€', // no amount
      'mailto', // no attendee
      'METHOD', // no invitation
    ]) {
      expect(text, isNot(contains(canary)), reason: canary);
    }
  });
}
