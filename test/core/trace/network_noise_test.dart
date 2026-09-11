// SPDX-License-Identifier: 0BSD
//
// #1135 — the Errors filter on the Developer screen was a third noise.
//
// A field trace of 67 errors carried 23 `Software caused connection
// abort` — a phone going through a tunnel — and the two real crashes in
// it were buried among them. A dropped connection is not a defect, and
// filing it as one costs the level its meaning.
//
// It is still recorded in full, one level down, where Warnings+ shows
// it. What changes is that ERROR comes to mean "the app is wrong".
import 'dart:io';

import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isTransientNetworkFailure', () {
    test('the exact shapes from the field trace', () {
      // Verbatim from deskilotrace-2026-09-11.
      expect(
        isTransientNetworkFailure(
          'ClientException: Software caused connection abort, '
          'uri=https://example.supabase.co/rest/v1/rpc/my_conversations',
        ),
        isTrue,
      );
      expect(
        isTransientNetworkFailure(
          const SocketException('Failed host lookup: example.supabase.co'),
        ),
        isTrue,
      );
    });

    test('a server REFUSAL is not a network failure', () {
      // The one that must never be downgraded: the server answered, and
      // what it said is the point.
      expect(
        isTransientNetworkFailure(
          'PostgrestException(message: you already have a reservation in '
          'that period (at most 1 at a time), code: P0001)',
        ),
        isFalse,
      );
    });

    test('a real crash is not a network failure', () {
      expect(
        isTransientNetworkFailure(ArgumentError('Invalid argument(s): 24.0')),
        isFalse,
      );
      expect(isTransientNetworkFailure(null), isFalse);
      expect(isTransientNetworkFailure(StateError('bad state')), isFalse);
    });
  });

  test('error() files a dropped connection as a warning, and keeps it', () {
    final log = TraceLogger.instance;
    log.error('messaging', 'conversations failed',
        error: 'ClientException: Software caused connection abort');
    log.error('booking', 'reserve failed',
        error: 'PostgrestException(message: refused, code: P0001)');

    final entries = log.entries;
    final dropped =
        entries.lastWhere((e) => e.message == 'conversations failed');
    final refused = entries.lastWhere((e) => e.message == 'reserve failed');

    expect(dropped.level, TraceLevel.warn,
        reason: 'the network dropped — not a defect');
    expect(refused.level, TraceLevel.error,
        reason: 'the server answered, and its refusal is a real finding');
    // Downgraded, never discarded.
    expect(dropped.error, contains('connection abort'));
  });

  test('#1153 — the sixth dropped connection in ten minutes is an ERROR', () {
    // One tunnel is a warning. A backend that keeps being unreachable is
    // not a tunnel, and hiding it under Warnings+ would leave the Errors
    // chip green while nothing works.
    final log = TraceLogger.instance;
    for (var i = 0; i < 4; i++) {
      log.error('sync', 'run $i',
          error: 'ClientException: Software caused connection abort');
    }
    TraceEntry by(String m) => log.entries.firstWhere((e) => e.message == m);
    expect(by('run 3').level, TraceLevel.warn,
        reason: 'four in a row is still a bad connection');
    log.error('sync', 'run 5',
        error: 'ClientException: Software caused connection abort');
    expect(by('run 5').level, TraceLevel.error,
        reason: 'the fifth is a pattern, and the pattern is the finding');
    // A real error in between resets the run: it was answered.
    log.error('sync', 'refused', error: 'PostgrestException(message: no)');
    log.error('sync', 'run again',
        error: 'ClientException: Software caused connection abort');
    expect(by('run again').level, TraceLevel.warn);
  });
}
