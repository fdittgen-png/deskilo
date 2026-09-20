// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1241 step 2 — the retry, and the two things it must NOT do.
import 'dart:io';

import 'package:deskilo/core/data/retry.dart';
import 'package:flutter_test/flutter_test.dart';

const _fast = [Duration(milliseconds: 1), Duration(milliseconds: 1)];

void main() {
  test('a dropped connection is retried, and the second attempt is the '
      'answer the member gets', () async {
    var attempts = 0;
    final result = await retryTransient<String>('book', () async {
      attempts++;
      if (attempts == 1) {
        throw const SocketException('Connection reset by peer');
      }
      return 'booked';
    }, delays: _fast);

    expect(result, 'booked');
    expect(attempts, 2);
  });

  test('a server refusal is NOT retried — a 403 three times is still a '
      '403, and the member waits three times as long to read it', () async {
    var attempts = 0;
    await expectLater(
      retryTransient<void>('book', () async {
        attempts++;
        throw StateError('not an active member');
      }, delays: _fast),
      throwsA(isA<StateError>()),
    );
    expect(attempts, 1, reason: 'exactly one attempt, no backoff, no delay');
  });

  test('it gives up rather than hanging: three attempts, then the '
      'original failure reaches the caller', () async {
    var attempts = 0;
    await expectLater(
      retryTransient<void>('book', () async {
        attempts++;
        throw const SocketException('Failed host lookup');
      }, delays: _fast),
      throwsA(isA<SocketException>()),
    );
    expect(attempts, 3, reason: 'one attempt plus one per delay');
  });

  test('the default budget is about a second and a half — long enough to '
      'cross a wifi roam, short enough that being offline is SAID', () {
    final total = kRetryDelays.fold<int>(0, (a, d) => a + d.inMilliseconds);
    expect(total, lessThan(2000));
    expect(kRetryDelays, isNotEmpty);
  });

  group('the idempotency key', () {
    test('is a version-4 UUID in the shape Postgres will cast', () {
      final id = newRequestId();
      expect(
        id,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        )),
        reason: 'create_reservation_once takes a uuid; a string Postgres '
            'cannot cast fails at the boundary rather than in a test',
      );
    });

    test('is different every time — a NEW booking must not collide with '
        'the last one', () {
      final ids = {for (var i = 0; i < 500; i++) newRequestId()};
      expect(ids, hasLength(500));
    });
  });
}
