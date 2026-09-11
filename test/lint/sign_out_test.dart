// SPDX-License-Identifier: 0BSD
//
// #1124 — a sign-out that does not drop the cache leaves the last
// principal's rows on the disk for the next one.
//
// `AuthRepository.signOut()` ends the Supabase session. It knows nothing
// about the file cache, so the entries survive it, and the entries are
// raw server rows: levels, the floor plan, and a fifteen-minute window of
// reservations carrying member names. `signOutAndForget` wipes the
// scope first and signs out second — first, because the scope is
// resolved from the CURRENT user and there is no scope once the session
// is gone.
//
// The order cannot be checked by reading the source, but WHO calls
// `signOut` can be, and that is the half that rots: the app has five
// sign-out buttons today, on five screens, and the sixth is written by
// somebody who greps for the fifth.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The only two files allowed to name `signOut` directly: the repository
/// that implements it and its interface. Everything else goes through
/// `signOutAndForget`.
const _allowed = {
  'lib/features/auth/data/supabase_auth_repository.dart',
  'lib/features/auth/domain/auth_repository.dart',
  'lib/features/auth/providers/sign_out.dart',
};

void main() {
  test('every sign-out goes through signOutAndForget', () {
    final offenders = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final path = file.path;
      if (_allowed.contains(path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        if (line.contains('.signOut()')) {
          offenders.add('$path:${i + 1}: $line');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Call signOutAndForget(ref) instead — it drops this '
          "principal's cache before the session ends (#1124). Found:\n"
          '${offenders.join('\n')}',
    );
  });

  test('signOutAndForget wipes before it signs out', () {
    final source =
        File('lib/features/auth/providers/sign_out.dart').readAsStringSync();
    final wipe = source.indexOf('wipeScope()');
    final out = source.indexOf('.signOut()');
    expect(wipe, greaterThan(-1), reason: 'the sweep is gone');
    expect(out, greaterThan(-1), reason: 'the sign-out is gone');
    expect(
      wipe,
      lessThan(out),
      reason: 'the sweep must run while there is still a principal to '
          'resolve the cache scope from; afterwards it is a no-op that '
          'reads like a success (#1124)',
    );
  });

  test('no repository builds a cache key by hand', () {
    // The scoping is a decorator so that a call site CANNOT forget it.
    // A repository that constructs a `FileCacheStore` of its own would
    // walk straight around that.
    final offenders = scanLines(
      handWrittenDartFiles('lib'),
      (line) => line.contains('FileCacheStore('),
    ).where((v) => !v.startsWith('lib/core/cache/')).toList();
    expect(offenders, isEmpty,
        reason: 'read the cache through cacheStoreProvider, which hands '
            'out the SCOPED store (#1124):\n${offenders.join('\n')}');
  });
}
