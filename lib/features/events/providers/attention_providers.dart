// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/backend/backend_settings.dart';
import '../../../core/storage/prefs_stores.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/trace_logger.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../domain/notification_feed.dart';
import 'event_providers.dart';

part 'attention_providers.g.dart';

abstract class UpdateSeenStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class PrefsUpdateSeenStore extends PrefsStringStore implements UpdateSeenStore {
  const PrefsUpdateSeenStore(super.key);
}

class InMemoryUpdateSeenStore implements UpdateSeenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

@Riverpod(keepAlive: true)
UpdateSeenStore updateSeenStore(Ref ref, String key) => PrefsUpdateSeenStore(key);

/// A device acknowledgement belongs to one person, server and workspace.
@riverpod
String? attentionScope(Ref ref) {
  final account = ref.watch(currentAccountIdProvider);
  final workspace = ref.watch(activeWorkspaceIdProvider).value;
  final server = ref.watch(activeBackendProvider).value?.url;
  return account == null || workspace == null || server == null
      ? null : jsonEncode([server, account, workspace]);
}

class UpdateReadState {
  const UpdateReadState(this.seenUntil, this.visitCutoff);
  final DateTime seenUntil;
  final DateTime visitCutoff;
}

/// Badges clear immediately; the currently visible feed retains its new rows.
@Riverpod(keepAlive: true)
class UpdatesSeen extends _$UpdatesSeen {
  @override
  Future<UpdateReadState> build(String scope) async {
    final now = ref.watch(clockProvider).now();
    final store = ref.read(updateSeenStoreProvider('workspace_updates_seen_$scope'));
    final stored = DateTime.tryParse(await store.read() ?? '');
    final cutoff = stored ?? now;
    if (stored == null) await store.write(cutoff.toUtc().toIso8601String());
    return UpdateReadState(cutoff, cutoff);
  }

  Future<void> markOpened() async {
    try {
      final previous = await future;
      if (!ref.mounted) return;
      final now = ref.read(clockProvider).now();
      state = AsyncData(UpdateReadState(now, previous.seenUntil));
      await ref.read(updateSeenStoreProvider('workspace_updates_seen_$scope'))
          .write(now.toUtc().toIso8601String());
    } catch (e, st) {
      TraceLogger.instance.warn('events', 'update acknowledgement unavailable',
          error: e, stackTrace: st);
    }
  }
}

typedef AttentionCounts = ({int total, int updates, int pending, int money});

/// The count uses the same authorized feed and pending-decision list as Alerts.
/// An unread pending event counts once, and direct messages stay in Messages.
@riverpod
AttentionCounts workspaceAttention(Ref ref) {
  if (!ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.eventsTab)) {
    return (total: 0, updates: 0, pending: 0, money: 0);
  }
  final scope = ref.watch(attentionScopeProvider);
  final workspace = ref.watch(activeWorkspaceIdProvider).value;
  if (scope == null || workspace == null) {
    return (total: 0, updates: 0, pending: 0, money: 0);
  }
  final cutoff = ref.watch(updatesSeenProvider(scope)).value?.seenUntil;
  final events = ref.watch(eventsProvider).value ?? const [];
  final pending = ref.watch(myPendingEventsProvider).value ?? const [];
  final pendingIds = {for (final e in pending) if (e.workspaceId == workspace) e.id};
  final newEvents = events.where((e) => e.workspaceId == workspace &&
      cutoff != null && e.createdAt.isAfter(cutoff)).toList();
  final unread = ref.watch(unreadNoteIdsProvider).value ?? const <String>{};
  final notes = ref.watch(myNotesProvider).value ?? const [];
  final broadcasts = {for (final n in notes)
    if (n.workspaceId == workspace && n.isBroadcast && unread.contains(n.id)) n.id};
  final updates = {for (final e in newEvents) if (!pendingIds.contains(e.id)) e.id};
  final money = {for (final e in [...newEvents, ...pending])
    if (e.workspaceId == workspace && categoryOfEvent(e) == NotificationCategory.money) e.id};
  return (total: pendingIds.length + updates.length + broadcasts.length,
    updates: updates.length + broadcasts.length, pending: pendingIds.length,
    money: money.length);
}
