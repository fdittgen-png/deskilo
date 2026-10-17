// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2567 — suppliers.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/supplier_commands.dart';
import '../data/supabase_supplier_repository.dart';
import '../domain/supplier.dart';
import 'credit_providers.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) => SupabaseSupplierRepository(ref.watch(moneyClientProvider)),
);

/// Creating, changing, archiving and resolving.
final supplierCommandProvider = Provider<SupplierCommands>(
  (ref) => SupplierCommands(ref.watch(supplierRepositoryProvider)),
);

/// The suppliers of one workspace, archived ones included.
final suppliersProvider = FutureProvider.autoDispose
    .family<List<Supplier>, String>(
      (ref, workspaceId) =>
          ref.watch(supplierRepositoryProvider).fetchSuppliers(workspaceId),
    );

/// The source records waiting for a person to pick their supplier.
final supplierReviewsProvider = FutureProvider.autoDispose
    .family<List<SupplierReview>, String>(
      (ref, workspaceId) =>
          ref.watch(supplierRepositoryProvider).fetchReviews(workspaceId),
    );

/// One supplier's bank-detail revisions, newest first (managers only).
final supplierBankHistoryProvider = FutureProvider.autoDispose
    .family<
      List<SupplierBankRevision>,
      ({String workspaceId, String supplierId})
    >(
      (ref, key) => ref
          .watch(supplierRepositoryProvider)
          .fetchBankHistory(key.workspaceId, key.supplierId),
    );
