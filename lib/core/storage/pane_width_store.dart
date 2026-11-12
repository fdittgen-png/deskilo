// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3607 — where a list keeps the width of the record pane beside it, per
// device. The app reads the device's preferences; a test and the Demo hold
// it in memory (device_prefs.dart), so no page that merely shows a list
// needs to know it exists.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_stores.dart';

/// The pane width of each list, by the list's name.
abstract interface class PaneWidthStore {
  Future<String?> read(String list);
  Future<void> write(String list, String? width);
}

/// The device's preferences, one key per list.
class PrefsPaneWidthStore implements PaneWidthStore {
  const PrefsPaneWidthStore();

  PrefsStringStore _of(String list) =>
      PrefsStringStore('list_detail_pane_$list');

  @override
  Future<String?> read(String list) => _of(list).read();

  @override
  Future<void> write(String list, String? width) => _of(list).write(width);
}

/// The store the app's lists keep their pane width in.
final paneWidthStoreProvider = Provider<PaneWidthStore>(
  (ref) => const PrefsPaneWidthStore(),
);
