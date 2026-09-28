// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/supabase_account_activity_repository.dart';
import '../domain/account_activity.dart';
part 'account_activity_providers.g.dart';

@Riverpod(keepAlive: true)
AccountActivityRepository accountActivityRepository(Ref ref) =>
    SupabaseAccountActivityRepository(Supabase.instance.client);

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
