// SPDX-License-Identifier: MIT
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_money_repository.dart';
import '../domain/fee_band.dart';
import '../domain/ledger_entry.dart';
import '../domain/money_repository.dart';
import '../domain/package.dart';
import '../domain/service_item.dart';
import '../domain/statement.dart';
import '../domain/subscription_levels.dart';

part 'money_providers.g.dart';

@Riverpod(keepAlive: true)
MoneyRepository moneyRepository(Ref ref) =>
    SupabaseMoneyRepository(Supabase.instance.client);

/// The signed-in member's statement for a period ('yyyy-MM').
@riverpod
Future<Statement?> myStatement(Ref ref, String period) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return null;
  return ref.watch(moneyRepositoryProvider).fetchStatement(member.id, period);
}

/// The signed-in member's full ledger, newest first.
@riverpod
Future<List<LedgerEntry>> myLedger(Ref ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchLedger(member.id);
}

/// Fee bands of the current workspace, ordered by from_pct (#128).
@Riverpod(keepAlive: true)
Future<List<FeeBand>> feeBands(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchFeeBands(workspace.id);
}

/// Offered subscription levels of the current workspace (#128).
@Riverpod(keepAlive: true)
Future<SubscriptionLevels> subscriptionLevels(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const SubscriptionLevels();
  return ref
      .watch(moneyRepositoryProvider)
      .fetchSubscriptionLevels(workspace.id);
}

/// Current period key in workspace terms ('yyyy-MM').
String currentPeriod() => DateFormat('yyyy-MM').format(DateTime.now());

/// Active consumable services of the current workspace (#123).
@Riverpod(keepAlive: true)
Future<List<ServiceItem>> services(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchServices(workspace.id);
}

/// Every service incl. deactivated ones — the owner's catalog editor (#123).
@riverpod
Future<List<ServiceItem>> allServices(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(moneyRepositoryProvider)
      .fetchServices(workspace.id, includeInactive: true);
}

/// Active day packages of the current workspace — the member buy sheet
/// (migration 0042).
@riverpod
Future<List<Package>> packages(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchPackages(workspace.id);
}

/// Every package incl. deactivated ones — the owner's package editor.
@riverpod
Future<List<Package>> allPackages(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(moneyRepositoryProvider)
      .fetchPackages(workspace.id, includeInactive: true);
}
