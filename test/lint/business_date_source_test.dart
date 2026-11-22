// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4322 -- a business date comes from the BUSINESS's calendar. A date made from the clock's instant
// by reading its year, month or day (`now().day`, `.toLocal().year`, `DateTime(now.year, ...)`,
// `DateUtils.dateOnly(now)`) is the date on the DEVICE's zone: a business in Auckland is read a day
// ahead of a phone in Los Angeles and the year filter of an invoice files it in the wrong year.
// The date is read through `businessDateOf` / `WorkspaceCalendar.dateOf` / `businessTodayProvider`
// (the workspace's time zone), or the server's own date is used.
//
// The cases left in `lib/features/*/domain` and `presentation` are COUNTED, each one a date to
// move onto the business's calendar; the ceiling only falls. (`DateTime.now()` itself is already
// banned by `no_wall_clock_test`, and `.toLocal()` below presentation is pinned by
// `format_seam_test`.)
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

final _deviceDate = LiteralKind(
  'a date read off the clock\'s instant',
  RegExp(
    r'\bnow\(\)\s*\.(?:year|month|day|weekday)\b'
    r'|\.toLocal\(\)\s*\.(?:year|month|day|weekday)\b'
    r'|\bDateTime\(\s*(?:now|today|_now|clock\.now\(\))\s*\.year\b'
    r'|DateUtils\.dateOnly\(\s*(?:now|clock\.now\(\)|ref\.read\(clockProvider\)\.now\(\))',
  ),
);

/// The cases recorded when the lint was added (#4322); each is a date to move onto the business's
/// calendar, and the number only falls.
const _ceiling = 68;

void main() {
  test('the pattern sees a date read off the device clock and not one read on the business\'s calendar', () {
    for (final bad in [
      'final d = clock.now().day;',
      'final y = at.toLocal().year;',
      'final today = DateTime(now.year, now.month, now.day);',
      'final d = DateUtils.dateOnly(now);',
      'final d = DateUtils.dateOnly(ref.read(clockProvider).now());',
    ]) {
      expect(_deviceDate.pattern.hasMatch(bad), isTrue, reason: bad);
    }
    for (final good in [
      'final d = businessDateOf(at, timezone);',
      'final d = calendar.dateOf(clock.now());',
      'final today = ref.watch(businessTodayProvider);',
      'final shown = appFormatOf(context).date(at);',
    ]) {
      expect(_deviceDate.pattern.hasMatch(good), isFalse, reason: good);
    }
  });

  test('dates made off the device clock in domain and presentation only fall', () {
    final files = filesUnder(['lib/features']).where(
      (f) =>
          (f.path.contains('/domain/') || f.path.contains('/presentation/')) &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'),
    );
    final perFile = countLiterals(files, [_deviceDate])[_deviceDate.name]!;
    expect(
      total(perFile),
      _ceiling,
      reason: ratchetMessage(
        rule: 'business date source (#4322): read the date on the business\'s calendar '
            '(businessDateOf, WorkspaceCalendar.dateOf, businessTodayProvider)',
        kind: _deviceDate.name,
        ceiling: _ceiling,
        actual: total(perFile),
        perFile: perFile,
      ),
    );
  });
}
