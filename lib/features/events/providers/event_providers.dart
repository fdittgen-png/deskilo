// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_event_repository.dart';
import '../domain/event_repository.dart';
import '../domain/workspace_event.dart';

part 'event_providers.g.dart';

@Riverpod(keepAlive: true)
EventRepository eventRepository(Ref ref) =>
    SupabaseEventRepository(Supabase.instance.client);

/// The active workspace's event feed, newest first (server-scoped by role).
@riverpod
Future<List<WorkspaceEvent>> events(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(eventRepositoryProvider).fetchEvents(workspace.id);
}
