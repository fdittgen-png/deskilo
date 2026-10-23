// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/supabase_account_activity_repository.dart';
import '../domain/account_activity.dart';
import 'credit_providers.dart';

part 'account_activity_providers.g.dart';

@Riverpod(keepAlive: true)
AccountActivityRepository accountActivityRepository(Ref ref) =>
    SupabaseAccountActivityRepository(ref.watch(personalClientProvider));

/// My own documents at the SELECTED workspace, read on that workspace's own
/// installation: `my_finance_overview` runs there under the person's session
/// on that host, so a connected installation's invoices never travel through
/// the personal home's client and are never answered by it.
@Riverpod(keepAlive: true)
AccountActivityRepository selectedWorkspaceAccountActivityRepository(
  Ref ref,
) =>
    SupabaseAccountActivityRepository(ref.watch(moneyClientProvider));

@riverpod
Future<List<AccountActivity>> accountActivity(
  Ref ref,
  AccountActivityKind kind, {
  ActivityCursor? before,
}) {
  if (ref.watch(authStateProvider).value == null) return Future.value([]);
  return ref
      .watch(accountActivityRepositoryProvider)
      .list(kind, before: before);
}

@riverpod
Future<List<AccountActivity>> connectedAccountActivity(
  Ref ref,
  String source,
  AccountActivityKind kind, {
  ActivityCursor? before,
}) {
  ref.watch(authStateProvider);
  return ref
      .watch(connectedInstallationsProvider)
      .use(
        source,
        (client) =>
            SupabaseAccountActivityRepository(client)
                .list(kind, before: before),
      );
}
