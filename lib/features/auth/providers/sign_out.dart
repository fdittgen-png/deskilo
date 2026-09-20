// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/trace/trace_logger.dart';
import 'auth_providers.dart';

/// Sign out, and take this principal's cache with it (#1124).
///
/// `AuthRepository.signOut` ends the session and nothing else. The disk
/// cache outlives it: the entries are files, named after the backend and
/// the user, and they would sit there until the TTL × 3 eviction sweep
/// reached them — readable again the moment the same person signs back
/// in, and taking up room on the device in the meantime.
///
/// The ORDER is the point. The scope is resolved from the CURRENT user,
/// so the wipe has to happen while there still is one; afterwards
/// `cacheScope` answers null and this would be a no-op that reads like a
/// success.
///
/// A failed wipe must not trap somebody in a session they asked to
/// leave: ending the session is the security action and clearing the
/// cache is the housekeeping, so the sweep is attempted, traced if it
/// fails, and the sign-out happens either way. The confidentiality half
/// does not depend on it — a scoped key cannot be read by the next
/// principal whether or not the file was deleted.
///
/// Every sign-out in the app goes through here, and
/// `test/lint/sign_out_test.dart` is what keeps it that way.
/// #1557 — the sweep deletes the files that exist NOW, and a read that
/// started before it can still be waiting on the server. Ending the
/// session generation first is what stops that answer from writing
/// itself back afterwards: wiping harder cannot, because the entry it
/// would create does not exist yet. It runs before the sweep, and the
/// sweep before the sign-out, for the same reason in two steps — each
/// fences what the next one can no longer reach.
Future<void> signOutAndForget(WidgetRef ref) async {
  CacheSession.instance.invalidate();
  final cache = ref.read(cacheStoreProvider);
  if (cache is ScopedCacheStore) {
    try {
      await cache.wipeScope();
    } catch (e, st) {
      TraceLogger.instance
          .warn('cache', 'sign-out sweep failed', error: e, stackTrace: st);
    }
  }
  await ref.read(authRepositoryProvider).signOut();
}
