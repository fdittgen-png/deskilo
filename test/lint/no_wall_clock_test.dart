// SPDX-License-Identifier: 0BSD
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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed to read the wall clock, each for a stated reason.
///
/// This list may only ever SHRINK. Adding to it is not a normal pull
/// request — the moment one exception is granted for convenience the
/// ratchet stops working, because the next person cites the precedent.
const _exempt = <String, String>{
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
  'lib/app/boot.dart': 'boot-time housekeeping, nothing asserts on it',

  // Pure-Dart default for call sites with no Ref; every widget call site
  // passes the clock explicitly.
  'lib/features/money/domain/bill_sections.dart': 'optional now parameter',

  // Mirrors cache_store.dart above.
  'test/helpers/mock_providers.dart': 'InMemoryCacheStore mirrors real expiry',
};

void main() {
  test('no wall-clock reads outside the exempt list', () {
    final violations = <String>[];

    for (final root in ['lib', 'test']) {
      final files = Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          // Generated code is not hand-written and not ours to fix.
          .where((f) => !f.path.endsWith('.g.dart'))
          .where((f) => !f.path.endsWith('.freezed.dart'))
          .where((f) => !f.path.contains('lib/l10n/'))
          // This file necessarily names the pattern it forbids.
          .where((f) => f.path != 'test/lint/no_wall_clock_test.dart')
          .where((f) => !_exempt.containsKey(f.path));

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          // A comment explaining the rule is not a violation of it.
          if (line.startsWith('//')) continue;
          if (line.contains('DateTime.now()')) {
            // Print the line: a lint failure whose message does not show
            // the match costs more time than the rule saves.
            violations.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

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
