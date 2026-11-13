// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3884 -- a workspace export that lacks bookings this version could not
// read says so on the sheet: a file that looks complete must not be.
import 'package:deskilo/features/workspace/domain/export_unreadable_note.dart';
import 'package:deskilo_xlsx/deskilo_xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sheets = [
    XlsxSheet(name: 'Reservations', rows: [
      ['id'],
      ['r1'],
    ]),
    XlsxSheet(name: 'Members', rows: [
      ['id'],
    ]),
  ];

  test('the note is the last row of the Reservations sheet only', () {
    final out = withBookingsNote(
      sheets,
      2,
      (n) => '$n bookings could not be read',
    );
    expect(out.first.rows.last, ['2 bookings could not be read']);
    expect(out.first.rows, hasLength(3));
    expect(out.last.rows, hasLength(1));
  });

  test('nothing is added when every booking was read', () {
    final out = withBookingsNote(sheets, 0, (n) => 'x');
    expect(out, same(sheets));
  });
}
