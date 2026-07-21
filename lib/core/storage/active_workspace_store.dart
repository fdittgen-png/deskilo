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
