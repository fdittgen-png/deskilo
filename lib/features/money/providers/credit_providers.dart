// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/clock.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_credit_repository.dart';
import '../domain/credit_product.dart';
import '../domain/member_price_list.dart' show openDaysIn;
import '../domain/purchase.dart' show purchaseDecidePermission;

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

/// The space's currency, which its books are kept in; null until the space
/// is read.
final spaceCurrencyProvider = Provider.autoDispose<String?>(
  (ref) => ref.watch(currentWorkspaceProvider).value?.currencyCode,
);

/// Fail closed while identity/workspace is uncertain or the approval grant is gone.
final purchaseApprovalAccessProvider = Provider.family<bool, String>((
  ref,
  workspaceId,
) {
  final workspace = ref.watch(currentWorkspaceProvider);
  final member = ref.watch(myMemberProvider);
  final permissions = ref.watch(myPermissionsProvider);
  final features = ref.watch(enabledFeaturesSyncProvider);
  if (workspace.isLoading ||
      workspace.hasError ||
      member.isLoading ||
      member.hasError) {
    return false;
  }
  return workspace.value?.id == workspaceId &&
      member.value?.status.name == 'active' &&
      features.any((feature) => feature.name == 'purchases') &&
      permissions.any(
        (permission) => permission.wireName == purchaseDecidePermission,
      );
});

/// #3587 — the open business as the invoicing screens need it: its id, its
/// currency, its country, and its calendar day of an instant (the
/// workspace's own context; the plain calendar day while it is not ready).
typedef InvoicingBusiness = ({
  String id,
  String currency,
  String country,
  DateTime Function(DateTime instant) dayOf,
});

/// #3587 — the [InvoicingBusiness] in scope.
final invoicingBusinessProvider = Provider.autoDispose<InvoicingBusiness>((
  ref,
) {
  final workspace = ref.watch(currentWorkspaceProvider).value;
  return (
    id: workspace?.id ?? '',
    currency: workspace?.currencyCode ?? '',
    country: workspace?.countryCode ?? '',
    dayOf:
        ref.watch(readyWorkspaceContextProvider)?.calendar.dateOf ??
        (DateTime d) => DateTime(d.year, d.month, d.day),
  );
});

/// #3283 — the days this month the workspace is open (its open weekdays
/// less its closures), the basis a percentage level is explained on.
@riverpod
Future<int> monthOpenDays(Ref ref) async {
  final now = ref.watch(clockProvider).now();
  return openDaysIn(
    DateTime(now.year, now.month),
    await ref.watch(openWeekdaysProvider.future),
    [for (final c in await ref.watch(closureDaysProvider.future)) c.day],
  );
}
