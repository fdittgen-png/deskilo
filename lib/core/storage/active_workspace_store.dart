// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'prefs_stores.dart';


part 'active_workspace_store.g.dart';

/// Persists which workspace (profile) is active across restarts (#89).
abstract class ActiveWorkspaceStore {
  Future<String?> read();
  Future<void> write(String? workspaceId);
}

class PrefsActiveWorkspaceStore extends PrefsStringStore implements ActiveWorkspaceStore {
  const PrefsActiveWorkspaceStore() : super('active_workspace_id');
}

@Riverpod(keepAlive: true)
ActiveWorkspaceStore activeWorkspaceStore(Ref ref) =>
    const PrefsActiveWorkspaceStore();

/// Persists the user-chosen DEFAULT profile (#322): the workspace the
/// app opens on at every start, regardless of what was active last.
/// Null = no default — the last active profile wins (the #89 behavior).
abstract class DefaultWorkspaceStore {
  Future<String?> read();
  Future<void> write(String? workspaceId);
}

class PrefsDefaultWorkspaceStore extends PrefsStringStore implements DefaultWorkspaceStore {
  const PrefsDefaultWorkspaceStore() : super('default_workspace_id');
}

@Riverpod(keepAlive: true)
DefaultWorkspaceStore defaultWorkspaceStore(Ref ref) =>
    const PrefsDefaultWorkspaceStore();
