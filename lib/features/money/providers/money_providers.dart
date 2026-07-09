// SPDX-License-Identifier: MIT
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_money_repository.dart';
import '../domain/ledger_entry.dart';
import '../domain/money_repository.dart';
import '../domain/plan.dart';
import '../domain/service_item.dart';
import '../domain/statement.dart';

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

/// Active plans of the current workspace.
@Riverpod(keepAlive: true)
Future<List<Plan>> plans(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchPlans(workspace.id);
}

/// Current period key in workspace terms ('yyyy-MM').
String currentPeriod() => DateFormat('yyyy-MM').format(DateTime.now());

/// Every plan incl. deactivated ones — the owner's plan editor (#105).
@riverpod
Future<List<Plan>> allPlans(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(moneyRepositoryProvider)
      .fetchPlans(workspace.id, includeInactive: true);
}

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
