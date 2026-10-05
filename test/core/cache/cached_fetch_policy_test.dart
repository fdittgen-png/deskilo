// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1849 — what a failed or malformed read may be answered with.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/core/cache/cached_fetch.dart';
import 'package:deskilo/core/cache/read_failure.dart';
import 'package:deskilo/core/cache/stale_reads.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';

Future<int> _read(
  InMemoryCacheStore cache,
  Future<Object?> Function() fetch, {
  CacheReadMode mode = CacheReadMode.networkFirst,
}) =>
    cachedFetch<int>(
      cache: cache,
      key: 'resv:k',
      ttl: const Duration(minutes: 5),
      mode: mode,
      fetchRaw: fetch,
      parse: (p) => (p! as Map)['rows'] as int,
    );

Future<InMemoryCacheStore> _warm() async {
  final cache = InMemoryCacheStore();
  await cache.put('resv:k', {'rows': 1}, ttl: const Duration(minutes: 5));
  return cache;
}

void main() {
  test('the classifier: outage is transient, refusal is denied, the rest '
      'is surfaced', () {
    expect(classifyReadFailure(const SocketException('x')), ReadFailure.transient);
    expect(classifyReadFailure(TimeoutException('x')), ReadFailure.transient);
    expect(
      classifyReadFailure(const PostgrestException(message: 'm', code: '503')),
      ReadFailure.transient,
    );
    expect(
      classifyReadFailure(const PostgrestException(message: 'm', code: '42501')),
      ReadFailure.denied,
    );
    expect(
      classifyReadFailure(const PostgrestException(message: 'm', code: 'PGRST301')),
      ReadFailure.denied,
    );
    expect(
      classifyReadFailure(const AuthException('expired', statusCode: '401')),
      ReadFailure.denied,
    );
    expect(classifyReadFailure(StateError('x')), ReadFailure.other);
    expect(
      classifyReadFailure(const PostgrestException(message: 'm', code: '22P02')),
      ReadFailure.other,
    );
  });

  test('a denial is not offline: the protected entry is not shown and is '
      'dropped', () async {
    final cache = await _warm();
    await expectLater(
      _read(cache, () async => throw const PostgrestException(message: 'denied', code: '42501')),
      throwsA(isA<PostgrestException>()),
    );
    expect(await cache.get('resv:k'), isNull);
  });

  test('an unclassified failure does not grant stale access, and keeps the '
      'entry', () async {
    final cache = await _warm();
    await expectLater(
      _read(cache, () async => throw StateError('boom')),
      throwsStateError,
    );
    expect(await cache.get('resv:k'), isNotNull);
  });

  test('HTTP 200 with invalid data: reported as invalid, the good cache '
      'survives, nothing is marked fresh', () async {
    final cache = await _warm();
    StaleReads.instance.served('resv:k', DateTime.utc(2026));
    await expectLater(
      _read(cache, () async => {'wrong': true}),
      throwsA(isA<CachedReadInvalid>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(((await cache.get('resv:k'))!.payload as Map)['rows'], 1);
    // not marked fresh: the earlier stale mark is untouched
    expect(StaleReads.instance.oldestSavedAt(['resv:']), isNotNull);
    StaleReads.instance.fresh('resv:k');
  });

  test('a transient outage still answers from a valid cache, labelled stale',
      () async {
    final cache = await _warm();
    final v = await _read(cache, () async => throw const SocketException('off'));
    expect(v, 1);
    expect(StaleReads.instance.oldestSavedAt(['resv:']), isNotNull);
    StaleReads.instance.fresh('resv:k');
  });

  test('an unreadable stale entry is dropped and the outage is reported',
      () async {
    final cache = InMemoryCacheStore();
    await cache.put('resv:k', {'old': 'shape'}, ttl: const Duration(minutes: 5));
    await expectLater(
      _read(cache, () async => throw const SocketException('off')),
      throwsA(isA<SocketException>()),
    );
    expect(await cache.get('resv:k'), isNull);
  });

  test('cacheFirst: an unreadable fresh entry falls through to the network',
      () async {
    final cache = InMemoryCacheStore();
    await cache.put('resv:k', {'old': 'shape'}, ttl: const Duration(minutes: 5));
    final v = await _read(cache, () async => {'rows': 9},
        mode: CacheReadMode.cacheFirst);
    expect(v, 9);
  });
}
