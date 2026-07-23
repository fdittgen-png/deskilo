// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'active_workspace_store.g.dart';

/// Persists which workspace (profile) is active across restarts (#89).
abstract class ActiveWorkspaceStore {
  Future<String?> read();
  Future<void> write(String? workspaceId);
}

class PrefsActiveWorkspaceStore implements ActiveWorkspaceStore {
  static const _key = 'active_workspace_id';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String? workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    if (workspaceId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, workspaceId);
    }
  }
}

@Riverpod(keepAlive: true)
ActiveWorkspaceStore activeWorkspaceStore(Ref ref) =>
    PrefsActiveWorkspaceStore();

/// Persists the user-chosen DEFAULT profile (#322): the workspace the
/// app opens on at every start, regardless of what was active last.
/// Null = no default — the last active profile wins (the #89 behavior).
abstract class DefaultWorkspaceStore {
  Future<String?> read();
  Future<void> write(String? workspaceId);
}

class PrefsDefaultWorkspaceStore implements DefaultWorkspaceStore {
  static const _key = 'default_workspace_id';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String? workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    if (workspaceId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, workspaceId);
    }
  }
}

@Riverpod(keepAlive: true)
DefaultWorkspaceStore defaultWorkspaceStore(Ref ref) =>
    PrefsDefaultWorkspaceStore();
