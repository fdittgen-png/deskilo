// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/prefs_stores.dart';

part 'save_folder_store.g.dart';

/// #3613 — the folder a desktop save dialog last delivered a file to, kept
/// per device: the next dialog starts there. Written only after a delivered
/// save, never after a cancel or a failure. Widget tests and the Demo
/// session swap in the in-memory store.
abstract class SaveFolderStore {
  Future<String?> read();
  Future<void> write(String folder);
}

class _PrefsSaveFolderStore implements SaveFolderStore {
  const _PrefsSaveFolderStore();

  static const _prefs = PrefsStringStore('files.last_save_folder');

  @override
  Future<String?> read() => _prefs.read();

  @override
  Future<void> write(String folder) => _prefs.write(folder);
}

/// Test double and Demo copy. [writes] counts every write.
class InMemorySaveFolderStore implements SaveFolderStore {
  InMemorySaveFolderStore([this.folder]);

  String? folder;
  int writes = 0;

  @override
  Future<String?> read() async => folder;

  @override
  Future<void> write(String folder) async {
    writes++;
    this.folder = folder;
  }
}

@Riverpod(keepAlive: true)
SaveFolderStore saveFolderStore(Ref ref) => const _PrefsSaveFolderStore();
