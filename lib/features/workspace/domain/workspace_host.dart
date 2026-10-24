// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2c -- where a new workspace is created: on a host the person
// CHOOSES among the workspace installations their personal home's operator
// enrolled (`my_workspace_hosts_v1`), never on whichever server answered.
//
// Pure: the reading of the home's answer and the one decision of whether a
// chosen host may be used now, from a FRESH read of the enrolments and the
// connections this device holds. A host that is no longer enrolled is
// revoked; one closed to new workspaces is not accepting; one this home
// cannot verify a person on, or whose connection here names another
// installation, is unverified. Each refusal is typed, and none of them
// falls back to another server.

import '../../../core/data/json_reader.dart';

/// What the personal home says about one enrolled host.
enum WorkspaceHostState {
  /// It accepts new workspaces and the person can be verified there.
  available,

  /// Its operator closed it to new workspaces.
  notAccepting,

  /// Nobody can be verified there under this home's identity.
  unverified,
}

/// One enrolled workspace installation, as the personal home lists it.
class WorkspaceHost {
  const WorkspaceHost({
    required this.installationId,
    required this.origin,
    required this.publishableKey,
    required this.state,
  });

  final String installationId;

  /// The HTTPS origin, without a path.
  final String origin;

  /// The publishable key; the home never hands out any other.
  final String publishableKey;
  final WorkspaceHostState state;

  /// The host name shown to the person.
  String get host => Uri.parse(origin).host;
}

/// The hosts a person may create a workspace on.
class WorkspaceHosts {
  const WorkspaceHosts({required this.hereHosts, required this.hosts});

  /// No enrolled host; this server hosts workspaces itself.
  static const localOnly = WorkspaceHosts(hereHosts: true, hosts: []);

  /// Whether the installation the app is signed in to hosts workspaces.
  final bool hereHosts;
  final List<WorkspaceHost> hosts;

  /// The home's answer; a malformed one is refused (a [JsonShapeException]
  /// or a [FormatException]), never a shorter list.
  static WorkspaceHosts parse(Object? json) {
    final r = JsonReader.of(json, context: _rpc);
    if (r.raw('here_hosts') is! bool || r.raw('hosts') is! List) {
      throw const FormatException('$_rpc: not a host list');
    }
    return WorkspaceHosts(
      hereHosts: r.isTrue('here_hosts'),
      hosts: r.objects('hosts', _host),
    );
  }

  static const _rpc = 'my_workspace_hosts_v1';

  static WorkspaceHost _host(JsonReader h) {
    final origin = h.string('origin');
    final key = h.string('publishable_key');
    final id = h.string('installation_id');
    final state = switch (h.string('state')) {
      'available' => WorkspaceHostState.available,
      'not_accepting' => WorkspaceHostState.notAccepting,
      'unverified' => WorkspaceHostState.unverified,
      _ => throw const FormatException('$_rpc: unknown host state'),
    };
    final uri = Uri.tryParse(origin);
    if (id.isEmpty || key.isEmpty || uri == null || uri.scheme != 'https' ||
        uri.host.isEmpty || uri.origin != origin) {
      throw const FormatException('$_rpc: host fields');
    }
    return WorkspaceHost(
      installationId: id,
      origin: origin,
      publishableKey: key,
      state: state,
    );
  }

  WorkspaceHost? byId(String installationId) =>
      hosts.where((h) => h.installationId == installationId).firstOrNull;
}

/// Why a chosen host is refused.
enum HostRefusal {
  /// The enrolment ended (or never was): it is not listed any more.
  revoked,

  /// Its operator closed it to new workspaces.
  notAccepting,

  /// The person cannot be verified there, or the connection this device
  /// holds for its address is another installation.
  unverified,
}

/// Whether a chosen host may be used now.
sealed class HostReadiness {
  const HostReadiness();
}

/// The host is enrolled, accepting and verified: create through [source].
class HostReady extends HostReadiness {
  const HostReady(this.host, this.source);
  final WorkspaceHost host;

  /// The connection's address in the pool.
  final String source;
}

/// The person has no connection to the host yet: sign in there with their
/// identity first (C1b's adoption), then choose again.
class HostNeedsConnection extends HostReadiness {
  const HostNeedsConnection(this.host);
  final WorkspaceHost host;
}

class HostRefused extends HostReadiness {
  const HostRefused(this.reason);
  final HostRefusal reason;
}

/// One connection this device holds: its address and the installation it
/// was verified to be.
typedef HostConnection = ({String source, String installationId});

/// Decides [installationId] against a [fresh] read of the enrolments and
/// the [connections] held.
HostReadiness decideHost(
  WorkspaceHosts fresh,
  String installationId,
  List<HostConnection> connections,
) {
  final host = fresh.byId(installationId);
  if (host == null) return const HostRefused(HostRefusal.revoked);
  switch (host.state) {
    case WorkspaceHostState.notAccepting:
      return const HostRefused(HostRefusal.notAccepting);
    case WorkspaceHostState.unverified:
      return const HostRefused(HostRefusal.unverified);
    case WorkspaceHostState.available:
      break;
  }
  String originOf(String url) => Uri.tryParse(url)?.origin ?? '';
  final atOrigin =
      connections.where((c) => originOf(c.source) == host.origin).firstOrNull;
  final elsewhere = connections.any((c) =>
      c.installationId == host.installationId &&
      originOf(c.source) != host.origin);
  if (elsewhere ||
      (atOrigin != null && atOrigin.installationId != host.installationId)) {
    return const HostRefused(HostRefusal.unverified);
  }
  return atOrigin == null ? HostNeedsConnection(host) : HostReady(host, atOrigin.source);
}

/// Reads the hosts on the personal home.
abstract interface class WorkspaceHostRepository {
  Future<WorkspaceHosts> fetchHosts();
}

/// Demo and a server without enrolments: this server only.
class LocalOnlyWorkspaceHostRepository implements WorkspaceHostRepository {
  const LocalOnlyWorkspaceHostRepository();

  @override
  Future<WorkspaceHosts> fetchHosts() async => WorkspaceHosts.localOnly;
}
