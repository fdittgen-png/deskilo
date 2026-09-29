// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — the narrow management/confirmation client registry. One client
// per verified installation + issuer + local account + purpose; the app's
// own backend switch stays the explicit flow it is. A lease records the
// generation a request started under: a switch, a sign-out or a revoke
// bumps it, and the late answer is discarded rather than published.
import '../../../core/trace/trace_logger.dart';
import '../domain/mcp_client.dart';
import '../domain/mcp_context.dart';

typedef McpTargetClientFactory = McpTargetClient Function(
  McpTargetKey key,
  VerifiedMcpTarget target,
);

/// The generation a request started under.
class McpLease {
  const McpLease._(this.key, this.generation);
  final McpTargetKey key;
  final int generation;
}

enum McpDisposeOutcome { disposed, failed }

class McpClientRegistry {
  McpClientRegistry(this._create);

  final McpTargetClientFactory _create;
  final _targets = <(String, String), VerifiedMcpTarget>{};
  final _clients = <McpTargetKey, McpTargetClient>{};
  final _generations = <McpTargetKey, int>{};
  bool _closed = false;

  /// Records a target the server verified for this account. The same
  /// installation and account under another issuer or origin retires the
  /// old clients first: they were created for a different authority.
  Future<Map<McpTargetKey, McpDisposeOutcome>> register(
    VerifiedMcpTarget target,
  ) async {
    if (_closed) throw const McpContextSuperseded();
    final slot = (target.installationId, target.account);
    final previous = _targets[slot];
    if (previous == target) return const {};
    // The old keys go stale synchronously (the body of _retire runs up to
    // its first await), before the new target is visible.
    final retired = previous == null
        ? null
        : _retire(
            (k) =>
                k.installationId == previous.installationId &&
                k.account == previous.account,
          );
    _targets[slot] = target;
    return retired == null ? const {} : await retired;
  }

  VerifiedMcpTarget? targetOf(McpScope scope) =>
      _targets[(scope.installationId, scope.account)];

  /// The client key for [scope]; a scope with no verified target is
  /// refused before anything is sent.
  McpTargetKey keyFor(McpScope scope, McpClientPurpose purpose) {
    final target = targetOf(scope);
    if (_closed || target == null) {
      throw McpTargetUnverified(scope.installationId);
    }
    return target.key(purpose);
  }

  McpTargetClient resolve(McpTargetKey key) {
    final target = _targets[(key.installationId, key.account)];
    if (_closed || target == null || target.issuer != key.issuer) {
      throw McpTargetUnverified(key.installationId);
    }
    return _clients.putIfAbsent(key, () => _create(key, target));
  }

  McpLease lease(McpTargetKey key) =>
      McpLease._(key, _generations.putIfAbsent(key, () => 0));

  bool isCurrent(McpLease lease) =>
      !_closed &&
      _generations[lease.key] == lease.generation &&
      _targets[(lease.key.installationId, lease.key.account)]?.issuer ==
          lease.key.issuer;

  void ensureCurrent(McpLease lease) {
    if (!isCurrent(lease)) throw const McpContextSuperseded();
  }

  /// Every client key this registry created or leased.
  Set<McpTargetKey> get keys => {..._clients.keys};

  /// Full target revoke: every purpose and account of [installationId]
  /// goes; no other installation's client is touched.
  Future<Map<McpTargetKey, McpDisposeOutcome>> revokeTarget(
    String installationId,
  ) {
    _targets.removeWhere((slot, _) => slot.$1 == installationId);
    return _retire((k) => k.installationId == installationId);
  }

  /// Sign-out or account change: every target, with one outcome each —
  /// never an all-or-nothing claim.
  Future<Map<McpTargetKey, McpDisposeOutcome>> disposeAll() {
    _targets.clear();
    return _retire((_) => true);
  }

  Future<Map<McpTargetKey, McpDisposeOutcome>> close() {
    _closed = true;
    return disposeAll();
  }

  // Generations move synchronously, before any disposal is awaited: a
  // lease taken before this call is stale from this line on.
  Future<Map<McpTargetKey, McpDisposeOutcome>> _retire(
    bool Function(McpTargetKey) which,
  ) async {
    for (final k in _generations.keys.where(which).toList()) {
      _generations[k] = _generations[k]! + 1;
    }
    final gone = [
      for (final e in _clients.entries.where((e) => which(e.key)).toList())
        e.value,
    ];
    for (final client in gone) {
      _clients.remove(client.key);
    }
    final outcomes = <McpTargetKey, McpDisposeOutcome>{};
    for (final client in gone) {
      try {
        await client.dispose();
        outcomes[client.key] = McpDisposeOutcome.disposed;
      } catch (e, st) {
        // trace-exempt: the error itself may quote a session; only that a
        // disposal failed is traced, and the outcome map reports it.
        TraceLogger.instance.warn(
          'mcp',
          'target client not disposed: ${e.runtimeType}',
          stackTrace: st,
        );
        outcomes[client.key] = McpDisposeOutcome.failed;
      }
    }
    return outcomes;
  }
}
