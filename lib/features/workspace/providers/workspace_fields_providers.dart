// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_workspace_fields.dart';
import '../domain/workspace_field.dart';
import '../domain/workspace_fields_repository.dart';
import '../domain/workspace_feature.dart';
import 'workspace_providers.dart';

part 'workspace_fields_providers.g.dart';

/// #1288 — the questions a workspace asks, and the answers to them.
@Riverpod(keepAlive: true)
WorkspaceFieldsRepository workspaceFieldsRepository(Ref ref) =>
    SupabaseWorkspaceFields(Supabase.instance.client);

/// The active workspace's questions, or none while the feature is off.
///
/// The flag is read here rather than in each form, so a workspace that
/// never turned it on makes no request at all — the identity form is
/// byte-identical to what it was, which is what #1288 asks for.
@riverpod
Future<List<WorkspaceField>> workspaceFields(Ref ref) async {
  if (!ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.customFields)) {
    return const [];
  }
  // Watched BEFORE the await: a watch after one is registered on a ref
  // that may already be disposed (provider_watch_before_await).
  final pending = ref.watch(currentWorkspaceProvider.future);
  final repository = ref.watch(workspaceFieldsRepositoryProvider);
  final workspace = await pending;
  if (workspace == null) return const [];
  return repository.fetchFields(workspace.id);
}

/// One member's answers, keyed by field key.
@riverpod
Future<Map<String, Object?>> memberFieldAnswers(Ref ref, String memberId) async {
  final pending = ref.watch(workspaceFieldsProvider.future);
  final repository = ref.watch(workspaceFieldsRepositoryProvider);
  if ((await pending).isEmpty) return const {};
  return repository.fetchAnswers(memberId);
}
