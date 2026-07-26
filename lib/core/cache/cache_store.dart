// SPDX-License-Identifier: 0BSD
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../trace/trace_logger.dart';

part 'cache_store.g.dart';

/// Entries written under a different schema version are misses: cached
/// payloads are RAW server rows, so a build that changed a row parser's
/// expectations must re-fetch instead of feeding old-shaped rows to new
/// code (the tankstellen #3219 lesson, keyed on a manual version rather
/// than the app build since rows — unlike parsed output — only break on
/// deliberate shape changes). Bump when a cached row shape changes.
const int cacheSchemaVersion = 1;

/// One cached payload with its freshness envelope (the tankstellen
/// `CacheManager` shape): [isExpired] gates the fresh tier, the entry
/// itself stays retrievable as the STALE tier — the caller decides
/// whether stale is acceptable (offline fallback).
class CacheEntry {
  const CacheEntry({
    required this.payload,
    required this.storedAt,
    required this.ttl,
  });

  /// JSON-safe raw data (server rows / row bundles — never parsed
  /// domain objects).
  final Object? payload;
  final DateTime storedAt;
  final Duration ttl;

  Duration get age => DateTime.now().difference(storedAt);
  bool get isExpired => age > ttl;
}

/// The cache seam (ported from tankstellen's `CacheStrategy`): repos
/// read/write through this, widget tests inject an in-memory fake.
abstract class CacheStore {
  /// The entry regardless of age — null only when never cached (or
  /// unreadable). Staleness is the CALLER's decision.
  Future<CacheEntry?> get(String key);

  Future<void> put(String key, Object? payload, {required Duration ttl});

  /// Drops every entry whose key starts with [prefix] — the mutation
  /// hook: a write to the floor plan busts `plan:`/`levels:` so the
  /// next read is network-fresh.
  Future<void> invalidatePrefix(String prefix);

  /// Deletes entries older than 3× their TTL (the tankstellen eviction
  /// rule); returns how many were dropped. Runs after boot.
  Future<int> evictExpired();
}

/// File-per-key JSON cache under the app-support directory. Every IO
/// failure degrades to a cache miss / no-op — the cache may never break
/// a fetch it exists to accelerate.
class FileCacheStore implements CacheStore {
  /// [directory] pins the cache dir (tests); production resolves the
  /// app-support directory lazily.
  FileCacheStore({Directory? directory}) : _dir = directory;

  Directory? _dir;

  Future<Directory?> _cacheDir() async {
    if (_dir != null) return _dir;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/cache');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return _dir = dir;
    } catch (e, st) {
      TraceLogger.instance.warn('cache', 'cache dir unavailable',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Human-readable slug + hash suffix: collision-safe and greppable on
  /// a device.
  static String _fileName(String key) {
    final slug = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
    final hash = key.hashCode.toUnsigned(32).toRadixString(16);
    return '$slug-$hash.json';
  }

  @override
  Future<CacheEntry?> get(String key) async {
    final dir = await _cacheDir();
    if (dir == null) return null;
    final file = File('${dir.path}/${_fileName(key)}');
    try {
      if (!file.existsSync()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map || raw['v'] != cacheSchemaVersion) {
        await file.delete();
        return null;
      }
      return CacheEntry(
        payload: raw['payload'],
        storedAt:
            DateTime.fromMillisecondsSinceEpoch(raw['storedAt'] as int? ?? 0),
        ttl: Duration(milliseconds: raw['ttlMs'] as int? ?? 0),
      );
    } catch (e, st) {
      // Corrupt entries are deleted and read as a miss.
      TraceLogger.instance
          .warn('cache', 'unreadable entry $key', error: e, stackTrace: st);
      try {
        await file.delete();
      } catch (_, _) {
        // trace-exempt: best-effort cleanup of an already-broken file.
      }
      return null;
    }
  }

  @override
  Future<void> put(String key, Object? payload,
      {required Duration ttl}) async {
    final dir = await _cacheDir();
    if (dir == null) return;
    try {
      final tmp = File('${dir.path}/${_fileName(key)}.tmp');
      await tmp.writeAsString(jsonEncode({
        'v': cacheSchemaVersion,
        'storedAt': DateTime.now().millisecondsSinceEpoch,
        'ttlMs': ttl.inMilliseconds,
        'payload': payload,
      }));
      // Atomic swap: a killed app never leaves a half-written entry.
      await tmp.rename('${dir.path}/${_fileName(key)}');
    } catch (e, st) {
      TraceLogger.instance
          .warn('cache', 'write failed for $key', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> invalidatePrefix(String prefix) async {
    final dir = await _cacheDir();
    if (dir == null) return;
    final filePrefix =
        prefix.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
    try {
      for (final file in dir.listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (name.startsWith(filePrefix)) await file.delete();
      }
    } catch (e, st) {
      TraceLogger.instance.warn('cache', 'invalidate $prefix failed',
          error: e, stackTrace: st);
    }
  }

  @override
  Future<int> evictExpired() async {
    final dir = await _cacheDir();
    if (dir == null) return 0;
    var evicted = 0;
    try {
      for (final file in dir.listSync().whereType<File>()) {
        try {
          final raw = jsonDecode(await file.readAsString());
          if (raw is! Map) {
            await file.delete();
            evicted++;
            continue;
          }
          final storedAt = DateTime.fromMillisecondsSinceEpoch(
              raw['storedAt'] as int? ?? 0);
          final ttl = Duration(milliseconds: raw['ttlMs'] as int? ?? 0);
          if (DateTime.now().difference(storedAt) > ttl * 3) {
            await file.delete();
            evicted++;
          }
        } catch (_, _) {
          // trace-exempt: unreadable files are exactly what eviction
          // exists to clear.
          await file.delete();
          evicted++;
        }
      }
    } catch (e, st) {
      TraceLogger.instance
          .warn('cache', 'eviction sweep failed', error: e, stackTrace: st);
    }
    return evicted;
  }
}

@Riverpod(keepAlive: true)
CacheStore cacheStore(Ref ref) => FileCacheStore();
