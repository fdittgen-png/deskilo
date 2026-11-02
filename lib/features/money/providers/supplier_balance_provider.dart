// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_supplier_balance_repository.dart';
import '../domain/supplier_balance.dart';
import '../domain/supplier_payables_page.dart';
import 'credit_providers.dart';

final supplierBalanceRepositoryProvider = Provider<SupplierBalanceRepository>(
  (ref) => SupabaseSupplierBalanceRepository(ref.watch(moneyClientProvider)),
);

/// The aggregate is scoped to the workspace and errors are not zero balances.
final supplierBalancesProvider = FutureProvider.autoDispose
    .family<List<SupplierBalance>, String>(
      (ref, workspaceId) =>
          ref.watch(supplierBalanceRepositoryProvider).fetchBalances(workspaceId),
    );

/// Each request names a supplier and cursor, so callers cannot mistake a
/// partial result for the complete list.
final supplierPayablesPageProvider = FutureProvider.autoDispose.family<
  SupplierPayablesPage,
  ({String workspaceId, String supplierId, SupplierPayablesCursor? after})
>((ref, key) => ref.watch(supplierBalanceRepositoryProvider).fetchPayables(
  key.workspaceId,
  key.supplierId,
  after: key.after,
));
