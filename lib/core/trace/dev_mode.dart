// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../storage/prefs_stores.dart';

part 'dev_mode.g.dart';

/// Persists the local developer-mode toggle (#144). Same seam shape as
/// `ActiveWorkspaceStore` so widget tests never touch platform channels.
abstract class DevModeStore {
  Future<bool> read();
  Future<void> write(bool enabled);
}

class PrefsDevModeStore extends PrefsBoolStore implements DevModeStore {
  const PrefsDevModeStore() : super('developer_mode');
}

@Riverpod(keepAlive: true)
DevModeStore devModeStore(Ref ref) => const PrefsDevModeStore();

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
