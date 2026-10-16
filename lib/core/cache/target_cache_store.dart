// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- a cache view for ONE workspace target. Two installations may
// hold the same local workspace id; a repository reading through this view
// can never be answered with the other target's rows, nor bust its keys.
import 'cache_store.dart';

class TargetCacheStore implements CacheStore {
  TargetCacheStore(this._inner, String namespace) : _prefix = 'tgt$namespace:';

  final CacheStore _inner;
  final String _prefix;

  @override
  Future<CacheEntry?> get(String key) => _inner.get('$_prefix$key');

  @override
  Future<void> put(String key, Object? payload, {required Duration ttl}) =>
      _inner.put('$_prefix$key', payload, ttl: ttl);

  @override
  Future<void> invalidatePrefix(String prefix) =>
      _inner.invalidatePrefix('$_prefix$prefix');

  @override
  Future<int> evictExpired() => _inner.evictExpired();
}
