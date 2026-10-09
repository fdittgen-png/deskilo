// SPDX-License-Identifier: AGPL-3.0-or-later
// Invariant: Finance opens only the counted category; other updates and pending decisions keep their counts.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/attention_providers.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/events/providers/notification_filter_providers.dart';
import 'package:deskilo/features/events/presentation/widgets/pending_decisions_section.dart';
import 'package:deskilo/features/money/presentation/widgets/money_attention_body.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

void main() {
  testWidgets('Finance opens its alerts and keeps other updates unread', (tester) async {
    SharedPreferences.setMockInitialValues({'workspace_updates_seen_finance':
      kTestNow.subtract(const Duration(days: 1)).toIso8601String()});
    WorkspaceEvent event(String id, EventType type, EventStatus status) => WorkspaceEvent(
      id: id, workspaceId: 'ws-1', type: type, action: EventAction.created,
      status: status, actorMemberId: 'member-2', subjectMemberId: 'member-1',
      payload: const {}, createdAt: kTestNow.subtract(const Duration(minutes: 1)));
    final invoice = event('invoice-update', EventType.invoiceIssue, EventStatus.applied);
    final reservation = event('booking-update', EventType.reservation, EventStatus.applied);
    final pending = event('pending-payment', EventType.payment, EventStatus.pending);
    final pendingBooking = event('pending-booking', EventType.reservation, EventStatus.pending);
    final events = FakeEventRepository()..events.addAll([invoice, reservation, pending, pendingBooking]);
    await tester.pumpWidget(ProviderScope(overrides: [
      ...standardTestOverrides(events: events, updateSeenStore: PrefsUpdateSeenStore.new),
      attentionScopeProvider.overrideWithValue('finance'),
      myPendingEventsProvider.overrideWith((ref) async => [pending, pendingBooking]),
    ], child: const DeskiloApp()));
    await tester.pumpAndSettle();
    await tapNavIcon(tester, Icons.account_balance_wallet_outlined);
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('money-alerts'));
    final container = ProviderScope.containerOf(tester.element(entry));
    expect(container.read(workspaceAttentionProvider).money, 2);
    expect(find.descendant(of: entry, matching: find.text('2')), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(container.read(notificationFilterProvider).requireValue.categories, {NotificationCategory.money});
    expect(find.byKey(const ValueKey('notif-cat-money')), findsOneWidget);
    expect(container.read(workspaceAttentionProvider), (total: 3, updates: 1, pending: 2, money: 1));
    expect(tester.widget<PendingDecisionsSection>(find.byType(PendingDecisionsSection)).pending.map((event) => event.id), ['pending-payment']);
    await tapNavIcon(tester, Icons.account_balance_wallet_outlined);
    await container.read(notificationFilterProvider.notifier).toggleCategory(NotificationCategory.reservations);
    await tester.pumpAndSettle();
    expect(container.read(workspaceAttentionProvider).updates, 1, reason: 'a hidden feed reads nothing');
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final category = find.byKey(const ValueKey('notif-cat-reservations'));
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(container.read(workspaceAttentionProvider), (total: 2, updates: 0, pending: 2, money: 1));
  });

  testWidgets('a failed feed leaves its unread cutoff unchanged', (tester) async {
    final before = kTestNow.subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({'workspace_updates_seen_failure': before.toIso8601String()});
    await tester.pumpWidget(ProviderScope(overrides: [
      ...standardTestOverrides(updateSeenStore: PrefsUpdateSeenStore.new),
      attentionScopeProvider.overrideWithValue('failure'),
      eventsProvider.overrideWith((ref) async => throw StateError('unavailable')),
    ], child: const DeskiloApp()));
    await tester.pumpAndSettle();
    await tapNavIcon(tester, Icons.account_balance_wallet_outlined);
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('money-alerts'));
    final container = ProviderScope.containerOf(tester.element(entry));
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(container.read(updatesSeenProvider('failure')).requireValue.seenFor(NotificationCategory.money), before);
  });

  testWidgets('disabled Alerts never fetches counts or exposes its entry', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      workspaceAttentionProvider.overrideWith((ref) => throw StateError('must not fetch')),
    ], child: const MaterialApp(home: Scaffold(body:
      MoneyAttentionBody(enabled: false, child: SizedBox())))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('money-alerts')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final count in [0, 124]) {
    testWidgets('Finance entry fits enlarged text and caps count $count', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(overrides: [
        enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.eventsTab}),
        workspaceAttentionProvider.overrideWithValue((total: count, updates: count, pending: 0, money: count)),
      ], child: const MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: MoneyAttentionBody(enabled: true, child: SizedBox()))))));
      await tester.pumpAndSettle();
      expect(find.byType(Badge), count == 0 ? findsNothing : findsOneWidget);
      if (count > 99) expect(find.text('99+'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
