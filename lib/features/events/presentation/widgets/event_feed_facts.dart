// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../../core/i18n/money_format.dart';
import '../../domain/event_decision.dart';
import '../../domain/notification_feed.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';

/// What one build of the feed reads, gathered once so the list, its rows
/// and its event tiles see the same values.
class EventFeedFacts {
  const EventFeedFacts({
    required this.filter,
    required this.groupingOn,
    required this.feed,
    required this.matchingPending,
    required this.unreadCount,
    required this.names,
    required this.targets,
    required this.currency,
    required this.decisions,
    required this.policies,
    required this.myMemberId,
  });

  final NotificationFilterState filter;

  /// The regrouping flag; OFF forces the flat list whatever was persisted.
  final bool groupingOn;
  final List<FeedItem> feed;

  /// The events awaiting my decision that the category filter keeps.
  final List<WorkspaceEvent> matchingPending;
  final int unreadCount;
  final Map<String, String> names;
  final Map<String, String> targets;
  final MoneyFormat currency;
  final Map<String, List<EventDecision>> decisions;
  final List<ValidationPolicy> policies;
  final String? myMemberId;

  bool get unreadOnly => filter.read == ReadFilter.unread;
  FeedGrouping get grouping => groupingOn ? filter.grouping : FeedGrouping.none;
}
