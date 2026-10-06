// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#1849 B): a cache write that finishes late never resurrects what
// a newer write or an invalidation superseded, and a temporary file is only
// ever removed when it is an orphan. Each test orders the writers by gates
// and polls the directory (untilReal), never by a fixed delay.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/core/cache/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/real_async.dart';

int _tmpCount(Directory d) =>
    d.listSync().where((f) => f.path.endsWith('.tmp')).length;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cache_barrier'));
  tearDown(() => dir.deleteSync(recursive: true));

  const ttl = Duration(minutes: 10);

  test(
    'an older writer finishing last never overwrites the newer value',
    () async {
      final gates = <Completer<void>>[Completer(), Completer()];
      var reached = 0;
      // Gate by the ORDER the writers arrive at the publish boundary, and
      // start the second writer only once the first is parked there: which
      // writer reaches it first is then no race.
      final store = FileCacheStore(
        directory: dir,
        beforePublish: (_) => gates[reached++].future,
      );
      final a = store.put('k', 'A', ttl: ttl);
      await untilReal(() => reached == 1, what: 'the first writer parked');
      final b = store.put('k', 'B', ttl: ttl);
      await untilReal(() => reached == 2, what: 'the second writer parked');
      gates[1].complete(); // B publishes first
      await b;
      gates[0].complete(); // A tries to publish afterwards
      await a;
      expect((await store.get('k'))!.payload, 'B');
      expect(dir.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
    },
  );

  test('an invalidation after the temp write stops the publish', () async {
    final gate = Completer<void>();
    final store = FileCacheStore(
      directory: dir,
      beforePublish: (_) => gate.future,
    );
    final w = store.put('acct:1:k', 'old', ttl: ttl);
    await untilReal(() => _tmpCount(dir) == 1, what: 'the temp write');
    await store.invalidatePrefix('acct:1:');
    gate.complete();
    await w;
    expect(await store.get('acct:1:k'), isNull);
    expect(dir.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
  });

  test(
    'eviction leaves a fresh temp file alone and removes an old orphan',
    () async {
      final store = FileCacheStore(directory: dir);
      await store.put('seed', 1, ttl: ttl);
      final fresh = File('${dir.path}/x.1.tmp')..writeAsStringSync('{');
      final orphan = File('${dir.path}/y.2.tmp')..writeAsStringSync('{');
      orphan.setLastModifiedSync(DateTime.utc(2020));
      await store.evictExpired();
      expect(fresh.existsSync(), isTrue);
      expect(orphan.existsSync(), isFalse);
    },
  );
}
