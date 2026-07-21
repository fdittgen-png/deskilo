// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'dev_mode.g.dart';

/// Persists the local developer-mode toggle (#144). Same seam shape as
/// `ActiveWorkspaceStore` so widget tests never touch platform channels.
abstract class DevModeStore {
  Future<bool> read();
  Future<void> write(bool enabled);
}

class PrefsDevModeStore implements DevModeStore {
  static const _key = 'developer_mode';

  @override
  Future<bool> read() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> write(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_key, enabled);
}

@Riverpod(keepAlive: true)
DevModeStore devModeStore(Ref ref) => PrefsDevModeStore();

/// Whether developer mode is on. Local diagnostics only — visible to every
/// user, default off, never synced to the backend.
@Riverpod(keepAlive: true)
class DevMode extends _$DevMode {
  @override
  Future<bool> build() => ref.watch(devModeStoreProvider).read();

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    await ref.read(devModeStoreProvider).write(enabled);
  }
}
