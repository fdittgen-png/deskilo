// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C5 — Me › Finances reads every workspace host my personal account
// names (#2563), grouped by installation exactly as My reservations reads
// them (#2553 C2). Composed here, where both features are: money sits
// below me in the feature graph.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/backend/connected_installation_providers.dart';
import '../core/backend/connected_pool_host_resolver.dart';
import '../core/backend/context_client_providers.dart';
import '../core/backend/context_clients.dart';
import '../core/session/session_source.dart';
import '../features/me/application/my_reservation_sources.dart';
import '../features/me/providers/me_providers.dart';
import '../features/money/application/finance_selection_commands.dart';
import '../features/money/data/host_finance_reader.dart';
import '../features/money/data/supabase_member_account_commands.dart';
import '../features/money/data/supabase_payment_gateway_repository.dart';
import '../features/money/domain/finance_hosts.dart';
import '../features/money/providers/finance_host_providers.dart';
import '../features/money/providers/finance_selection_provider.dart';
import '../features/money/providers/invoice_group_providers.dart';
import '../features/workspace/data/supabase_workspace_repository.dart';
import '../features/workspace/domain/member.dart';
import '../features/workspace/providers/workspace_providers.dart';

/// Puts the hosts in a scope's overrides (main.dart, the demo container).
final Override financeHostsFromMe = financeHostsProvider.overrideWith((
  ref,
) async {
  final refs = await ref.watch(personalWorkspaceRefsProvider.future);
  return [
    for (final source in myReservationSourcesOf(refs))
      FinanceHost(
        installationId: source.installationId,
        workspaceIds: source.workspaceIds,
        hostedHere: source.hostedHere,
        labels: source.labels,
      ),
  ];
});

/// #3556 (part 2) — my personal home's installation, which a group's
/// reference names for an invoice the home answered.
final Override financeHomeFromMe = financeHomeInstallationProvider.overrideWith(
  (ref) async {
    final home =
        (await ref.watch(personalWorkspaceRefsProvider.future)).homeInstallationId;
    return home.isEmpty ? null : home;
  },
);

/// Commands capture the displayed installation, never the selected one.
final Override financeWorkspaceEntryFromApp = financeWorkspaceEntryProvider
    .overrideWith((ref) {
      final principal = ref.watch(sessionStateProvider).value;
      final root = ref.watch(personalClientProvider);
      final identity = ref.watch(installationIdReaderProvider);
      final pool = ref.watch(connectedInstallationsProvider);
      return (target) async {
        if (!ref.mounted || principal == null || ref.read(sessionStateProvider).value != principal) return null;
        final home = await identity(root);
        final host = await resolveFinanceHost(
          FinanceHost(installationId: target.installationId,
            workspaceIds: [target.workspaceId], hostedHere: home == target.installationId),
          connected: () => ref.read(connectedSourcesProvider.future),
          resolverFor: (origin) => ConnectedPoolHostResolver(
            active: ActiveInstallationHostResolver(root, identity), root: root,
            pool: () => pool, sourceOf: (_) => origin),
        );
        var retained = false;
        try {
          bool current() => ref.mounted &&
              ref.read(sessionStateProvider).value == principal &&
              host.installationId == target.installationId &&
              host.client.auth.currentUser?.id == host.localUserId &&
              (host.lease?.isLive ?? true);
          if (!current()) return null;
          final repository = SupabaseWorkspaceRepository(host.client);
          final workspaces = await repository.fetchMyWorkspaces();
          final workspace = workspaces.where((w) => w.id == target.workspaceId).singleOrNull;
          final member = await repository.fetchMyMember(target.workspaceId);
          if (!current() || workspace == null || member == null || member.status != MemberStatus.active) return null;
          retained = true;
          return FinanceCommandTarget(target: target, memberId: member.id,
            currency: workspace.currencyCode,
            commands: SupabaseMemberAccountCommands(host.client),
            gateway: SupabasePaymentGatewayRepository(host.client),
            isCurrent: current, release: () => host.lease?.release(),
            open: () async {
              if (!current()) return false;
              final active = ref.read(activeWorkspaceIdProvider.notifier);
              final origin = host.lease?.source;
              if (origin == null) {
                await active.select(target.workspaceId);
              } else {
                active.activateConnected(target.workspaceId, origin);
              }
              return current() && ref.read(activeWorkspaceIdProvider).value == target.workspaceId &&
                  ref.read(selectedWorkspaceHostProvider)?.source == origin;
            });
        } finally {
          if (!retained) host.lease?.release();
        }
      };
    });
