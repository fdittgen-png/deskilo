// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2569 — the premises lease.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/commitment_commands.dart';
import '../application/lease_commands.dart';
import '../data/supabase_lease_commitment_repository.dart';
import '../data/supabase_premises_lease_repository.dart';
import '../domain/lease_commitment.dart';
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

final leaseCommitmentRepositoryProvider = Provider<LeaseCommitmentRepository>(
  (ref) => SupabaseLeaseCommitmentRepository(ref.watch(moneyClientProvider)),
);

/// Matching a bill to a lease's expected rent, and reversing a match.
final commitmentCommandProvider = Provider<CommitmentCommands>(
  (ref) => CommitmentCommands(ref.watch(leaseCommitmentRepositoryProvider)),
);

/// The occurrences of one lease, newest first, with what is matched.
final leaseCommitmentsProvider = FutureProvider.autoDispose
    .family<CommitmentPage, ({String workspaceId, String leaseId})>(
      (ref, key) => ref
          .watch(leaseCommitmentRepositoryProvider)
          .fetchCommitments(key.workspaceId, key.leaseId),
    );
