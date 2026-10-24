// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2c -- creating a workspace on a host the person chose.
//
// The choice is checked again at the moment it is used: the enrolments are
// read FRESH on the personal home (a host revoked or closed since the list
// was shown is refused with its reason), the device's connection to the
// host must be to the enrolled installation, and only then is the host's
// own client pinned for the creation. The existing onboarding then runs on
// that client (C1b's adopted session); nothing is ever created on another
// server in its place.
import '../../../core/backend/connected_installations.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/workspace_host.dart';

/// The host a creation runs on: its enrolment, its address in the pool and
/// the pinned client of that connection.
class CreationHostLease {
  const CreationHostLease(this.host, this.source, this.pin);
  final WorkspaceHost host;
  final String source;
  final PinnedClient pin;
}

class CreateOnHost {
  const CreateOnHost(this._hosts, this._pool, this._use);

  final WorkspaceHostRepository _hosts;
  final ConnectedInstallations _pool;

  /// Makes [CreationHostLease] the host of the next creation.
  final void Function(CreationHostLease lease) _use;

  /// Whether [installationId] may be created on now; when it may, its
  /// pinned client becomes the creation's. A connection that needs a
  /// sign-in again answers [HostNeedsConnection]; one whose installation
  /// changed is [HostRefusal.unverified]. A transient failure is thrown as
  /// the pool's typed [ConnectionFailure] and changes nothing.
  Future<HostReadiness> prepare(String installationId) async {
    final fresh = await _hosts.fetchHosts();
    final connections = [
      for (final c in await _pool.list())
        (source: c.endpoint.url, installationId: c.installationId),
    ];
    final readiness = decideHost(fresh, installationId, connections);
    if (readiness is! HostReady) return readiness;
    final PinnedClient pin;
    try {
      pin = await _pool.pin(readiness.source);
    } on ConnectionFailure catch (failure, st) {
      TraceLogger.instance.warn('workspace', 'creation host not pinned',
          error: failure.reason, stackTrace: st);
      return switch (failure.reason) {
        ConnectionFailureReason.expired ||
        ConnectionFailureReason.denied ||
        ConnectionFailureReason.notConnected =>
          HostNeedsConnection(readiness.host),
        ConnectionFailureReason.changedIdentity =>
          const HostRefused(HostRefusal.unverified),
        _ => throw failure,
      };
    }
    if (pin.installationId != installationId) {
      pin.release();
      return const HostRefused(HostRefusal.unverified);
    }
    _use(CreationHostLease(readiness.host, readiness.source, pin));
    return readiness;
  }
}
