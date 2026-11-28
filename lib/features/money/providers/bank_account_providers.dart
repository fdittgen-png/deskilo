// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- the bank accounts of a business, and the names statements were imported under that no account carries.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_bank_account_repository.dart';
import '../domain/bank/bank_account.dart';
import 'credit_providers.dart' show moneyClientProvider;

/// Where the bank accounts live: the server's; the Demo its own.
final bankAccountRepositoryProvider = Provider<BankAccountRepository>(
  (ref) => SupabaseBankAccountRepository(ref.watch(moneyClientProvider)),
  name: 'bankAccountRepositoryProvider',
);

/// The accounts of a business, active first, by name: what the import picks from and the Master data card counts.
final bankAccountsProvider = FutureProvider.autoDispose.family<List<BankAccount>, String>(
  (ref, workspaceId) => ref.watch(bankAccountRepositoryProvider).accounts(workspaceId),
  retry: (_, _) => null,
);

/// The names earlier statements were imported under that no account carries yet.
final unattachedBankNamesProvider = FutureProvider.autoDispose.family<List<UnattachedBankName>, String>(
  (ref, workspaceId) => ref.watch(bankAccountRepositoryProvider).unattached(workspaceId),
  retry: (_, _) => null,
);
