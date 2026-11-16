// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — my groups of invoices on Me › Finances: the groups my
// personal home keeps, my personal home's installation (what a reference
// names for an invoice it answered), and each group read against the
// overview now.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../../../core/session/session_source.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/supabase_invoice_group_repository.dart';
import '../domain/finance_overview.dart';
import '../domain/invoice_groups.dart';
import 'finance_overview_provider.dart';

part 'invoice_group_providers.g.dart';

@riverpod
InvoiceGroupRepository invoiceGroupRepository(Ref ref) =>
    SupabaseInvoiceGroupRepository(ref.watch(personalClientProvider));

/// My personal home's installation id. Unknown by default; the composition
/// root reads it from my personal account (`financeHomeFromMe`, lib/app),
/// as it does the hosts.
@riverpod
Future<String?> financeHomeInstallation(Ref ref) async => null;

/// My groups, newest read; none while signed out. Each change is written,
/// then the groups are read again.
@riverpod
class InvoiceGroups extends _$InvoiceGroups {
  @override
  Future<List<InvoiceGroup>> build() async {
    if (ref.watch(authStateProvider).value == null) return const [];
    // CACHE-01 (#2557): the groups are this account's.
    ref.watch(sessionStateProvider.select((s) => s.value));
    return ref.watch(invoiceGroupRepositoryProvider).groups();
  }

  InvoiceGroupRepository get _repo => ref.read(invoiceGroupRepositoryProvider);

  Future<T> _then<T>(Future<T> Function(InvoiceGroupRepository) write) async {
    try {
      return await write(_repo);
    } finally {
      ref.invalidateSelf();
    }
  }

  /// The new group's id. Throws [InvoiceGroupRefused].
  Future<String> create(String name) => _then((r) => r.create(name));

  /// Throws [InvoiceGroupRefused].
  Future<void> rename(String groupId, String name) =>
      _then((r) => r.rename(groupId, name));

  Future<void> delete(String groupId) => _then((r) => r.delete(groupId));

  Future<void> add(String groupId, InvoiceRef invoice, String number) =>
      _then((r) => r.add(groupId, invoice, number));

  Future<void> remove(String groupId, InvoiceRef invoice) =>
      _then((r) => r.remove(groupId, invoice));
}

/// The reference of an invoice My finances shows, or null when its
/// installation cannot be told (then it is not offered for a group).
@riverpod
InvoiceRef? Function(FinanceInvoice) invoiceRefResolver(Ref ref) {
  final overview = ref.watch(financeOverviewProvider).value;
  final home = ref.watch(financeHomeInstallationProvider).value;
  return (invoice) => overview == null
      ? null
      : invoiceRefOf(overview, invoice, homeInstallationId: home);
}

/// Each of my groups as the overview reads it now, by group id.
@riverpod
Map<String, InvoiceGroupView> invoiceGroupViews(Ref ref) {
  final groups = ref.watch(invoiceGroupsProvider).value ?? const []; // empty-ok: while the groups are read or failed, no group narrows the lists; the groups row shows the failure with Try again
  final overview =
      ref.watch(financeOverviewProvider).value ?? const FinanceOverview(); // empty-ok: before the overview answers, a group shows its references as unreadable, never an old amount
  final home = ref.watch(financeHomeInstallationProvider).value;
  return {
    for (final g in groups)
      g.id: invoiceGroupView(g, overview, homeInstallationId: home),
  };
}
