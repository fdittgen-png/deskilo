// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/ui/edge_fade_scroll.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/notification_feed.dart';
import '../../domain/workspace_event.dart';
import '../../providers/notification_filter_providers.dart';
import '../event_labels.dart';

/// #598 -- the symbol of a grouping axis; it fronts both the chip and every
/// group header (where tapping it ungroups).
IconData feedGroupingIcon(FeedGrouping grouping) => switch (grouping) {
  FeedGrouping.type => Icons.category_outlined,
  FeedGrouping.date => Icons.today_outlined,
  FeedGrouping.user => Icons.person_outline,
  FeedGrouping.none => Icons.notes,
};

String _groupingLabel(AppLocalizations l10n, FeedGrouping grouping) =>
    switch (grouping) {
      FeedGrouping.type => l10n.notifGroupByType,
      FeedGrouping.date => l10n.notifGroupByDate,
      FeedGrouping.user => l10n.notifGroupByUser,
      FeedGrouping.none => '',
    };

/// #196 -- the semantic outcome trailing an event: pending waits,
/// applied/confirmed succeeded (green), rejected failed (red). Expired and
/// unknown (#1088) events carry no outcome mark.
Widget? eventOutcomeMark(BuildContext context, EventStatus status) =>
    switch (status) {
      EventStatus.pending => const Icon(Icons.hourglass_top, size: 18),
      EventStatus.applied || EventStatus.confirmed => Icon(
        Icons.check_circle_outline,
        size: 18,
        color: AppStatusColors.successOf(Theme.of(context).brightness),
      ),
      EventStatus.rejected => Icon(
        Icons.cancel_outlined,
        size: 18,
        color: Theme.of(context).colorScheme.error,
      ),
      EventStatus.expired || EventStatus.unknown => null,
    };

/// The feed's filter lines (#581): categories, read state with the sort
/// toggle, and -- when regrouping is on (#598) -- the grouping axis. Every
/// choice persists through the filter notifier.
class EventsFilterBar extends ConsumerWidget {
  const EventsFilterBar({
    super.key,
    required this.filter,
    required this.unreadCount,
    required this.groupingOn,
  });

  final NotificationFilterState filter;
  final int unreadCount;
  final bool groupingOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // #581 — ONE filter line: categories × read state, all
        // persisted. Empty category selection = everything.
        EdgeFadeScroll(
          padding: AppSpacing.mdH,
          child: Row(
            children: [
              FilterChip(
                key: const ValueKey('events-filter-all'),
                label: Text(l10n.eventsFilterAll),
                selected: filter.categories.isEmpty,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => ref
                    .read(notificationFilterProvider.notifier)
                    .clearCategories(),
              ),
              for (final category in NotificationCategory.values) ...[
                const SizedBox(width: 8),
                FilterChip(
                  key: ValueKey('notif-cat-${category.wire}'),
                  label: Text(notificationCategoryLabel(l10n, category)),
                  selected: filter.categories.contains(category),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => ref
                      .read(notificationFilterProvider.notifier)
                      .toggleCategory(category),
                ),
              ],
            ],
          ),
        ),
        // Read-state line, kept OFF the category line so both
        // stay reachable without scrolling (#539/#546 — the
        // keys predate the mixed feed).
        Padding(
          padding: AppSpacing.mdH,
          child: Row(
            children: [
              // #1184 — the same overflow strategy as the
              // category line above: the chips scroll and say
              // so, while the sort button keeps its place at
              // the end. As a plain Row this line ran off the
              // right of a narrow phone at a large text scale,
              // and a four-digit unread count did it at any
              // scale.
              Expanded(
                child: EdgeFadeScroll(
                  child: Row(
                    children: [
                      FilterChip(
                        key: const ValueKey('notes-filter-unread'),
                        label: Text(
                          '${l10n.notesFilterUnread}'
                          '${unreadCount == 0 ? '' : ' ($unreadCount)'}',
                        ),
                        selected: filter.read == ReadFilter.unread,
                        visualDensity: VisualDensity.compact,
                        onSelected: (value) => ref
                            .read(notificationFilterProvider.notifier)
                            .setRead(
                              value ? ReadFilter.unread : ReadFilter.all,
                            ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        key: const ValueKey('notes-filter-read'),
                        label: Text(l10n.notesFilterRead),
                        selected: filter.read == ReadFilter.read,
                        visualDensity: VisualDensity.compact,
                        onSelected: (value) => ref
                            .read(notificationFilterProvider.notifier)
                            .setRead(value ? ReadFilter.read : ReadFilter.all),
                      ),
                    ],
                  ),
                ),
              ),
              // #581 — flip the date sort; the choice persists
              // like the rest of the filter. It sat in an app
              // bar this screen no longer has (#702), and it
              // reads better here anyway: every other control
              // that shapes the list is on these two lines.
              IconButton(
                key: const ValueKey('events-sort-toggle'),
                tooltip: l10n.notifSortByDate,
                onPressed: () =>
                    ref.read(notificationFilterProvider.notifier).toggleSort(),
                icon: Icon(
                  filter.sort == FeedSort.newestFirst
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                ),
              ),
            ],
          ),
        ),
        // #598 — the regrouping line: fold the feed by type,
        // day or member. Tapping the selected chip — or the
        // symbol on any group header — returns to flat.
        if (groupingOn)
          EdgeFadeScroll(
            padding: AppSpacing.mdH,
            child: Row(
              children: [
                Text(
                  l10n.notifGroupBy,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                for (final axis in const [
                  FeedGrouping.type,
                  FeedGrouping.date,
                  FeedGrouping.user,
                ]) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    key: ValueKey('notif-group-${axis.name}'),
                    // #1191 — a selected chip draws its OWN
                    // tick, and it lands on the avatar: the
                    // group-by glyph under a checkmark reads
                    // as a dark smudge. The avatar IS the
                    // state here.
                    showCheckmark: false,
                    avatar: Icon(feedGroupingIcon(axis), size: 18),
                    label: Text(_groupingLabel(l10n, axis)),
                    selected: filter.grouping == axis,
                    visualDensity: VisualDensity.compact,
                    onSelected: (value) => ref
                        .read(notificationFilterProvider.notifier)
                        .setGrouping(value ? axis : FeedGrouping.none),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
