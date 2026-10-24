// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2c -- the enrolled workspace hosts and the host a creation runs
// on. The list is read on the personal home; the chosen host's pinned
// client is held only for the session that chose it.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/session/session_source.dart';
import '../application/create_on_host.dart';
import '../data/supabase_workspace_host_repository.dart';
import '../domain/workspace_host.dart';

export '../application/create_on_host.dart' show CreationHostLease;

part 'workspace_host_providers.g.dart';

@Riverpod(keepAlive: true)
WorkspaceHostRepository workspaceHostRepository(Ref ref) =>
    SupabaseWorkspaceHostRepository(ref.watch(personalClientProvider));

/// The hosts offered when the person creates a space. A failed read says
/// so (no retries stacked behind a spinner, #2339).
@Riverpod(retry: noWorkspaceHostRetry)
Future<WorkspaceHosts> workspaceHosts(Ref ref) =>
    ref.watch(workspaceHostRepositoryProvider).fetchHosts();

Duration? noWorkspaceHostRetry(int retryCount, Object error) => null;

/// The host the next creation runs on; none means this server. A choice
/// belongs to the session that made it, and its pinned client is given
/// back when it is replaced, cleared or the session changes.
@Riverpod(keepAlive: true)
class CreationHost extends _$CreationHost {
  /// The lease held, kept beside the state: a life-cycle may not read it.
  CreationHostLease? _held;

  @override
  CreationHostLease? build() {
    ref.watch(sessionStateProvider);
    ref.onDispose(() {
      _held?.pin.release();
      _held = null;
    });
    return null;
  }

  /// Whether a host is held now; read where a life-cycle may not read state.
  bool get held => _held != null;

  void use(CreationHostLease lease) {
    final previous = _held;
    _held = lease;
    state = lease;
    if (previous != null && previous.pin != lease.pin) previous.pin.release();
  }

  void clear() {
    _held?.pin.release();
    _held = null;
    state = null;
  }

  /// Clears [lease] when it is still the one held: a screen that leaves
  /// never drops a newer choice.
  void drop(CreationHostLease lease) {
    if (!ref.mounted || _held != lease) return;
    clear();
  }
}

/// Checks a chosen host again and, when it may be used, makes it the
/// creation's.
@riverpod
CreateOnHost createOnHost(Ref ref) => CreateOnHost(
      ref.watch(workspaceHostRepositoryProvider),
      ref.watch(connectedInstallationsProvider),
      ref.read(creationHostProvider.notifier).use,
    );
