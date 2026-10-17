// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/purchase_commands.dart';
import '../data/supabase_purchase_repository.dart';
import '../domain/purchase.dart';
import 'credit_providers.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => SupabasePurchaseRepository(ref.watch(moneyClientProvider)),
);

/// Capturing a supplier bill.
final purchaseCommandProvider = Provider<PurchaseCommands>(
  (ref) => PurchaseCommands(ref.watch(purchaseRepositoryProvider)),
);

/// The purchase documents the signed-in person may read, newest first.
final purchasesProvider = FutureProvider.autoDispose
    .family<List<PurchaseSummary>, String>(
      (ref, workspaceId) =>
          ref.watch(purchaseRepositoryProvider).fetchPurchases(workspaceId),
    );

/// One document with its lines and evidence.
final purchaseDetailProvider = FutureProvider.autoDispose
    .family<PurchaseDetail, ({String workspaceId, String purchaseId})>(
      (ref, key) => ref
          .watch(purchaseRepositoryProvider)
          .fetchDetail(key.workspaceId, key.purchaseId),
    );
