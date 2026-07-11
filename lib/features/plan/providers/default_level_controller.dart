// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../workspace/providers/workspace_providers.dart';
import 'floor_plan_providers.dart';

part 'default_level_controller.g.dart';

/// Persists each member's preferred floor level per workspace (#159).
/// Same seam shape as `LocaleStore` so widget tests never touch
/// platform channels.
abstract class DefaultLevelStore {
  /// The stored level id for [workspaceId], or null when never chosen.
  Future<String?> read(String workspaceId);

  /// Persists [levelId] as the default for [workspaceId].
  Future<void> write(String workspaceId, String levelId);
}

class PrefsDefaultLevelStore implements DefaultLevelStore {
  static String _key(String workspaceId) => 'default_level_$workspaceId';

  @override
  Future<String?> read(String workspaceId) async =>
      (await SharedPreferences.getInstance()).getString(_key(workspaceId));

  @override
  Future<void> write(String workspaceId, String levelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(workspaceId), levelId);
  }
}

@Riverpod(keepAlive: true)
DefaultLevelStore defaultLevelStore(Ref ref) => PrefsDefaultLevelStore();

/// The level shown on the Plan tab (#159): initially the stored default
/// of the active workspace when that level still exists, else the first
/// level (sort order). Selecting a level applies instantly and persists
/// it as the member's default for this workspace.
@Riverpod(keepAlive: true)
class SelectedLevelId extends _$SelectedLevelId {
  @override
  Future<String?> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    if (workspace == null) return null;
    final levels = await ref.watch(levelsProvider.future);
    final stored =
        await ref.watch(defaultLevelStoreProvider).read(workspace.id);
    if (levels.any((l) => l.id == stored)) return stored;
    return levels.firstOrNull?.id;
  }

  Future<void> select(String levelId) async {
    state = AsyncData(levelId);
    final workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null) return;
    await ref.read(defaultLevelStoreProvider).write(workspace.id, levelId);
  }

  /// Shows [levelId] WITHOUT writing the store (#182): the calendar's
  /// "Show on plan" jump is a one-off navigation — it must not silently
  /// overwrite the default level the member chose deliberately via
  /// [select]. The transient choice lasts until the next [select] or
  /// until this notifier rebuilds (e.g. workspace switch).
  void showTransient(String levelId) {
    state = AsyncData(levelId);
  }
}
