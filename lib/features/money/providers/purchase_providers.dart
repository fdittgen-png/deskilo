// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/purchase_commands.dart';
import '../data/supabase_purchase_repository.dart';
import '../domain/purchase.dart';
import 'credit_providers.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => SupabasePurchaseRepository(ref.watch(moneyClientProvider)),
);

/// Capturing a supplier bill or a member's receipt.
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

/// What the space owes for approved purchases: a member's own claims, a
/// manager's all of them.
final payablesProvider = FutureProvider.autoDispose
    .family<List<PayableRow>, String>(
      (ref, workspaceId) =>
          ref.watch(purchaseRepositoryProvider).fetchPayables(workspaceId),
    );

/// #2573 — the sites, levels and offices a purchase line can name.
final purchasePlacesProvider = FutureProvider.autoDispose
    .family<List<PurchasePlace>, String>(
      (ref, workspaceId) =>
          ref.watch(purchaseRepositoryProvider).fetchPlaces(workspaceId),
    );

/// The exchange rate recorded with a purchase in another currency than the
/// space's; null when none is.
final purchaseExchangeRateProvider = FutureProvider.autoDispose
    .family<DocumentExchangeRate?, ({String workspaceId, String purchaseId})>(
      (ref, key) => ref
          .watch(purchaseRepositoryProvider)
          .fetchExchangeRate(key.workspaceId, key.purchaseId),
    );

/// The sources an exchange rate may name, in display order.
final exchangeRateSourcesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(purchaseRepositoryProvider).fetchExchangeRateSources(),
);
