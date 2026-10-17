// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_credit_repository.dart';
import '../domain/credit_product.dart';

part 'credit_providers.g.dart';

/// #2564 O3 -- where every money source runs: the verified host of the
/// selected workspace, never the personal home and never the process-wide
/// client. Money factories take this one provider.
final moneyClientProvider = Provider<SupabaseClient>(
  (ref) => ref.watch(selectedWorkspaceClientProvider),
);

/// #1279 — carnets.
@Riverpod(keepAlive: true)
CreditRepository creditRepository(Ref ref) =>
    SupabaseCreditRepository(ref.watch(moneyClientProvider));

/// The current workspace's carnet catalogue, active and not.
@riverpod
Future<List<CreditProduct>> creditProducts(Ref ref) async {
  final repository = ref.watch(creditRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const <CreditProduct>[];
  return repository.fetchCreditProducts(workspace.id);
}

/// Half-days [memberId] can still spend.
@riverpod
Future<int> memberCreditBalance(Ref ref, String memberId) =>
    ref.watch(creditRepositoryProvider).memberCreditBalance(memberId);
