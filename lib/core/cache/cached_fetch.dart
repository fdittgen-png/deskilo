// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import '../trace/trace_logger.dart';
import 'cache_store.dart';
import 'stale_reads.dart';

/// How a read treats the cache (the tankstellen two-tier semantics).
enum CacheReadMode {
  /// A FRESH cache entry is served without touching the network — for
  /// slow-changing data whose local mutations bust the cache (floor
  /// plans, levels). Expired entries fall through to the network, which
  /// falls back to the stale entry when offline.
  cacheFirst,

  /// The network is always primary; the cache only answers when the
  /// network FAILS (offline backbone) — for live data where a stale
  /// answer online would mislead (reservations).
  networkFirst,
}

/// One read through the cache: [fetchRaw] must return a JSON-safe
/// payload (raw rows / row bundles), [parse] turns it into the domain
/// value — parsing always runs with CURRENT code, whatever build wrote
/// the entry.
///
/// [cacheable] (optional) judges a payload before it is persisted:
/// `false` skips the write AND drops any stored entry under [key]. The
/// #572 use: an RLS-empty answer (a pending member reads zero levels)
/// must never be cached, or it outlives the approval that ends it.
Future<T> cachedFetch<T>({
  required CacheStore cache,
  required String key,
  required Duration ttl,
  required CacheReadMode mode,
  required Future<Object?> Function() fetchRaw,
  required T Function(Object? payload) parse,
  bool Function(Object? payload)? cacheable,
}) async {
  // #1557 — every cache action of THIS read is bound to the session it
  // starts in. `fetchRaw` is an await long enough for the person to sign
  // out and somebody else to sign in; the scoped store resolves the
  // principal when it is called, so the late answer would be written,
  // invalidated or read back under whoever is signed in by then. The
  // fence compares the session at write time and drops the operation
  // when it has moved on. The caller still gets its own answer — only
  // the cache is fenced.
  final fenced = fenceRead(cache);
  if (mode == CacheReadMode.cacheFirst) {
    final hit = await fenced.get(key);
    if (hit != null && !hit.isExpired) return parse(hit.payload);
  }
  try {
    final raw = await fetchRaw();
    // The write must never delay the answer.
    if (cacheable == null || cacheable(raw)) {
      unawaited(fenced.put(key, raw, ttl: ttl));
    } else {
      unawaited(fenced.invalidatePrefix(key));
    }
    StaleReads.instance.fresh(key);
    return parse(raw);
  } catch (e, st) {
    final stale = await fenced.get(key);
    if (stale != null) {
      TraceLogger.instance.warn('cache', 'stale served for $key',
          error: e, stackTrace: st);
      // #1305 S3 — a screen showing this can say it is not live.
      StaleReads.instance.served(key, stale.storedAt);
      return parse(stale.payload);
    }
    rethrow;
  }
}
