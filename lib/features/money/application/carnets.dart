// SPDX-License-Identifier: 0BSD
//
// #1279 — what the carnet surfaces ask for, and what each makes stale
// (ADR 0024: presentation says what was chosen, this decides the write).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../providers/credit_providers.dart';
import '../providers/money_providers.dart';

Future<void> addCarnet(
  WidgetRef ref, {
  required String name,
  required int halfDays,
  required int priceCents,
  int? validityMonths,
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  await ref.read(creditRepositoryProvider).createCreditProduct(workspace.id,
      name: name,
      halfDays: halfDays,
      priceCents: priceCents,
      validityMonths: validityMonths);
  ref.invalidate(creditProductsProvider);
}

Future<void> setCarnetActive(WidgetRef ref, String productId, bool active) async {
  await ref.read(creditRepositoryProvider).setCreditProductActive(productId, active);
  ref.invalidate(creditProductsProvider);
}

/// Sells a carnet: the sale is one charge on this month's bill, so the
/// statement and the ledger are stale as well as the balance.
Future<void> sellCarnet(WidgetRef ref, String memberId, String productId) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  await ref.read(creditRepositoryProvider).sellCredit(workspace.id, memberId, productId);
  ref
    ..invalidate(memberCreditBalanceProvider(memberId))
    ..invalidate(myStatementProvider)
    ..invalidate(myLedgerProvider);
}
