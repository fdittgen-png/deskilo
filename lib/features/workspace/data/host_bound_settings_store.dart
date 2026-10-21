// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/settings/settings.dart';
import 'supabase_settings_repository.dart';

/// Runs [use] with the client that serves [workspaceId] (null: the platform's
/// own view) and gives it back when [use] is done.
typedef SettingsClientScope =
    Future<T> Function<T>(
      String? workspaceId,
      Future<T> Function(SupabaseClient client) use,
    );

/// #2564 -- the settings registry on the host the workspace lives on.
///
/// The client is asked for at each call and handed back afterwards: the host
/// of a connected workspace is a pinned lease that ends with its connection,
/// so a store that kept the client would outlive it, and one that asked for
/// it through the workspace context would depend on the very context that
/// captures these settings.
class HostBoundSettingsStore implements SettingsStore {
  HostBoundSettingsStore(this._scope, this._cache);

  final SettingsClientScope _scope;
  final CacheStore _cache;

  @override
  Future<SettingsSet> load(String? workspaceId) => _scope(
    workspaceId,
    (client) => SupabaseSettingsRepository(client, _cache).load(workspaceId),
  );

  @override
  Future<List<SettingVersion>> history(String? workspaceId, String key) =>
      _scope(
        workspaceId,
        (client) => SupabaseSettingsRepository(
          client,
          _cache,
        ).history(workspaceId, key),
      );

  @override
  Future<void> setValue({
    String? workspaceId,
    required String key,
    required Object value,
    String note = '',
  }) => _scope(
    workspaceId,
    (client) => SupabaseSettingsRepository(client, _cache).setValue(
      workspaceId: workspaceId,
      key: key,
      value: value,
      note: note,
    ),
  );
}
