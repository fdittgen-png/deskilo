// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3099 (PERF-2) — what one change signal costs the inbox, counted on the
// demo event repository. A burst of `events` signals is one list read; a
// decision re-reads the decisions only, never the 100-row events page.
import 'dart:async';

import 'package:deskilo/app/realtime_invalidations.dart';
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = Workspace(
  id: 'ws-a',
  name: 'ws-a',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE22',
);

class _Sync implements RealtimeSync {
  final feed = StreamController<String>();
  @override
  Stream<String> watch(String workspaceId) => feed.stream;
  @override
  Stream<String> watchAccount() => const Stream.empty();
}

class _CountingEvents extends FakeEventRepository {
  int lists = 0;
  int decisionReads = 0;

  @override
  Future<List<WorkspaceEvent>> fetchEvents(
    String workspaceId, {
    int limit = 100,
  }) {
    lists++;
    return super.fetchEvents(workspaceId, limit: limit);
  }

  @override
  Future<Map<String, List<EventDecision>>> fetchDecisions(
    String workspaceId,
    List<String> eventIds,
  ) {
    decisionReads++;
    return super.fetchDecisions(workspaceId, eventIds);
  }
}

void main() {
  late _Sync sync;
  late _CountingEvents repo;

  Future<void> start(WidgetTester tester) async {
    sync = _Sync();
    repo = _CountingEvents()
      ..events.add(
        WorkspaceEvent(
          id: 'ev-1',
          workspaceId: _ws.id,
          type: EventType.invoiceIssue,
          action: EventAction.created,
          status: EventStatus.pending,
          actorMemberId: 'other',
          subjectMemberId: 'member-1',
          payload: const {},
          createdAt: DateTime.utc(2026, 10, 30, 9),
        ),
      );
    final container = ProviderContainer(
      overrides: [
        ...realtimeWiringFromApp,
        ...realtimeSyncOverrides(sync),
        eventRepositoryProvider.overrideWithValue(repo),
        currentWorkspaceProvider.overrideWith((ref) async => _ws),
      ],
    );
    addTearDown(container.dispose);
    final subs = [
      container.listen(
        realtimeInvalidatorProvider(RealtimeTarget.workspace),
        (_, _) {},
      ),
      container.listen(eventsProvider, (_, _) {}),
      container.listen(eventDecisionsProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });
    await container.read(
      realtimeInvalidatorProvider(RealtimeTarget.workspace).future,
    );
    await container.read(eventDecisionsProvider.future);
    await tester.pump();
    repo
      ..lists = 0
      ..decisionReads = 0;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 10));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('5 events signals within the debounce: one list read', (
    tester,
  ) async {
    await start(tester);
    for (var i = 0; i < 5; i++) {
      sync.feed.add('events');
    }
    await settle(tester);
    expect(repo.lists, 1);
  });

  testWidgets('a decision re-reads the decisions, never the events page', (
    tester,
  ) async {
    await start(tester);
    sync.feed.add('event_decisions');
    await settle(tester);
    expect(repo.lists, 0);
    expect(repo.decisionReads, 1);
  });
}
