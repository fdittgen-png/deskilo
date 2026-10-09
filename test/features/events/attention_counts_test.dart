// SPDX-License-Identifier: AGPL-3.0-or-later
// Invariant: alert counts belong to one person, server and workspace;
// reading new updates preserves pending decisions and the visible feed.
import 'dart:convert';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/attention_providers.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/mock_providers.dart';

class _Clock implements Clock {
  _Clock(this.at);
  DateTime at;
  @override
  DateTime now() => at;
}

void main() {
  final before = DateTime.utc(2026, 10, 8, 8);
  final now = DateTime.utc(2026, 10, 8, 9);
  WorkspaceEvent event(String id, {String workspace = 'ws-1', EventType type = EventType.invoiceIssue}) =>
      WorkspaceEvent(id: id, workspaceId: workspace, type: type,
        action: EventAction.created, status: EventStatus.applied,
        actorMemberId: 'other', subjectMemberId: 'member-1',
        payload: const {}, createdAt: now);
  MemberNote note(String id, {String? to}) => MemberNote(id: id, workspaceId: 'ws-1',
      fromMemberId: 'other', toMemberId: to, body: 'Update', createdAt: now);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a first visit establishes a baseline; a later visit keeps its new feed rows', () async {
    final clock = _Clock(before);
    final c = ProviderContainer(overrides: [clockProvider.overrideWithValue(clock)]);
    addTearDown(c.dispose);
    expect((await c.read(updatesSeenProvider('person-server-space').future)).seenUntil, before);
    clock.at = now;
    await c.read(updatesSeenProvider('person-server-space').notifier).markOpened();
    final opened = c.read(updatesSeenProvider('person-server-space')).requireValue;
    expect(opened.seenUntil, now);
    expect(opened.visitCutoff, before);
    final reloaded = ProviderContainer(overrides: [clockProvider.overrideWithValue(clock)]);
    addTearDown(reloaded.dispose);
    expect((await reloaded.read(updatesSeenProvider('person-server-space').future)).seenUntil, now);
    expect((await reloaded.read(updatesSeenProvider('another-person').future)).seenUntil, now);
  });

  test('the acknowledgement identity follows account, server and workspace', () async {
    final c = ProviderContainer(overrides: standardTestOverrides());
    addTearDown(c.dispose);
    final subscription = c.listen(attentionScopeProvider, (_, _) {});
    addTearDown(subscription.close);
    await c.read(activeWorkspaceIdProvider.future);
    final server = await c.read(activeBackendProvider.future);
    await c.pump();
    expect(c.read(attentionScopeProvider), jsonEncode([server.url, c.read(currentAccountIdProvider), 'ws-1']));
    c.read(activeWorkspaceIdProvider.notifier).activate('ws-2');
    await c.pump();
    expect(c.read(attentionScopeProvider), jsonEncode([server.url, c.read(currentAccountIdProvider), 'ws-2']));
  });

  test('new invoices and reminders count once; pending decisions survive reading', () async {
    SharedPreferences.setMockInitialValues({'workspace_updates_seen_scope': before.toIso8601String()});
    final pending = event('decision', type: EventType.payment);
    final c = ProviderContainer(overrides: [
      ...standardTestOverrides(clock: FixedClock(now), updateSeenStore: PrefsUpdateSeenStore.new),
      attentionScopeProvider.overrideWithValue('scope'),
      eventsProvider.overrideWith((ref) async => [event('invoice'), event('reminder', type: EventType.invoiceReminder), pending, event('foreign', workspace: 'ws-2')]),
      myPendingEventsProvider.overrideWith((ref) async => [pending]),
      myNotesProvider.overrideWith((ref) async => [note('broadcast'), note('direct', to: 'member-1')]),
      unreadNoteIdsProvider.overrideWith((ref) async => {'broadcast', 'direct'}),
    ]);
    addTearDown(c.dispose);
    final subscription = c.listen(workspaceAttentionProvider, (_, _) {});
    addTearDown(subscription.close);
    await c.read(activeWorkspaceIdProvider.future);
    await c.pump();
    await Future.wait([c.read(eventsProvider.future),
      c.read(myPendingEventsProvider.future), c.read(myNotesProvider.future),
      c.read(unreadNoteIdsProvider.future), c.read(updatesSeenProvider('scope').future)]);
    await c.pump();
    expect(c.read(workspaceAttentionProvider), (total: 4, updates: 3, pending: 1, money: 3));
    await c.read(updatesSeenProvider('scope').notifier).markOpened();
    await c.pump();
    expect(c.read(workspaceAttentionProvider), (total: 2, updates: 1, pending: 1, money: 1));
    c.read(activeWorkspaceIdProvider.notifier).activate('ws-2');
    await c.pump();
    expect(c.read(workspaceAttentionProvider).pending, 0);
  });

  test('disabled Alerts has no badge and never requests its feed', () async {
    final c = ProviderContainer(overrides: [
      enabledFeaturesSyncProvider.overrideWithValue(const <WorkspaceFeature>{}),
      eventsProvider.overrideWith((ref) => throw StateError('must not fetch')),
    ]);
    addTearDown(c.dispose);
    expect(c.read(workspaceAttentionProvider), (total: 0, updates: 0, pending: 0, money: 0));
  });
}
