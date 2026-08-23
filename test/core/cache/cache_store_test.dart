// SPDX-License-Identifier: 0BSD
//
// The tankstellen-style cache (field request): TTL envelopes, two-tier
// retrieval (fresh primary / stale offline fallback), schema stamping,
// prefix busting on mutations, and 3×TTL eviction.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/cache/cached_fetch.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryCacheStore semantics (the shared contract)', () {
    test('roundtrip, expiry, prefix busting, eviction', () async {
      final cache = InMemoryCacheStore();
      await cache.put('plan:l1', {'a': 1}, ttl: const Duration(minutes: 10));
      await cache.put('levels:w1', [1, 2], ttl: const Duration(minutes: 10));

      final hit = await cache.get('plan:l1');
      expect(hit, isNotNull);
      expect(hit!.isExpired, isFalse);
      expect((hit.payload as Map)['a'], 1);

      await cache.invalidatePrefix('plan:');
      expect(await cache.get('plan:l1'), isNull);
      expect(await cache.get('levels:w1'), isNotNull);
    });
  });

  group('cachedFetch', () {
    test('cacheFirst serves a fresh entry without touching the network',
        () async {
      final cache = InMemoryCacheStore();
      await cache.put('k', {'rows': 1}, ttl: const Duration(minutes: 10));
      var networkCalls = 0;

      final value = await cachedFetch<int>(
        cache: cache,
        key: 'k',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.cacheFirst,
        fetchRaw: () async {
          networkCalls++;
          return {'rows': 2};
        },
        parse: (payload) => (payload as Map)['rows'] as int,
      );

      expect(value, 1);
      expect(networkCalls, 0);
    });

    test('cacheFirst falls through to the network once expired and '
        'refreshes the entry', () async {
      final cache = InMemoryCacheStore();
      cache.entries['k'] = CacheEntry(
        payload: const {'rows': 1},
        storedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ttl: const Duration(minutes: 10),
      );

      final value = await cachedFetch<int>(
        cache: cache,
        key: 'k',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.cacheFirst,
        fetchRaw: () async => {'rows': 2},
        parse: (payload) => (payload as Map)['rows'] as int,
      );

      expect(value, 2);
      // Wait a microtask: the write is deliberately not awaited.
      await Future<void>.delayed(Duration.zero);
      expect(((await cache.get('k'))!.payload as Map)['rows'], 2);
    });

    test('networkFirst ignores a fresh cache online, serves it as the '
        'STALE fallback when the network fails', () async {
      final cache = InMemoryCacheStore();
      await cache.put('k', {'rows': 1}, ttl: const Duration(minutes: 10));

      final online = await cachedFetch<int>(
        cache: cache,
        key: 'k',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () async => {'rows': 2},
        parse: (payload) => (payload as Map)['rows'] as int,
      );
      expect(online, 2);

      final offline = await cachedFetch<int>(
        cache: cache,
        key: 'k',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () async => throw const SocketException('offline'),
        parse: (payload) => (payload as Map)['rows'] as int,
      );
      expect(offline, 2);
    });

    test('no cache + network failure rethrows', () async {
      await expectLater(
        cachedFetch<int>(
          cache: InMemoryCacheStore(),
          key: 'k',
          ttl: const Duration(minutes: 10),
          mode: CacheReadMode.networkFirst,
          fetchRaw: () async => throw const SocketException('offline'),
          parse: (payload) => 0,
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('FileCacheStore', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('deskilo-cache'));
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('a schema-version mismatch reads as a miss (tankstellen #3219 '
        'lesson: never feed old-shaped rows to new parsers)', () async {
      final store = _seeded(temp);
      await store.put('x', {'rows': 1}, ttl: const Duration(minutes: 10));
      // Rewrite the REAL entry file with an older schema version.
      final file = temp.listSync().whereType<File>().single;
      final raw = jsonDecode(file.readAsStringSync()) as Map;
      raw['v'] = cacheSchemaVersion - 1;
      file.writeAsStringSync(jsonEncode(raw));

      expect(await store.get('x'), isNull);
      // The mismatched entry is dropped, not kept around.
      expect(temp.listSync().whereType<File>(), isEmpty);
    });

    test('corrupt entries are deleted and read as a miss', () async {
      final store = _seeded(temp);
      await store.put('k', {'a': 1}, ttl: const Duration(minutes: 5));
      // Corrupt the file on disk.
      final file = temp.listSync().whereType<File>().single;
      file.writeAsStringSync('{not json');
      expect(await store.get('k'), isNull);
      expect(temp.listSync().whereType<File>(), isEmpty);
    });

    test('roundtrip + evictExpired drops >3×TTL entries', () async {
      final store = _seeded(temp);
      await store.put('fresh', {'a': 1}, ttl: const Duration(hours: 1));
      // Hand-write an ancient entry.
      File('${temp.path}/old.json').writeAsStringSync(jsonEncode({
        'v': cacheSchemaVersion,
        'storedAt': DateTime.now()
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
        'ttlMs': 60000,
        'payload': {},
      }));

      expect(await store.evictExpired(), 1);
      expect(((await store.get('fresh'))!.payload as Map)['a'], 1);
    });
  });

  group('cacheable judgement (#572)', () {
    test(
        'a payload judged not cacheable is served but NEVER persisted, '
        'and it evicts what was stored under the key', () async {
      // The invitation bug: a pending member's RLS-empty level list was
      // disk-cached and outlived the approval that ended it.
      final cache = InMemoryCacheStore();
      await cache.put('levels:w1', <Object?>[],
          ttl: const Duration(minutes: 10));

      final value = await cachedFetch<List<Object?>>(
        cache: cache,
        key: 'levels:w1',
        ttl: const Duration(minutes: 10),
        // networkFirst so the poisoned entry does not answer the read.
        mode: CacheReadMode.networkFirst,
        fetchRaw: () async => <Object?>[],
        cacheable: (payload) => payload is List && payload.isNotEmpty,
        parse: (payload) => payload as List<Object?>,
      );
      expect(value, isEmpty);
      // Both the new write AND the old entry are gone.
      await Future<void>.delayed(Duration.zero);
      expect(await cache.get('levels:w1'), isNull);

      // A non-empty answer caches normally again.
      await cachedFetch<List<Object?>>(
        cache: cache,
        key: 'levels:w1',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () async => <Object?>[1],
        cacheable: (payload) => payload is List && payload.isNotEmpty,
        parse: (payload) => payload as List<Object?>,
      );
      await Future<void>.delayed(Duration.zero);
      expect(await cache.get('levels:w1'), isNotNull);
    });
  });

  group('unavailable cache dir (#614)', () {
    test('degrades to misses and warns at most once', () async {
      // No pinned directory + no path_provider in the test VM: the
      // resolution fails on first use and must stay failed quietly.
      final store = FileCacheStore();
      final warningsBefore = TraceLogger.instance.entries
          .where((e) => e.message == 'cache dir unavailable')
          .length;
      expect(await store.get('k'), isNull);
      await store.put('k', 'v', ttl: const Duration(minutes: 5));
      expect(await store.get('k'), isNull);
      expect(await store.evictExpired(), 0);
      final warningsAfter = TraceLogger.instance.entries
          .where((e) => e.message == 'cache dir unavailable')
          .length;
      expect(warningsAfter - warningsBefore, lessThanOrEqualTo(1),
          reason: 'unavailable is a state, diagnosed once — not per call');
    });
  });
}

/// A [FileCacheStore] whose directory resolution is pinned to [dir].
FileCacheStore _seeded(Directory dir) => FileCacheStore(directory: dir);
