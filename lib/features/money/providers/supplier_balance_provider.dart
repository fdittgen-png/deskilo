// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_supplier_balance_repository.dart';
import '../domain/supplier_balance.dart';
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
