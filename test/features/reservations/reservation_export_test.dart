// SPDX-License-Identifier: 0BSD
//
// #677 — the developer reservation dump.
//
// Asked for as: "export all current existing reservations, checkouts of
// the past present and future for analysis and debugge". The word that
// shapes every test below is DEBUG: this file exists to answer a bug
// report, so the failure modes that matter are the quiet ones — a row
// silently dropped, a timestamp that reads plausibly in the wrong zone,
// a comma in a name that shifts every following column.
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_export.dart';
import 'package:flutter_test/flutter_test.dart';

Reservation res({
  String id = 'r1',
  String? seatId,
  String? deskId,
  String? officeId,
  String? levelId,
  String? spaceLabel,
  ReservationStatus status = ReservationStatus.reserved,
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? checkedInAt,
  DateTime? checkedOutAt,
  String? seriesId,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'm-1',
      seatId: seatId,
      deskId: deskId,
      officeId: officeId,
      levelId: levelId,
      spaceLabel: spaceLabel,
      startsAt: startsAt ?? DateTime.utc(2026, 8, 27, 9),
      endsAt: endsAt ?? DateTime.utc(2026, 8, 27, 17),
      status: status,
      checkedInAt: checkedInAt,
      checkedOutAt: checkedOutAt,
      seriesId: seriesId,
    );

String csv(List<Reservation> rows) => buildReservationExportCsv(
      reservations: rows,
      generatedAt: DateTime.utc(2026, 8, 27, 10, 30),
      workspaceId: 'ws-1',
    );

/// The data lines only — the `#` preamble and the header are asserted
/// separately.
List<String> dataRows(String out) => out
    .split('\n')
    .where((l) => l.isNotEmpty && !l.startsWith('#'))
    .skip(1)
    .toList();

void main() {
  group('nothing is filtered out', () {
    test('EVERY status is exported, including the ones the UI hides', () {
      // Cancelled and released bookings are noise most of the time. In a
      // "why can nobody book this seat" report they are the answer, and
      // an export that dropped them would send someone hunting for a row
      // the file removed.
      final rows = [
        for (final s in ReservationStatus.values)
          res(id: 'r-${s.name}', seatId: 's1', status: s),
      ];
      final out = csv(rows);
      expect(dataRows(out).length, ReservationStatus.values.length);
      for (final s in ReservationStatus.values) {
        expect(out, contains(reservationStatusToDb(s)),
            reason: '${s.name} is missing from the dump');
      }
    });

    test('the row count is stated, so a truncated file is obvious', () {
      final out = csv([res(seatId: 's1'), res(id: 'r2', seatId: 's2')]);
      expect(out, contains('# 2 row(s)'));
    });

    test('an empty workspace still produces a valid, self-describing file',
        () {
      final out = csv(const []);
      expect(out, contains('# 0 row(s)'));
      expect(out, contains('id,workspace_id'),
          reason: 'the header must be there even with no rows — an empty '
              'file is indistinguishable from a failed export');
    });
  });

  group('the times cannot be misread', () {
    test('stamps are UTC with the Z, whatever zone they arrive in', () {
      // A local-time dump of a booking straddling a DST change is
      // unreadable exactly when the DST change is the bug.
      final local = DateTime.utc(2026, 8, 27, 9).toLocal();
      final out = csv([res(seatId: 's1', startsAt: local)]);
      expect(out, contains('2026-08-27T09:00:00.000Z'));
    });

    test('a booking nobody checked into has EMPTY lateness, not zero', () {
      // Writing 0 there would claim it was punctual.
      final out = csv([res(seatId: 's1')]);
      final cells = dataRows(out).single.split(',');
      final header = out
          .split('\n')
          .firstWhere((l) => l.startsWith('id,'))
          .split(',');
      expect(cells[header.indexOf('checked_in_late_minutes')], '');
      expect(cells[header.indexOf('checked_out_at_utc')], '');
    });

    test('an EARLY check-in reads as negative, not as on-time', () {
      // Check-in opens 15 minutes before the start, so early is legal —
      // and suppressing the sign would hide the difference between
      // "arrived early" and "arrived on the dot".
      final out = csv([
        res(
          seatId: 's1',
          checkedInAt: DateTime.utc(2026, 8, 27, 8, 50),
        ),
      ]);
      expect(out, contains(',-10,'));
    });
  });

  group('the scope column says what was actually booked', () {
    test('each of the four kinds is labelled', () {
      expect(reservationScopeOf(res(seatId: 's')), ReservationScope.seat);
      expect(reservationScopeOf(res(deskId: 'd')), ReservationScope.desk);
      expect(reservationScopeOf(res(officeId: 'o')), ReservationScope.office);
      expect(reservationScopeOf(res(levelId: 'l')), ReservationScope.level);
    });

    test('a row with NO target is admitted, not silently mislabelled', () {
      // A malformed row is precisely what a bug report is about; calling
      // it a seat booking would bury the finding.
      expect(reservationScopeOf(res()), ReservationScope.unknown);
      expect(csv([res()]), contains(',unknown,'));
    });
  });

  group('a name cannot corrupt the file', () {
    test('a comma in the space label is quoted', () {
      // #587 writes a human-readable chain into space_label, and one
      // unquoted comma there shifts every following column — the reader
      // then MISREADS the file rather than failing on it.
      final out = csv([
        res(seatId: 's1', spaceLabel: 'Pézenas · Level 1, Room A · Table 2'),
      ]);
      expect(out, contains('"Pézenas · Level 1, Room A · Table 2"'));
      // The row must still have exactly as many cells as the header.
      final header = out
          .split('\n')
          .firstWhere((l) => l.startsWith('id,'))
          .split(',')
          .length;
      final cells = _splitCsv(dataRows(out).single).length;
      expect(cells, header);
    });

    test('a quote in the label is doubled, per RFC 4180', () {
      final out = csv([res(seatId: 's1', spaceLabel: 'Room "Annex"')]);
      expect(out, contains('"Room ""Annex"""'));
    });

    test('the deletion snapshot survives into the dump', () {
      // It is the ONLY trace of what a deleted plan object was, so a dump
      // without it loses the answer to "what was this booking for".
      final out = csv([res(seatId: 's1', spaceLabel: 'deleted table 4')]);
      expect(out, contains('deleted table 4'));
    });
  });
}

/// A minimal RFC 4180 splitter — enough to count cells in a quoted row.
List<String> _splitCsv(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      cells.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(c);
    }
  }
  cells.add(buffer.toString());
  return cells;
}
