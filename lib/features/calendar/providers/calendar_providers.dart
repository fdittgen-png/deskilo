// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/calendar/calendar_item.dart';
import '../../../core/trace/traced.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_calendar_repository.dart';
import '../domain/calendar_repository.dart';

part 'calendar_providers.g.dart';

@Riverpod(keepAlive: true)
CalendarRepository calendarRepository(Ref ref) =>
    SupabaseCalendarRepository(Supabase.instance.client);

/// One range of the hub (#718), cached per [query] — a re-tap of the
/// same day costs nothing, a different day is a different key. Realtime
/// invalidates the whole family when any dated table changes, so a
/// booking made on another device lands in the open range too.
@riverpod
Future<CalendarPage> calendarItems(Ref ref, CalendarQuery query) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return CalendarPage.empty;
  return traced(
    'calendar',
    'calendar items',
    () => ref.read(calendarRepositoryProvider).fetchItems(workspace.id, query),
  );
}

/// Who could look at my data (#719).
@riverpod
Future<AccessMap> whoCanAccessMe(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return AccessMap.empty;
  return traced(
    'privacy',
    'who can access me',
    () => ref.read(calendarRepositoryProvider).whoCanAccessMe(workspace.id),
  );
}

/// Who DID look (#719): rows about me, or the workspace's for a member
/// who manages members — the server decides which.
@riverpod
Future<List<DataAccessEntry>> dataAccessLog(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return traced(
    'privacy',
    'access log',
    () => ref.read(calendarRepositoryProvider).fetchAccessLog(workspace.id),
  );
}
