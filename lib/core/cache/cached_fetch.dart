// SPDX-License-Identifier: 0BSD
import 'dart:async';

import '../trace/trace_logger.dart';
import 'cache_store.dart';

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
Future<T> cachedFetch<T>({
  required CacheStore cache,
  required String key,
  required Duration ttl,
  required CacheReadMode mode,
  required Future<Object?> Function() fetchRaw,
  required T Function(Object? payload) parse,
}) async {
  if (mode == CacheReadMode.cacheFirst) {
    final hit = await cache.get(key);
    if (hit != null && !hit.isExpired) return parse(hit.payload);
  }
  try {
    final raw = await fetchRaw();
    // The write must never delay the answer.
    unawaited(cache.put(key, raw, ttl: ttl));
    return parse(raw);
  } catch (e, st) {
    final stale = await cache.get(key);
    if (stale != null) {
      TraceLogger.instance.warn('cache', 'stale served for $key',
          error: e, stackTrace: st);
      return parse(stale.payload);
    }
    rethrow;
  }
}
