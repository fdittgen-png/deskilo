// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo messenger's blocked accounts (0387), apart from the repository so
// it keeps to its length budget.
import '../../../features/directory/domain/messenger.dart';

mixin DemoAccountBlocks {
  /// The accounts the person blocked (0387).
  final blocked = <String, String>{};

  /// The repository's own availability check, before every call.
  void checkAvailable();

  Future<List<BlockedAccount>> myBlocks() async {
    checkAvailable();
    return [
      for (final e in blocked.entries)
        BlockedAccount(userId: e.key, name: e.value),
    ];
  }

  Future<void> blockAccount(String user) async {
    checkAvailable();
    blocked.putIfAbsent(user, () => user);
  }

  Future<void> unblockAccount(String user) async {
    checkAvailable();
    blocked.remove(user);
  }
}
