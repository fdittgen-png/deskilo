// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — the kinds of business, and the workspace's own.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/business_kind_commands.dart';
import '../data/supabase_business_kind_repository.dart';
import '../domain/business_kind.dart';
import '../domain/business_profile.dart';
import 'settings_providers.dart';
import 'workspace_providers.dart';

part 'business_kind_providers.g.dart';

@Riverpod(keepAlive: true)
BusinessKindRepository businessKindRepository(Ref ref) =>
    SupabaseBusinessKindRepository(ref.watch(selectedWorkspaceClientProvider));

/// The kinds of business, in their order.
@riverpod
Future<List<BusinessKind>> businessKinds(Ref ref) =>
    ref.watch(businessKindRepositoryProvider).kinds();

/// What the selected workspace says it is (coworking until it says otherwise).
@riverpod
Future<BusinessProfile> businessProfile(Ref ref) async =>
    BusinessProfile.fromSettings(
      await ref.watch(currentSettingsProvider.future),
    );

/// What the kind chooser does.
@riverpod
BusinessKindCommands businessKindCommands(Ref ref) => BusinessKindCommands(
  ref.watch(businessKindRepositoryProvider),
  ref.watch(workspaceRepositoryProvider),
);
