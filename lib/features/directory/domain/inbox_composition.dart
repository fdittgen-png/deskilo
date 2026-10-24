// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2556 C1 -- the inbox composed from its sources: every row a source has
// read, merged as `mergeInboxes` merges servers, with each source's own
// state beside it. Pure Dart.
import 'inbox_sources.dart';
import 'messenger.dart';

/// The merged inbox and the state of each source it was composed from.
class ComposedInbox extends UnifiedInbox {
  const ComposedInbox(super.entries, {required this.sources});

  /// Each source's own state, in the order of [inboxSlotsFor].
  final List<InboxSlot> sources;

  /// A source's first page is still being read.
  bool get reading => sources.any((s) => s.state == InboxSlotState.reading);

  /// A source has older conversations than the list shows.
  bool get hasMore => sources.any((s) => s.hasMore);

  /// A further page is being read.
  bool get loadingMore => sources.any((s) => s.loadingMore);
}

/// Every row the [slots] read, merged (the same conversation read twice,
/// as a legacy server answers both roles, is shown once).
///
/// A row is shown only down to the horizon: the oldest row of each source
/// that still has more, the latest of them. Below it, a source's next page
/// could still hold a newer row, so nothing there is shown yet -- a later
/// page never lands above what is already on screen.
ComposedInbox composeInbox(List<InboxSlot> slots) {
  final bySource = <String, List<InboxRow>>{};
  DateTime? horizon;
  for (final slot in slots) {
    if (slot.rows.isEmpty) continue;
    (bySource[slot.source] ??= []).addAll(slot.rows);
    if (slot.hasMore) {
      final last = InboxEntry.fromRow(slot.rows.last)?.lastAt;
      if (last != null && (horizon == null || last.isAfter(horizon))) {
        horizon = last;
      }
    }
  }
  final edge = horizon;
  return ComposedInbox([
    for (final e in mergeInboxes(bySource).entries)
      if (edge == null || !e.lastAt.isBefore(edge)) e,
  ], sources: List.unmodifiable(slots));
}
