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
  const UpdateReadState(this.seenUntil, this.visitCutoff,
      {this.categories = const {}, this.visitCategories = const {}});
  final DateTime seenUntil;
  final DateTime visitCutoff;
  final Map<NotificationCategory, DateTime> categories, visitCategories;
  DateTime seenFor(NotificationCategory category) => _later(seenUntil, categories[category]);
  DateTime visitFor(NotificationCategory category) => _later(visitCutoff, visitCategories[category]);
  static DateTime _later(DateTime baseline, DateTime? value) =>
      value != null && value.isAfter(baseline) ? value : baseline;
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
    final categories = <NotificationCategory, DateTime>{};
    for (final category in NotificationCategory.values) {
      final value = DateTime.tryParse(await _categoryStore(category).read() ?? '');
      if (value != null) categories[category] = value;
    }
    return UpdateReadState(cutoff, cutoff, categories: categories, visitCategories: categories);
  }

  UpdateSeenStore _categoryStore(NotificationCategory category) =>
      ref.read(updateSeenStoreProvider('workspace_updates_seen_${scope}_${category.wire}'));

  Future<void> markOpened({Set<NotificationCategory> categories = const {},
      bool newVisit = true}) async {
    try {
      final loaded = await future;
      if (!ref.mounted) return;
      final previous = state.value ?? loaded;
      final now = ref.read(clockProvider).now();
      state = AsyncData(UpdateReadState(categories.isEmpty ? now : previous.seenUntil,
        newVisit ? previous.seenUntil : previous.visitCutoff,
        categories: {...previous.categories, for (final category in categories) category: now},
        visitCategories: newVisit ? previous.categories : previous.visitCategories));
      if (categories.isEmpty) {
        await ref.read(updateSeenStoreProvider('workspace_updates_seen_$scope')).write(now.toUtc().toIso8601String());
      } else {
        for (final category in categories) {
          await _categoryStore(category).write(now.toUtc().toIso8601String());
        }
      }
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
  T? loaded<T>(AsyncValue<T> value) => value.hasError || value.isReloading ? null : value.value;
  if (!ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.eventsTab)) {
    return (total: 0, updates: 0, pending: 0, money: 0);
  }
  final scope = ref.watch(attentionScopeProvider);
  final workspace = ref.watch(activeWorkspaceIdProvider).value;
  if (scope == null || workspace == null) {
    return (total: 0, updates: 0, pending: 0, money: 0);
  }
  final readState = loaded(ref.watch(updatesSeenProvider(scope)));
  final events = loaded(ref.watch(eventsProvider)) ?? const [];
  final pending = loaded(ref.watch(myPendingEventsProvider)) ?? const [];
  final pendingIds = {for (final e in pending) if (e.workspaceId == workspace) e.id};
  final newEvents = events.where((e) => e.workspaceId == workspace &&
      readState != null && e.createdAt.isAfter(readState.seenFor(categoryOfEvent(e)))).toList();
  final unread = loaded(ref.watch(unreadNoteIdsProvider)) ?? const <String>{};
  final notes = loaded(ref.watch(myNotesProvider)) ?? const [];
  final broadcasts = {for (final n in notes)
    if (n.workspaceId == workspace && n.isBroadcast && unread.contains(n.id)) n.id};
  final updates = {for (final e in newEvents) if (!pendingIds.contains(e.id)) e.id};
  final money = {for (final e in [...newEvents, ...pending])
    if (e.workspaceId == workspace && categoryOfEvent(e) == NotificationCategory.money) e.id};
  return (total: pendingIds.length + updates.length + broadcasts.length,
    updates: updates.length + broadcasts.length, pending: pendingIds.length,
    money: money.length);
}
