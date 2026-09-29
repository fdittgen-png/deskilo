// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — every management read and mutation goes through its captured
// scope's own client. A mutation is an immutable intent: its scope,
// payload and id are fixed when it is made, so a retry after a transient
// failure — or after the person switched to another workspace or server —
// is the SAME request to the SAME target, never a request built from the
// current selection. A second submit of an intent already in flight joins
// it instead of sending twice.
import '../../../core/ids/request_id.dart';
import '../domain/mcp_client.dart';
import '../domain/mcp_context.dart';
import 'mcp_client_registry.dart';

/// One intent: where it goes, what it is, and its one id for every retry.
class McpMutation<P> {
  McpMutation({
    required this.scope,
    required this.operation,
    required this.payload,
    this.purpose = McpClientPurpose.management,
    String? mutationId,
  }) : mutationId = mutationId ?? newRequestId();

  final McpScope scope;
  final String operation;
  final P payload;
  final McpClientPurpose purpose;
  final String mutationId;
}

class McpCommands {
  McpCommands(this._registry);

  final McpClientRegistry _registry;
  final _inflight = <(McpTargetKey, String), Future<Object?>>{};

  McpClientRegistry get registry => _registry;

  /// A read for [scope]. Its answer is discarded (typed
  /// [McpContextSuperseded]) if the scope was switched, signed out of or
  /// revoked while it was out.
  Future<R> read<R>(
    McpScope scope,
    Future<R> Function(McpRepositories repositories) query, {
    McpClientPurpose purpose = McpClientPurpose.management,
  }) => _send(_registry.keyFor(scope, purpose), query);

  /// Sends [mutation] (again). The same intent in flight is joined.
  Future<R> execute<R>(
    McpMutation<Object?> mutation,
    Future<R> Function(McpRepositories repositories, McpMutation<Object?> m)
    send,
  ) {
    final key = _registry.keyFor(mutation.scope, mutation.purpose);
    final slot = (key, mutation.mutationId);
    final running = _inflight[slot];
    if (running != null) return running.then((r) => r as R);
    final future = _send(key, (repositories) => send(repositories, mutation));
    _inflight[slot] = future;
    // trace-exempt: the caller receives the failure; this only releases
    // the slot so a later retry is sent.
    future.whenComplete(() => _inflight.remove(slot)).ignore();
    return future;
  }

  Future<R> _send<R>(
    McpTargetKey key,
    Future<R> Function(McpRepositories repositories) action,
  ) async {
    final lease = _registry.lease(key);
    final client = _registry.resolve(key);
    final answer = await client.run(action);
    _registry.ensureCurrent(lease);
    return answer;
  }
}
