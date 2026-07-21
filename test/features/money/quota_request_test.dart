// SPDX-License-Identifier: 0BSD
//
// Quota enforcement + extension requests (migration 0031): reservations
// are capped by the subscription entitlement; a member who needs more
// requests a number of half-days, and owners/admins validate per the
// owner's policy. These tests cover the client half: the request flow
// on the Money tab, the quota event in the feed, and the booking error
// mapping when the server rejects a beyond-quota reservation.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/quota_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import '../plan/plan_closed_day_test.dart'
    show ThrowingReservationRepository, pumpAvailabilityPlan;
import '../plan/plan_screen_test.dart' show seatCenter;
import 'money_screen_test.dart' show pumpMoney;

void main() {
  testWidgets(
      'requesting extra half-days from the Money tab submits a pending '
      'quota event for the shown period', (tester) async {
    final events = FakeEventRepository();
    await pumpMoney(tester, events: events);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('quota-request-button')),
      100,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('quota-request-button')),
    );
    await tester.tap(find.byKey(const ValueKey('quota-request-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('quota-request-count')),
      '4',
    );
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    final request = events.events.single;
    expect(request.type, EventType.quota);
    expect(request.status, EventStatus.pending);
    expect(request.payload['half_days'], 4);
    expect(
      request.payload['period'],
      DateFormat('yyyy-MM').format(DateTime.now()),
    );
    expect(
      find.text('Request sent — waiting for validation.'),
      findsOneWidget,
    );
  });

  testWidgets('a quota request needs another admin to decide it',
      (tester) async {
    final events = FakeEventRepository();
    await pumpMoney(tester, events: events);
    await events.requestQuotaExtension(
      'ws-1',
      period: '2026-07',
      halfDays: 4,
    );

    expect(events.events.single.needsAdminDecider, isTrue);
  });

  testWidgets('the events feed names the quota request', (tester) async {
    final events = FakeEventRepository()..respondingMemberId = 'member-1';
    await events.requestQuotaExtension(
      'ws-1',
      period: '2026-07',
      halfDays: 4,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          events: events,
          workspace: FakeWorkspaceRepository.withWorkspace()
            ..memberNames = {'member-1': 'Flo'},
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Flo requests 4 extra half-days for 2026-07'),
      findsOneWidget,
    );
  });

  testWidgets(
      'a beyond-quota refusal from the booking RPC maps to the quota '
      'message with the request pointer', (tester) async {
    await pumpAvailabilityPlan(
      tester,
      reservations: ThrowingReservationRepository(
        const PostgrestException(
          // Pins assert_member_quota's error text (0031) via
          // QuotaExceededError.serverSubstring.
          message: 'half-day quota exceeded — request additional half-days',
        ),
      ),
    );
    expect(
      'half-day quota exceeded — request additional half-days',
      contains(QuotaExceededError.serverSubstring),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Monthly half-day quota reached — request extra half-days '
          'from the Money tab.'),
      findsOneWidget,
    );
  });
}
