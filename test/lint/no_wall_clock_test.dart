// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Time lint: nothing a widget test pumps may read the wall clock.
//
// Two tests asserted against the real calendar — one on the literal month
// name, one on a fake whose statement period was pinned to '2026-07' while
// the screen asked for the running month. Both passed for three weeks and
// went red together at the 2026-08-01 boundary with no commit in between.
// CI was green on the 28th and red on the 1st with nothing merged between.
//
// A time bomb is not a regression, and bumping the string only resets the
// fuse. The fix is a seam: `clockProvider` in `lib/`, pinned to `kTestNow`
// by `standardTestOverrides` in `test/`.
//
// Both halves are guarded here, because either one alone re-arms the bomb:
// a widget reading `DateTime.now()` ignores the pinned clock, and a test
// seeding from `DateTime.now()` disagrees with it.

import 'package:flutter_test/flutter_test.dart';

import '../../tool/lib_roots.dart';
import 'lint_sources.dart';

/// Files allowed to read the wall clock, each for a stated reason.
///
/// This list may only ever SHRINK. Adding to it is not a normal pull
/// request — the moment one exception is granted for convenience the
/// ratchet stops working, because the next person cites the precedent.
const _exempt = <String, String>{
  // ADR 0028 (#1373) — the in-memory cache store, moved from
  // test/helpers by the Demo work. Freshness inside `CacheStore` is
  // measured against the wall clock, so a pinned `storedAt` would make
  // every entry read as expired the moment it was written.
  'lib/core/demo/data/stores.dart':
      'the in-memory cache stamps entries with the clock CacheStore compares them against',
  // The seam itself: SystemClock is what `DateTime.now()` is for.
  'lib/core/time/clock.dart': 'defines SystemClock',

  // Freshness is measured against the wall clock inside the store, so a
  // pinned storedAt would make every entry read as expired.
  'lib/core/cache/cache_store.dart': 'cache expiry is real-time',
  'test/core/cache/cache_store_test.dart': 'exercises real-time expiry',

  // Log lines and scheduled notifications are stamped by the platform, not
  // by app logic a test asserts on.
  'lib/core/trace/trace_logger.dart': 'log timestamps',
  'lib/core/notifications/local_notification_service.dart': 'OS scheduling',
  // #614: drives the REAL service, whose past-reminder skip compares
  // against the real clock — a pinned test instant would filter every
  // reminder out before the overlap under test even starts.
  'test/core/notifications/reminder_overlap_test.dart':
      'exercises the real-clock reminder sweep',
  'lib/app/boot.dart': 'boot-time housekeeping, nothing asserts on it',

  // Pure-Dart default for call sites with no Ref; every widget call site
  // passes the clock explicitly.
  'lib/features/money/domain/bill_sections.dart': 'optional now parameter',

  // Mirrors cache_store.dart above.
  'test/helpers/mock_providers.dart': 'InMemoryCacheStore mirrors real expiry',
};

/// #3659 (i18n I13) — a calendar day about a business fact is the
/// business's, never the device's. In `lib/features/**/domain` and
/// `**/application`, `.toLocal()` and a day built from `now`'s device
/// components (`DateTime(now.year, now.month, now.day)`) decide a day on
/// the device: take the day from the business's calendar instead
/// (`businessTodayAt`, `WorkspaceCalendar.dateOf`, a `dayOf` parameter).
/// The files below held such reads when the rule came, with their count;
/// a count may only fall, and a file leaves the list at zero.
const _deviceDayFiles = <String, int>{
  'lib/features/money/domain/bill_pdf.dart': 1,
  'lib/features/money/domain/company_lookup.dart': 1,
  'lib/features/money/domain/einvoice_gateway.dart': 2,
  'lib/features/money/domain/finance_filter.dart': 2,
  'lib/features/money/domain/invoice_match_row.dart': 3,
  'lib/features/money/domain/reminder_evidence.dart': 2,
  'lib/features/money/domain/usage_record.dart': 5,
  'lib/features/money/domain/vies_check.dart': 1,
  'lib/features/profile/domain/rights_request.dart': 1,
  'lib/features/reservations/domain/my_reservations_composition.dart': 2,
  'lib/features/reservations/domain/my_reservations.dart': 2,
};

final _deviceDay = RegExp(
  r'\.toLocal\(\)'
  r'|DateTime\(\s*[\w.]*now\.year,\s*[\w.]*now\.month,\s*[\w.]*now\.day',
  caseSensitive: false,
);

/// The device-day reads on the code [lines] of a file.
int deviceDayReads(Iterable<String> lines) => lines
    .where((l) => !l.trimLeft().startsWith('//'))
    .map((l) => _deviceDay.allMatches(l).length)
    .fold(0, (a, b) => a + b);

bool _domainOrApplication(String path) =>
    path.startsWith('lib/features/') &&
    (path.contains('/domain/') || path.contains('/application/'));

void main() {
  test('a device-day read is seen; a business day is not (#3659)', () {
    expect(deviceDayReads(['final d = at.toLocal();']), 1);
    expect(deviceDayReads(['DateTime(now.year, now.month, now.day)']), 1);
    expect(deviceDayReads(['DateTime(clock.now.year, clock.now.month, x)']),
        0);
    expect(deviceDayReads(['final d = calendar.dateOf(now);']), 0);
    expect(deviceDayReads(['// was at.toLocal()']), 0);
  });

  test('no device day in a feature\'s domain or application, beyond the '
      'named files, and none of theirs grows (#3659)', () {
    final found = <String, int>{
      for (final f in handWrittenDartFiles('lib/features'))
        if (_domainOrApplication(f.path))
          f.path: deviceDayReads(f.readAsLinesSync()),
    }..removeWhere((_, n) => n == 0);
    final grown = [
      for (final MapEntry(key: path, value: n) in found.entries)
        if (n > (_deviceDayFiles[path] ?? 0))
          '$path: $n (allowed ${_deviceDayFiles[path] ?? 0})',
    ];
    final shrunk = [
      for (final MapEntry(key: path, value: allowed) in _deviceDayFiles.entries)
        if ((found[path] ?? 0) < allowed)
          '$path: ${found[path] ?? 0} (listed $allowed)',
    ];
    expect(grown, isEmpty,
        reason: 'a day decided on the device; read the business\'s calendar');
    expect(shrunk, isEmpty,
        reason: 'lower the count in _deviceDayFiles (or remove the file at 0)');
  });

  test('no wall-clock reads outside the exempt list', () {
    final violations = <String>[];

    final files = handWrittenDartFilesIn(['lib', 'test', ...packageLibRoots()])
        // These files necessarily name the pattern they forbid.
        .where((f) => f.path != 'test/lint/no_wall_clock_test.dart')
        .where((f) => f.path != 'test/lint/lint_sources.dart')
        .where((f) => !_exempt.containsKey(f.path));
    violations.addAll(
      scanLines(files, (line) => line.contains('DateTime.now()')),
    );

    expect(
      violations,
      isEmpty,
      reason: 'Wall-clock read outside the exempt list:\n'
          '${violations.join('\n')}\n\n'
          'In lib/: inject the clock — `ref.watch(clockProvider).now()` in '
          'build, `ref.read(...)` in a handler, or take a `DateTime now` '
          'parameter where there is no Ref.\n'
          'In test/: seed from `kTestNow` / `kTestPeriod` '
          '(test/helpers/test_clock.dart), which is what '
          'standardTestOverrides pins the app to.',
    );
  });
}
