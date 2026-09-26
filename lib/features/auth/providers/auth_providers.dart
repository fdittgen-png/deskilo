// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_auth_repository.dart';
import '../data/supabase_identity_binding_repository.dart';
import '../data/supabase_second_factor_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/identity_binding.dart';
import '../domain/second_factor.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    SupabaseAuthRepository(Supabase.instance.client);

@Riverpod(keepAlive: true)
Stream<String?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();

/// #1647 — the signed-in account's canonical-identity binding.
@Riverpod(keepAlive: true)
IdentityBindingRepository identityBindingRepository(Ref ref) =>
    SupabaseIdentityBindingRepository(Supabase.instance.client);

/// #1627 — the second factor a database decision needs.
@Riverpod(keepAlive: true)
SecondFactorRepository secondFactorRepository(Ref ref) =>
    SupabaseSecondFactorRepository(Supabase.instance.client);

/// #1608/#1611 — what this database lets the signed-in account do:
/// administrator, MCP eligibility. Re-read after every change.
@riverpod
Future<DatabaseCapabilities> myDatabaseCapabilities(Ref ref) =>
    ref.watch(identityBindingRepositoryProvider).databaseCapabilities();
