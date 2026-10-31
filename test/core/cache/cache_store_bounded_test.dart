// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 (PERF-9) — the file cache remembered the sequence of every key it
// ever wrote, for the life of the process, so a key that changed on every
// read (upcoming bookings keyed by "now") grew two maps without end. The
// bookkeeping exists only to order writers of one key that overlap; once
// no writer of a key is in flight, nothing is remembered for it.
import 'dart:io';

import 'package:deskilo/core/cache/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('100 written keys leave no bookkeeping behind', () async {
    final dir = Directory.systemTemp.createTempSync('cache_bounded_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cache = FileCacheStore(directory: dir);
    for (var i = 0; i < 100; i++) {
      await cache.put('resv:ws-a:$i', [i], ttl: const Duration(minutes: 15));
    }
    expect(cache.trackedWrites, 0);
    // And what was written is still there to read.
    expect(await cache.get('resv:ws-a:99'), isNotNull);
  });
}
