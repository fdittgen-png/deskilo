// SPDX-License-Identifier: 0BSD
//
// #1124 — one device, two people, one cache directory.
//
// The keys the repositories build name a workspace and a level. They do
// not name the backend and they do not name the user, and `signOut()`
// deletes nothing, so the entries written by whoever signed in first
// answered the reads of whoever signed in second — including reads that
// RLS would have refused, because the cache never asks the server.
//
// These tests are written against the behaviour, not the key format:
// what matters is that B cannot read what A wrote, whatever the prefix
// turns out to look like.
import 'dart:async';

import 'package:deskilo/core/cache/cache_scope.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/cache/cached_fetch.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  const backend = 'https://zwzbynivewivvjmripeb.supabase.co';
  const other = 'https://selfhosted.example.org';

  group('cacheScope', () {
    test('no principal, no scope', () {
      expect(cacheScope(backendUrl: backend, userId: null), isNull);
      expect(cacheScope(backendUrl: backend, userId: ''), isNull);
    });

    test('a different user is a different scope', () {
      expect(
        cacheScope(backendUrl: backend, userId: 'a'),
        isNot(cacheScope(backendUrl: backend, userId: 'b')),
      );
    });

    test('a different backend is a different scope', () {
      expect(
        cacheScope(backendUrl: backend, userId: 'a'),
        isNot(cacheScope(backendUrl: other, userId: 'a')),
      );
    });

    test('the same pair is the same scope across calls', () {
      expect(
        cacheScope(backendUrl: backend, userId: 'a'),
        cacheScope(backendUrl: backend, userId: 'a'),
      );
    });

    test('neither the host nor the user id is legible in the scope', () {
      // A cache file name shows up in a file manager and in a device
      // backup. It does not need to say who the user is.
      final scope = cacheScope(backendUrl: backend, userId: 'marjorie-uuid')!;
      expect(scope, isNot(contains('marjorie')));
      expect(scope, isNot(contains('supabase')));
      expect(scope, isNot(contains('zwzbyn')));
    });
  });

  group('ScopedCacheStore', () {
    test('what A cached, B cannot read', () async {
      final disk = InMemoryCacheStore();
      var user = 'user-a';
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );

      await store.put('levels:w1', [
        {'id': 'l1'},
      ], ttl: const Duration(minutes: 10));
      expect(await store.get('levels:w1'), isNotNull);

      // The sign-out and sign-in of somebody else. Nothing was deleted;
      // only the principal changed.
      user = 'user-b';
      expect(await store.get('levels:w1'), isNull,
          reason: "B must not be served A's rows");

      // And A still has what A cached.
      user = 'user-a';
      expect(await store.get('levels:w1'), isNotNull);
    });

    test('the same user on another instance reads nothing across', () async {
      final disk = InMemoryCacheStore();
      var url = backend;
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: url, userId: 'user-a'),
      );

      await store.put('plan:l1', {'offices': <Object>[]},
          ttl: const Duration(minutes: 10));
      url = other;
      expect(await store.get('plan:l1'), isNull);
    });

    test('signed out, the store neither reads nor writes', () async {
      final disk = InMemoryCacheStore();
      String? user;
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );

      await store.put('levels:w1', [1], ttl: const Duration(minutes: 10));
      expect(await store.get('levels:w1'), isNull);

      // And nothing reached the disk under a bare key either, where the
      // next principal would have found it.
      user = 'user-a';
      expect(await store.get('levels:w1'), isNull);
      expect(await disk.get('levels:w1'), isNull);
    });

    test('invalidatePrefix stays inside the scope', () async {
      final disk = InMemoryCacheStore();
      var user = 'user-a';
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );

      await store.put('plan:l1', {'a': 1}, ttl: const Duration(minutes: 10));
      user = 'user-b';
      await store.put('plan:l1', {'b': 2}, ttl: const Duration(minutes: 10));

      // B busts the plan cache after editing a floor plan.
      await store.invalidatePrefix('plan:');
      expect(await store.get('plan:l1'), isNull);

      user = 'user-a';
      expect(await store.get('plan:l1'), isNotNull,
          reason: "B's mutation must not reach into A's entries");
    });

    test('wipeScope drops this principal and only this principal', () async {
      final disk = InMemoryCacheStore();
      var user = 'user-a';
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );

      await store.put('levels:w1', [1], ttl: const Duration(minutes: 10));
      await store.put('plan:l1', {'a': 1}, ttl: const Duration(minutes: 10));
      user = 'user-b';
      await store.put('levels:w1', [2], ttl: const Duration(minutes: 10));

      user = 'user-a';
      await store.wipeScope();
      expect(await store.get('levels:w1'), isNull);
      expect(await store.get('plan:l1'), isNull);

      user = 'user-b';
      expect(await store.get('levels:w1'), isNotNull,
          reason: "A signing out must not empty B's cache on a shared "
              'device');
    });

    test('after sign-out there is no scope, so the wipe is a no-op', () async {
      // The reason `signOutAndForget` sweeps BEFORE it signs out. If the
      // order is ever swapped, this is what the code would be doing.
      final disk = InMemoryCacheStore();
      String? user = 'user-a';
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );
      await store.put('levels:w1', [1], ttl: const Duration(minutes: 10));

      user = null;
      await store.wipeScope();

      user = 'user-a';
      expect(await store.get('levels:w1'), isNotNull,
          reason: 'a wipe with no principal cannot have wiped anything — '
              'the entry is still there, which is the bug the ordering '
              'in signOutAndForget avoids');
    });
  });

  // #1557 — the account can change WHILE a read is waiting.
  //
  // Everything here is production code: the real `cachedFetch`, the real
  // `ScopedCacheStore`, the real in-memory disk. A fake of any of them
  // would only prove something about the fake.
  //
  // `test/lint/sign_out_test.dart` proves nothing about this: it compares
  // the POSITION of two strings inside sign_out.dart, so it is green
  // whatever the code does at runtime — it stayed green while this bug
  // existed, and it stays green if the fence below is deleted again.
  group('a read that outlives its session', () {
    // A barrier for the write `cachedFetch` deliberately does not await,
    // not a sleep: one turn of the event loop is everything an in-memory
    // write needs, and every assertion below fails loudly if it were not
    // enough.
    Future<void> writeSettled() => Future<void>.delayed(Duration.zero);

    test("A's late answer is not written under B", () async {
      final disk = InMemoryCacheStore();
      String? user = 'user-a';
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );

      final started = Completer<void>();
      final answer = Completer<Object?>();
      final readAsA = cachedFetch<List<Object?>>(
        cache: store,
        key: 'levels:w1',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () {
          started.complete();
          return answer.future;
        },
        parse: (payload) => (payload! as List).cast<Object?>(),
      );
      await started.future;

      // A signs out and B signs in while the server is still thinking —
      // the order signOutAndForget uses.
      CacheSession.instance.invalidate();
      await store.wipeScope();
      user = null;
      user = 'user-b';

      // The server answers A's question, with rows only A may see.
      answer.complete([
        {'id': 'a-only'},
      ]);
      expect(await readAsA, hasLength(1),
          reason: 'the caller still gets the answer it asked for — only '
              'the cache is fenced');
      await writeSettled();

      expect(disk.entries, isEmpty,
          reason: "A's rows reached the disk after the sweep had emptied "
              'it');
      expect(await store.get('levels:w1'), isNull,
          reason: "B must not be served A's rows");

      // And B's own cache-first read still has to ask the server.
      var asked = false;
      final readAsB = await cachedFetch<List<Object?>>(
        cache: store,
        key: 'levels:w1',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.cacheFirst,
        fetchRaw: () async {
          asked = true;
          return <Object?>[];
        },
        parse: (payload) => (payload! as List).cast<Object?>(),
      );
      expect(asked, isTrue,
          reason: 'a contaminated entry would have answered B without a '
              'round trip');
      expect(readAsB, isEmpty);
    });

    test('signing back in as the same person revives nothing', () async {
      final disk = InMemoryCacheStore();
      String? user = 'user-a';
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );

      final started = Completer<void>();
      final answer = Completer<Object?>();
      final readAsA = cachedFetch<List<Object?>>(
        cache: store,
        key: 'levels:w1',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () {
          started.complete();
          return answer.future;
        },
        parse: (payload) => (payload! as List).cast<Object?>(),
      );
      await started.future;

      CacheSession.instance.invalidate();
      await store.wipeScope();
      user = null;
      user = 'user-a';

      answer.complete([
        {'id': 'l1'},
      ]);
      await readAsA;
      await writeSettled();

      expect(disk.entries, isEmpty,
          reason: 'A → signed out → A resolves to the same scope string, '
              'so only the session generation can tell the ended session '
              'from the new one; the sweep asked for an empty cache and '
              'must get one');
    });

    test("an expired read's refusal to cache spares B's entry", () async {
      final disk = InMemoryCacheStore();
      String? user = 'user-a';
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );

      final started = Completer<void>();
      final answer = Completer<Object?>();
      final readAsA = cachedFetch<List<Object?>>(
        cache: store,
        key: 'levels:w1',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () {
          started.complete();
          return answer.future;
        },
        parse: (payload) => (payload! as List).cast<Object?>(),
        // The #572 rule: an RLS-empty answer is never cached, and drops
        // whatever is stored under the key.
        cacheable: (payload) => (payload! as List).isNotEmpty,
      );
      await started.future;

      CacheSession.instance.invalidate();
      await store.wipeScope();
      user = 'user-b';
      await store.put('levels:w1', [
        {'id': 'b-only'},
      ], ttl: const Duration(minutes: 10));

      answer.complete(<Object?>[]);
      await readAsA;
      await writeSettled();

      expect(await store.get('levels:w1'), isNotNull,
          reason: "a read that belonged to A must not delete B's entry "
              'through the cacheable == false path');
    });

    test("a failed read of A's is not answered out of B's cache", () async {
      final disk = InMemoryCacheStore();
      String? user = 'user-a';
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: user),
      );

      final started = Completer<void>();
      final answer = Completer<Object?>();
      final readAsA = cachedFetch<List<Object?>>(
        cache: store,
        key: 'levels:w1',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () {
          started.complete();
          return answer.future;
        },
        parse: (payload) => (payload! as List).cast<Object?>(),
      );
      await started.future;

      CacheSession.instance.invalidate();
      await store.wipeScope();
      user = 'user-b';
      await store.put('levels:w1', [
        {'id': 'b-only'},
      ], ttl: const Duration(minutes: 10));

      answer.completeError(StateError('offline'));
      await expectLater(readAsA, throwsA(isA<StateError>()),
          reason: "B's entry is not A's offline fallback: the read fails, "
              "which is the truth — A's session is over");
    });

    test('the ordinary same-session read still caches', () async {
      final disk = InMemoryCacheStore();
      final store = ScopedCacheStore(
        disk,
        () => cacheScope(backendUrl: backend, userId: 'user-a'),
      );

      await cachedFetch<List<Object?>>(
        cache: store,
        key: 'levels:w1',
        ttl: const Duration(minutes: 10),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () async => [
          {'id': 'l1'},
        ],
        parse: (payload) => (payload! as List).cast<Object?>(),
      );
      await writeSettled();

      expect(await store.get('levels:w1'), isNotNull,
          reason: 'the fence may only drop writes whose session ENDED');
    });
  });
}
