// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The active workspace choice, split out of workspace_providers.dart (#2562:
// a connected installation's workspace is selected session-only).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../../../core/storage/active_workspace_store.dart';
import '../../../core/trace/trace_logger.dart';
import 'workspace_providers.dart';

part 'active_workspace_providers.g.dart';

/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins (#322; server-first since #458, so a fresh install
/// lands on it); in-session switches last until the next start. The
/// device's memory is per account (#1823). Null: no space chosen yet.
@Riverpod(keepAlive: true)
class ActiveWorkspaceId extends _$ActiveWorkspaceId {
  @override
  Future<String?> build() async {
    final (account, store) = (ref.watch(currentAccountIdProvider), ref.watch(activeWorkspaceStoreProvider));
    final defaultId = await ref.watch(defaultWorkspaceIdProvider.future);
    if (defaultId != null || account == null) return defaultId;
    return store.read(account);
  }

  /// An explicit join/create result selects this session without changing
  /// the saved account default or scheduling a late cross-context write.
  void activate(String workspaceId) {
    // #2562 -- a workspace of this installation is never read through a
    // connected installation just because a past selection named one.
    ref.read(selectedWorkspaceHostProvider.notifier).clear();
    state = AsyncData(workspaceId);
  }

  /// #2562 -- the session-only selection of a workspace that lives on the
  /// connected installation [source]: no saved default, no root-side write
  /// (the root server does not know this workspace).
  void activateConnected(String workspaceId, String source) {
    state = AsyncData(workspaceId);
    ref.read(selectedWorkspaceHostProvider.notifier).select(workspaceId, source);
  }

  Future<void> select(String workspaceId) async {
    ref.read(selectedWorkspaceHostProvider.notifier).clear();
    if (ref.read(currentAccountIdProvider) case final account?) await ref.read(activeWorkspaceStoreProvider).write(account, workspaceId);
    state = AsyncData(workspaceId);
    // #996 — a switch is the new default: the next start lands where
    // the user left, on the same side of the pair. Offline, the active
    // store already moved; the default follows at the next switch.
    try {
      await ref.read(defaultWorkspaceIdProvider.notifier).set(workspaceId);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
          'workspace', 'default-workspace write failed — active kept',
          error: e, stackTrace: st);
    }
  }
}
