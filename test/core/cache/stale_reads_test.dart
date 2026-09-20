// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1305 S3 — a read answered from the stale tier is remembered until the
// network answers again, so a screen can tell live data from saved data.
import 'package:deskilo/core/cache/cached_fetch.dart';
import 'package:deskilo/core/cache/stale_reads.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  tearDown(StaleReads.instance.reset);

  test('the oldest stale answer of a family is reported, others ignored', () {
    final reads = StaleReads();
    final early = DateTime.utc(2026, 9, 17, 8);
    final late = DateTime.utc(2026, 9, 17, 9);
    reads.served('resv:ws:a', late);
    reads.served('resv:ws:b', early);
    reads.served('plan:level', DateTime.utc(2026, 9, 1));
    expect(reads.oldestSavedAt(['resv:']), early);
    expect(reads.oldestSavedAt(['nothing:']), isNull);
  });

  test('one success clears its whole family, not other families', () {
    final reads = StaleReads();
    var notified = 0;
    reads.addListener(() => notified++);
    reads.served('resv:ws:a', DateTime.utc(2026));
    reads.served('resv:ws:b', DateTime.utc(2026));
    reads.served('plan:level', DateTime.utc(2026));
    reads.fresh('resv:ws:c');
    expect(reads.oldestSavedAt(['resv:']), isNull);
    expect(reads.oldestSavedAt(['plan:']), isNotNull);
    expect(notified, 4);
    reads.fresh('resv:ws:c');
    expect(notified, 4, reason: 'nothing changed, nobody is told');
  });

  test('cachedFetch marks a stale fallback and clears it on success',
      () async {
    final cache = InMemoryCacheStore();
    await cache.put('resv:ws:day', 7, ttl: const Duration(minutes: 1));
    final saved = (await cache.get('resv:ws:day'))!.storedAt;

    final offline = await cachedFetch<int>(
      cache: cache,
      key: 'resv:ws:day',
      ttl: const Duration(minutes: 1),
      mode: CacheReadMode.networkFirst,
      fetchRaw: () async => throw StateError('offline'),
      parse: (p) => p! as int,
    );
    expect(offline, 7);
    expect(StaleReads.instance.oldestSavedAt(['resv:']), saved);

    final online = await cachedFetch<int>(
      cache: cache,
      key: 'resv:ws:day',
      ttl: const Duration(minutes: 1),
      mode: CacheReadMode.networkFirst,
      fetchRaw: () async => 8,
      parse: (p) => p! as int,
    );
    expect(online, 8);
    expect(StaleReads.instance.oldestSavedAt(['resv:']), isNull);
  });
}
