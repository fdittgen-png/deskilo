// SPDX-License-Identifier: MIT
import 'package:deskilo/features/events/domain/event_repository.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';

/// In-memory [EventRepository] mimicking respond_to_event semantics.
class FakeEventRepository implements EventRepository {
  final events = <WorkspaceEvent>[];

  @override
  Future<List<WorkspaceEvent>> fetchEvents(
    String workspaceId, {
    int limit = 100,
  }) async {
    return events.where((e) => e.workspaceId == workspaceId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> respond(String eventId, {required bool accept}) async {
    final i = events.indexWhere((e) => e.id == eventId);
    if (i < 0) throw StateError('unknown event');
    if (events[i].status != EventStatus.pending) {
      throw StateError('already decided');
    }
    events[i] = events[i].copyWith(
      status: accept ? EventStatus.confirmed : EventStatus.rejected,
      decidedAt: DateTime.now(),
    );
  }
}
