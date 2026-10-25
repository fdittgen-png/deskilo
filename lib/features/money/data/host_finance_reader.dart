// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C5 — my own documents (C6: and my payments) on one workspace host, asked through THAT
// host's own verified client (the installation the app is signed in to,
// or the connected pool's pinned client for the host's origin), never
// through the personal home's or the selected workspace's. A host that is
// not connected here, or answers as another installation, is refused:
// `my_finance_overview` stays local to each host.
import '../../../core/backend/connected_target.dart';
import '../../../core/backend/context_clients.dart';
import '../domain/account_activity.dart';
import '../domain/finance_hosts.dart';
import '../domain/finance_overview.dart';
import 'supabase_account_activity_repository.dart';

/// The verified host of [host]: the installation the app is signed in to
/// for a host of my personal home, else the [connected] installation whose
/// verified identity is the host's, through the existing resolver
/// ([resolverFor] the connected origin, null for the signed-in one).
Future<ResolvedWorkspaceHost> resolveFinanceHost(
  FinanceHost host, {
  required Future<List<ConnectedInstallation>> Function() connected,
  required WorkspaceHostResolver Function(String? origin) resolverFor,
}) async {
  String? origin;
  if (!host.hostedHere) {
    for (final c in await connected()) {
      if (c.installationId == host.installationId) origin = c.endpoint.url;
    }
    if (origin == null) {
      throw FinanceHostUnavailable(
        '${host.installationId} is not connected here',
      );
    }
  }
  return resolverFor(origin).resolve(host.workspaceIds.first);
}

class HostFinanceReader implements FinanceHostReader {
  const HostFinanceReader({required this.hostOf});

  /// The verified host of a source, with its own client.
  final Future<ResolvedWorkspaceHost> Function(FinanceHost host) hostOf;

  @override
  Future<FinanceOverview> overview(FinanceHost host) async {
    final resolved = await hostOf(host);
    try {
      if (resolved.installationId != host.installationId) {
        throw FinanceHostUnavailable(
          'asked ${host.installationId}, answered ${resolved.installationId}',
        );
      }
      // My invoices and reminders, then my payments, on the same host and
      // its own client: a host answers for all three or not at all.
      final repository = SupabaseAccountActivityRepository(resolved.client);
      final overview = await repository.overview();
      final payments = await repository.list(AccountActivityKind.payments);
      return overview.withPayments(payments);
    } finally {
      resolved.lease?.release();
    }
  }
}
