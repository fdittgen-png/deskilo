// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2569 — the premises lease.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/lease_commands.dart';
import '../data/supabase_premises_lease_repository.dart';
import '../domain/premises_lease.dart';
import 'credit_providers.dart';

final premisesLeaseRepositoryProvider = Provider<PremisesLeaseRepository>(
  (ref) => SupabasePremisesLeaseRepository(ref.watch(moneyClientProvider)),
);

/// Saving a lease, adding a term, giving notice.
final leaseCommandProvider = Provider<LeaseCommands>(
  (ref) => LeaseCommands(ref.watch(premisesLeaseRepositoryProvider)),
);

/// The leases of one workspace, newest first.
final premisesLeasesProvider = FutureProvider.autoDispose
    .family<List<PremisesLease>, String>(
      (ref, workspaceId) =>
          ref.watch(premisesLeaseRepositoryProvider).fetchLeases(workspaceId),
    );
