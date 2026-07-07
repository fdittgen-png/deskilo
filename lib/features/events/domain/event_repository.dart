// SPDX-License-Identifier: MIT
import 'workspace_event.dart';

/// Events boundary. Fetching also triggers the lazy timeout sweep
/// (spec §8.2) until Epic #9 adds a scheduled runner.
abstract class EventRepository {
  Future<List<WorkspaceEvent>> fetchEvents(String workspaceId, {int limit});

  /// Subject decision on a pending event; rejecting voids what the event
  /// would have applied (e.g. the tentative reservation).
  Future<void> respond(String eventId, {required bool accept});
}
