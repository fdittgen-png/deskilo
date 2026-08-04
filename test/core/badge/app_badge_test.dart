// SPDX-License-Identifier: 0BSD
//
// App-icon badge (#426): the pending-confirmations count lands on the
// launcher icon whenever the count changes — the same number as the
// in-app bell, which the realtime invalidations keep fresh.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_notification_service.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('the shell pushes the pending count to the app badge '
      'AND mirrors each pending as an active notification (#432)',
      (tester) async {
    final badge = FakeAppBadge();
    final notifications = FakeNotificationService();
    final events = FakeEventRepository()
      ..events.add(WorkspaceEvent(
        id: 'evt-1',
        workspaceId: 'ws-1',
        type: EventType.reservation,
        action: EventAction.created,
        actorMemberId: 'member-2',
        subjectMemberId: 'member-1',
        reservationId: 'res-1',
        payload: const {
          'starts_at': '2026-07-08T09:00:00Z',
          'ends_at': '2026-07-08T17:00:00Z',
          'seat_id': 'seat-4',
        },
        status: EventStatus.pending,
        createdAt: kTestNow,
      ));
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
            events: events, badge: badge, notifications: notifications),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(badge.counts, isNotEmpty,
        reason: 'the shell wired the count to the icon');
    expect(badge.counts.last, 1,
        reason: 'one pending confirmation → 1 on the icon');
    // #432: One UI counts ACTIVE notifications — the mirror gives the
    // launcher exactly one per pending confirmation.
    expect(notifications.pendingSyncs, isNotEmpty);
    expect(notifications.pendingSyncs.last, hasLength(1));
    expect(notifications.pendingSyncs.last.single.id, 'evt-1');
  });
}
