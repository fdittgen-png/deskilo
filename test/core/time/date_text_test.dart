// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2385 — the fixed-shape date texts the files and keys are written in.
import 'package:deskilo/core/time/date_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 3, 4, 9, 5, 3);

  test('calendar dates', () {
    expect(ymd(at), '20260304');
    expect(isoDay(at), '2026-03-04');
    expect(dmy(at), '04/03/2026');
    expect(ddmm(at), '0403');
    expect(yearMonth(2026, 3), '2026-03');
    expect(yearMonth(2026, 3, separator: ''), '202603');
  });

  test('clock times', () {
    expect(hhmm(at), '09:05');
    expect(hhmmss(at, separator: ''), '090503');
    expect(clockFromMinutes(545), '09:05');
    expect(twoDigits(7), '07');
  });

  test('the year has four digits, as ISO 8601 writes it', () {
    expect(isoDay(DateTime.utc(987, 1, 2)), '0987-01-02');
  });
}
