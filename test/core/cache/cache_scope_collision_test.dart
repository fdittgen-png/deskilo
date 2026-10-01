// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2008 — private cached rows never alias another principal. The two
// UUID-shaped ids below share one 32-bit FNV hash (and their length), so
// under the old scope they shared a namespace on the same backend: B
// would be served A's rows. The scope is now a domain-separated SHA-256;
// the file store names files the same on every run and checks the exact
// key it was given; legacy entries are dropped, never migrated.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/cache/cache_scope.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _backend = 'https://abc.supabase.co';
const _a = 'cf44606d-3dc9-33eb-ae1c-5ee0d34d5847';
const _b = 'c8df1976-2d31-f9da-a937-c6ddb934ef9b';

/// The retired scope, kept here as the red fixture's oracle.
String _fnv(String value) {
  var h = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    h = (h ^ unit) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cache2008'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the fixture pair collided under the retired scope', () {
    expect(_fnv(_a), _fnv(_b));
    expect(_a.length, _b.length);
  });

  test('the pair gets two different scopes now', () {
    expect(
      cacheScope(backendUrl: _backend, userId: _a),
      isNot(cacheScope(backendUrl: _backend, userId: _b)),
    );
  });

  test('a fixed vector: the scope is stable across runs and SDKs', () {
    expect(cacheScope(backendUrl: _backend, userId: _a), startsWith('s2'));
    expect(cacheScope(backendUrl: _backend, userId: _a)!.length, 2 + 32 + 1);
    expect(
      FileCacheStore.fileNameFor('levels:ws-1'),
      'levels_ws-1-${cacheDigest('cache-file-v2', ['levels:ws-1'], 16)}.json',
    );
    // Length-prefixed parts: moving a separator never aliases.
    expect(
      cacheDigest('d', ['ab', 'c'], 64),
      isNot(cacheDigest('d', ['a', 'bc'], 64)),
    );
  });

  test('A warms the real file store; B, same backend and key, misses; A '
      'still reads its own', () async {
    final files = FileCacheStore(directory: dir);
    final asA = ScopedCacheStore(
      files,
      () => cacheScope(backendUrl: _backend, userId: _a),
    );
    final asB = ScopedCacheStore(
      files,
      () => cacheScope(backendUrl: _backend, userId: _b),
    );
    await asA.put('reservations:ws-1', {
      'canary': 'A-private',
    }, ttl: const Duration(hours: 1));

    expect(await asB.get('reservations:ws-1'), isNull);
    expect((await asA.get('reservations:ws-1'))!.payload, {
      'canary': 'A-private',
    });
  });

  test('reopened with a new store instance, the entry is found', () async {
    await FileCacheStore(directory: dir)
        .put('plan:l1', {'rows': 1}, ttl: const Duration(hours: 1));
    expect((await FileCacheStore(directory: dir).get('plan:l1'))!.payload, {
      'rows': 1,
    });
  });

  test('a file whose envelope names another key is a miss', () async {
    final store = FileCacheStore(directory: dir);
    File('${dir.path}/${FileCacheStore.fileNameFor('plan:l1')}')
        .writeAsStringSync(
          jsonEncode({
            'v': cacheSchemaVersion,
            'k': 'plan:someone-else',
            'storedAt': 0, // freshness plays no part here
            'ttlMs': 3600000,
            'payload': {'canary': 'other'},
          }),
        );
    expect(await store.get('plan:l1'), isNull);
  });

  test('legacy and malformed entries miss and are dropped', () async {
    final store = FileCacheStore(directory: dir);
    final legacy = File('${dir.path}/${FileCacheStore.fileNameFor('plan:l1')}')
      ..writeAsStringSync(
        jsonEncode({
          'v': 1,
          'storedAt': 0, // freshness plays no part here
          'ttlMs': 3600000,
          'payload': {'canary': 'legacy'},
        }),
      );
    expect(await store.get('plan:l1'), isNull);
    expect(legacy.existsSync(), isFalse);

    // An old-named v1 file is never read again; eviction removes it.
    final orphan = File('${dir.path}/plan_l1-1234abcd.json')
      ..writeAsStringSync(
        jsonEncode({
          'v': 1,
          'storedAt': 0, // freshness plays no part here
          'ttlMs': 3600000,
          'payload': <String, Object?>{},
        }),
      );
    File('${dir.path}/broken.json').writeAsStringSync('{not json');
    expect(await store.evictExpired(), greaterThanOrEqualTo(1));
    expect(orphan.existsSync(), isFalse);
  });

  test('signed out: no scope, nothing read or written', () async {
    expect(cacheScope(backendUrl: _backend, userId: null), isNull);
    final scoped = ScopedCacheStore(
      FileCacheStore(directory: dir),
      () => cacheScope(backendUrl: _backend, userId: null),
    );
    await scoped.put('plan:l1', {'x': 1}, ttl: const Duration(hours: 1));
    expect(dir.listSync(), isEmpty);
  });
}
