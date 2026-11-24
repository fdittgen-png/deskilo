// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/backend/auth_secret_store.dart';
import '../domain/till_offline_queue.dart';

/// #4373 -- the offline state of one till, kept in the app's existing secure store (the platform key store; on the web it
/// protects data at rest only). It holds prices, a session number and cash sales -- never card data.
class SecureOfflineStore implements OfflineStore {
  SecureOfflineStore(this._secrets, {required this.workspaceId});

  final AuthSecretStore _secrets;
  final String workspaceId;

  String get _key => 'till.offline.$workspaceId';

  @override
  Future<String?> read() => _secrets.read(_key);

  @override
  Future<void> write(String json) => _secrets.write(_key, json);

  @override
  Future<void> wipe() => _secrets.delete(_key);
}
