// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/help_hint_store.dart';

part 'help_hint_providers.g.dart';

/// The set of dismissed hint ids (#606), loaded from disk once and kept
/// in sync eagerly on every change — the notification-filter idiom.
/// Unknown ids in the stored set are tolerated by design: a hint that no
/// longer exists simply never asks to be shown.
@Riverpod(keepAlive: true)
class DismissedHelpHints extends _$DismissedHelpHints {
  @override
  Future<Set<String>> build() =>
      ref.watch(helpHintStoreProvider).readDismissed();

  Future<void> dismiss(String id) async {
    final next = {...state.value ?? const <String>{}, id};
    state = AsyncData(next);
    await ref.read(helpHintStoreProvider).writeDismissed(next);
  }

  /// Settings → "Show help hints again": every hint returns.
  Future<void> restoreAll() async {
    state = const AsyncData(<String>{});
    await ref.read(helpHintStoreProvider).writeDismissed(const {});
  }
}
