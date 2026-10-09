// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the app icon says "1", but not WHERE. Each of my spaces on
// Me › Home carries its own count, so the person sees which space and
// which side (production or development) the notifications belong to.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../directory/domain/messenger.dart';
import '../../directory/providers/messenger_providers.dart';
import '../../events/providers/event_providers.dart';
import '../../workspace/providers/workspace_providers.dart';

part 'space_attention_provider.g.dart';

/// What waits for me in each space, by workspace id.
///
/// The space I am in counts exactly what the app icon counts (decisions
/// waiting for me + unread messages), so its number is the icon's. Every
/// other space counts its unread conversations, muted and archived ones
/// staying quiet as they do on the Messages badge.
Map<String, int> spaceAttention({
  required UnifiedInbox? inbox,
  String? activeId,
  int activeCount = 0,
}) {
  final counts = <String, int>{};
  for (final entry in inbox?.entries ?? const <InboxEntry>[]) {
    final id = entry.workspaceId;
    if (id == null || id == activeId) continue;
    final flags = entry.flags;
    if ((flags?.muted ?? false) || (flags?.archived ?? false)) continue;
    if (entry.unread <= 0) continue;
    counts[id] = (counts[id] ?? 0) + entry.unread;
  }
  if (activeId != null && activeCount > 0) counts[activeId] = activeCount;
  return counts;
}

@riverpod
Map<String, int> spaceAttentionCounts(Ref ref) {
  final inbox = ref.watch(unifiedInboxProvider);
  final active = ref.watch(currentWorkspaceProvider).value;
  final pending = ref.watch(myPendingEventsProvider).value?.length ?? 0;
  final unread = ref.watch(unreadNoteCountProvider).value ?? 0;
  return spaceAttention(
    inbox: inbox.isReloading ? null : inbox.value,
    activeId: active?.id,
    activeCount: pending + unread,
  );
}
