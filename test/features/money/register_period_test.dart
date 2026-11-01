// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the window a drill-through opens the invoice register on.
import 'package:deskilo/features/money/domain/register_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegisterPeriod.parse', () {
    test('months span their first to their last day', () {
      final window = RegisterPeriod.parse('2026-02', '2026-03')!;
      expect(window.first, DateTime(2026, 2));
      expect(window.last, DateTime(2026, 3, 31));
    });

    test('days are taken as given', () {
      final window = RegisterPeriod.parse('2026-02-10', '2026-02-12')!;
      expect(window.first, DateTime(2026, 2, 10));
      expect(window.last, DateTime(2026, 2, 12));
    });

    test('a reversed pair is put in order', () {
      final window = RegisterPeriod.parse('2026-03', '2026-01')!;
      expect(window.first, DateTime(2026));
      expect(window.last, DateTime(2026, 3, 31));
    });

    test('February of a leap year ends on the 29th', () {
      expect(RegisterPeriod.parse('2028-02', '2028-02')!.last.day, 29);
    });

    test('anything missing, malformed or out of bounds is no window', () {
      for (final pair in const [
        (null, null),
        ('2026-01', null),
        (null, '2026-01'),
        ('junk', '2026-01'),
        ('2026-13', '2026-13'),
        ('2026-00', '2026-01'),
        ('2026-02-30', '2026-03'),
        ('0026-01', '2026-01'),
        ('2026-01', '20260-01'),
        ('1999-12', '2026-01'),
        ('2026-01', '2101-01'),
        ('2026-1', '2026-3'),
        ('', ''),
      ]) {
        expect(RegisterPeriod.parse(pair.$1, pair.$2), isNull, reason: '$pair');
      }
    });

    test('contains is inclusive of both end days, whatever the hour', () {
      final window = RegisterPeriod.parse('2026-02', '2026-02')!;
      expect(window.contains(DateTime(2026, 2)), isTrue);
      expect(window.contains(DateTime(2026, 2, 28, 23, 59)), isTrue);
      expect(window.contains(DateTime(2026, 1, 31, 23, 59)), isFalse);
      expect(window.contains(DateTime(2026, 3)), isFalse);
    });
  });
}
