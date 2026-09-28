// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/workspace_application.dart';
import '../data/supabase_workspace_application_repository.dart';
import '../application/application_replies.dart';

part 'workspace_application_providers.g.dart';

@Riverpod(keepAlive: true)
WorkspaceApplicationRepository workspaceApplicationRepository(Ref ref) =>
    SupabaseWorkspaceApplicationRepository(Supabase.instance.client);

@riverpod
ApplicationReplies applicationReplies(Ref ref) =>
    ApplicationReplies(ref.watch(workspaceApplicationRepositoryProvider));

@riverpod
Future<List<WorkspaceApplication>> workspaceApplications(
  Ref ref, {
  ApplicationCursor? before,
}) {
  if (ref.watch(authStateProvider).value == null) return Future.value([]);
  return ref.watch(workspaceApplicationRepositoryProvider).list(before: before);
}

@riverpod
Future<List<ApplicationMessage>> workspaceApplicationThread(
  Ref ref,
  String id, {
  ApplicationCursor? before,
}) {
  if (ref.watch(authStateProvider).value == null) return Future.value([]);
  return ref
      .watch(workspaceApplicationRepositoryProvider)
      .thread(id, before: before);
}
