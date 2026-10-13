// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cached_fetch.dart';
import '../../../core/data/json_reader.dart';
import '../../../core/settings/settings.dart';

/// #2484 -- the settings registry through its definer functions (0428).
///
/// Reads go through the scoped cache (its keys already name the installation
/// and the signed-in person); the key adds the workspace, and the cached
/// payload is re-parsed with current code on every read. The cache is a
/// copy: a successful read replaces it and a write drops it.
class SupabaseSettingsRepository implements SettingsStore {
  SupabaseSettingsRepository(this._client, this._cache);

  final SupabaseClient _client;
  final CacheStore _cache;

  static const _prefix = 'settings:v1:';
  static const _ttl = Duration(hours: 12);

  @override
  Future<SettingsSet> load(String? workspaceId) => cachedFetch<SettingsSet>(
        cache: _cache,
        key: '$_prefix${workspaceId ?? 'platform'}',
        ttl: _ttl,
        mode: CacheReadMode.networkFirst,
        fetchRaw: () => _client.rpc<Object?>(
          'my_settings',
          params: {'p_workspace': workspaceId},
        ),
        parse: SettingsSet.parse,
      );

  @override
  Future<List<SettingVersion>> history(String? workspaceId, String key) async {
    final raw = await _client.rpc<Object?>(
      'setting_history',
      params: {'p_workspace': workspaceId, 'p_key': key},
    );
    if (raw is! List) {
      throw JsonShapeException('setting_history', '', 'list', '${raw.runtimeType}');
    }
    return [for (final row in raw) SettingVersion.fromJson(row)];
  }

  @override
  Future<void> setValue({
    String? workspaceId,
    required String key,
    required Object value,
    String note = '',
  }) async {
    await _client.rpc<Object?>(
      'set_setting',
      params: {
        'p_workspace': workspaceId,
        'p_key': key,
        'p_value': value,
        'p_note': note,
      },
    );
    await _cache.invalidatePrefix(_prefix);
  }
}
